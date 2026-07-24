import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_nzbget/service_nzbget.dart';

Instance _instance() => const Instance(
      id: 'n1',
      name: 'NZBGet',
      // swapped to ServiceKind.nzbget in the core-wiring task
      kind: ServiceKind.sabnzbd,
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
}
