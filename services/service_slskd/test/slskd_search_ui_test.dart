import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_slskd/service_slskd.dart';

final String? _fontDir = () {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    return null;
  }
  return '$flutterRoot/bin/cache/artifacts/material_fonts';
}();

final String screenshotDir = Platform.environment['SLSKD_SHOTS_DIR'] ??
    'build/screenshots/service_slskd';

const Instance testInstance = Instance(
  id: 'test-slskd-search',
  name: 'Soulseek Daemon',
  kind: ServiceKind.slskd,
  localUrl: 'http://127.0.0.1:5030/',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthApiKey(apiKey: 'secret-key'),
);

Future<void> _loadFonts() async {
  if (_fontDir == null) {
    return;
  }
  final Directory dir = Directory(_fontDir!);
  if (!dir.existsSync()) {
    return;
  }

  File? findFontFile(String filename) {
    final File direct = File('$_fontDir/$filename');
    if (direct.existsSync()) {
      return direct;
    }
    final String lower = filename.toLowerCase();
    try {
      for (final FileSystemEntity entity in dir.listSync()) {
        if (entity is File &&
            entity.path.split(RegExp(r'[/\\]')).last.toLowerCase() == lower) {
          return entity;
        }
      }
    } catch (_) {}
    return null;
  }

  final FontLoader roboto = FontLoader('Roboto');
  for (final String font in <String>[
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final File? f = findFontFile(font);
    if (f != null && f.existsSync()) {
      roboto.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
  }
  await roboto.load();

  final File? icons = findFontFile('MaterialIcons-Regular.otf');
  if (icons != null && icons.existsSync()) {
    final FontLoader materialIcons = FontLoader('MaterialIcons');
    materialIcons.addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await materialIcons.load();
  }
}

Future<void> capture(
  WidgetTester tester,
  GlobalKey key,
  String fileName,
) async {
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final Uint8List? pngBytes = await tester.runAsync<Uint8List?>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  });
  final Directory dir = Directory(screenshotDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final File outFile = File('$screenshotDir/$fileName');
  outFile.writeAsBytesSync(pngBytes!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  final mockSearches = <SlskdSearch>[
    SlskdSearch(
      id: 'search-1',
      searchText: 'Daft Punk',
      state: 'Completed',
      isComplete: true,
      fileCount: 7,
      responseCount: 2,
      startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    SlskdSearch(
      id: 'search-2',
      searchText: 'Radiohead',
      state: 'Completed',
      isComplete: true,
      fileCount: 3,
      responseCount: 1,
      startedAt: DateTime.now().subtract(const Duration(seconds: 40)),
    ),
  ];

  final mockResponses = <SlskdSearchResponse>[
    const SlskdSearchResponse(
      username: 'AudioPhile99',
      fileCount: 4,
      lockedFileCount: 0,
      hasFreeUploadSlot: true,
      queueLength: 0,
      uploadSpeed: 2800000, // 2.8 MB/s
      token: 101,
      files: <SlskdSearchFile>[
        SlskdSearchFile(
          filename: r'Music\Daft Punk\Discovery (2001) [FLAC]\01 - One More Time.flac',
          size: 38500000,
          extension: 'flac',
          bitDepth: 24,
          bitRate: 1411,
          length: 320,
        ),
        SlskdSearchFile(
          filename: r'Music\Daft Punk\Discovery (2001) [FLAC]\02 - Aerodynamic.flac',
          size: 24200000,
          extension: 'flac',
          bitDepth: 24,
          bitRate: 1411,
          length: 207,
        ),
        SlskdSearchFile(
          filename: r'Music\Daft Punk\Discovery (2001) [FLAC]\03 - Digital Love.flac',
          size: 32100000,
          extension: 'flac',
          bitDepth: 24,
          bitRate: 1411,
          length: 298,
        ),
        SlskdSearchFile(
          filename: r'Music\Daft Punk\Discovery (2001) [FLAC]\04 - Harder Better Faster.flac',
          size: 27800000,
          extension: 'flac',
          bitDepth: 24,
          bitRate: 1411,
          length: 224,
        ),
      ],
    ),
    const SlskdSearchResponse(
      username: 'GrooveMaster',
      fileCount: 3,
      lockedFileCount: 0,
      hasFreeUploadSlot: true,
      queueLength: 0,
      uploadSpeed: 1950000, // 1.95 MB/s
      token: 102,
      files: <SlskdSearchFile>[
        SlskdSearchFile(
          filename: r'MP3\Daft Punk\Homework (1997) [320k]\01 Daftendirekt.mp3',
          size: 6800000,
          extension: 'mp3',
          bitRate: 320,
          length: 164,
        ),
        SlskdSearchFile(
          filename: r'MP3\Daft Punk\Homework (1997) [320k]\02 WDPK 83.7 FM.mp3',
          size: 1900000,
          extension: 'mp3',
          bitRate: 320,
          length: 28,
        ),
        SlskdSearchFile(
          filename: r'MP3\Daft Punk\Homework (1997) [320k]\03 Revolution 909.mp3',
          size: 13200000,
          extension: 'mp3',
          bitRate: 320,
          length: 326,
        ),
      ],
    ),
  ];

  group('SlskdSearchTab Widget & Screenshot Tests', () {
    testWidgets('renders search tab, toggles views, tests filter bottom sheet, and captures screenshots',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdActiveTabProvider(testInstance).overrideWith((ref) => 1),
            slskdSearchesProvider(testInstance).overrideWith((ref) => mockSearches),
            slskdSearchResponsesProvider((testInstance, 'search-1')).overrideWith(
              (ref) => mockResponses,
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF007ACC),
              brightness: Brightness.dark,
              fontFamily: 'Roboto',
            ),
            builder: (BuildContext context, Widget? child) {
              return RepaintBoundary(
                key: repaintKey,
                child: child!,
              );
            },
            home: const SlskdHome(instance: testInstance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppBar: SearchBar and View Toggle button
      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);

      // Verify Active Searches Ribbon
      expect(find.text('Daft Punk (7)'), findsOneWidget);
      expect(find.text('Radiohead (3)'), findsOneWidget);

      // Verify Grouped Album cards
      expect(find.text('Discovery (2001) [FLAC]'), findsOneWidget);
      expect(find.text('Homework (1997) [320k]'), findsOneWidget);
      expect(find.text('AudioPhile99'), findsOneWidget);
      expect(find.text('GrooveMaster'), findsOneWidget);
      expect(find.text('Download Album'), findsNWidgets(2));
      expect(find.text('01 - One More Time.flac'), findsOneWidget);

      // 1. Capture Screenshot: Album Grouped View (Default)
      await capture(tester, repaintKey, 'slskd_search_grouped.png');

      // 2. Toggle to Flat View
      await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
      await tester.pumpAndSettle();

      // Verify Flat View icon switched
      expect(find.byIcon(Icons.album_outlined), findsOneWidget);
      expect(find.text('01 - One More Time.flac'), findsOneWidget);
      expect(find.text('01 Daftendirekt.mp3'), findsOneWidget);

      // Capture Screenshot: Flat List View
      await capture(tester, repaintKey, 'slskd_search_flat.png');

      // Toggle back to Grouped View
      await tester.tap(find.byIcon(Icons.album_outlined));
      await tester.pumpAndSettle();

      // 3. Open Sort & Filter Modal Bottom Sheet via Mini FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Sort & Filter Results'), findsOneWidget);
      expect(find.text('Audio Format'), findsOneWidget);
      expect(find.text('FLAC Only'), findsOneWidget);
      expect(find.text('MP3 Only'), findsOneWidget);
      expect(find.text('Free Slot Only (Instant)'), findsOneWidget);
      expect(find.text('Fastest Speed'), findsOneWidget);

      // Capture Screenshot: Modal Bottom Sheet
      await capture(tester, repaintKey, 'slskd_search_filter_sheet.png');

      // 4. Select FLAC Only filter and tap Done
      await tester.tap(find.text('FLAC Only'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Verify filtered state: Discovery is present, Homework (MP3) is filtered out
      expect(find.text('Discovery (2001) [FLAC]'), findsOneWidget);
      expect(find.text('Homework (1997) [320k]'), findsNothing);
      expect(find.text('Filters active:'), findsOneWidget);

      // Capture Screenshot: Filtered State
      await capture(tester, repaintKey, 'slskd_search_filtered.png');

      // 5. Reset filters via active filters pill
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Homework (1997) [320k]'), findsOneWidget);
    });

    testWidgets('renders initial empty search view when no searches exist',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdActiveTabProvider(testInstance).overrideWith((ref) => 1),
            slskdSearchesProvider(testInstance).overrideWith((ref) => const []),
          ],
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF007ACC),
              brightness: Brightness.dark,
              fontFamily: 'Roboto',
            ),
            builder: (BuildContext context, Widget? child) {
              return RepaintBoundary(
                key: repaintKey,
                child: child!,
              );
            },
            home: const SlskdHome(instance: testInstance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('P2P Music Search'), findsOneWidget);
      expect(
        find.text('Search artists, albums, or tracks across millions of Soulseek peer shares.'),
        findsOneWidget,
      );

      // Capture Screenshot: Initial Empty State
      await capture(tester, repaintKey, 'slskd_search_empty.png');
    });

    testWidgets('says a search failed rather than that it found nothing',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // What slskd stores for a search started while it is not logged in to
      // Soulseek.
      final failedSearch = <SlskdSearch>[
        SlskdSearch(
          id: 'search-failed',
          searchText: 'Daft Punk',
          state: 'Completed, Errored',
          isComplete: true,
          startedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdActiveTabProvider(testInstance).overrideWith((ref) => 1),
            slskdSearchesProvider(testInstance).overrideWith((ref) => failedSearch),
            slskdSearchResponsesProvider((testInstance, 'search-failed')).overrideWith(
              (ref) => const <SlskdSearchResponse>[],
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF007ACC),
              brightness: Brightness.dark,
              fontFamily: 'Roboto',
            ),
            home: const SlskdHome(instance: testInstance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search for "Daft Punk" failed'), findsOneWidget);
      expect(find.textContaining('connected to Soulseek'), findsOneWidget);
      expect(find.text('No results found for "Daft Punk"'), findsNothing);
    });

    testWidgets('keeps a finished search finished through a poll', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      final failedSearch = <SlskdSearch>[
        SlskdSearch(
          id: 'search-failed',
          searchText: 'Daft Punk',
          state: 'Completed, Errored',
          isComplete: true,
          startedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdActiveTabProvider(testInstance).overrideWith((ref) => 1),
            slskdSearchesProvider(testInstance).overrideWith((ref) => failedSearch),
            slskdSearchResponsesProvider((testInstance, 'search-failed')).overrideWith(
              (ref) async {
                await Future<void>.delayed(const Duration(milliseconds: 50));
                return const <SlskdSearchResponse>[];
              },
            ),
          ],
          child: const MaterialApp(home: SlskdHome(instance: testInstance)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Search for "Daft Punk" failed'), findsOneWidget);

      ProviderScope.containerOf(tester.element(find.byType(SlskdHome)))
          .invalidate(slskdSearchResponsesProvider((testInstance, 'search-failed')));
      await tester.pump();
      expect(find.text('Search for "Daft Punk" failed'), findsOneWidget);
      expect(find.text('Stop Search'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('album download leaves out locked tracks', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final List<String> requested = <String>[];
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:5030/'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == 'api/v0/transfers/downloads/batches') {
              final List<dynamic> files = (options.data as Map)['files'] as List<dynamic>;
              requested.addAll(files.map((dynamic f) => (f as Map)['filename'] as String));
            }
            return handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200, data: <String, dynamic>{}),
            );
          },
        ),
      );

      final responses = <SlskdSearchResponse>[
        const SlskdSearchResponse(
          username: 'AudioPhile99',
          fileCount: 1,
          lockedFileCount: 1,
          hasFreeUploadSlot: true,
          queueLength: 0,
          uploadSpeed: 2800000,
          token: 101,
          files: <SlskdSearchFile>[
            SlskdSearchFile(
              filename: r'Music\Daft Punk\Discovery\01 - One More Time.flac',
              size: 38500000,
              extension: 'flac',
            ),
          ],
          lockedFiles: <SlskdSearchFile>[
            SlskdSearchFile(
              filename: r'Music\Daft Punk\Discovery\02 - Aerodynamic.flac',
              size: 24200000,
              extension: 'flac',
              isLocked: true,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdActiveTabProvider(testInstance).overrideWith((ref) => 1),
            slskdSearchesProvider(testInstance).overrideWith((ref) => mockSearches),
            slskdSearchResponsesProvider((testInstance, 'search-1')).overrideWith(
              (ref) => responses,
            ),
            slskdApiProvider(testInstance).overrideWith((ref) async => SlskdApi(dio)),
          ],
          child: const MaterialApp(home: SlskdHome(instance: testInstance)),
        ),
      );
      await tester.pumpAndSettle();

      // Show locked files, so the album holds one of each.
      await tester.tap(find.byTooltip('Sort & Filter Results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide Locked Files'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('02 - Aerodynamic.flac'), findsOneWidget);

      await tester.tap(find.text('Download Album'));
      await tester.pumpAndSettle();

      expect(requested, <String>[r'Music\Daft Punk\Discovery\01 - One More Time.flac']);
    });
  });
}
