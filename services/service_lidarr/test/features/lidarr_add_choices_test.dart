import 'dart:async';
import 'dart:typed_data';

import 'package:core_storage/core_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

import 'test_helpers.dart';

/// Issue #234: the add sheet starts from the last choices on this instance.
class _Server {
  _Server({this.status = 201});

  final int status;
  Map<String, dynamic>? posted;

  /// Holds the add request open until completed.
  Completer<void>? gate;

  Dio dio() {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:8686/'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler h) {
          Object? data;
          int code = 200;
          switch (options.path) {
            case '/api/v1/rootfolder':
              data = <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1,
                  'path': '/data/music',
                  'defaultQualityProfileId': 1,
                  'defaultMetadataProfileId': 1,
                },
                <String, dynamic>{'id': 2, 'path': '/data/other'},
              ];
            case '/api/v1/qualityprofile':
              data = <Map<String, dynamic>>[
                <String, dynamic>{'id': 1, 'name': 'Any'},
                <String, dynamic>{'id': 2, 'name': 'FLAC Lossless'},
              ];
            case '/api/v1/metadataprofile':
              data = <Map<String, dynamic>>[
                <String, dynamic>{'id': 1, 'name': 'Standard'},
                <String, dynamic>{'id': 2, 'name': 'Lossless Studio'},
              ];
            case '/api/v1/tag':
              data = <Map<String, dynamic>>[];
            case '/api/v1/artist' when options.method == 'POST':
              posted = Map<String, dynamic>.from(options.data as Map);
              code = status;
              data = status < 300 ? options.data : <String, dynamic>{};
            default:
              return h.next(options);
          }
          void finish() {
            if (code >= 400) {
              return h.reject(
                DioException.badResponse(
                  statusCode: code,
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: code,
                    data: data,
                  ),
                ),
              );
            }
            h.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: code,
                data: data,
              ),
            );
          }

          final Completer<void>? held = gate;
          if (options.method == 'POST' && held != null) {
            unawaited(held.future.then((_) => finish()));
            return;
          }
          finish();
        },
      ),
    );
    return dio;
  }
}

const ArtistResource _artist = ArtistResource(
  artistName: 'The Smile',
  foreignArtistId: '654321-smile-mbid',
);

Future<void> _openAndAdd(
  WidgetTester tester,
  _Server server, {
  Future<List<RootFolderResource>>? folders,
  Future<List<MetadataProfileResource>>? metadata,
  Future<void> Function()? beforeAdd,
  Future<void> Function()? whileAdding,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final Dio dio = server.dio();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        lidarrApiProvider(testInstance).overrideWith((ref) => LidarrApi(dio)),
        lidarrArtistsProvider(testInstance).overrideWith((ref) async => []),
        if (folders != null)
          lidarrRootFoldersProvider(testInstance).overrideWith((ref) => folders),
        if (metadata != null)
          lidarrMetadataProfilesProvider(testInstance)
              .overrideWith((ref) => metadata),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: LidarrAddArtistSheet(instance: testInstance, artist: _artist),
        ),
      ),
    ),
  );
  if (folders == null && metadata == null) {
    await tester.pumpAndSettle();
  } else {
    // A loading spinner never settles: let everything else arrive.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  await beforeAdd?.call();
  await tester.tap(find.widgetWithText(FilledButton, 'Add Artist'));
  if (whileAdding != null) {
    // The add button spins while the request is held, so no settling here.
    for (int i = 0; i < 50 && server.posted == null; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await whileAdding();
  }
  await tester.pumpAndSettle();
}

Map<String, dynamic> _options(Map<String, dynamic> body) =>
    body['addOptions'] as Map<String, dynamic>;

void main() {
  late Box<String> box;

  // In memory: a file-backed box queues its disk writes on the widget test's
  // fake clock, and closing it then waits forever.
  setUp(() async {
    box = await Hive.openBox<String>(
      AtriumBoxes.settings,
      bytes: Uint8List(0),
    );
  });

  tearDown(() async {
    await box.close();
  });

  testWidgets('with nothing remembered, folder defaults still apply',
      (WidgetTester tester) async {
    final _Server server = _Server();
    await _openAndAdd(tester, server);

    expect(server.posted!['rootFolderPath'], '/data/music');
    expect(server.posted!['qualityProfileId'], 1);
    expect(server.posted!['metadataProfileId'], 1);
  });

  testWidgets('remembered choices win over folder defaults',
      (WidgetTester tester) async {
    AddChoices.write('lidarr', testInstance.id, <String, Object?>{
      'rootFolderPath': '/data/other',
      'qualityProfileId': 2,
      'metadataProfileId': 2,
      'monitored': false,
      'monitor': 'future',
      'monitorNewItems': 'none',
      'searchForMissingAlbums': true,
    });
    final _Server server = _Server();
    await _openAndAdd(tester, server);

    final Map<String, dynamic> body = server.posted!;
    expect(body['rootFolderPath'], '/data/other');
    expect(body['qualityProfileId'], 2);
    expect(body['metadataProfileId'], 2);
    expect(body['monitored'], isFalse);
    expect(body['monitorNewItems'], 'none');
    expect(_options(body)['monitor'], 'future');
    expect(_options(body)['searchForMissingAlbums'], isTrue);
  });

  testWidgets('remembered profiles win over the default folder too',
      (WidgetTester tester) async {
    AddChoices.write('lidarr', testInstance.id, <String, Object?>{
      'rootFolderPath': '/data/music',
      'qualityProfileId': 2,
      'metadataProfileId': 2,
    });
    final _Server server = _Server();
    await _openAndAdd(tester, server);

    expect(server.posted!['qualityProfileId'], 2);
    expect(server.posted!['metadataProfileId'], 2);
  });

  testWidgets('remembered profiles still win when folders load last',
      (WidgetTester tester) async {
    AddChoices.write('lidarr', testInstance.id, <String, Object?>{
      'qualityProfileId': 2,
      'metadataProfileId': 2,
    });
    final Completer<List<RootFolderResource>> late =
        Completer<List<RootFolderResource>>();
    final _Server server = _Server();
    await _openAndAdd(
      tester,
      server,
      folders: late.future,
      beforeAdd: () async {
        late.complete(const <RootFolderResource>[
          RootFolderResource(
            id: 1,
            path: '/data/music',
            defaultQualityProfileId: 1,
            defaultMetadataProfileId: 1,
          ),
        ]);
        await tester.pumpAndSettle();
      },
    );

    expect(server.posted!['rootFolderPath'], '/data/music');
    expect(server.posted!['qualityProfileId'], 2);
    expect(server.posted!['metadataProfileId'], 2);
  });

  testWidgets('a change made while lists load is kept',
      (WidgetTester tester) async {
    AddChoices.write('lidarr', testInstance.id, <String, Object?>{
      'qualityProfileId': 1,
      'searchForMissingAlbums': false,
    });
    final Completer<List<MetadataProfileResource>> late =
        Completer<List<MetadataProfileResource>>();
    final _Server server = _Server();
    await _openAndAdd(
      tester,
      server,
      metadata: late.future,
      beforeAdd: () async {
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Search for Missing Albums'),
        );
        await tester.pump();
        await tester.tap(find.text('Any'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('FLAC Lossless').last);
        await tester.pump(const Duration(milliseconds: 500));
        late.complete(const <MetadataProfileResource>[
          MetadataProfileResource(id: 1, name: 'Standard'),
        ]);
        await tester.pumpAndSettle();
      },
    );

    expect(server.posted!['qualityProfileId'], 2);
    expect(_options(server.posted!)['searchForMissingAlbums'], isTrue);
  });

  testWidgets('a deleted profile or unknown option falls back',
      (WidgetTester tester) async {
    AddChoices.write('lidarr', testInstance.id, <String, Object?>{
      'rootFolderPath': '/gone',
      'qualityProfileId': 99,
      'metadataProfileId': 98,
      'monitor': 'sometimes',
      'monitorNewItems': 7,
    });
    final _Server server = _Server();
    await _openAndAdd(tester, server);

    final Map<String, dynamic> body = server.posted!;
    expect(body['rootFolderPath'], '/data/music');
    expect(body['qualityProfileId'], 1);
    expect(body['metadataProfileId'], 1);
    expect(body['monitorNewItems'], 'all');
    expect(_options(body)['monitor'], 'all');
  });

  testWidgets('profile ids saved as decimals fall back',
      (WidgetTester tester) async {
    AddChoices.write('lidarr', testInstance.id, <String, Object?>{
      'qualityProfileId': 2.0,
      'metadataProfileId': 2.0,
    });
    final _Server server = _Server();
    await _openAndAdd(tester, server);

    expect(server.posted!['qualityProfileId'], 1);
    expect(server.posted!['metadataProfileId'], 1);
  });

  testWidgets('saves what was sent, not a change made while adding',
      (WidgetTester tester) async {
    final _Server server = _Server()..gate = Completer<void>();
    await _openAndAdd(
      tester,
      server,
      whileAdding: () async {
        expect(server.posted, isNotNull);
        final Finder tile =
            find.widgetWithText(SwitchListTile, 'Search for Missing Albums');
        await tester.ensureVisible(tile);
        await tester.pump();
        await tester.tap(tile);
        await tester.pump();
        server.gate!.complete();
      },
    );

    expect(_options(server.posted!)['searchForMissingAlbums'], isFalse);
    expect(
      AddChoices.read('lidarr', testInstance.id)!['searchForMissingAlbums'],
      isFalse,
    );
  });

  testWidgets('saves what was picked after a successful add',
      (WidgetTester tester) async {
    final _Server server = _Server();
    await _openAndAdd(tester, server);

    expect(AddChoices.read('lidarr', testInstance.id), <String, Object?>{
      'rootFolderPath': '/data/music',
      'qualityProfileId': 1,
      'metadataProfileId': 1,
      'monitored': true,
      'monitor': 'all',
      'monitorNewItems': 'all',
      'searchForMissingAlbums': false,
    });
  });

  testWidgets('a failed add remembers nothing', (WidgetTester tester) async {
    final _Server server = _Server(status: 500);
    await _openAndAdd(tester, server);

    expect(server.posted, isNotNull);
    expect(AddChoices.read('lidarr', testInstance.id), isNull);
  });
}
