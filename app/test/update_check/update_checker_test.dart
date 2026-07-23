// app/test/update_check/update_checker_test.dart
import 'dart:io';

import 'package:atrium/src/preferences.dart';
import 'package:atrium/src/update_check/update_check_state.dart';
import 'package:atrium/src/update_check/update_checker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:hive_ce/hive.dart';

import '../support/fake_http_client_adapter.dart';

Dio _dio(({int status, Object? data}) Function(RequestOptions) factory) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.github.com/'));
  dio.httpClientAdapter = FakeHttpClientAdapter(factory);
  return dio;
}

ProviderContainer _container(Box<String> box, Dio dio) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      settingsBoxProvider.overrideWithValue(box),
      githubDioProvider.overrideWithValue(dio),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  late Directory tempDir;
  late Box<String> box;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('atrium_update');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('settings');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteBoxFromDisk('settings');
    tempDir.deleteSync(recursive: true);
  });

  test('a newer release marks updateAvailable and is persisted', () async {
    final ProviderContainer c = _container(
      box,
      _dio((RequestOptions o) => (
            status: 200,
            data: <String, dynamic>{
              'tag_name': 'v1.2.0',
              'html_url': 'https://github.com/retransmit/Atrium/releases/tag/v1.2.0',
            },
          )),
    );
    await c.read(updateCheckProvider.notifier).check();
    final UpdateCheckState s = c.read(updateCheckProvider);
    expect(s.status, UpdateStatus.updateAvailable);
    expect(s.latestVersion, '1.2.0');
    expect(box.get('update.latestVersion'), '1.2.0');
  });

  test('the same release marks upToDate', () async {
    final ProviderContainer c = _container(
      box,
      _dio((RequestOptions o) =>
          (status: 200, data: <String, dynamic>{'tag_name': 'v1.1.0'})),
    );
    await c.read(updateCheckProvider.notifier).check();
    expect(c.read(updateCheckProvider).status, UpdateStatus.upToDate);
    expect(c.read(updateCheckProvider).hasNewer, isFalse);
  });

  test('a server error sets error but keeps a known available banner', () async {
    await box.put('update.latestVersion', '1.3.0');
    final ProviderContainer c = _container(
      box,
      _dio((RequestOptions o) => (status: 500, data: <String, dynamic>{})),
    );
    // build() re-derived updateAvailable from the cached 1.3.0.
    expect(c.read(updateCheckProvider).status, UpdateStatus.updateAvailable);
    await c.read(updateCheckProvider.notifier).check();
    final UpdateCheckState s = c.read(updateCheckProvider);
    expect(s.status, UpdateStatus.error);
    expect(s.hasNewer, isTrue);
  });

  test('build re-derives from cache with no network', () async {
    await box.put('update.latestVersion', '1.5.0');
    final ProviderContainer c = _container(
      box,
      _dio((RequestOptions o) => throw StateError('must not be called')),
    );
    final UpdateCheckState s = c.read(updateCheckProvider);
    expect(s.status, UpdateStatus.updateAvailable);
    expect(s.latestVersion, '1.5.0');
  });
}
