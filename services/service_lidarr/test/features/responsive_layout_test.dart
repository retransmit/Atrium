import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';
import 'package:service_lidarr/src/features/activity/views/queue_view.dart';
import 'package:service_lidarr/src/features/artists/views/artist_history_view.dart';
import 'package:service_lidarr/src/features/settings/sections/download_clients_section.dart';
import 'package:service_lidarr/src/features/settings/sections/indexers_section.dart';

import 'test_helpers.dart';

void main() {
  group('LidarrFormatters.formatWireEnum Unit Tests', () {
    test('sanitizes C# backend wire enums cleanly', () {
      expect(
        LidarrFormatters.formatWireEnum('torrentDownloadProtocol'),
        equals('TORRENT'),
      );
      expect(
        LidarrFormatters.formatWireEnum('usenetDownloadProtocol'),
        equals('USENET'),
      );
      expect(
        LidarrFormatters.formatWireEnum('torrentProtocol'),
        equals('TORRENT'),
      );
      expect(
        LidarrFormatters.formatWireEnum('torrent'),
        equals('TORRENT'),
      );
      expect(
        LidarrFormatters.formatWireEnum(''),
        equals('--'),
      );
      expect(
        LidarrFormatters.formatWireEnum(null),
        equals('--'),
      );
    });
  });

  group('Lidarr Responsive Layout Widget Tests', () {
    testWidgets(
      'IndexersSection does not squish long indexer titles at 360dp width and 1.3x text scale',
      (WidgetTester tester) async {
        await tester.setViewport(textScale: 1.3);

        final Dio dio = Dio(
          BaseOptions(
            baseUrl: 'http://127.0.0.1:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/api/v1/indexer') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: [
                      {
                        'id': 1,
                        'name': 'BT.etree (Prowlarr Tracker)',
                        'enableRss': true,
                        'enableAutomaticSearch': true,
                        'enableInteractiveSearch': true,
                        'protocol': 'TorrentDownloadProtocol',
                        'implementationName': 'Torznab',
                      },
                    ],
                  ),
                );
              }
              if (options.path == '/api/v1/indexer/schema') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <dynamic>[],
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
              lidarrApiProvider(testInstance).overrideWith(
                (ref) => LidarrApi(dio),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: IndexersSection(instance: testInstance),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('BT.etree (Prowlarr Tracker)'), findsOneWidget);
        expect(find.text('TORRENT'), findsOneWidget);

        // Verify title width is not squished (should be >= 150px and height < 150px at 1.3x text scale)
        final RenderBox titleBox = tester.renderObject(
          find.text('BT.etree (Prowlarr Tracker)'),
        );
        expect(titleBox.size.width, greaterThan(150));
        expect(titleBox.size.height, lessThan(150));
      },
    );

    testWidgets(
      'QueueView modal details limits status messages to 3 with expansion button',
      (WidgetTester tester) async {
        await tester.setViewport();

        final Dio dio = Dio(
          BaseOptions(
            baseUrl: 'http://127.0.0.1:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        final List<Map<String, dynamic>> tenMessages = List.generate(
          10,
          (i) => {
            'title': 'Track Error #$i',
            'messages': ['Audio file failed hash verification for track $i.'],
          },
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/api/v1/queue') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'page': 1,
                      'pageSize': 20,
                      'totalRecords': 1,
                      'records': [
                        {
                          'id': 99,
                          'title': 'Ado - Zanmu [FLAC]',
                          'status': 'warning',
                          'trackedDownloadStatus': 'warning',
                          'statusMessages': tenMessages,
                          'protocol': 'TorrentDownloadProtocol',
                          'downloadClient': 'qBittorrent',
                          'indexer': 'Nyaa',
                          'size': 600000000,
                          'sizeleft': 0,
                          'albumId': 42,
                        },
                      ],
                    },
                  ),
                );
              }
              if (options.path == '/api/v1/queue/status') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {'totalCount': 1, 'count': 1},
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
              lidarrApiProvider(testInstance).overrideWith(
                (ref) => LidarrApi(dio),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: QueueView(instance: testInstance),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap on the queue item card to open download details bottom sheet
        expect(find.text('Ado - Zanmu [FLAC]'), findsOneWidget);
        await tester.tap(find.text('Ado - Zanmu [FLAC]'));
        await tester.pumpAndSettle();

        // Verify bottom sheet opened
        expect(find.text('Download Details'), findsOneWidget);
        expect(find.text('Manual Import'), findsOneWidget);
        expect(find.text('Interactive Search'), findsOneWidget);

        // Verify button height symmetry (proves Interactive Search did not break into 2 lines with height mismatch)
        final RenderBox manualBox = tester.renderObject(
          find.widgetWithText(FilledButton, 'Manual Import'),
        );
        final RenderBox searchBox = tester.renderObject(
          find.widgetWithText(OutlinedButton, 'Interactive Search'),
        );
        expect(manualBox.size.height, equals(searchBox.size.height));

        // Verify only 3 messages rendered initially + expansion button
        expect(
          find.text('Track Error #0', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('Track Error #1', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('Track Error #2', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('Track Error #3', skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text('Show all 10 messages', skipOffstage: false),
          findsOneWidget,
        );

        // Scroll to the expansion toggle and tap it
        await tester.scrollUntilVisible(
          find.text('Show all 10 messages'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Show all 10 messages'));
        await tester.pumpAndSettle();

        // Verify all 10 messages now visible
        expect(
          find.text('Track Error #3', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('Track Error #9', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Show less', skipOffstage: false), findsOneWidget);
      },
    );

    testWidgets(
      'DownloadClientsSection does not squish long client titles at 360dp width and 1.3x text scale',
      (WidgetTester tester) async {
        await tester.setViewport(textScale: 1.3);

        final Dio dio = Dio(
          BaseOptions(
            baseUrl: 'http://127.0.0.1:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/api/v1/downloadclient') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: [
                      {
                        'id': 1,
                        'name':
                            'Transmission Remote Daemon (High Performance Client)',
                        'enable': true,
                        'protocol': 'TorrentDownloadProtocol',
                        'implementationName': 'Transmission',
                      },
                    ],
                  ),
                );
              }
              if (options.path == '/api/v1/downloadclient/schema') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <dynamic>[],
                  ),
                );
              }
              if (options.path == '/api/v1/remotepathmapping') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <dynamic>[],
                  ),
                );
              }
              if (options.path == '/api/v1/config/downloadclient') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{},
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
              lidarrApiProvider(testInstance).overrideWith(
                (ref) => LidarrApi(dio),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: DownloadClientsSection(instance: testInstance),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Transmission Remote Daemon (High Performance Client)'),
          findsOneWidget,
        );
        expect(find.text('TORRENT'), findsOneWidget);

        // Verify title width is not squished (should be >= 150px and height < 250px at 1.3x text scale)
        final RenderBox titleBox = tester.renderObject(
          find.text('Transmission Remote Daemon (High Performance Client)'),
        );
        expect(titleBox.size.width, greaterThan(150));
        expect(titleBox.size.height, lessThan(250));
      },
    );

    testWidgets(
      'LidarrUnmappedFilesScreen search and selection controls do not overflow at 360dp width and 1.3x text scale',
      (WidgetTester tester) async {
        await tester.setViewport(textScale: 1.3);

        final Dio dio = Dio(
          BaseOptions(
            baseUrl: 'http://127.0.0.1:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/api/v1/trackfile') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: [
                      {
                        'id': 1,
                        'artistId': 1,
                        'path':
                            '/music/Unmapped/01 - Special Track Name That Is Quite Long.flac',
                        'size': 35000000,
                        'audioTags': {
                          'title': 'Special Track Name That Is Quite Long',
                          'artistTitle': 'Radiohead',
                          'albumTitle': 'A Moon Shaped Pool',
                        },
                      },
                    ],
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
              lidarrApiProvider(testInstance).overrideWith(
                (ref) => LidarrApi(dio),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: LidarrUnmappedFilesScreen(
                  instance: testInstance,
                  artistId: 1,
                  artistName: 'Radiohead',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Search bar and Select All action button render cleanly without overflow
        expect(find.byType(TextField), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, 'Select All'),
          findsOneWidget,
        );

        // Tap Select All
        await tester.tap(find.widgetWithText(TextButton, 'Select All'));
        await tester.pumpAndSettle();

        // Verify button toggled to Deselect
        expect(
          find.widgetWithText(TextButton, 'Deselect'),
          findsOneWidget,
        );
      },
    );

    final String extremelyLongString =
        'Super Long Text That Exceeds The Narrow Viewport Width And Will Wrap ' * 3;

    final Dio dio = Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:8686',
        headers: {'X-Api-Key': 'mock-key'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/history')) {
            return handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'records': [
                    {'id': 1, 'sourceTitle': 'Test'},
                  ],
                },
              ),
            );
          }
          return handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: [
                {'id': 1, 'path': '/test/file.mp3'},
              ],
            ),
          );
        },
      ),
    );

    testWidgets(
      'LidarrUnmappedFilesScreen lays out without overflow at 2x text scale on a narrow screen',
      (WidgetTester tester) async {
        await tester.setViewport(textScale: 2.0, width: 320);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lidarrApiProvider(testInstance).overrideWith((ref) => LidarrApi(dio)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LidarrUnmappedFilesScreen(
                  instance: testInstance,
                  artistId: 1,
                  artistName: extremelyLongString,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'LidarrTrackFileEditorScreen lays out without overflow at 2x text scale on a narrow screen',
      (WidgetTester tester) async {
        await tester.setViewport(textScale: 2.0, width: 320);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lidarrApiProvider(testInstance).overrideWith((ref) => LidarrApi(dio)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LidarrTrackFileEditorScreen(
                  instance: testInstance,
                  artistId: 1,
                  albumId: 1,
                  albumTitle: extremelyLongString,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'ArtistHistoryView lays out without overflow at 2x text scale on a narrow screen',
      (WidgetTester tester) async {
        await tester.setViewport(textScale: 2.0, width: 320);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lidarrApiProvider(testInstance).overrideWith((ref) => LidarrApi(dio)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ArtistHistoryView(
                  instance: testInstance,
                  artistId: 1,
                  showAppBar: true,
                  artistName: extremelyLongString,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
    );
  });
}
