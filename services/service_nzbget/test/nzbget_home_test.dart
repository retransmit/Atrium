import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_nzbget/service_nzbget.dart';

Instance _instance() => const Instance(
      id: 'n1',
      name: 'NZBGet',
      kind: ServiceKind.nzbget,
      localUrl: 'http://localhost:6789',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.userPass(username: 'nzbget', password: 'pass'),
    );

void main() {
  testWidgets('queue tab renders the summary and a group card',
      (WidgetTester tester) async {
    final Instance instance = _instance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          nzbgetQueueProvider(instance).overrideWith(
            (Ref ref) => Future<List<NzbgetGroup>>.value(<NzbgetGroup>[
              const NzbgetGroup(
                nzbId: 1,
                name: 'Linux.ISO',
                status: 'DOWNLOADING',
                fileSizeMb: 1000,
                remainingSizeMb: 400,
                downloadedSizeMb: 600,
              ),
            ]),
          ),
          nzbgetStatusProvider(instance).overrideWith(
            (Ref ref) => Future<NzbgetStatus>.value(
              const NzbgetStatus(downloadRate: 2 * 1024 * 1024),
            ),
          ),
          nzbgetHistoryProvider(instance).overrideWith(
            (Ref ref) =>
                Future<List<NzbgetHistoryEntry>>.value(<NzbgetHistoryEntry>[]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: NzbgetHome(instance: instance)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Linux.ISO'), findsOneWidget);
    expect(find.text('2.0 MB/s'), findsOneWidget);
    expect(find.textContaining('Downloading'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);
  });

  testWidgets('history tab renders a failed entry with a retry action',
      (WidgetTester tester) async {
    final Instance instance = _instance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          nzbgetQueueProvider(instance).overrideWith(
            (Ref ref) => Future<List<NzbgetGroup>>.value(<NzbgetGroup>[]),
          ),
          nzbgetStatusProvider(instance).overrideWith(
            (Ref ref) => Future<NzbgetStatus>.value(const NzbgetStatus()),
          ),
          nzbgetHistoryProvider(instance).overrideWith(
            (Ref ref) =>
                Future<List<NzbgetHistoryEntry>>.value(<NzbgetHistoryEntry>[
              const NzbgetHistoryEntry(
                nzbId: 2,
                name: 'Broken.Download',
                status: 'FAILURE/PAR',
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: NzbgetHome(instance: instance)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Broken.Download'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsOneWidget);
  });

  testWidgets('add sheet loads server categories into its dropdown',
      (WidgetTester tester) async {
    final Instance instance = _instance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          nzbgetQueueProvider(instance).overrideWith(
            (Ref ref) => Future<List<NzbgetGroup>>.value(<NzbgetGroup>[
              const NzbgetGroup(
                nzbId: 1,
                name: 'Linux.ISO',
                status: 'DOWNLOADING',
                fileSizeMb: 1000,
                remainingSizeMb: 400,
                downloadedSizeMb: 600,
              ),
            ]),
          ),
          nzbgetStatusProvider(instance).overrideWith(
            (Ref ref) => Future<NzbgetStatus>.value(const NzbgetStatus()),
          ),
          nzbgetHistoryProvider(instance).overrideWith(
            (Ref ref) =>
                Future<List<NzbgetHistoryEntry>>.value(<NzbgetHistoryEntry>[]),
          ),
          nzbgetCategoriesProvider(instance).overrideWith(
            (Ref ref) => Future<List<String>>.value(<String>['movies', 'tv']),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: NzbgetHome(instance: instance)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Add NZB'));
    await tester.pumpAndSettle();

    expect(find.text('Add NZB'), findsOneWidget);

    await tester.tap(find.text('Category (optional)'));
    await tester.pumpAndSettle();

    expect(find.text('movies'), findsWidgets);
  });

  testWidgets('same-position drop clears the drag freeze so later polls render',
      (WidgetTester tester) async {
    final Instance instance = _instance();
    List<NzbgetGroup> queue = <NzbgetGroup>[
      const NzbgetGroup(
        nzbId: 1,
        name: 'Alpha.ISO',
        status: 'DOWNLOADING',
        fileSizeMb: 1000,
        remainingSizeMb: 400,
        downloadedSizeMb: 600,
      ),
      const NzbgetGroup(
        nzbId: 2,
        name: 'Beta.ISO',
        status: 'QUEUED',
        fileSizeMb: 500,
        remainingSizeMb: 500,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          // Reads the mutable local so a later invalidate serves fresh data,
          // standing in for the periodic poll.
          nzbgetQueueProvider(instance).overrideWith(
            (Ref ref) => Future<List<NzbgetGroup>>.value(queue),
          ),
          nzbgetStatusProvider(instance).overrideWith(
            (Ref ref) => Future<NzbgetStatus>.value(const NzbgetStatus()),
          ),
          nzbgetHistoryProvider(instance).overrideWith(
            (Ref ref) =>
                Future<List<NzbgetHistoryEntry>>.value(<NzbgetHistoryEntry>[]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: NzbgetHome(instance: instance)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Alpha.ISO'), findsOneWidget);
    expect(find.text('Beta.ISO'), findsOneWidget);

    // Lift the first card's handle, wiggle past touch slop, and drop it back
    // on its own slot. The framework fires onReorderEnd but never onReorder
    // for a same-position drop; a leaked drag flag would keep the working
    // copy frozen from here on.
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_handle).first),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Alpha.ISO'), findsOneWidget);
    expect(find.text('Beta.ISO'), findsOneWidget);

    // Simulate the next poll delivering changed data. If the drag freeze
    // leaked, the build-time sync stays skipped and the stale rows keep
    // rendering.
    queue = <NzbgetGroup>[
      queue.first,
      const NzbgetGroup(
        nzbId: 2,
        name: 'Gamma.ISO',
        status: 'QUEUED',
        fileSizeMb: 500,
        remainingSizeMb: 500,
      ),
    ];
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(NzbgetHome)),
      listen: false,
    );
    container.invalidate(nzbgetQueueProvider(instance));
    await tester.pumpAndSettle();

    expect(find.text('Gamma.ISO'), findsOneWidget);
    expect(find.text('Beta.ISO'), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
  });
}
