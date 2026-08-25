import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';
import 'package:service_lidarr/src/features/activity/views/history_view.dart';

import 'test_helpers.dart';

void main() {
  group('Lidarr Activity Feature Widget Tests', () {
    testWidgets(
        'LidarrInteractiveSearchSheet renders releases, filters query, and grabs release',
        (tester) async {
      bool postGrabCalled = false;
      Map<String, dynamic>? grabbedPayload;

      final Dio dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8686',
          headers: {'X-Api-Key': 'mock-key'},
        ),
      );

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST' && options.path == '/api/v1/release') {
              postGrabCalled = true;
              grabbedPayload = Map<String, dynamic>.from(options.data as Map);
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.data,
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      const approvedRelease = ReleaseResource(
        guid: 'release-guid-1',
        indexerId: 1,
        indexer: 'Nyaa',
        title: 'Ado - Kyogen [FLAC]',
        protocol: DownloadProtocol.torrent,
        size: 500000000,
        seeders: 25,
        leechers: 2,
        approved: true,
        rejected: false,
        quality: QualityModel(
          quality: Quality(id: 1, name: 'FLAC'),
        ),
      );

      const rejectedRelease = ReleaseResource(
        guid: 'release-guid-2',
        indexerId: 2,
        indexer: '1337x',
        title: 'Ado - Kyogen [MP3 320]',
        protocol: DownloadProtocol.torrent,
        size: 150000000,
        seeders: 5,
        leechers: 0,
        approved: false,
        rejected: true,
        rejections: ['Existing file meets cutoff: FLAC', 'Wrong format'],
        quality: QualityModel(
          quality: Quality(id: 2, name: 'MP3 320'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrApiProvider(testInstance)
                .overrideWith((ref) => LidarrApi(dio)),
            lidarrReleasesForAlbumProvider((testInstance, 30)).overrideWith(
              (ref) async => [approvedRelease, rejectedRelease],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LidarrInteractiveSearchScreen(
                instance: testInstance,
                title: 'Kyogen',
                albumId: 30,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Interactive Search'), findsOneWidget);
      expect(find.text('Kyogen'), findsOneWidget);
      expect(find.text('Ado - Kyogen [FLAC]'), findsOneWidget);
      expect(find.text('Ado - Kyogen [MP3 320]'), findsOneWidget);

      // Filter by text 'MP3'
      await tester.enterText(find.byType(TextField), 'MP3');
      await tester.pumpAndSettle();

      expect(find.text('Ado - Kyogen [FLAC]'), findsNothing);
      expect(find.text('Ado - Kyogen [MP3 320]'), findsOneWidget);

      // Clear filter
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Ado - Kyogen [FLAC]'), findsOneWidget);

      // Grab approved release
      await tester.tap(find.byTooltip('Grab Release'));
      await tester.pumpAndSettle();

      expect(postGrabCalled, isTrue);
      expect(grabbedPayload?['guid'], equals('release-guid-1'));
      expect(grabbedPayload?['indexerId'], equals(1));
      expect(grabbedPayload?['id'], equals(0));
      expect(grabbedPayload?['id'], isA<int>());

      // Grab rejected release -> should show confirmation dialog
      postGrabCalled = false;
      await tester.tap(find.byTooltip('Rejected (Force Grab)'));
      await tester.pumpAndSettle();

      expect(find.text('Force Grab Release?'), findsOneWidget);
      expect(find.text('Existing file meets cutoff: FLAC'), findsAtLeast(1));

      // Confirm force grab
      await tester.tap(find.widgetWithText(FilledButton, 'Grab Anyway'));
      await tester.pumpAndSettle();

      expect(postGrabCalled, isTrue);
      expect(grabbedPayload?['guid'], equals('release-guid-2'));
      expect(grabbedPayload?['indexerId'], equals(2));
      expect(grabbedPayload?['id'], equals(0));
      expect(grabbedPayload?['id'], isA<int>());
    });

    testWidgets(
        'ActivityTab renders Queue, History, and Blocklist and performs item actions',
        (tester) async {
      bool queueDeleted = false;
      int? deletedQueueId;
      bool historyFailedCalled = false;
      int? failedHistoryId;
      bool blocklistDeleted = false;
      int? deletedBlocklistId;

      final Dio dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8686',
          headers: {'X-Api-Key': 'mock-key'},
        ),
      );

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'DELETE' &&
                options.path.startsWith('/api/v1/queue/')) {
              queueDeleted = true;
              deletedQueueId = int.tryParse(options.path.split('/').last);
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                ),
              );
            }
            if (options.method == 'POST' &&
                options.path.startsWith('/api/v1/history/failed/')) {
              historyFailedCalled = true;
              failedHistoryId = int.tryParse(options.path.split('/').last);
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                ),
              );
            }
            if (options.method == 'DELETE' &&
                options.path.startsWith('/api/v1/blocklist/')) {
              blocklistDeleted = true;
              deletedBlocklistId = int.tryParse(options.path.split('/').last);
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

      const queueItem = QueueResource(
        id: 101,
        title: 'Ado - Kyogen [FLAC]',
        status: 'downloading',
        downloadClient: 'qBittorrent',
        size: 500000000,
        sizeleft: 200000000,
        timeleft: '00:05:30',
        artist: ArtistResource(artistName: 'Ado'),
        album: AlbumResource(title: 'Kyogen'),
      );

      const historyItem = HistoryResource(
        id: 1,
        sourceTitle: 'Ado - Kyogen [FLAC] (Grabbed)',
        eventType: EntityHistoryEventType.grabbed,
        date: '2026-08-15T12:00:00Z',
        artist: ArtistResource(artistName: 'Ado'),
        album: AlbumResource(title: 'Kyogen'),
      );

      const blocklistItem = BlocklistResource(
        id: 201,
        sourceTitle: 'Ado - Fake Track [MP3]',
        message: 'Invalid track length / bad quality',
        date: '2026-08-14T10:00:00Z',
        artist: ArtistResource(artistName: 'Ado'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrApiProvider(testInstance)
                .overrideWith((ref) => LidarrApi(dio)),
            lidarrQueueProvider(testInstance)
                .overrideWith((ref) async => [queueItem]),
            lidarrHistoryPagedProvider(
              (
                testInstance,
                page: 1,
                pageSize: 50,
                eventType: null,
              ),
            ).overrideWith(
              (ref) async => const HistoryResourcePagingResource(
                page: 1,
                pageSize: 50,
                totalRecords: 1,
                records: [historyItem],
              ),
            ),
            lidarrBlocklistProvider(testInstance)
                .overrideWith((ref) async => [blocklistItem]),
          ],
          child: const MaterialApp(
            home: ActivityTab(instance: testInstance),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Queue sub-tab
      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Blocklist'), findsOneWidget);
      expect(find.text('Kyogen'), findsOneWidget);
      expect(find.textContaining('Ado'), findsAtLeast(1));

      // Remove from Queue
      await tester.tap(find.byTooltip('Remove from Queue'));
      await tester.pumpAndSettle();

      expect(find.text('Remove from Queue'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(queueDeleted, isTrue);
      expect(deletedQueueId, equals(101));

      // 2. Switch to History sub-tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('Ado - Kyogen [FLAC] (Grabbed)'), findsOneWidget);

      // Open Filter Sheet
      await tester.tap(find.byTooltip('Filter & Group History'));
      await tester.pumpAndSettle();

      expect(find.text('Event Type Filter'), findsOneWidget);
      expect(find.text('Grabbed'), findsOneWidget);
      expect(find.text('Imported'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Deleted'), findsOneWidget);

      // Filter by 'Imported' -> empty list
      await tester.tap(find.text('Imported'));
      await tester.pumpAndSettle();
      // Dismiss sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Ado - Kyogen [FLAC] (Grabbed)'), findsNothing);

      // Open Filter Sheet and Reset
      await tester.tap(find.byTooltip('Filter & Group History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All Events'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Ado - Kyogen [FLAC] (Grabbed)'), findsOneWidget);

      // Mark as Failed
      await tester.tap(find.byTooltip('Mark as Failed'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Failed?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Mark Failed'));
      await tester.pumpAndSettle();

      expect(historyFailedCalled, isTrue);
      expect(failedHistoryId, equals(1));

      // 3. Switch to Blocklist sub-tab
      await tester.tap(find.text('Blocklist'));
      await tester.pumpAndSettle();

      expect(find.text('Ado - Fake Track [MP3]'), findsOneWidget);
      expect(find.text('Invalid track length / bad quality'), findsOneWidget);
      expect(find.byTooltip('Clear Blocklist'), findsOneWidget);

      // Remove from Blocklist
      await tester.tap(find.byTooltip('Remove from Blocklist'));
      await tester.pumpAndSettle();

      expect(find.text('Remove from Blocklist?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(blocklistDeleted, isTrue);
      expect(deletedBlocklistId, equals(201));
    });

    testWidgets(
        'ActivityTab unified search, grouping toggle, and deep queue item inspection sheet',
        (tester) async {
      final Dio dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8686',
          headers: {'X-Api-Key': 'mock-key'},
        ),
      );

      const queueItem1 = QueueResource(
        id: 101,
        title: 'Ado - Kyogen [FLAC]',
        status: 'downloading',
        downloadClient: 'qBittorrent',
        indexer: 'Nyaa',
        protocol: DownloadProtocol.torrent,
        size: 500000000,
        sizeleft: 200000000,
        timeleft: '00:05:30',
        artistId: 1,
        albumId: 30,
        artist: ArtistResource(artistName: 'Ado'),
        album: AlbumResource(title: 'Kyogen'),
        customFormatScore: 100,
        outputPath: '/downloads/music/Ado',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrApiProvider(testInstance)
                .overrideWith((ref) => LidarrApi(dio)),
            lidarrQueueProvider(testInstance)
                .overrideWith((ref) async => [queueItem1]),
            lidarrHistoryPagedProvider(
              (
                testInstance,
                page: 1,
                pageSize: 50,
                eventType: null,
              ),
            ).overrideWith(
              (ref) async => const HistoryResourcePagingResource(
                page: 1,
                pageSize: 50,
                totalRecords: 0,
                records: [],
              ),
            ),
            lidarrBlocklistProvider(testInstance)
                .overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: ActivityTab(instance: testInstance),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Unified Search Bar in header
      expect(find.text('Search activity...'), findsOneWidget);

      // Filter query that doesn't match
      await tester.enterText(find.byType(TextField), 'Yoasobi');
      await tester.pumpAndSettle();
      expect(find.text('No matches found'), findsOneWidget);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(find.text('Kyogen'), findsOneWidget);

      // 2. Toggle grouping mode (default grouped -> plain list)
      expect(find.byTooltip('Switch to plain list'), findsOneWidget);
      await tester.tap(find.byTooltip('Switch to plain list'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Switch to grouped view'), findsOneWidget);

      // 3. Tap on queue item to open Deep Diagnostics Sheet
      await tester.tap(find.text('Kyogen'));
      await tester.pumpAndSettle();

      // Verify Deep Item Modal Sheet content
      expect(find.text('Download Details'), findsOneWidget);
      expect(find.text('Technical Details'), findsOneWidget);
      expect(find.text('qBittorrent'), findsOneWidget);
      expect(find.text('Nyaa'), findsOneWidget);
      expect(find.text('TORRENT'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('/downloads/music/Ado'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Manual Import'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Interactive Search'),
        findsOneWidget,
      );

      // Close modal sheet
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Download Details'), findsNothing);
    });

    testWidgets(
        'HistoryView supports pagination, infinite scrolling (onLoad), and pull-to-refresh',
        (tester) async {
      int historyFetchCount = 0;

      final List<HistoryResource> page1Records = List.generate(
        50,
        (i) => HistoryResource(
          id: i + 1,
          sourceTitle: 'Release Event Item #${i + 1}',
          eventType: EntityHistoryEventType.grabbed,
          date: '2026-08-15T12:00:00Z',
          artist: const ArtistResource(artistName: 'Test Artist'),
          album: const AlbumResource(title: 'Test Album'),
        ),
      );

      final List<HistoryResource> page2Records = List.generate(
        25,
        (i) => HistoryResource(
          id: i + 51,
          sourceTitle: 'Release Event Item #${i + 51}',
          eventType: EntityHistoryEventType.downloadImported,
          date: '2026-08-14T12:00:00Z',
          artist: const ArtistResource(artistName: 'Test Artist'),
          album: const AlbumResource(title: 'Test Album'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrHistoryPagedProvider(
              (
                testInstance,
                page: 1,
                pageSize: 50,
                eventType: null,
              ),
            ).overrideWith(
              (ref) async {
                historyFetchCount++;
                return HistoryResourcePagingResource(
                  page: 1,
                  pageSize: 50,
                  totalRecords: 75,
                  records: page1Records,
                );
              },
            ),
            lidarrHistoryPagedProvider(
              (
                testInstance,
                page: 2,
                pageSize: 50,
                eventType: null,
              ),
            ).overrideWith(
              (ref) async {
                historyFetchCount++;
                return HistoryResourcePagingResource(
                  page: 2,
                  pageSize: 50,
                  totalRecords: 75,
                  records: page2Records,
                );
              },
            ),
            lidarrActivityGroupedProvider(testInstance).overrideWith(
              () => _TestActivityGroupedNotifier(testInstance, false),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HistoryView(
                instance: testInstance,
              ),
            ),
          ),
        ),
      );

      // Trigger post-frame callback and allow async load
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      // 1. Verify Page 1 items are displayed
      expect(historyFetchCount, equals(1));
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).currentPage,
        equals(1),
      );
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).totalLoaded,
        equals(50),
      );
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).hasMore,
        isTrue,
      );
      expect(find.text('Release Event Item #1'), findsOneWidget);

      // 2. Trigger infinite scroll / load more
      await tester.state<HistoryViewState>(find.byType(HistoryView)).loadMore();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      // Verify Page 2 was requested and items are appended
      expect(historyFetchCount, equals(2));
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).currentPage,
        equals(2),
      );
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).totalLoaded,
        equals(75),
      );
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).hasMore,
        isFalse,
      );

      // 3. Trigger Pull-to-Refresh
      await tester
          .state<HistoryViewState>(find.byType(HistoryView))
          .loadInitial();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(historyFetchCount, equals(3));
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).currentPage,
        equals(1),
      );
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).totalLoaded,
        equals(50),
      );
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).hasMore,
        isTrue,
      );
    });
  });
}

class _TestActivityGroupedNotifier extends LidarrActivityGroupedNotifier {
  _TestActivityGroupedNotifier(super.instance, this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}
