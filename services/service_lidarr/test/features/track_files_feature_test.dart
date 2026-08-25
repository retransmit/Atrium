import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

import 'test_helpers.dart';

void main() {
  group('Lidarr Track Files Feature Widget Tests', () {
    testWidgets(
        'LidarrManualImportDialog scans folder, matches tracks, and dispatches ManualImport command',
        (tester) async {
      String? commandDispatched;
      Map<String, dynamic>? commandPayload;

      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://localhost:8686',
          headers: {'X-Api-Key': 'mock-key'},
        ),
      );

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET' &&
                options.path == '/api/v1/manualimport') {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: [
                    {
                      'id': 1,
                      'path': '/downloads/Radiohead - Burn the Witch.flac',
                      'name': 'Radiohead - Burn the Witch.flac',
                      'size': 25000000,
                      'artist': {
                        'id': 1,
                        'artistName': 'Radiohead',
                      },
                      'album': {
                        'id': 101,
                        'title': 'A Moon Shaped Pool',
                        'albumType': 'Studio',
                      },
                      'tracks': [
                        {
                          'id': 501,
                          'trackNumber': '1',
                          'title': 'Burn the Witch',
                        },
                      ],
                      'quality': {
                        'quality': {'id': 3, 'name': 'FLAC'},
                        'revision': {
                          'version': 1,
                          'real': 0,
                          'isRepack': false,
                        },
                      },
                      'qualityWeight': 100,
                      'rejections': <dynamic>[],
                    },
                  ],
                  statusCode: 200,
                ),
              );
            }
            if (options.method == 'POST' && options.path == '/api/v1/command') {
              final body = options.data as Map<String, dynamic>;
              commandDispatched = body['name'] as String?;
              commandPayload = body;
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {
                    'name': commandDispatched,
                    'status': 'queued',
                    'id': 2001,
                  },
                  statusCode: 201,
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrApiProvider(testInstance)
                .overrideWith((ref) => LidarrApi(dio)),
            lidarrArtistsProvider(testInstance).overrideWith(
              (ref) async => [
                const ArtistResource(id: 1, artistName: 'Radiohead'),
              ],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  return ElevatedButton(
                    onPressed: () => showLidarrManualImportFlow(
                      context,
                      ref,
                      testInstance,
                      initialFolder: '/downloads',
                    ),
                    child: const Text('Open Manual Import'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open flow
      await tester.tap(find.text('Open Manual Import'));
      await tester.pumpAndSettle();

      // Verify Setup Dialog
      expect(find.text('Manual Import'), findsOneWidget);
      expect(find.text('Folder Path'), findsOneWidget);
      expect(find.text('/downloads'), findsOneWidget);

      // Tap Scan Folder
      await tester.tap(find.text('Scan Folder'));
      await tester.pumpAndSettle();

      // Verify Results Dialog
      expect(find.text('Import Files (1)'), findsOneWidget);
      expect(find.text('Radiohead - Burn the Witch.flac'), findsOneWidget);
      expect(find.text('Radiohead'), findsWidgets);
      expect(find.text('A Moon Shaped Pool'), findsOneWidget);
      expect(find.text('1. Burn the Witch'), findsOneWidget);
      expect(find.text('FLAC'), findsWidgets);
      expect(find.text('+Score: 100'), findsOneWidget);

      // Execute Import
      await tester.tap(find.text('Import Selected'));
      await tester.pumpAndSettle();

      expect(commandDispatched, equals('ManualImport'));
      expect(commandPayload?['importMode'], equals('auto'));
      final List<dynamic>? files = commandPayload?['files'] as List<dynamic>?;
      expect(files?.length, equals(1));
      final Map<String, dynamic> firstFile = files![0] as Map<String, dynamic>;
      expect(firstFile['artistId'], equals(1));
      expect(firstFile['albumId'], equals(101));
      expect(firstFile['trackIds'], equals([501]));
    });

    testWidgets(
      'LidarrRenameDialog displays rename diff preview and executes RenameFiles command',
      (WidgetTester tester) async {
        String? commandDispatched;
        Map<String, dynamic>? commandPayload;

        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET' && options.path == '/api/v1/rename') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      {
                        'id': 1,
                        'artistId': 1,
                        'albumId': 101,
                        'trackNumbers': [1],
                        'trackFileId': 901,
                        'existingPath':
                            '/music/Radiohead/A Moon Shaped Pool/01.flac',
                        'newPath':
                            '/music/Radiohead/A Moon Shaped Pool/01 - Burn the Witch.flac',
                      },
                    ],
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'POST' &&
                  options.path == '/api/v1/command') {
                final body = options.data as Map<String, dynamic>;
                commandDispatched = body['name'] as String?;
                commandPayload = body;
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: {
                      'name': commandDispatched,
                      'status': 'queued',
                      'id': 3001,
                    },
                    statusCode: 201,
                  ),
                );
              }
              return handler.next(options);
            },
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lidarrApiProvider(testInstance)
                  .overrideWith((ref) => LidarrApi(dio)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () => showLidarrRenameDialog(
                        context,
                        instance: testInstance,
                        artistId: 1,
                        albumId: 101,
                        artistName: 'Radiohead',
                        albumTitle: 'A Moon Shaped Pool',
                      ),
                      child: const Text('Open Rename Dialog'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open Dialog
        await tester.tap(find.text('Open Rename Dialog'));
        await tester.pumpAndSettle();

        // Verify Dialog Content
        expect(find.text('Rename A Moon Shaped Pool'), findsOneWidget);
        expect(find.text('1 of 1 selected'), findsOneWidget);
        expect(find.text('Track 1'), findsOneWidget);
        expect(find.text('01.flac'), findsOneWidget);
        expect(find.text('01 - Burn the Witch.flac'), findsOneWidget);

        // Execute Rename
        await tester.tap(find.text('Rename (1)'));
        await tester.pumpAndSettle();

        expect(commandDispatched, equals('RenameFiles'));
        expect(commandPayload?['artistId'], equals(1));
        final files = commandPayload?['files'] as List<dynamic>?;
        expect(files, equals([901]));
      },
    );

    testWidgets(
      'LidarrRenameDialog renders empty state when all files are correctly named',
      (WidgetTester tester) async {
        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET' && options.path == '/api/v1/rename') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: <dynamic>[],
                    statusCode: 200,
                  ),
                );
              }
              return handler.next(options);
            },
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lidarrApiProvider(testInstance)
                  .overrideWith((ref) => LidarrApi(dio)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () => showLidarrRenameDialog(
                        context,
                        instance: testInstance,
                        artistId: 1,
                        artistName: 'Radiohead',
                      ),
                      child: const Text('Open Rename Dialog'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open Dialog
        await tester.tap(find.text('Open Rename Dialog'));
        await tester.pumpAndSettle();

        // Verify Empty State Content
        expect(find.text('Rename Radiohead'), findsOneWidget);
        expect(find.text('All files are correctly named'), findsOneWidget);
        expect(
          find.text('No audio files need to be organized or renamed.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LidarrRetagDialog displays tag difference preview and executes RetagFiles command',
      (WidgetTester tester) async {
        String? commandDispatched;
        Map<String, dynamic>? commandPayload;

        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET' && options.path == '/api/v1/retag') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      {
                        'id': 1,
                        'artistId': 1,
                        'albumId': 101,
                        'trackNumbers': [1],
                        'trackFileId': 901,
                        'path':
                            '/music/Radiohead/A Moon Shaped Pool/01 - Burn the Witch.flac',
                        'changes': [
                          {
                            'field': 'Title',
                            'oldValue': 'Burn the Witch (Live)',
                            'newValue': 'Burn the Witch',
                          },
                        ],
                      },
                    ],
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'POST' &&
                  options.path == '/api/v1/command') {
                final body = options.data as Map<String, dynamic>;
                commandDispatched = body['name'] as String?;
                commandPayload = body;
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: {
                      'name': commandDispatched,
                      'status': 'queued',
                      'id': 4001,
                    },
                    statusCode: 201,
                  ),
                );
              }
              return handler.next(options);
            },
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lidarrApiProvider(testInstance)
                  .overrideWith((ref) => LidarrApi(dio)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () => showLidarrRetagDialog(
                        context,
                        instance: testInstance,
                        artistId: 1,
                        albumId: 101,
                        artistName: 'Radiohead',
                        albumTitle: 'A Moon Shaped Pool',
                      ),
                      child: const Text('Open Retag Dialog'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open Dialog
        await tester.tap(find.text('Open Retag Dialog'));
        await tester.pumpAndSettle();

        // Verify Dialog Content
        expect(find.text('Retag A Moon Shaped Pool'), findsOneWidget);
        expect(find.text('1 of 1 selected'), findsOneWidget);
        expect(find.text('Track 1'), findsOneWidget);
        expect(find.text('01 - Burn the Witch.flac'), findsOneWidget);
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Burn the Witch (Live)'), findsOneWidget);
        expect(find.text('Burn the Witch'), findsOneWidget);

        // Execute Retag
        await tester.tap(find.text('Retag (1)'));
        await tester.pumpAndSettle();

        expect(commandDispatched, equals('RetagFiles'));
        expect(commandPayload?['artistId'], equals(1));
        final files = commandPayload?['files'] as List<dynamic>?;
        expect(files, equals([901]));
      },
    );

    testWidgets(
      'LidarrRetagDialog renders empty state when all tags are up-to-date',
      (WidgetTester tester) async {
        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET' && options.path == '/api/v1/retag') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: <dynamic>[],
                    statusCode: 200,
                  ),
                );
              }
              return handler.next(options);
            },
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lidarrApiProvider(testInstance)
                  .overrideWith((ref) => LidarrApi(dio)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () => showLidarrRetagDialog(
                        context,
                        instance: testInstance,
                        artistId: 1,
                        artistName: 'Radiohead',
                      ),
                      child: const Text('Open Retag Dialog'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open Dialog
        await tester.tap(find.text('Open Retag Dialog'));
        await tester.pumpAndSettle();

        // Verify Empty State Content
        expect(find.text('Retag Radiohead'), findsOneWidget);
        expect(find.text('All tags are up-to-date'), findsOneWidget);
        expect(
          find.text('No audio files need tag modifications.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LidarrTrackFileEditorSheet renders audio track files, allows selection, bulk edits quality, and bulk deletes files',
      (WidgetTester tester) async {
        Map<String, dynamic>? editorPayload;
        Map<String, dynamic>? bulkDeletePayload;

        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET' &&
                  options.path == '/api/v1/trackfile') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      {
                        'id': 101,
                        'artistId': 1,
                        'albumId': 10,
                        'path':
                            '/music/Radiohead/A Moon Shaped Pool/01 Burn the Witch.flac',
                        'size': 30000000,
                        'quality': {
                          'quality': {'id': 1, 'name': 'FLAC'},
                        },
                        'mediaInfo': {
                          'audioCodec': 'FLAC',
                          'audioBitRate': '1000 kbps',
                        },
                      },
                      {
                        'id': 102,
                        'artistId': 1,
                        'albumId': 10,
                        'path':
                            '/music/Radiohead/A Moon Shaped Pool/02 Daydreaming.flac',
                        'size': 45000000,
                        'quality': {
                          'quality': {'id': 1, 'name': 'FLAC'},
                        },
                        'mediaInfo': {
                          'audioCodec': 'FLAC',
                          'audioBitRate': '1000 kbps',
                        },
                      },
                    ],
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'GET' &&
                  options.path == '/api/v1/qualityprofile') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      {
                        'id': 1,
                        'name': 'Lossless',
                        'cutoff': 1,
                      },
                    ],
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'PUT' &&
                  options.path == '/api/v1/trackfile/editor') {
                editorPayload = options.data as Map<String, dynamic>?;
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'DELETE' &&
                  options.path == '/api/v1/trackfile/bulk') {
                bulkDeletePayload = options.data as Map<String, dynamic>?;
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                  ),
                );
              }
              return handler.next(options);
            },
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lidarrApiProvider(testInstance)
                  .overrideWith((ref) => LidarrApi(dio)),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: LidarrTrackFileEditorSheet(
                  instance: testInstance,
                  artistId: 1,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Track Files Editor'), findsOneWidget);
        expect(find.text('01 Burn the Witch.flac'), findsOneWidget);
        expect(find.text('02 Daydreaming.flac'), findsOneWidget);

        // Select first track file
        await tester.tap(find.text('01 Burn the Witch.flac'));
        await tester.pumpAndSettle();

        expect(find.text('1 / 2 selected'), findsOneWidget);
        expect(find.byTooltip('Edit Quality'), findsOneWidget);
        expect(find.byTooltip('Delete Selected'), findsOneWidget);

        // Bulk edit quality
        await tester.tap(find.byTooltip('Edit Quality'));
        await tester.pumpAndSettle();

        expect(find.text('Edit 1 Track Files'), findsOneWidget);
        await tester.tap(find.text('Apply Changes'));
        await tester.pumpAndSettle();

        expect(editorPayload, isNotNull);
        expect(editorPayload!['trackFileIds'], equals([101]));

        // Select again to bulk delete
        await tester.tap(find.text('01 Burn the Witch.flac'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Delete Selected'));
        await tester.pumpAndSettle();

        expect(find.text('Delete 1 Audio Files?'), findsOneWidget);
        await tester.tap(find.text('Delete Permanently'));
        await tester.pumpAndSettle();

        expect(bulkDeletePayload, isNotNull);
        expect(bulkDeletePayload!['trackFileIds'], equals([101]));
      },
    );

    testWidgets(
      'LidarrUnmappedFilesSheet renders unmapped files, triggers manual import flow, and deletes unmapped file',
      (WidgetTester tester) async {
        bool deleteCalled = false;

        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET' &&
                  options.path == '/api/v1/trackfile') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      {
                        'id': 201,
                        'artistId': 1,
                        'path': '/music/Radiohead/Extra/bonus_track.mp3',
                        'size': 10000000,
                        'audioTags': {
                          'artistTitle': 'Radiohead',
                          'albumTitle': 'B-Sides',
                          'title': 'Bonus Track',
                        },
                      },
                    ],
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'DELETE' &&
                  options.path == '/api/v1/trackfile/201') {
                deleteCalled = true;
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                  ),
                );
              }
              return handler.next(options);
            },
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lidarrApiProvider(testInstance)
                  .overrideWith((ref) => LidarrApi(dio)),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: LidarrUnmappedFilesSheet(
                  instance: testInstance,
                  artistId: 1,
                  artistName: 'Radiohead',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Unmapped Files — Radiohead'), findsOneWidget);
        expect(find.text('bonus_track.mp3'), findsOneWidget);
        expect(find.text('Radiohead — B-Sides — Bonus Track'), findsOneWidget);
        expect(find.text('Manual Import'), findsOneWidget);

        // Delete unmapped file
        await tester.tap(find.byTooltip('Delete File'));
        await tester.pumpAndSettle();

        expect(find.text('Delete Unmapped File?'), findsOneWidget);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(deleteCalled, isTrue);
      },
    );
  });
}
