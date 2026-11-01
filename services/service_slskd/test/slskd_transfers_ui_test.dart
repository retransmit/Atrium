import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_slskd/service_slskd.dart';
import 'package:service_slskd/src/transfers/slskd_analytics_sheet.dart';

final String? _fontDir = () {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    return null;
  }
  return '$flutterRoot/bin/cache/artifacts/material_fonts';
}();

final String _artifactOutDir = Platform.environment['SLSKD_SHOTS_DIR'] ??
    'build/screenshots/service_slskd';

const Instance testInstance = Instance(
  id: 'slskd-1',
  name: 'Home slskd',
  kind: ServiceKind.slskd,
  localUrl: 'http://slskd.local:5030/',
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

Future<void> _capture(WidgetTester tester, GlobalKey key, String filename) async {
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final Uint8List? pngBytes = await tester.runAsync<Uint8List?>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  });
  final Directory dir = Directory(_artifactOutDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final File outFile = File('$_artifactOutDir/$filename');
  outFile.writeAsBytesSync(pngBytes!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<SlskdUserTransfers> mockDownloads = [
    SlskdUserTransfers(
      username: 'AudioPhile99',
      directories: [
        SlskdDirectoryTransfers(
          directory: r'Music\Daft Punk\Discovery (2001) [FLAC]',
          fileCount: 3,
          files: [
            SlskdTransfer(
              id: 'dl-1',
              username: 'AudioPhile99',
              direction: TransferDirection.download,
              filename: r'Music\Daft Punk\Discovery (2001) [FLAC]\01 - One More Time.flac',
              size: 38500000,
              state: 'InProgress',
              requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
              startedAt: DateTime.now().subtract(const Duration(seconds: 45)),
              bytesTransferred: 26950000,
              averageSpeed: 1850000.0, // 1.85 MB/s
            ),
            SlskdTransfer(
              id: 'dl-2',
              username: 'AudioPhile99',
              direction: TransferDirection.download,
              filename: r'Music\Daft Punk\Discovery (2001) [FLAC]\02 - Aerodynamic.flac',
              size: 24200000,
              state: 'Queued, Remotely',
              requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
              placeInQueue: 1,
            ),
            SlskdTransfer(
              id: 'dl-3',
              username: 'AudioPhile99',
              direction: TransferDirection.download,
              filename: r'Music\Daft Punk\Discovery (2001) [FLAC]\03 - Digital Love.flac',
              size: 32100000,
              state: 'Completed, Succeeded',
              requestedAt: DateTime.now().subtract(const Duration(minutes: 5)),
              startedAt: DateTime.now().subtract(const Duration(minutes: 4)),
              endedAt: DateTime.now().subtract(const Duration(minutes: 2)),
              bytesTransferred: 32100000,
            ),
          ],
        ),
      ],
    ),
    SlskdUserTransfers(
      username: 'VinylCollector',
      directories: [
        SlskdDirectoryTransfers(
          directory: r'FLAC\Radiohead\In Rainbows',
          fileCount: 2,
          files: [
            SlskdTransfer(
              id: 'dl-4',
              username: 'VinylCollector',
              direction: TransferDirection.download,
              filename: r'FLAC\Radiohead\In Rainbows\01 15 Step.flac',
              size: 28400000,
              state: 'InProgress',
              requestedAt: DateTime.now().subtract(const Duration(minutes: 1)),
              startedAt: DateTime.now().subtract(const Duration(seconds: 20)),
              bytesTransferred: 14200000,
              averageSpeed: 1200000.0, // 1.2 MB/s
            ),
            SlskdTransfer(
              id: 'dl-5',
              username: 'VinylCollector',
              direction: TransferDirection.download,
              filename: r'FLAC\Radiohead\In Rainbows\02 Bodysnatchers.flac',
              size: 31000000,
              state: 'Completed, Errored',
              requestedAt: DateTime.now().subtract(const Duration(minutes: 3)),
            ),
          ],
        ),
      ],
    ),
  ];

  final List<SlskdUserTransfers> mockUploads = [
    SlskdUserTransfers(
      username: 'GrooveRider',
      directories: [
        SlskdDirectoryTransfers(
          directory: r'Shares\Lossless\Electronic',
          fileCount: 1,
          files: [
            SlskdTransfer(
              id: 'ul-1',
              username: 'GrooveRider',
              direction: TransferDirection.upload,
              filename: r'Shares\Lossless\Electronic\Aphex Twin - Windowlicker.flac',
              size: 45000000,
              state: 'InProgress',
              requestedAt: DateTime.now().subtract(const Duration(minutes: 1)),
              startedAt: DateTime.now().subtract(const Duration(seconds: 30)),
              bytesTransferred: 18000000,
              averageSpeed: 2400000.0, // 2.4 MB/s
            ),
          ],
        ),
      ],
    ),
  ];

  setUpAll(() async {
    await _loadFonts();
  });

  group('SlskdTransfersTab Widget & Screenshot Tests', () {
    testWidgets('renders transfers, toggles flat/grouped, tests filter bottom sheet, and captures screenshots',
        (WidgetTester tester) async {
      // Standard modern mobile phone viewport (iPhone 15/16 Pro & Pixel 8: 393 x 852 logical points)
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdDownloadsProvider(testInstance).overrideWith((ref) => mockDownloads),
            slskdUploadsProvider(testInstance).overrideWith((ref) => mockUploads),
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

      // Verify AppBar: Hamburger, SearchBar, and View Toggle button
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);

      // Verify Stats Bar metrics
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Queued'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Failed'), findsWidgets);

      // Verify Mini FAB (Sort & Filter) in bottom-right
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      // Verify Peer cards and track names in Grouped View (Default)
      expect(find.text('GrooveRider'), findsOneWidget);
      expect(find.text('AudioPhile99'), findsOneWidget);
      expect(find.text('Aphex Twin - Windowlicker.flac'), findsOneWidget);
      expect(find.text('01 - One More Time.flac'), findsOneWidget);
      expect(find.text('02 - Aerodynamic.flac'), findsOneWidget);
      expect(find.text('03 - Digital Love.flac'), findsOneWidget);
      expect(find.text('#1 in queue'), findsOneWidget);
      expect(find.text('DOWNLOAD'), findsWidgets);
      expect(find.text('UPLOAD'), findsOneWidget);

      // 1. Capture Screenshot: Grouped View (Default)
      await _capture(tester, repaintKey, 'slskd_transfers_grouped.png');
      await _capture(tester, repaintKey, 'slskd_transfers_preview.png');

      // 2. Toggle to Flat View
      await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
      await tester.pumpAndSettle();

      // Verify Flat View icon switched to Grouped icon
      expect(find.byIcon(Icons.group_work_outlined), findsOneWidget);
      // Verify flat items
      expect(find.text('Aphex Twin - Windowlicker.flac'), findsOneWidget);
      expect(find.text('01 - One More Time.flac'), findsOneWidget);

      // Capture Screenshot: Flat List View
      await _capture(tester, repaintKey, 'slskd_transfers_flat.png');

      // 3. Tap on a transfer item to open Transfer Details Modal Bottom Sheet
      await tester.tap(find.text('01 - One More Time.flac'));
      await tester.pumpAndSettle();

      // Verify Details Sheet contents
      expect(find.text('Soulseek Diagnostics'), findsOneWidget);
      expect(find.text('File Location'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('AudioPhile99'), findsWidgets);
      expect(find.text('InProgress'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Capture Screenshot: Transfer Details Modal Bottom Sheet
      await _capture(tester, repaintKey, 'slskd_transfers_details_sheet.png');

      // Dismiss details sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Toggle back to Grouped View
      await tester.tap(find.byIcon(Icons.group_work_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);

      // 3. Open Sort & Filter Modal Bottom Sheet via Mini FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Sort & Filter'), findsOneWidget);
      expect(find.text('Direction'), findsOneWidget);
      expect(find.text('Downloads (5)'), findsOneWidget);
      expect(find.text('Uploads (1)'), findsOneWidget);
      expect(find.text('Peer Name (A-Z)'), findsOneWidget);

      // Capture Screenshot: Modal Bottom Sheet
      await _capture(tester, repaintKey, 'slskd_transfers_filter_sheet.png');

      // 4. Select Uploads filter and tap Done
      await tester.tap(find.text('Uploads (1)'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Verify filtered state: only GrooveRider is shown
      expect(find.text('GrooveRider'), findsOneWidget);
      expect(find.text('Aphex Twin - Windowlicker.flac'), findsOneWidget);
      expect(find.text('AudioPhile99'), findsNothing);
      expect(find.text('Filters active:'), findsOneWidget);

      // Capture Screenshot: Filtered State
      await _capture(tester, repaintKey, 'slskd_transfers_filtered.png');

      // 5. Reset filters via active filters pill
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('AudioPhile99'), findsOneWidget);

      // Test Search in SearchBar: type "Radiohead"
      await tester.enterText(find.byType(SearchBar), 'Radiohead');
      await tester.pump();
      expect(find.text('VinylCollector'), findsOneWidget);
      expect(find.text('AudioPhile99'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('AudioPhile99'), findsOneWidget);

      // Test Search with 0 matches empty state
      await tester.enterText(find.byType(SearchBar), 'NonExistentXYZ');
      await tester.pump();
      expect(find.text('No transfers match "NonExistentXYZ"'), findsOneWidget);
      expect(find.text('Clear Search'), findsOneWidget);

      // Tap Clear Search button
      await tester.tap(find.text('Clear Search'));
      await tester.pumpAndSettle();
      expect(find.text('AudioPhile99'), findsOneWidget);
    });

    testWidgets('renders clean empty queue state when 0 transfers exist', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdDownloadsProvider(testInstance).overrideWith((ref) => const []),
            slskdUploadsProvider(testInstance).overrideWith((ref) => const []),
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

      expect(find.text('No transfers in queue'), findsOneWidget);
      expect(find.text('Search Music'), findsOneWidget);
    });

    testWidgets('keeps an empty queue and its filter row through a poll', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdDownloadsProvider(testInstance).overrideWith((ref) async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return const <SlskdUserTransfers>[];
            }),
            slskdUploadsProvider(testInstance).overrideWith((ref) => const []),
          ],
          child: const MaterialApp(home: SlskdHome(instance: testInstance)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sort & Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Downloads ('));
      await tester.tap(find.text('Completed').last);
      await tester.tap(find.text('File Size (Largest)'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // The chips overflow the row, so scroll it along.
      await tester.drag(find.text('Downloads').first, const Offset(-300, 0));
      await tester.pumpAndSettle();
      final double scrolledX = tester.getTopLeft(find.text('Reset')).dx;

      ProviderScope.containerOf(tester.element(find.byType(SlskdHome)))
          .invalidate(slskdDownloadsProvider(testInstance));
      await tester.pump();
      expect(find.text('Reset'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Reset')).dx, scrolledX);
    });

    testWidgets('renders SlskdAnalyticsSheet with KPIs, leaderboard, and Pareto failure charts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      final mockLeaderboard = <SlskdTransferSummary>[
        const SlskdTransferSummary(
          username: 'VinylVault',
          totalBytes: 14500000000,
          count: 420,
          averageSpeed: 3800000.0,
        ),
        const SlskdTransferSummary(
          username: 'AudioPhile99',
          totalBytes: 8900000000,
          count: 215,
          averageSpeed: 2100000.0,
        ),
        const SlskdTransferSummary(
          username: 'SoulSeeker',
          totalBytes: 4200000000,
          count: 98,
          averageSpeed: 1400000.0,
        ),
      ];

      final mockPareto = <SlskdTransferExceptionSummary>[
        const SlskdTransferExceptionSummary(
          exception: 'Cancelled by remote peer',
          count: 18,
          distinctUsers: 7,
        ),
        const SlskdTransferExceptionSummary(
          exception: 'Connection timed out',
          count: 6,
          distinctUsers: 4,
        ),
      ];

      final mockDirs = <SlskdTransferDirectorySummary>[
        const SlskdTransferDirectorySummary(
          directory: 'FLAC/Radiohead - In Rainbows',
          count: 154,
          distinctUsers: 32,
        ),
        const SlskdTransferDirectorySummary(
          directory: 'MP3/Daft Punk - Discovery',
          count: 88,
          distinctUsers: 19,
        ),
      ];

      const mockKpis = <String, SlskdPrometheusMetric>{
        'process_working_set_bytes': SlskdPrometheusMetric(
          name: 'process_working_set_bytes',
          samples: [SlskdPrometheusMetricSample(value: 178257920.0)],
        ),
        'dotnet_total_memory_bytes': SlskdPrometheusMetric(
          name: 'dotnet_total_memory_bytes',
          samples: [SlskdPrometheusMetricSample(value: 62914560.0)],
        ),
        'microsoft_aspnetcore_server_kestrel_current_connections': SlskdPrometheusMetric(
          name: 'microsoft_aspnetcore_server_kestrel_current_connections',
          samples: [SlskdPrometheusMetricSample(value: 8.0)],
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdTransferLeaderboardProvider((testInstance, 'Download')).overrideWith((ref) => mockLeaderboard),
            slskdTransferExceptionsParetoProvider((testInstance, 'Download')).overrideWith((ref) => mockPareto),
            slskdTransferDirectoriesProvider(testInstance).overrideWith((ref) => mockDirs),
            slskdPrometheusKpisProvider(testInstance).overrideWith((ref) => mockKpis),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF007ACC),
              brightness: Brightness.dark,
              fontFamily: 'Roboto',
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: repaintKey,
                child: const SlskdAnalyticsSheet(
                  instance: testInstance,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Transfer Analytics & KPIs'), findsOneWidget);
      expect(find.text('Resident Memory'), findsOneWidget);
      expect(find.text('VinylVault'), findsOneWidget);
      expect(find.text('Cancelled by remote peer'), findsOneWidget);

      await _capture(tester, repaintKey, 'slskd_transfers_analytics.png');
    });

    testWidgets('renders SlskdHome in Material 3 light theme with full contrast',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdDownloadsProvider(testInstance).overrideWith((ref) => mockDownloads),
            slskdUploadsProvider(testInstance).overrideWith((ref) => mockUploads),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF007ACC),
              brightness: Brightness.light,
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
      expect(find.text('AudioPhile99'), findsOneWidget);
      expect(find.text('VinylCollector'), findsOneWidget);
      await _capture(tester, repaintKey, 'slskd_transfers_light.png');
    });

    testWidgets('fastest speed ranks running transfers above finished ones', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      SlskdUserTransfers peer(String name, String state, double speed) => SlskdUserTransfers(
            username: name,
            directories: <SlskdDirectoryTransfers>[
              SlskdDirectoryTransfers(
                directory: 'Album',
                fileCount: 1,
                files: <SlskdTransfer>[
                  SlskdTransfer(
                    id: '$name-1',
                    username: name,
                    direction: TransferDirection.download,
                    filename: r'Album\01.flac',
                    size: 30000000,
                    state: state,
                    requestedAt: DateTime(2026),
                    bytesTransferred: 10000000,
                    averageSpeed: speed,
                  ),
                ],
              ),
            ],
          );

      // The finished peer keeps a high final average; the running one is slower.
      final List<SlskdUserTransfers> downloads = <SlskdUserTransfers>[
        peer('FinishedPeer', 'Completed, Succeeded', 9000000),
        peer('RunningPeer', 'InProgress', 1000000),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdDownloadsProvider(testInstance).overrideWith((ref) => downloads),
            slskdUploadsProvider(testInstance).overrideWith((ref) => const []),
          ],
          child: const MaterialApp(home: SlskdHome(instance: testInstance)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sort & Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fastest Speed'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('RunningPeer')).dy,
        lessThan(tester.getTopLeft(find.text('FinishedPeer')).dy),
      );
    });
  });
}
