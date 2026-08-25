import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

import 'test_helpers.dart';

void main() {
  group('Lidarr Artists Feature Widget Tests', () {
    testWidgets('ArtistDetailScreen renders discography and track list',
        (tester) async {
      const artist = ArtistResource(
        id: 1,
        artistName: 'Radiohead',
        overview: 'Famous rock band from Oxfordshire.',
        genres: ['Alternative Rock', 'Art Rock'],
        statistics: ArtistStatisticsResource(
          albumCount: 1,
          trackFileCount: 3,
          totalTrackCount: 3,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrArtistByIdProvider((testInstance, 1))
                .overrideWith((ref) async => artist),
            lidarrAlbumsForArtistProvider((testInstance, 1)).overrideWith(
              (ref) async => [
                const AlbumResource(
                  id: 10,
                  artistId: 1,
                  title: 'OK Computer',
                  albumType: 'Studio',
                  releaseDate: '1997-05-21',
                  statistics: AlbumStatisticsResource(
                    trackFileCount: 3,
                    totalTrackCount: 3,
                  ),
                ),
              ],
            ),
            lidarrTracksForAlbumProvider((testInstance, 1, 10)).overrideWith(
              (ref) async => [
                const TrackResource(
                  id: 101,
                  artistId: 1,
                  albumId: 10,
                  title: 'Airbag',
                  trackNumber: '1',
                  duration: 284000,
                  hasFile: true,
                ),
                const TrackResource(
                  id: 102,
                  artistId: 1,
                  albumId: 10,
                  title: 'Paranoid Android',
                  trackNumber: '2',
                  duration: 383000,
                  hasFile: true,
                ),
              ],
            ),
            lidarrArtistHistoryProvider((testInstance, 1)).overrideWith(
              (ref) async => [
                const HistoryResource(
                  id: 99,
                  eventType: EntityHistoryEventType.grabbed,
                  sourceTitle: 'Radiohead - OK Computer (FLAC)',
                  date: '2026-08-10T12:00:00Z',
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: ArtistDetailScreen(
              instance: testInstance,
              artistId: 1,
              initialArtist: artist,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Radiohead'), findsAtLeast(1));

      // Scroll to album and expand
      await tester.scrollUntilVisible(
        find.text('OK Computer'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Studio Albums (1)'), findsOneWidget);
      expect(find.text('OK Computer'), findsOneWidget);

      await tester.tap(find.text('OK Computer'));
      await tester.pumpAndSettle();

      expect(find.text('Airbag'), findsOneWidget);
      expect(find.text('Paranoid Android'), findsOneWidget);

      // Return to ArtistDetailScreen
      Navigator.of(tester.element(find.text('Airbag'))).pop();
      await tester.pumpAndSettle();

      // Open Activity History from overflow menu
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activity History'));
      await tester.pumpAndSettle();

      expect(find.text('Radiohead - OK Computer (FLAC)'), findsOneWidget);
      expect(find.text('grabbed'), findsOneWidget);
    });

    testWidgets(
        'ArtistDetailScreen triggers server commands and renders multi-disc separators',
        (tester) async {
      final List<Map<String, dynamic>> dispatchedCommands = [];

      final Dio dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8686',
          headers: {'X-Api-Key': 'mock-key'},
        ),
      );

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/v1/command' && options.method == 'POST') {
              final Map<String, dynamic> bodyMap =
                  Map<String, dynamic>.from(options.data as Map);
              dispatchedCommands.add(bodyMap);
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id': 42,
                    'name': bodyMap['name'],
                    'status': 'queued',
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      const artist = ArtistResource(
        id: 1,
        artistName: 'Radiohead',
        overview: 'Famous rock band.',
        genres: ['Alternative Rock'],
        statistics: ArtistStatisticsResource(
          albumCount: 1,
          trackFileCount: 4,
          totalTrackCount: 4,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrApiProvider(testInstance)
                .overrideWith((ref) => LidarrApi(dio)),
            lidarrArtistByIdProvider((testInstance, 1))
                .overrideWith((ref) async => artist),
            lidarrAlbumsForArtistProvider((testInstance, 1)).overrideWith(
              (ref) async => [
                const AlbumResource(
                  id: 10,
                  artistId: 1,
                  title: 'OK Computer (Collector Edition)',
                  albumType: 'Studio',
                  mediumCount: 2,
                  releaseDate: '1997-05-21',
                  statistics: AlbumStatisticsResource(
                    trackFileCount: 4,
                    totalTrackCount: 4,
                  ),
                ),
              ],
            ),
            lidarrTracksForAlbumProvider((testInstance, 1, 10)).overrideWith(
              (ref) async => [
                const TrackResource(
                  id: 101,
                  artistId: 1,
                  albumId: 10,
                  mediumNumber: 1,
                  title: 'Airbag',
                  trackNumber: '1',
                  duration: 284000,
                  hasFile: true,
                  trackFileId: 501,
                ),
                const TrackResource(
                  id: 102,
                  artistId: 1,
                  albumId: 10,
                  mediumNumber: 1,
                  title: 'Paranoid Android',
                  trackNumber: '2',
                  duration: 383000,
                  hasFile: true,
                ),
                const TrackResource(
                  id: 103,
                  artistId: 1,
                  albumId: 10,
                  mediumNumber: 2,
                  title: 'Polyethylene',
                  trackNumber: '1',
                  duration: 260000,
                  hasFile: true,
                ),
                const TrackResource(
                  id: 104,
                  artistId: 1,
                  albumId: 10,
                  mediumNumber: 2,
                  title: 'Pearly*',
                  trackNumber: '2',
                  duration: 215000,
                  hasFile: false,
                ),
              ],
            ),
            lidarrTrackFilesForAlbumProvider((testInstance, 10)).overrideWith(
              (ref) async => [
                const TrackFileResource(
                  id: 501,
                  albumId: 10,
                  path: '/music/Radiohead/OK Computer/01 - Airbag.flac',
                  size: 35000000,
                  mediaInfo: MediaInfoResource(
                    audioCodec: 'FLAC',
                    audioBitRate: '980 kbps',
                    audioChannels: 2.0,
                    audioSampleRate: '44.1 kHz',
                    audioBits: '16 bit',
                  ),
                ),
              ],
            ),
            lidarrArtistHistoryProvider((testInstance, 1)).overrideWith(
              (ref) async => [],
            ),
          ],
          child: const MaterialApp(
            home: ArtistDetailScreen(
              instance: testInstance,
              artistId: 1,
              initialArtist: artist,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Tap Refresh & Scan button in AppBar
      await tester.tap(find.byTooltip('Refresh & Scan'));
      await tester.pumpAndSettle();

      expect(dispatchedCommands, hasLength(1));
      expect(dispatchedCommands.first['name'], equals('RefreshArtist'));
      expect(dispatchedCommands.first['artistId'], equals(1));

      // 2. Tap Search Missing button in Hero
      await tester.tap(find.text('Search Missing'));
      await tester.pumpAndSettle();

      expect(dispatchedCommands, hasLength(2));
      expect(dispatchedCommands[1]['name'], equals('ArtistSearch'));
      expect(dispatchedCommands[1]['artistId'], equals(1));

      // 3. Open Album options action sheet via trailing options button and trigger Auto Search
      await tester.scrollUntilVisible(
        find.text('OK Computer (Collector Edition)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Album options').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Auto Search'));
      await tester.pumpAndSettle();

      expect(dispatchedCommands, hasLength(3));
      expect(dispatchedCommands[2]['name'], equals('AlbumSearch'));
      expect(dispatchedCommands[2]['albumIds'], equals([10]));

      // 4. Expand Album Card and verify Disc 1 and Disc 2 headers
      await tester.scrollUntilVisible(
        find.text('OK Computer (Collector Edition)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK Computer (Collector Edition)'));
      await tester.pumpAndSettle();

      expect(find.text('Disc 1'), findsOneWidget);
      expect(find.text('Airbag'), findsOneWidget);

      // 5. Tap on Airbag track to open Track Details modal sheet
      await tester.ensureVisible(find.text('Airbag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Airbag'));
      await tester.pumpAndSettle();

      expect(find.text('Media & File Information'), findsOneWidget);
      expect(find.textContaining('FLAC'), findsAtLeast(1));
      expect(find.text('Delete Audio File'), findsOneWidget);

      // Close track details sheet and pop AlbumDetailScreen
      Navigator.of(tester.element(find.text('Media & File Information'))).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Disc 1'))).pop();
      await tester.pumpAndSettle();

      // 6. Open Artist Info & Links modal bottom sheet
      await tester.tap(find.byTooltip('Artist Info & Links'));
      await tester.pumpAndSettle();

      expect(find.text('Configuration & Library'), findsOneWidget);
      expect(find.text('Biography'), findsOneWidget);
    });

    testWidgets(
        'ArtistDetailScreen renders responsive layout on 360dp phone and toggles section monitoring',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final List<Map<String, dynamic>> putCalls = [];
      final Dio dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8686',
          headers: {'X-Api-Key': 'mock-key'},
        ),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/v1/album/monitor' &&
                options.method == 'PUT') {
              putCalls.add(Map<String, dynamic>.from(options.data as Map));
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

      const artist = ArtistResource(
        id: 1,
        artistName: 'Ado',
        disambiguation: 'Japanese vocalist',
        genres: ['J-Pop', 'Alternative Rock', 'Indie Rock'],
        monitored: true,
        statistics: ArtistStatisticsResource(
          albumCount: 2,
          trackFileCount: 14,
          totalTrackCount: 30,
          sizeOnDisk: 717436000,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrApiProvider(testInstance)
                .overrideWith((ref) => LidarrApi(dio)),
            lidarrArtistByIdProvider((testInstance, 1))
                .overrideWith((ref) async => artist),
            lidarrAlbumsForArtistProvider((testInstance, 1)).overrideWith(
              (ref) async => [
                const AlbumResource(
                  id: 10,
                  artistId: 1,
                  title: '残夢 (Zanmu)',
                  albumType: 'Studio',
                  monitored: true,
                  releaseDate: '2024-07-10',
                  statistics: AlbumStatisticsResource(
                    trackFileCount: 0,
                    totalTrackCount: 16,
                  ),
                ),
                const AlbumResource(
                  id: 11,
                  artistId: 1,
                  title: '狂言 (Kyogen)',
                  albumType: 'Studio',
                  monitored: true,
                  releaseDate: '2022-01-26',
                  statistics: AlbumStatisticsResource(
                    trackFileCount: 14,
                    totalTrackCount: 14,
                  ),
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: ArtistDetailScreen(
              instance: testInstance,
              artistId: 1,
              initialArtist: artist,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify artist name, disambiguation, genres, and progress stats
      expect(find.text('Ado'), findsAtLeast(1));
      expect(find.text('Japanese vocalist'), findsOneWidget);
      expect(find.textContaining('J-Pop'), findsAtLeast(1));
      expect(find.textContaining('14/30 tracks'), findsOneWidget);

      // Scroll to Studio Albums section
      await tester.scrollUntilVisible(
        find.text('Studio Albums (2)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Studio Albums (2)'), findsOneWidget);
      expect(find.text('Monitored'), findsAtLeast(1));

      // Tap the section monitoring button to unmonitor studio albums
      await tester.tap(find.widgetWithText(TextButton, 'Monitored').first);
      await tester.pumpAndSettle();

      expect(putCalls, hasLength(1));
      expect(putCalls.first['albumIds'], equals([10, 11]));
      expect(putCalls.first['monitored'], equals(false));

      // Verify both album cards are present on 360dp phone without overflow
      await tester.scrollUntilVisible(
        find.text('残夢 (Zanmu)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('残夢 (Zanmu)'), findsOneWidget);
      expect(find.text('狂言 (Kyogen)'), findsOneWidget);
    });

    testWidgets(
        'ArtistDetailScreen multi-selection enters selection mode, toggles albums, and executes bulk actions',
        (tester) async {
      final List<Map<String, dynamic>> putCalls = [];
      final List<Map<String, dynamic>> commands = [];

      final Dio dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8686',
          headers: {'X-Api-Key': 'mock-key'},
        ),
      );
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/v1/album/monitor' &&
                options.method == 'PUT') {
              putCalls.add(Map<String, dynamic>.from(options.data as Map));
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{},
                ),
              );
            }
            if (options.path == '/api/v1/command' && options.method == 'POST') {
              final Map<String, dynamic> dataMap =
                  Map<String, dynamic>.from(options.data as Map);
              commands.add(dataMap);
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: <String, dynamic>{
                    'name': dataMap['name'],
                    'state': 'queued',
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      const artist = ArtistResource(
        id: 1,
        artistName: 'Daft Punk',
        status: ArtistStatusType.ended,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrApiProvider(testInstance)
                .overrideWith((ref) => LidarrApi(dio)),
            lidarrArtistByIdProvider((testInstance, 1))
                .overrideWith((ref) async => artist),
            lidarrAlbumsForArtistProvider((testInstance, 1)).overrideWith(
              (ref) async => [
                const AlbumResource(
                  id: 101,
                  artistId: 1,
                  title: 'Discovery',
                  albumType: 'Studio',
                  monitored: true,
                ),
                const AlbumResource(
                  id: 102,
                  artistId: 1,
                  title: 'Random Access Memories',
                  albumType: 'Studio',
                  monitored: true,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: ArtistDetailScreen(
              instance: testInstance,
              artistId: 1,
              initialArtist: artist,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to Discovery album
      await tester.scrollUntilVisible(
        find.text('Discovery'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Discovery'), findsOneWidget);

      // Long press on Discovery to enter selection mode
      await tester.longPress(find.text('Discovery'));
      await tester.pumpAndSettle();

      // Verify contextual selection AppBar and bulk actions bar
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('Invert'), findsOneWidget);
      expect(find.text('Monitor'), findsOneWidget);
      expect(find.text('Unmonitor'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Select All
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      // Tap Bulk Search
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(commands, hasLength(1));
      expect(commands.first['name'], equals('AlbumSearch'));
      expect(commands.first['albumIds'], equals([101, 102]));

      // Selection mode should be cleared after action
      expect(find.text('2 selected'), findsNothing);

      // Re-enter selection mode and test Bulk Unmonitor
      await tester.longPress(find.text('Discovery'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Unmonitor'));
      await tester.pumpAndSettle();

      expect(putCalls, hasLength(1));
      expect(putCalls.first['albumIds'], equals([101]));
      expect(putCalls.first['monitored'], equals(false));
    });

    testWidgets(
        'LidarrAddArtistSearchScreen searches online catalog and detects library presence',
        (tester) async {
      const localArtist = ArtistResource(
        id: 1,
        artistName: 'Radiohead',
        foreignArtistId: 'a74b1b7f-71a5-4011-9441-d0b5e4122711',
        overview: 'English rock band.',
        status: ArtistStatusType.continuing,
      );

      const unaddedArtist = ArtistResource(
        artistName: 'The Smile',
        foreignArtistId: '654321-smile-mbid',
        overview: 'English rock band formed by Thom Yorke and Jonny Greenwood.',
        status: ArtistStatusType.continuing,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrArtistsProvider(testInstance)
                .overrideWith((ref) async => [localArtist]),
            lidarrArtistLookupProvider((testInstance, 'The Smile'))
                .overrideWith(
              (ref) async => [localArtist, unaddedArtist],
            ),
          ],
          child: const MaterialApp(
            home: LidarrAddArtistSearchScreen(instance: testInstance),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially shows empty search prompt
      expect(find.text('Search for an artist to add'), findsOneWidget);

      // Enter search text
      await tester.enterText(find.byType(SearchBar), 'The Smile');
      // Advance past the 600ms debounce timer
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Shows both artists
      expect(find.widgetWithText(Card, 'Radiohead'), findsOneWidget);
      expect(find.widgetWithText(Card, 'The Smile'), findsOneWidget);

      // Radiohead has 'Added' badge
      expect(find.text('Added'), findsOneWidget);

      // The Smile has add circle icon
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    });

    testWidgets(
        'LidarrAddArtistSheet renders all configuration options and submits POST',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const unaddedArtist = ArtistResource(
        artistName: 'The Smile',
        foreignArtistId: '654321-smile-mbid',
        overview: 'English rock band formed by Thom Yorke and Jonny Greenwood.',
        disambiguation: 'UK rock group',
        genres: ['Alternative Rock', 'Post-Punk'],
        status: ArtistStatusType.continuing,
      );

      bool postCalled = false;
      ArtistResource? sentPayload;
      Map<String, dynamic>? sentJson;

      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8686/'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/v1/rootfolder') {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 1, 'path': '/data/music', 'freeSpace': 536870912000},
                  ],
                ),
              );
            }
            if (options.path == '/api/v1/qualityprofile') {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 1, 'name': 'Any'},
                    {'id': 2, 'name': 'FLAC Lossless'},
                  ],
                ),
              );
            }
            if (options.path == '/api/v1/metadataprofile') {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 1, 'name': 'Standard'},
                    {'id': 2, 'name': 'Lossless Studio'},
                  ],
                ),
              );
            }
            if (options.path == '/api/v1/tag') {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 10, 'label': 'favorite'},
                    {'id': 20, 'label': 'vinyl'},
                  ],
                ),
              );
            }
            if (options.method == 'POST' && options.path == '/api/v1/artist') {
              postCalled = true;
              if (options.data is Map) {
                sentJson = Map<String, dynamic>.from(options.data as Map);
              }
              sentPayload = options.data is ArtistResource
                  ? options.data as ArtistResource
                  : ArtistResource.fromJson(
                      Map<String, dynamic>.from(options.data as Map),
                    );
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 201,
                  data: options.data,
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
            lidarrArtistsProvider(testInstance).overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LidarrAddArtistSheet(
                instance: testInstance,
                artist: unaddedArtist,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check artist identity
      expect(find.text('Add Artist Options'), findsOneWidget);
      expect(find.text('The Smile'), findsOneWidget);
      expect(find.text('(UK rock group)'), findsOneWidget);
      expect(find.text('Alternative Rock, Post-Punk'), findsOneWidget);

      // Check section cards
      expect(find.text('Paths & Profiles'), findsOneWidget);
      expect(find.text('Monitoring Options'), findsOneWidget);
      expect(find.text('Monitored'), findsOneWidget);
      expect(find.text('Search for Missing Albums'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);

      // Check tag chips
      expect(find.text('favorite'), findsOneWidget);
      expect(find.text('vinyl'), findsOneWidget);

      // Tap tag chip
      await tester.tap(find.text('favorite'));
      await tester.pumpAndSettle();

      // Toggle search for missing albums switch
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Search for Missing Albums'),
      );
      await tester.pumpAndSettle();

      // Tap Add Artist button
      await tester.tap(find.widgetWithText(FilledButton, 'Add Artist'));
      await tester.pumpAndSettle();

      // Verify POST call was triggered with correct fields
      expect(postCalled, isTrue);
      expect(sentPayload, isNotNull);
      expect(sentPayload!.rootFolderPath, equals('/data/music'));
      expect(sentPayload!.qualityProfileId, equals(1));
      expect(sentPayload!.metadataProfileId, equals(1));
      expect(sentPayload!.tags, contains(10));
      expect(sentPayload!.addOptions?.searchForMissingAlbums, isTrue);

      // Asserted on the raw body rather than the parsed resource. Lidarr
      // declares its fields as non-nullable value types and refuses a null
      // outright, failing the whole request before validating anything, so
      // nothing the app sends may carry one. Round-tripping through
      // ArtistResource hides that, which is how it went unnoticed.
      expect(sentJson, isNotNull);
      expect(
        _nullPaths(sentJson!),
        isEmpty,
        reason: 'Lidarr rejects a null with a JSON conversion error',
      );
    });

    testWidgets('LidarrEditArtistSheet renders and submits updates',
        (tester) async {
      bool putCalled = false;
      ArtistResource? updatedPayload;

      final Dio dio = Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:8686',
          headers: {'X-Api-Key': 'mock-key'},
        ),
      );

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/v1/rootfolder') {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 1, 'path': '/data/music', 'freeSpace': 536870912000},
                  ],
                ),
              );
            }
            if (options.path == '/api/v1/qualityprofile') {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 1, 'name': 'Any'},
                    {'id': 2, 'name': 'FLAC Lossless'},
                  ],
                ),
              );
            }
            if (options.path == '/api/v1/metadataprofile') {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 1, 'name': 'Standard'},
                  ],
                ),
              );
            }
            if (options.path == '/api/v1/tag') {
              return handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {'id': 10, 'label': 'favorite'},
                  ],
                ),
              );
            }
            if (options.method == 'PUT' &&
                options.path.startsWith('/api/v1/artist/')) {
              putCalled = true;
              updatedPayload = options.data is ArtistResource
                  ? options.data as ArtistResource
                  : ArtistResource.fromJson(
                      Map<String, dynamic>.from(options.data as Map),
                    );
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

      const existingArtist = ArtistResource(
        id: 5,
        artistName: 'Radiohead',
        rootFolderPath: '/data/music',
        qualityProfileId: 1,
        metadataProfileId: 1,
        monitored: true,
        monitorNewItems: NewItemMonitorTypes.all,
        tags: [10],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lidarrApiProvider(testInstance)
                .overrideWith((ref) => LidarrApi(dio)),
            lidarrArtistsProvider(testInstance)
                .overrideWith((ref) async => [existingArtist]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LidarrEditArtistSheet(
                instance: testInstance,
                artist: existingArtist,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Radiohead'), findsOneWidget);
      expect(find.text('Profiles & Paths'), findsOneWidget);
      expect(find.text('Monitoring'), findsOneWidget);

      // Tap Save Changes
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(putCalled, isTrue);
      expect(updatedPayload, isNotNull);
      expect(updatedPayload!.id, equals(5));
      expect(updatedPayload!.artistName, equals('Radiohead'));
    });

    testWidgets(
      'ArtistsTab multi-selection enters selection mode and executes bulk operations',
      (WidgetTester tester) async {
        Map<String, dynamic>? lastPutPayload;
        Map<String, dynamic>? lastDeletePayload;
        String? lastCommand;
        Map<String, dynamic>? lastCommandPayload;

        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET' && options.path == '/api/v1/artist') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      {
                        'id': 1,
                        'artistName': 'Radiohead',
                        'monitored': true,
                        'statistics': {'albumCount': 9, 'trackFileCount': 100},
                      },
                      {
                        'id': 2,
                        'artistName': 'Pink Floyd',
                        'monitored': false,
                        'statistics': {'albumCount': 15, 'trackFileCount': 150},
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
                      {'id': 1, 'name': 'Lossless'},
                      {'id': 2, 'name': 'Standard'},
                    ],
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'GET' &&
                  options.path == '/api/v1/metadataprofile') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      {'id': 1, 'name': 'Standard'},
                    ],
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'GET' &&
                  options.path == '/api/v1/rootfolder') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      {'id': 1, 'path': '/music'},
                    ],
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'GET' && options.path == '/api/v1/tag') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: [
                      {'id': 10, 'label': 'rock'},
                      {'id': 20, 'label': 'electronic'},
                    ],
                    statusCode: 200,
                  ),
                );
              }
              if (options.method == 'PUT' &&
                  options.path == '/api/v1/artist/editor') {
                lastPutPayload = options.data as Map<String, dynamic>?;
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                  ),
                );
              }
              if (options.method == 'DELETE' &&
                  options.path == '/api/v1/artist/editor') {
                lastDeletePayload = options.data as Map<String, dynamic>?;
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                  ),
                );
              }
              if (options.method == 'POST' &&
                  options.path == '/api/v1/command') {
                final body = options.data as Map<String, dynamic>;
                lastCommand = body['name'] as String?;
                lastCommandPayload = body;
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: {'name': lastCommand, 'status': 'queued'},
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
            child: const MaterialApp(
              home: Scaffold(
                body: ArtistsTab(instance: testInstance),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Initial State: Both artists rendered in grid
        expect(find.text('Radiohead'), findsOneWidget);
        expect(find.text('Pink Floyd'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);

        // 2. Long-press on 'Radiohead' to enter selection mode
        await tester.longPress(find.text('Radiohead'));
        await tester.pumpAndSettle();

        expect(find.text('1 selected'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
        expect(find.byTooltip('More bulk actions'), findsOneWidget);

        // 3. Select All
        await tester.tap(find.text('Select All'));
        await tester.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);

        // 4. Test Bulk Edit Dialog
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        expect(find.text('Edit 2 artists'), findsOneWidget);
        await tester.tap(find.text('Apply Changes'));
        await tester.pumpAndSettle();

        expect(lastPutPayload?['artistIds'], unorderedEquals([1, 2]));
        ScaffoldMessenger.of(tester.element(find.byType(ArtistsTab)))
            .clearSnackBars();
        await tester.pumpAndSettle();

        // 5. Test Bulk Rename Command
        // Re-select artist
        await tester.longPress(find.text('Pink Floyd'));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);

        await tester.tap(find.byTooltip('More bulk actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Rename Files'));
        await tester.pumpAndSettle();
        expect(find.text('Rename Files'), findsWidgets);
        await tester.tap(find.widgetWithText(FilledButton, 'Rename Files'));
        await tester.pumpAndSettle();

        expect(lastCommand, equals('RenameArtist'));
        expect(lastCommandPayload?['artistIds'], equals([2]));
        ScaffoldMessenger.of(tester.element(find.byType(ArtistsTab)))
            .clearSnackBars();
        await tester.pumpAndSettle();

        // 6. Test Bulk Delete Dialog
        await tester.longPress(find.text('Radiohead'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete 1 Artists?'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete (1)'));
        await tester.pumpAndSettle();

        expect(lastDeletePayload?['artistIds'], equals([1]));
      },
    );

    testWidgets(
      'Lidarr Album Studio sheet and Calendar Feed dialog render and execute actions',
      (tester) async {
        final Dio dio = Dio(
          BaseOptions(
            baseUrl: 'http://127.0.0.1:8686',
            headers: {'X-Api-Key': 'mock-key'},
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/api/v1/artist') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: [
                      {
                        'id': 1,
                        'artistName': 'Radiohead',
                        'status': 'continuing',
                        'monitored': true,
                      },
                    ],
                  ),
                );
              }
              if (options.path == '/api/v1/album') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: [
                      {
                        'id': 101,
                        'title': 'OK Computer',
                        'artistId': 1,
                        'monitored': true,
                        'albumType': 'Studio',
                        'releaseDate': '1997-05-21',
                      },
                    ],
                  ),
                );
              }
              if (options.path == '/api/v1/config/host') {
                return handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'id': 1,
                      'apiKey': 'my-test-api-key',
                    },
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
                body: LidarrHome(instance: testInstance),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Album Studio Action
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        expect(find.text('Album Studio'), findsOneWidget);
        await tester.tap(find.text('Album Studio'));
        await tester.pumpAndSettle();

        expect(find.text('Album Studio'), findsWidgets);
        expect(find.text('Radiohead'), findsWidgets);

        // Close Album Studio
        await tester.pageBack();
        await tester.pumpAndSettle();

        // 2. Calendar Feed Action
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        expect(find.text('iCal Calendar Feed'), findsOneWidget);
        await tester.tap(find.text('iCal Calendar Feed'));
        await tester.pumpAndSettle();

        expect(find.text('iCal Calendar Feed'), findsWidgets);
        expect(find.byTooltip('Copy URL'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      },
    );
  });
}

/// Every place a null appears in [body], as a dotted path, so a failure names
/// the offending field instead of just saying the map is wrong.
List<String> _nullPaths(Object? node, [String path = r'$']) {
  final List<String> found = <String>[];
  if (node is Map) {
    node.forEach((Object? k, Object? v) {
      if (v == null) {
        found.add('$path.$k');
      } else {
        found.addAll(_nullPaths(v, '$path.$k'));
      }
    });
  } else if (node is List) {
    for (int i = 0; i < node.length; i++) {
      if (node[i] == null) {
        found.add('$path[$i]');
      } else {
        found.addAll(_nullPaths(node[i], '$path[$i]'));
      }
    }
  }
  return found;
}
