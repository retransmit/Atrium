import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_cleanuparr/service_cleanuparr.dart';

const Instance testInstance = Instance(
  id: 'cleanuparr-1',
  name: 'Home Cleanuparr',
  kind: ServiceKind.cleanuparr,
  localUrl: 'http://cleanuparr.local:11011/',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthApiKey(apiKey: 'cleanuparr-secret-key'),
);

const CleanuparrStrikeItem stalled =
    CleanuparrStrikeItem(id: 'a', title: 'Still.Stalled');

/// Search waits for typing to pause before it reaches the server, and the
/// Strikes tab's empty state follows the search the list was fetched with,
/// not the text still waiting on that pause.
void main() {
  late List<String> strikeSearches;
  late List<String> eventSearches;

  Future<void> pumpTab(WidgetTester tester, Widget tab) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    strikeSearches = <String>[];
    eventSearches = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // One strike, which the search "Still" finds and anything else
          // does not.
          cleanuparrStrikesProvider(testInstance).overrideWith((ref) {
            final String search =
                ref.watch(cleanuparrStrikesSearchProvider(testInstance));
            strikeSearches.add(search);
            return search.isEmpty || 'Still.Stalled'.contains(search)
                ? const <CleanuparrStrikeItem>[stalled]
                : const <CleanuparrStrikeItem>[];
          }),
          cleanuparrStrikesCountProvider(testInstance).overrideWith((ref) => 1),
          cleanuparrEventsProvider(testInstance).overrideWith((ref) {
            eventSearches
                .add(ref.watch(cleanuparrEventsSearchProvider(testInstance)));
            return const <CleanuparrEvent>[];
          }),
        ],
        child: MaterialApp(home: tab),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeSlowly(WidgetTester tester, String text) async {
    for (int i = 1; i <= text.length; i++) {
      await tester.enterText(find.byType(TextField), text.substring(0, i));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('typing searches strikes once, after the pause', (
    WidgetTester tester,
  ) async {
    await pumpTab(tester, const CleanuparrStrikesTab(instance: testInstance));

    await typeSlowly(tester, 'Still');
    expect(strikeSearches, <String>['']);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(strikeSearches, <String>['', 'Still']);
  });

  testWidgets('typing searches events once, after the pause', (
    WidgetTester tester,
  ) async {
    await pumpTab(tester, const CleanuparrEventsTab(instance: testInstance));

    await typeSlowly(tester, 'crack');
    expect(eventSearches, <String>['']);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(eventSearches, <String>['', 'crack']);
  });

  testWidgets('a search with no match does not claim the queue is clean', (
    WidgetTester tester,
  ) async {
    await pumpTab(tester, const CleanuparrStrikesTab(instance: testInstance));

    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('No Strikes Found'), findsOneWidget);
    expect(find.text("No strikes matching 'matrix'"), findsOneWidget);
    expect(find.text('All Queues Clean'), findsNothing);
  });

  testWidgets('erasing the search never flashes All Queues Clean', (
    WidgetTester tester,
  ) async {
    await pumpTab(tester, const CleanuparrStrikesTab(instance: testInstance));
    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Backspaced to empty: the list still holds the "matrix" result until
    // the pause is over, and must say so.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('All Queues Clean'), findsNothing);
    expect(find.text("No strikes matching 'matrix'"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Still.Stalled'), findsOneWidget);
  });

  testWidgets('a back-press reset is not undone by a pending keystroke', (
    WidgetTester tester,
  ) async {
    await pumpTab(tester, const CleanuparrStrikesTab(instance: testInstance));
    await tester.enterText(find.byType(TextField), 'mat');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // More typing, then the shell's back handler clears the search before
    // the pause is over.
    await tester.enterText(find.byType(TextField), 'matrix');
    await tester.pump(const Duration(milliseconds: 100));
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(CleanuparrStrikesTab)),
    );
    container.read(cleanuparrStrikesSearchProvider(testInstance).notifier).state =
        '';
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(container.read(cleanuparrStrikesSearchProvider(testInstance)), '');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('Still.Stalled'), findsOneWidget);
  });

  testWidgets('a strike without an id cannot be reset', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cleanuparrStrikesProvider(testInstance).overrideWith(
            (ref) => const <CleanuparrStrikeItem>[
              CleanuparrStrikeItem(id: '', title: 'No.Id'),
              stalled,
            ],
          ),
          cleanuparrStrikesCountProvider(testInstance).overrideWith((ref) => 2),
        ],
        child: const MaterialApp(
          home: CleanuparrStrikesTab(instance: testInstance),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final List<IconButton> resets = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.delete_sweep_outlined),
        )
        .toList();
    expect(resets, hasLength(2));
    expect(resets.first.onPressed, isNull);
    expect(resets.last.onPressed, isNotNull);
  });
}
