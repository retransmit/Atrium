import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_prowlarr/service_prowlarr.dart';

const List<ProwlarrIndexer> _indexers = <ProwlarrIndexer>[
  ProwlarrIndexer(
    id: 1,
    name: 'Example Public Tracker',
    enable: true,
    protocol: 'torrent',
  ),
  ProwlarrIndexer(
    id: 2,
    name: 'Example Private Tracker',
    enable: true,
    protocol: 'torrent',
  ),
  ProwlarrIndexer(id: 4, name: 'Old Tracker', protocol: 'torrent'),
  ProwlarrIndexer(
    id: 5,
    name: 'Example Usenet Indexer',
    enable: true,
    protocol: 'usenet',
  ),
];

const List<ProwlarrCategory> _tree = <ProwlarrCategory>[
  ProwlarrCategory(
    id: 2000,
    name: 'Movies',
    subCategories: <ProwlarrCategory>[
      ProwlarrCategory(id: 2040, name: 'Movies/HD'),
      ProwlarrCategory(id: 2045, name: 'Movies/UHD'),
    ],
  ),
  ProwlarrCategory(
    id: 5000,
    name: 'TV',
    subCategories: <ProwlarrCategory>[
      ProwlarrCategory(id: 5040, name: 'TV/HD'),
    ],
  ),
];

Future<void> _pump(WidgetTester tester, Widget picker) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: picker)),
      ),
    );

CheckboxListTile _tile(WidgetTester tester, String title) =>
    tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, title),
    );

void main() {
  testWidgets('ticking Torrents replaces ticked torrent indexers',
      (WidgetTester tester) async {
    Set<int>? reported;
    await _pump(
      tester,
      ProwlarrIndexerPicker(
        indexers: _indexers,
        selected: const <int>{1, 5},
        onChanged: (Set<int> s) => reported = s,
      ),
    );
    await tester.tap(find.text('Torrents'));
    expect(reported, <int>{prowlarrAllTorrents, 5});
  });

  testWidgets('a ticked group checks and locks its members',
      (WidgetTester tester) async {
    await _pump(
      tester,
      ProwlarrIndexerPicker(
        indexers: _indexers,
        selected: const <int>{prowlarrAllTorrents},
        onChanged: (_) {},
      ),
    );
    final CheckboxListTile member = _tile(tester, 'Example Public Tracker');
    expect(member.value, isTrue);
    expect(member.onChanged, isNull);
    expect(_tile(tester, 'Example Usenet Indexer').onChanged, isNotNull);
  });

  testWidgets('disabled indexers show Disabled and cannot be ticked',
      (WidgetTester tester) async {
    await _pump(
      tester,
      ProwlarrIndexerPicker(
        indexers: _indexers,
        selected: const <int>{},
        onChanged: (_) {},
      ),
    );
    expect(
      find.descendant(
        of: find.widgetWithText(CheckboxListTile, 'Old Tracker'),
        matching: find.text('Disabled'),
      ),
      findsOneWidget,
    );
    expect(_tile(tester, 'Old Tracker').onChanged, isNull);
  });

  testWidgets('a protocol with no indexers has no group row',
      (WidgetTester tester) async {
    await _pump(
      tester,
      ProwlarrIndexerPicker(
        indexers: _indexers.where((ProwlarrIndexer i) => i.id != 5).toList(),
        selected: const <int>{},
        onChanged: (_) {},
      ),
    );
    expect(find.text('Torrents'), findsOneWidget);
    expect(find.text('Usenet'), findsNothing);
  });

  testWidgets('ticking a parent category replaces its ticked subs',
      (WidgetTester tester) async {
    Set<int>? reported;
    await _pump(
      tester,
      ProwlarrCategoryPicker(
        categories: _tree,
        selected: const <int>{2040, 5040},
        onChanged: (Set<int> s) => reported = s,
      ),
    );
    await tester.tap(
      find
          .descendant(
            of: find.widgetWithText(ExpansionTile, 'Movies'),
            matching: find.byType(Checkbox),
          )
          .first,
    );
    expect(reported, <int>{2000, 5040});
  });

  testWidgets('a ticked parent checks and locks its subs',
      (WidgetTester tester) async {
    await _pump(
      tester,
      ProwlarrCategoryPicker(
        categories: _tree,
        selected: const <int>{2000},
        onChanged: (_) {},
      ),
    );
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    final CheckboxListTile sub = _tile(tester, 'HD');
    expect(sub.value, isTrue);
    expect(sub.onChanged, isNull);
  });
}
