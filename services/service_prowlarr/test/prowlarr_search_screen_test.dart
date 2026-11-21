import 'dart:async';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_prowlarr/service_prowlarr.dart';

import 'support/fake_prowlarr.dart';
import 'support/prowlarr_test_instance.dart';

void main() {
  late FakeProwlarr server;

  setUp(() => server = FakeProwlarr());

  List<RequestOptions> searches() => server.to('GET', 'api/v1/search');

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            instanceDioProvider(prowlarrTestInstance)
                .overrideWith((Ref ref) async => dioFor(server)),
          ],
          child: const MaterialApp(
            home: ProwlarrSearchScreen(instance: prowlarrTestInstance),
          ),
        ),
      );

  /// Lets animations and requests run without waiting for the search
  /// spinner, which never settles.
  Future<void> run(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> submit(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await run(tester);
  }

  /// Opens the filters, taps each of [labels], and presses Done.
  Future<void> pick(WidgetTester tester, List<String> labels) async {
    await tester.tap(find.byTooltip('Filters'));
    await run(tester);
    for (final String label in labels) {
      final Finder parent = find.widgetWithText(ExpansionTile, label);
      final Finder target = parent.evaluate().isEmpty
          ? find.text(label)
          : find
              .descendant(of: parent, matching: find.byType(Checkbox))
              .first;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump();
    }
    await tester.tap(find.text('Done'));
    await run(tester);
  }

  testWidgets('the search sends the chosen filter',
      (WidgetTester tester) async {
    await pump(tester);
    await pick(tester, <String>['Torrents', 'Movies']);
    await submit(tester, 'dune');
    final Uri uri = searches().last.uri;
    expect(uri.queryParametersAll['indexerIds'], <String>['-2']);
    expect(uri.queryParametersAll['categories'], <String>['2000']);
  });

  testWidgets('the hint follows the filter', (WidgetTester tester) async {
    await pump(tester);
    expect(find.text('Search all indexers...'), findsOneWidget);
    await pick(tester, <String>['Torrents']);
    expect(find.text('Search all torrents...'), findsOneWidget);
  });

  testWidgets('changing the filter re-runs the search on screen once',
      (WidgetTester tester) async {
    await pump(tester);
    await submit(tester, 'dune');
    expect(searches(), hasLength(1));
    await pick(tester, <String>['Torrents', 'Usenet', 'Movies']);
    expect(searches(), hasLength(2));
    final Uri uri = searches().last.uri;
    expect(uri.queryParametersAll['indexerIds'], <String>['-2', '-1']);
    expect(uri.queryParametersAll['categories'], <String>['2000']);
  });

  testWidgets('closing the sheet unchanged does not search again',
      (WidgetTester tester) async {
    await pump(tester);
    await submit(tester, 'dune');
    await pick(tester, <String>[]);
    expect(searches(), hasLength(1));
  });

  testWidgets('no re-run before the first search',
      (WidgetTester tester) async {
    await pump(tester);
    await pick(tester, <String>['Torrents']);
    expect(searches(), isEmpty);
  });

  testWidgets('the re-run uses the searched query, not edited text',
      (WidgetTester tester) async {
    await pump(tester);
    await submit(tester, 'dune');
    await tester.enterText(find.byType(TextField), 'arrival');
    await pick(tester, <String>['Torrents']);
    expect(searches(), hasLength(2));
    expect(searches().last.uri.queryParameters['query'], 'dune');
  });

  testWidgets('an older search answer does not replace a newer one',
      (WidgetTester tester) async {
    final Completer<void> first = Completer<void>();
    int calls = 0;
    server.onCall('GET', 'api/v1/search', (RequestOptions _) async {
      calls++;
      if (calls == 1) {
        await first.future;
        return <dynamic>[releaseJson('Old answer')];
      }
      return <dynamic>[releaseJson('New answer')];
    });
    await pump(tester);
    await submit(tester, 'dune');
    await pick(tester, <String>['Torrents']);
    expect(find.text('New answer'), findsOneWidget);
    first.complete();
    await run(tester);
    expect(find.text('New answer'), findsOneWidget);
    expect(find.text('Old answer'), findsNothing);
  });
}
