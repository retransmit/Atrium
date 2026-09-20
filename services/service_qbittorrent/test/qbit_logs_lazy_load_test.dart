import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

/// The log is only fetched once the Logs tab is opened.
///
/// The tabs sit in an IndexedStack, which builds all of them when the screen
/// opens, so the Logs tab fetched qBittorrent's whole log every time the
/// screen was opened. Seen through a proxy in front of a live qBittorrent:
/// opening the screen on the Home tab requested /api/v2/log/main, and a busy
/// server keeps 20,000 entries, about 2 MB of JSON.
void main() {
  testWidgets('the log is fetched when Logs is opened, not before',
      (WidgetTester tester) async {
    int logFetches = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        qbitRawTorrentsProvider(_instance)
            .overrideWith((Ref ref) async => const <QbitTorrent>[]),
        qbitTransferProvider(_instance)
            .overrideWith((Ref ref) async => const QbitTransferInfo()),
        qbitLogsProvider(_instance).overrideWith((Ref ref) async {
          logFetches++;
          return const <QbitLogEntry>[];
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: const QbittorrentHome(instance: _instance),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(logFetches, 0, reason: 'nobody has opened the Logs tab yet');

    void selectTab(int index) => container
        .read(qbitActiveTabBarIndexProvider(_instance).notifier)
        .state = index;

    selectTab(2);
    await tester.pump();
    await tester.pump();

    expect(logFetches, 1);
    expect(find.text('No logs available'), findsOneWidget);

    // The tab is kept once built, so going back to it does not fetch again.
    selectTab(0);
    await tester.pump();
    selectTab(2);
    await tester.pump();

    expect(logFetches, 1);
  });
}

const Instance _instance = Instance(
  id: 'test-qbit',
  name: 'Test qBittorrent',
  kind: ServiceKind.qbittorrent,
  localUrl: 'http://localhost',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);
