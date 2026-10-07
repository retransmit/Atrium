import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

void main() {
  /// [count] rows, largest first: 100, 99, 98 and so on.
  List<AdguardHomeCount> rows(int count) => <AdguardHomeCount>[
        for (int i = 0; i < count; i++)
          AdguardHomeCount('site$i.example', 100 - i),
      ];

  Future<void> pump(WidgetTester tester, Widget list) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: list)),
        ),
      );

  testWidgets('shows the first five and adds the rest up as Others',
      (WidgetTester tester) async {
    await pump(
      tester,
      AdguardHomeTopList(
        kind: AdguardHomeTopListKind.queriedDomains,
        rows: rows(8),
        onViewAll: () {},
      ),
    );

    expect(find.text('Top queried domains'), findsOneWidget);
    for (int i = 0; i < 5; i++) {
      expect(find.text('site$i.example'), findsOneWidget);
    }
    expect(find.text('site5.example'), findsNothing);
    // 95 + 94 + 93.
    expect(find.text('Others'), findsOneWidget);
    expect(find.text('282'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
  });

  testWidgets('a list that fits has no Others and nothing more to open',
      (WidgetTester tester) async {
    await pump(
      tester,
      AdguardHomeTopList(
        kind: AdguardHomeTopListKind.clients,
        rows: rows(5),
        onViewAll: () {},
      ),
    );

    expect(find.text('site4.example'), findsOneWidget);
    expect(find.text('Others'), findsNothing);
    expect(find.text('View all'), findsNothing);
  });

  testWidgets('response times are not added up', (WidgetTester tester) async {
    // An average of averages would mean nothing.
    await pump(
      tester,
      AdguardHomeTopList(
        kind: AdguardHomeTopListKind.upstreamTimes,
        rows: <AdguardHomeCount>[
          for (int i = 0; i < 7; i++)
            AdguardHomeCount('upstream$i.example', (7 - i) / 10),
        ],
        onViewAll: () {},
      ),
    );

    // Seconds, written as milliseconds.
    expect(find.text('700 ms'), findsOneWidget);
    expect(find.text('Others'), findsNothing);
    expect(find.text('View all'), findsOneWidget);
  });

  testWidgets('View all and a row\'s button tell whoever shows the list',
      (WidgetTester tester) async {
    int opened = 0;
    final List<String> asked = <String>[];
    await pump(
      tester,
      AdguardHomeTopList(
        kind: AdguardHomeTopListKind.blockedDomains,
        rows: rows(6),
        onBlocking: (String domain, {required bool block}) =>
            asked.add('${block ? 'block' : 'unblock'} $domain'),
        onViewAll: () => opened++,
      ),
    );

    await tester.tap(find.byTooltip('Unblock site1.example'));
    await tester.tap(find.text('View all'));

    expect(asked, <String>['unblock site1.example']);
    expect(opened, 1);
  });

  testWidgets('clients and upstreams have no button to block them',
      (WidgetTester tester) async {
    await pump(
      tester,
      AdguardHomeTopList(
        kind: AdguardHomeTopListKind.clients,
        rows: rows(2),
        onBlocking: (String domain, {required bool block}) {},
      ),
    );

    expect(find.byType(IconButton), findsNothing);
  });

  test('a slow upstream gets its thousands grouped like every other figure',
      () {
    expect(AdguardHomeTopListKind.upstreamTimes.format(1.14394), '1,144 ms');
    expect(AdguardHomeTopListKind.upstreamTimes.format(0.00531), '5 ms');
    expect(AdguardHomeTopListKind.queriedDomains.format(17467), '17,467');
  });

  testWidgets('the bars end in one line whatever the length of the figures',
      (WidgetTester tester) async {
    // A bar is read against the others, which works only on one scale.
    await pump(
      tester,
      const AdguardHomeTopList(
        kind: AdguardHomeTopListKind.upstreams,
        rows: <AdguardHomeCount>[
          AdguardHomeCount('quad9.example', 9761),
          AdguardHomeCount('router.example', 2),
          AdguardHomeCount('google.example', 1),
        ],
      ),
    );

    final Finder bars = find.byType(LinearProgressIndicator);
    expect(bars, findsNWidgets(3));
    final double end = tester.getTopRight(bars.first).dx;
    expect(tester.getTopRight(bars.at(1)).dx, end);
    expect(tester.getTopRight(bars.at(2)).dx, end);
  });

  testWidgets('the figures share a right edge, Others among them',
      (WidgetTester tester) async {
    await pump(
      tester,
      AdguardHomeTopList(
        kind: AdguardHomeTopListKind.queriedDomains,
        rows: rows(8),
        onBlocking: (String domain, {required bool block}) {},
      ),
    );

    final double edge = tester.getTopRight(find.text('100')).dx;
    expect(tester.getTopRight(find.text('96')).dx, edge);
    // 95 + 94 + 93.
    expect(tester.getTopRight(find.text('282')).dx, edge);
  });

  testWidgets('an empty list says so', (WidgetTester tester) async {
    await pump(
      tester,
      const AdguardHomeTopList(
        kind: AdguardHomeTopListKind.upstreams,
        rows: <AdguardHomeCount>[],
      ),
    );

    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('Others'), findsNothing);
  });
}
