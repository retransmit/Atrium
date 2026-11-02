import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_deluge/service_deluge.dart';

const Instance testInstance = Instance(
  id: 'deluge-1',
  name: 'Home Deluge',
  kind: ServiceKind.deluge,
  localUrl: 'http://deluge.local:8112/',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthUserPass(username: '', password: ''),
);

const List<DelugeTorrent> torrents = <DelugeTorrent>[
  DelugeTorrent(
    id: 'a',
    name: 'Fetching ISO',
    state: 'Downloading',
    progress: 40,
    downloadRate: 2048,
  ),
  DelugeTorrent(id: 'b', name: 'Finished ISO', state: 'Seeding', progress: 100),
];

/// The Deluge page as the app assembles it: the drawer and its app-bar button
/// on the outer Scaffold, the list as the body.
Widget page({List<DelugeTorrent> list = torrents}) => ProviderScope(
      overrides: [
        delugeRawTorrentsProvider(testInstance).overrideWith((ref) => list),
        delugeFilterTreeProvider(testInstance).overrideWith(
          (ref) => const DelugeFilterTree(
            states: <DelugeFilterBucket>[
              DelugeFilterBucket(name: 'All', count: 2),
              DelugeFilterBucket(name: 'Downloading', count: 1),
              DelugeFilterBucket(name: 'Seeding', count: 1),
            ],
          ),
        ),
        delugeSessionStatusProvider(testInstance)
            .overrideWith((ref) => const DelugeSessionStatus()),
        delugeSessionPausedProvider(testInstance).overrideWith((ref) => false),
        delugeSpeedLimitsProvider(testInstance)
            .overrideWith((ref) => const DelugeSpeedLimits()),
        delugeFreeSpaceProvider(testInstance).overrideWith((ref) => 0),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const <Widget>[DelugeFilterAppBarAction(instance: testInstance)],
          ),
          endDrawer: const DelugeFilterDrawer(instance: testInstance),
          body: const DelugeHome(instance: testInstance),
        ),
      ),
    );

void main() {
  testWidgets('a state picked in the drawer narrows the list and says so',
      (WidgetTester tester) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.text('Fetching ISO'), findsOneWidget);
    expect(find.text('Finished ISO'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('deluge-active-filter')), findsNothing);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

    await tester.tap(find.byTooltip('Filter torrents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seeding (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Fetching ISO'), findsNothing);
    expect(find.text('Finished ISO'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('deluge-active-filter')), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Fetching ISO'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('deluge-active-filter')), findsNothing);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('an empty list only blames the filter when one is on',
      (WidgetTester tester) async {
    await tester.pumpWidget(page(list: const <DelugeTorrent>[]));
    await tester.pumpAndSettle();

    expect(find.text('Add one with the + button.'), findsOneWidget);
    expect(find.text('Nothing matches this filter.'), findsNothing);

    final ProviderContainer container =
        ProviderScope.containerOf(tester.element(find.byType(DelugeHome)));
    container.read(delugeFilterProvider(testInstance).notifier).state =
        const DelugeFilter(state: 'Paused');
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches this filter.'), findsOneWidget);
    expect(find.text('Add one with the + button.'), findsNothing);
  });
}
