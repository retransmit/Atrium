import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_aria2/service_aria2.dart';

const Instance testInstance = Instance(
  id: 'aria2-1',
  name: 'Home aria2',
  kind: ServiceKind.aria2,
  localUrl: 'http://aria2.local:6800/',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthUserPass(username: '', password: ''),
);

void main() {
  const Aria2Download activeDownload = Aria2Download(
    gid: 'gid-active-1',
    status: 'active',
    totalLength: 104857600,
    completedLength: 52428800,
    downloadSpeed: 2097152,
    uploadSpeed: 102400,
    files: <Aria2File>[
      Aria2File(
        index: 1,
        path: '/downloads/debian.iso',
        length: 104857600,
        completedLength: 52428800,
      ),
    ],
  );

  const Aria2Download waitingDownload = Aria2Download(
    gid: 'gid-waiting-1',
    status: 'waiting',
    totalLength: 204800000,
    files: <Aria2File>[
      Aria2File(index: 1, path: '/downloads/arch.iso', length: 204800000),
    ],
  );

  const Aria2Download completedDownload = Aria2Download(
    gid: 'gid-complete-1',
    status: 'complete',
    totalLength: 50000000,
    completedLength: 50000000,
    files: <Aria2File>[
      Aria2File(
        index: 1,
        path: '/downloads/fedora.iso',
        length: 50000000,
        completedLength: 50000000,
      ),
    ],
  );

  const Aria2Download erroredDownload = Aria2Download(
    gid: 'gid-error-1',
    status: 'error',
    errorCode: 9,
    errorMessage: 'Status 404 Not Found',
    files: <Aria2File>[
      Aria2File(index: 1, path: '/downloads/broken.zip', length: 1000),
    ],
  );

  const Aria2Snapshot testSnapshot = Aria2Snapshot(
    stat: Aria2GlobalStat(
      downloadSpeed: 2097152,
      uploadSpeed: 102400,
      numActive: 1,
      numWaiting: 1,
      numStopped: 2,
    ),
    version: Aria2Version(
      version: '1.37.0',
      enabledFeatures: <String>['BitTorrent', 'HTTPS', 'Async DNS'],
    ),
    active: <Aria2Download>[activeDownload],
    waiting: <Aria2Download>[waitingDownload],
    stopped: <Aria2Download>[completedDownload, erroredDownload],
  );

  final Map<String, String> testGlobalOptions = <String, String>{
    'max-overall-download-limit': '5242880',
    'max-overall-upload-limit': '1048576',
    'max-concurrent-downloads': '5',
    'max-connection-per-server': '4',
    'dir': '/downloads/default',
    'seed-ratio': '1.5',
  };

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        aria2SnapshotProvider(testInstance).overrideWith((ref) => testSnapshot),
        aria2GlobalOptionsProvider(
          testInstance,
        ).overrideWith((ref) => testGlobalOptions),
      ],
      child: const MaterialApp(home: Aria2Home(instance: testInstance)),
    );
  }

  testWidgets(
    'Aria2Home renders unified downloads hub and switches to Settings and System tabs',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify Tab 0: Downloads
      expect(find.text('Downloads'), findsWidgets);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.byType(EasyRefresh), findsOneWidget);

      // Filter chips present
      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Queued (1)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);
      expect(find.text('Errors (1)'), findsOneWidget);

      // Downloads displayed
      expect(find.text('debian.iso'), findsOneWidget);
      expect(find.text('arch.iso'), findsOneWidget);
      expect(find.text('fedora.iso'), findsOneWidget);
      expect(find.text('broken.zip'), findsOneWidget);

      // Tap Filter chip 'Completed'
      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();

      expect(find.text('fedora.iso'), findsOneWidget);
      expect(find.text('debian.iso'), findsNothing);

      // Switch to Tab 1: Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(EasyRefresh), findsOneWidget);
      expect(find.text('Aria2 Settings'), findsOneWidget);
      expect(find.text('Bandwidth & Limits'), findsOneWidget);
      expect(find.text('Tasks & Concurrency'), findsOneWidget);
      expect(find.text('Storage & Directories'), findsOneWidget);
      expect(find.text('/downloads/default'), findsOneWidget);

      // Switch to Tab 2: System
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      expect(find.byType(EasyRefresh), findsOneWidget);
      expect(find.text('Daemon Information'), findsOneWidget);
      expect(find.text('1.37.0'), findsOneWidget);
      expect(find.text('Global Telemetry'), findsOneWidget);
      expect(find.text('Maintenance Operations'), findsOneWidget);
      expect(find.text('Save session now'), findsOneWidget);
    },
  );

  testWidgets(
    'Aria2DownloadDetailScreen renders interactive file checkboxes and speed limit button',
    (WidgetTester tester) async {
      const Aria2Download multiFileTorrent = Aria2Download(
        gid: 'gid-torrent-1',
        status: 'active',
        torrentName: 'Linux ISOs Pack',
        totalLength: 3000,
        completedLength: 1500,
        downloadSpeed: 1000,
        uploadLength: 500,
        files: <Aria2File>[
          Aria2File(
            index: 1,
            path: 'Linux ISOs Pack/ubuntu.iso',
            length: 2000,
            completedLength: 1500,
          ),
          Aria2File(
            index: 2,
            path: 'Linux ISOs Pack/readme.txt',
            length: 1000,
            selected: false,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aria2DownloadProvider((
              testInstance,
              'gid-torrent-1',
            )).overrideWith((ref) => multiFileTorrent),
          ],
          child: const MaterialApp(
            home: Aria2DownloadDetailScreen(
              instance: testInstance,
              gid: 'gid-torrent-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Linux ISOs Pack'), findsWidgets);
      expect(find.text('Speed limit'), findsOneWidget);
      expect(find.text('ubuntu.iso'), findsOneWidget);
      expect(find.text('readme.txt'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));

      // Tap Speed Limit button
      await tester.tap(find.text('Speed limit'));
      await tester.pump();
      // The dialog should open
      expect(find.text('Task speed limits'), findsOneWidget);
    },
  );

  group('pull to refresh', () {
    // One download, so no tab's content fills the screen and only
    // always-scrollable physics lets the pull through.
    const Aria2Snapshot shortSnapshot = Aria2Snapshot(
      stat: Aria2GlobalStat(numActive: 1),
      version: Aria2Version(version: '1.37.0'),
      active: <Aria2Download>[activeDownload],
      waiting: <Aria2Download>[],
      stopped: <Aria2Download>[],
    );

    late int snapshotBuilds;
    late int optionBuilds;

    Future<void> pumpShortHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      snapshotBuilds = 0;
      optionBuilds = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aria2SnapshotProvider(testInstance).overrideWith((ref) {
              snapshotBuilds++;
              return shortSnapshot;
            }),
            aria2GlobalOptionsProvider(testInstance).overrideWith((ref) {
              optionBuilds++;
              return <String, String>{'max-concurrent-downloads': '5'};
            }),
          ],
          child: const MaterialApp(home: Aria2Home(instance: testInstance)),
        ),
      );
      await tester.pumpAndSettle();
    }

    // A refresh needs a pull of about a quarter of the list's height, so
    // start near the top of this tall surface and go far.
    Future<void> pull(WidgetTester tester, Finder list) async {
      await tester.dragFrom(
        tester.getTopLeft(list) + const Offset(540, 40),
        const Offset(0, 1500),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a pull on a short Downloads list reloads it', (
      WidgetTester tester,
    ) async {
      await pumpShortHome(tester);
      final int before = snapshotBuilds;

      await pull(tester, find.byType(CustomScrollView));

      expect(snapshotBuilds, before + 1);
    });

    testWidgets('a pull on Settings reloads the options', (
      WidgetTester tester,
    ) async {
      await pumpShortHome(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final int before = optionBuilds;

      await pull(tester, find.byType(ListView));

      expect(optionBuilds, before + 1);
    });

    testWidgets('a pull on System reloads the stats', (
      WidgetTester tester,
    ) async {
      await pumpShortHome(tester);
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      final int before = snapshotBuilds;

      await pull(tester, find.byType(ListView));

      expect(snapshotBuilds, before + 1);
    });
  });

  testWidgets('Aria2Home hamburger opens drawer', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aria2SnapshotProvider(testInstance).overrideWith((ref) => testSnapshot),
          aria2GlobalOptionsProvider(
            testInstance,
          ).overrideWith((ref) => testGlobalOptions),
        ],
        child: const MaterialApp(
          home: Aria2Home(
            instance: testInstance,
            drawer: Drawer(child: Text('Services Navigation Drawer')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Services Navigation Drawer'), findsNothing);

    // Tap the hamburger menu button
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // The drawer is now open and its content visible!
    expect(find.text('Services Navigation Drawer'), findsOneWidget);
  });
}
