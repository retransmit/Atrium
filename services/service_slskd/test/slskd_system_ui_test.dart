import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_slskd/service_slskd.dart';
import 'package:service_slskd/src/system/slskd_daemon_card.dart';
import 'package:service_slskd/src/system/slskd_disk_files_sheet.dart';
import 'package:service_slskd/src/system/slskd_logs_view.dart';
import 'package:service_slskd/src/system/slskd_options_sheet.dart';
import 'package:service_slskd/src/system/slskd_share_contents_sheet.dart';
import 'package:service_slskd/src/tabs/slskd_system_tab.dart';

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
  id: 'test-slskd-system',
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

  const mockAppState = SlskdApplicationState(
    version: SlskdVersionState(
      current: '0.22.1',
      full: '0.22.1+4b8f102',
      latest: '0.22.1',
      isUpdateAvailable: false,
    ),
    server: SlskdServerStatus(
      address: 'server.slsknet.org:2242',
      state: 'Connected',
      isConnected: true,
      isLoggedIn: true,
    ),
    user: SlskdUserState(
      username: 'AudioPhileX',
      isPrivileged: true,
      privilegesRemaining: 42,
      averageSpeed: 1468000,
      directoryCount: 128,
      fileCount: 3420,
      uploadCount: 580,
    ),
    shares: SlskdSharesState(
      directories: 128,
      files: 3420,
    ),
    vpn: SlskdVpnState(
      isReady: true,
      isConnected: true,
      publicIpAddress: '198.51.100.42',
      location: 'Zurich, Switzerland',
      forwardedPort: 50300,
    ),
    connectionWatchdog: SlskdConnectionWatchdogState(
      isEnabled: true,
    ),
  );

  final mockSharesMap = <String, List<SlskdLocalShare>>{
    'LocalHost': <SlskdLocalShare>[
      const SlskdLocalShare(
        id: '1',
        name: 'FLAC Hi-Res Albums',
        path: '/storage/music/flac',
        directories: 84,
        files: 2150,
      ),
      const SlskdLocalShare(
        id: '2',
        name: 'MP3 320k Discography',
        path: '/storage/music/mp3',
        directories: 44,
        files: 1270,
      ),
      const SlskdLocalShare(
        id: '3',
        name: 'Private Incomplete Stash',
        path: '/storage/music/private',
        isExcluded: true,
      ),
    ],
  };

  final mockLogs = <SlskdLogRecord>[
    SlskdLogRecord(
      timestamp: DateTime(2026, 10, 24, 20, 15, 32),
      level: 'Information',
      context: 'slskd.Core.Server',
      message: 'Successfully established connection with Soulseek server.',
    ),
    SlskdLogRecord(
      timestamp: DateTime(2026, 10, 24, 20, 18, 04),
      level: 'Information',
      context: 'slskd.Shares',
      message: 'Share index updated: 3,420 files across 128 directories.',
    ),
    SlskdLogRecord(
      timestamp: DateTime(2026, 10, 24, 20, 22, 11),
      level: 'Warning',
      context: 'slskd.Transfers',
      message: 'Peer VinylLover timed out during transfer handshake; retrying (attempt 1/3).',
    ),
    SlskdLogRecord(
      timestamp: DateTime(2026, 10, 24, 20, 25, 48),
      level: 'Error',
      context: 'slskd.Network.UPnP',
      message: 'UPnP port mapping failed for port 50300: Gateway returned HTTP 500.',
    ),
    SlskdLogRecord(
      timestamp: DateTime(2026, 10, 24, 20, 30),
      level: 'Debug',
      context: 'slskd.Search.Distributed',
      message: 'Routing search query "Daft Punk Discovery" to 14 distributed child nodes.',
    ),
  ];

  group('SlskdSystemTab Widget & Screenshot Tests', () {
    testWidgets('renders System Health, Shares, Logs, details sheet, and actions menu',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdApplicationStateProvider(testInstance).overrideWith((ref) => mockAppState),
            slskdSharesProvider(testInstance).overrideWith((ref) => mockSharesMap),
            slskdLogsProvider(testInstance).overrideWith((ref) => mockLogs),
            slskdLogFilesProvider(testInstance).overrideWith((ref) => <SlskdDiskFile>[]),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D9488),
                brightness: Brightness.dark,
              ),
              fontFamily: 'Roboto',
            ),
            builder: (BuildContext context, Widget? child) {
              return RepaintBoundary(
                key: repaintKey,
                child: child!,
              );
            },
            home: const SlskdSystemTab(
              instance: testInstance,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify and capture Health view
      expect(find.text('System & Health'), findsOneWidget);
      expect(find.text('Soulseek Network'), findsOneWidget);
      expect(find.text('server.slsknet.org:2242'), findsOneWidget);
      expect(find.text('AudioPhileX'), findsOneWidget);
      expect(find.text('slskd Daemon'), findsOneWidget);
      expect(find.text('VPN Protection'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_system_health.png');

      // 2. Switch to Shares segment
      await tester.tap(find.text('Shares'));
      await tester.pumpAndSettle();

      expect(find.text('Shared Library'), findsOneWidget);
      expect(find.text('3420 files across 128 folders'), findsOneWidget);
      expect(find.text('Rescan Shares'), findsOneWidget);
      expect(find.text('FLAC Hi-Res Albums'), findsOneWidget);
      expect(find.text('MP3 320k Discography'), findsOneWidget);
      expect(find.text('Private Incomplete Stash'), findsOneWidget);
      expect(find.text('Excluded'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_system_shares.png');

      // 3. Switch to Logs segment
      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Information'), findsOneWidget);
      expect(find.text('Debug'), findsOneWidget);
      expect(find.textContaining('Successfully established connection'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_system_logs.png');

      // 4. Tap on an error log entry to open details sheet
      await tester.tap(find.textContaining('UPnP port mapping failed'));
      await tester.pumpAndSettle();

      expect(find.text('Log Message'), findsOneWidget);
      expect(find.text('Context: slskd.Network.UPnP'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_system_log_details.png');

      // Close bottom sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // 5. Open more actions menu and verify actions
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Transfer analytics & KPIs'), findsOneWidget);
      expect(find.text('Host storage explorer'), findsOneWidget);
      expect(find.text('Configuration & diagnostics'), findsOneWidget);
    });

    testWidgets('renders SlskdShareContentsSheet with folder tree and files',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      final mockShareDirs = <SlskdDirectory>[
        const SlskdDirectory(
          name: 'Radiohead - In Rainbows [FLAC]',
          files: [
            SlskdSearchFile(
              filename: '01 15 Step.flac',
              size: 28400000,
              extension: 'flac',
              bitRate: 980,
            ),
            SlskdSearchFile(
              filename: '02 Bodysnatchers.flac',
              size: 31200000,
              extension: 'flac',
              bitRate: 1012,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdShareContentsProvider((testInstance, '1')).overrideWith((ref) => mockShareDirs),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D9488),
                brightness: Brightness.dark,
              ),
              fontFamily: 'Roboto',
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: repaintKey,
                child: const SlskdShareContentsSheet(
                  instance: testInstance,
                  shareId: '1',
                  title: 'FLAC Hi-Res Albums',
                  sharePath: '/storage/music/flac',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('FLAC Hi-Res Albums'), findsOneWidget);
      expect(find.text('/storage/music/flac'), findsOneWidget);
      expect(find.text('Radiohead - In Rainbows [FLAC]'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_share_contents_sheet.png');
    });

    testWidgets('renders SlskdDiskFilesSheet with downloads and incomplete segments',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      const mockDiskDir = SlskdDiskDirectory(
        name: 'downloads',
        fullName: '/storage/downloads',
        directories: [
          SlskdDiskDirectory(
            name: 'Daft Punk - Discovery (2001)',
            fullName: '/storage/downloads/Daft Punk - Discovery (2001)',
          ),
        ],
        files: [
          SlskdDiskFile(
            name: 'ambient_session_live.flac',
            fullName: '/storage/downloads/ambient_session_live.flac',
            length: 52400000,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdDownloadsDirectoryProvider((testInstance, null)).overrideWith((ref) => mockDiskDir),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D9488),
                brightness: Brightness.dark,
              ),
              fontFamily: 'Roboto',
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: repaintKey,
                child: const SlskdDiskFilesSheet(
                  instance: testInstance,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Host Storage Explorer'), findsOneWidget);
      expect(find.text('Downloads'), findsNWidgets(2));
      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.text('Daft Punk - Discovery (2001)'), findsOneWidget);
      expect(find.text('ambient_session_live.flac'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_disk_files_sheet.png');
    });

    testWidgets('renders SlskdOptionsSheet with overview and diagnostics',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      const mockOptions = <String, dynamic>{
        'soulseek': {
          'username': 'AudioPhileX',
          'listenPort': 50300,
        },
        'network': {
          'upnp': true,
        },
        'remoteConfiguration': true,
        'directories': {
          'downloads': '/storage/downloads',
          'incomplete': '/storage/incomplete',
        },
        'flags': {
          'noVersionCheck': false,
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdOptionsProvider(testInstance).overrideWith((ref) => mockOptions),
            slskdDebugTransfersProvider(testInstance).overrideWith((ref) => <String, dynamic>{'active': <dynamic>[], 'queued': <dynamic>[]}),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D9488),
                brightness: Brightness.dark,
              ),
              fontFamily: 'Roboto',
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: repaintKey,
                child: const SlskdOptionsSheet(
                  instance: testInstance,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Configuration & Diagnostics'), findsOneWidget);
      expect(find.text('Soulseek Account & Listening'), findsOneWidget);
      expect(find.text('AudioPhileX'), findsOneWidget);
      expect(find.text('50300'), findsOneWidget);
      expect(find.text('/storage/downloads'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_system_options_sheet.png');

      // Test Diagnostics segment
      await tester.tap(find.text('Diagnostics'));
      await tester.pumpAndSettle();
      expect(find.text('Force Garbage Collection'), findsOneWidget);
      expect(find.text('Loopback Echo Test'), findsOneWidget);
      expect(find.text('Run GC'), findsOneWidget);
      expect(find.text('Ping'), findsOneWidget);
      await capture(tester, repaintKey, 'slskd_system_options_diagnostics.png');
    });

    testWidgets('daemon card does not call an unknown update status up to date',
        (WidgetTester tester) async {
      Future<void> pumpCard(bool? updateAvailable) => tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Scaffold(
                  body: SlskdDaemonCard(
                    instance: testInstance,
                    version: SlskdVersionState(
                      current: '0.26.2.0',
                      isUpdateAvailable: updateAvailable,
                    ),
                  ),
                ),
              ),
            ),
          );

      await pumpCard(null);
      expect(find.text('Up to date'), findsNothing);
      expect(find.text('Check for updates'), findsOneWidget);

      await pumpCard(false);
      expect(find.text('Up to date'), findsOneWidget);

      await pumpCard(true);
      expect(find.text('Update Available'), findsOneWidget);
    });

    testWidgets('falls back to the live log when the open file is rotated away',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      List<SlskdDiskFile> files = const <SlskdDiskFile>[
        SlskdDiskFile(name: 'slskd-20261029.log', fullName: '/app/logs/slskd-20261029.log', length: 1200),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdSelectedHistoricalLogProvider(testInstance).overrideWith(
              (ref) => 'slskd-20261029.log',
            ),
            slskdLogFilesProvider(testInstance).overrideWith((ref) async => files),
            slskdLogFileContentProvider((testInstance, 'slskd-20261029.log')).overrideWith(
              (ref) async => 'an old line',
            ),
            slskdLogsProvider(testInstance).overrideWith((ref) => mockLogs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ListView(children: const <Widget>[SlskdLogsView(instance: testInstance)]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('an old line'), findsOneWidget);

      // slskd rotated the file away.
      files = const <SlskdDiskFile>[
        SlskdDiskFile(name: 'slskd-20261030.log', fullName: '/app/logs/slskd-20261030.log', length: 800),
      ];
      ProviderScope.containerOf(tester.element(find.byType(SlskdLogsView)))
          .invalidate(slskdLogFilesProvider(testInstance));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('an old line'), findsNothing);
      expect(find.text('Live Stream (In-Memory)'), findsOneWidget);
    });
  });
}
