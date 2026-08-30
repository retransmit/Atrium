import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

/// The chosen sort has to outlive the process.
///
/// Issue #143: the order was held in a plain in-memory provider, so every
/// launch threw the choice away and went back to newest-first. These cover the
/// round trip through the settings box, and the two ways stored text can go
/// stale between versions.
void main() {
  group('with Hive open', () {
    late Directory tempDir;
    late Box<String> box;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qbit_sort_test');
      Hive.init(tempDir.path);
      box = await Hive.openBox<String>(AtriumBoxes.settings);
    });

    tearDown(() async {
      await box.clear();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('starts at newest first when nothing has been stored', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      final QbitSortConfig config = c.read(qbitSortProvider(_instance));

      expect(config.field, QbitSortField.addedOn);
      expect(config.ascending, isFalse);
    });

    test('a chosen field survives a restart', () async {
      final ProviderContainer first = ProviderContainer();
      await first
          .read(qbitSortProvider(_instance).notifier)
          .setField(QbitSortField.name);
      first.dispose();

      // A fresh container is what a relaunch looks like: the notifier is built
      // again from nothing but the box.
      final ProviderContainer second = ProviderContainer();
      addTearDown(second.dispose);

      expect(
        second.read(qbitSortProvider(_instance)).field,
        QbitSortField.name,
      );
    });

    test('the direction survives a restart too', () async {
      final ProviderContainer first = ProviderContainer();
      await first.read(qbitSortProvider(_instance).notifier).toggleDirection();
      first.dispose();

      final ProviderContainer second = ProviderContainer();
      addTearDown(second.dispose);

      expect(second.read(qbitSortProvider(_instance)).ascending, isTrue);
    });

    test('two instances are remembered separately', () async {
      const Instance other = Instance(
        id: 'second-qbit',
        name: 'Second',
        kind: ServiceKind.qbittorrent,
        localUrl: 'http://localhost',
        externalUrl: '',
        urlMode: UrlMode.auto,
        auth: InstanceAuth.apiKey(apiKey: 'k'),
      );

      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      await c
          .read(qbitSortProvider(_instance).notifier)
          .setField(QbitSortField.ratio);

      // Someone running two servers is likely to want them ordered
      // differently, so one must not drag the other with it.
      expect(c.read(qbitSortProvider(other)).field, QbitSortField.addedOn);
    });

    test('a field name the enum no longer has falls back rather than wedging',
        () async {
      // A later version could drop a sort field. Stored text naming it must
      // not leave the list unsortable.
      await box.put('qbit.sort.${_instance.id}', 'fieldThatWasRemoved:asc');

      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(qbitSortProvider(_instance)).field, QbitSortField.addedOn);
    });

    test('malformed stored text falls back', () async {
      await box.put('qbit.sort.${_instance.id}', 'nonsense');

      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(qbitSortProvider(_instance)).field, QbitSortField.addedOn);
      expect(c.read(qbitSortProvider(_instance)).ascending, isFalse);
    });
  });

  test('without Hive booted it still sorts, it just forgets', () async {
    // Widget tests never open the box. Sorting has to keep working there
    // rather than throwing on a box that was never registered.
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);

    await c
        .read(qbitSortProvider(_instance).notifier)
        .setField(QbitSortField.size);

    expect(c.read(qbitSortProvider(_instance)).field, QbitSortField.size);
  });
}

const Instance _instance = Instance(
  id: 'test-qbit',
  name: 'Test qBittorrent',
  kind: ServiceKind.qbittorrent,
  localUrl: 'http://localhost',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);
