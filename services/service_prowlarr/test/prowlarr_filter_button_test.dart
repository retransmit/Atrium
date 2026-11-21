import 'package:core_networking/core_networking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_prowlarr/service_prowlarr.dart';

import 'support/fake_prowlarr.dart';
import 'support/prowlarr_test_instance.dart';

void main() {
  late FakeProwlarr server;
  late ValueNotifier<ProwlarrSearchFilter> filter;
  late FocusNode field;
  late int closed;

  setUp(() {
    server = FakeProwlarr();
    filter = ValueNotifier<ProwlarrSearchFilter>(const ProwlarrSearchFilter());
    field = FocusNode();
    closed = 0;
  });

  tearDown(() {
    filter.dispose();
    field.dispose();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            instanceDioProvider(prowlarrTestInstance)
                .overrideWith((Ref ref) async => dioFor(server)),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: TextField(focusNode: field),
                actions: <Widget>[
                  ProwlarrFilterButton(
                    instance: prowlarrTestInstance,
                    filter: filter,
                    onClosed: () => closed++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
  }

  testWidgets('badge shows the filter count and hides at zero',
      (WidgetTester tester) async {
    await pump(tester);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    filter.value = const ProwlarrSearchFilter(
      indexerIds: <int>{prowlarrAllTorrents},
      categories: <int>{2000},
    );
    await tester.pump();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('the sheet has both sections and Done closes it',
      (WidgetTester tester) async {
    await pump(tester);
    await open(tester);
    expect(find.text('Search filters'), findsOneWidget);
    expect(find.text('Indexers'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(closed, 0);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Search filters'), findsNothing);
    expect(closed, 1);
  });

  testWidgets('Clear empties the filter', (WidgetTester tester) async {
    filter.value = const ProwlarrSearchFilter(
      indexerIds: <int>{prowlarrAllTorrents},
      categories: <int>{2000},
    );
    await pump(tester);
    await open(tester);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(filter.value.isEmpty, isTrue);
  });

  testWidgets('closing the sheet leaves the search field unfocused',
      (WidgetTester tester) async {
    await pump(tester);
    field.requestFocus();
    await tester.pump();
    expect(field.hasFocus, isTrue);
    await open(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(field.hasFocus, isFalse);
  });

  testWidgets('a failed category load keeps indexers and offers retry',
      (WidgetTester tester) async {
    server.fail('GET', 'api/v1/indexer/categories', 500);
    await pump(tester);
    await open(tester);
    expect(find.text('Example Public Tracker'), findsOneWidget);
    expect(find.text('Could not load categories'), findsOneWidget);
    server.mend('GET', 'api/v1/indexer/categories');
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load categories'), findsNothing);
    expect(find.text('Movies'), findsOneWidget);
  });

  testWidgets('categories are fetched once, not on every open',
      (WidgetTester tester) async {
    await pump(tester);
    await open(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await open(tester);
    expect(server.to('GET', 'api/v1/indexer/categories'), hasLength(1));
  });
}
