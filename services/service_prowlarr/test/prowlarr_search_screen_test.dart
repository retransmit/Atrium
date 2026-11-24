import 'dart:async';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Opens the filters, picks the search type [label], and presses Done.
  Future<void> pickType(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Filters'));
    await run(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, label));
    await tester.pump();
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

  testWidgets('Retry searches the query that failed, not the field',
      (WidgetTester tester) async {
    server.fail('GET', 'api/v1/search', 500);
    await pump(tester);
    await submit(tester, 'dune');
    expect(find.text('Retry'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    server.mend('GET', 'api/v1/search');
    await tester.tap(find.text('Retry'));
    await run(tester);
    expect(searches(), hasLength(2));
    expect(searches().last.uri.queryParameters['query'], 'dune');
  });

  testWidgets('chips show for a typed search only',
      (WidgetTester tester) async {
    await pump(tester);
    expect(find.byType(ActionChip), findsNothing);
    await pickType(tester, 'Movie');
    expect(find.widgetWithText(ActionChip, 'ImdbId'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'TraktId'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'TvdbId'), findsNothing);
    await pickType(tester, 'Basic');
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('a chip inserts its token and focuses the field',
      (WidgetTester tester) async {
    await pump(tester);
    await pickType(tester, 'Movie');
    await tester.tap(find.widgetWithText(ActionChip, 'ImdbId'));
    await tester.pump();
    final TextEditingController field =
        tester.widget<TextField>(find.byType(TextField)).controller!;
    expect(field.text, '{ImdbId:}');
    expect(field.selection, const TextSelection.collapsed(offset: 8));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('switching back to Basic keeps typed tokens',
      (WidgetTester tester) async {
    await pump(tester);
    await pickType(tester, 'TV');
    await tester.tap(find.widgetWithText(ActionChip, 'Season'));
    await tester.pump();
    await pickType(tester, 'Basic');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '{Season:}',
    );
  });

  testWidgets('the search sends the type', (WidgetTester tester) async {
    await pump(tester);
    await pickType(tester, 'TV');
    await submit(tester, '{TvdbId:71663}');
    expect(searches().last.uri.queryParameters['type'], 'tvsearch');
    expect(searches().last.uri.queryParameters['query'], '{TvdbId:71663}');
  });

  testWidgets('changing only the type re-runs the search',
      (WidgetTester tester) async {
    await pump(tester);
    await submit(tester, 'dune');
    await pickType(tester, 'Movie');
    expect(searches(), hasLength(2));
    expect(searches().last.uri.queryParameters['type'], 'movie');
  });

  testWidgets('the TV chip row scrolls instead of overflowing on a phone',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);
    await pickType(tester, 'TV');
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(ActionChip, 'Year').hitTestable(), findsNothing);
    await tester.dragUntilVisible(
      find.widgetWithText(ActionChip, 'Year'),
      find.ancestor(
        of: find.byType(ActionChip).first,
        matching: find.byType(Scrollable),
      ),
      const Offset(-100, 0),
    );
    await tester.ensureVisible(find.widgetWithText(ActionChip, 'Year'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(ActionChip, 'Year').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('picking a type in the sheet keeps the keyboard down',
      (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Filters'));
    await run(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Movie'));
    await run(tester);
    final FocusNode field =
        tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    expect(field.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.text('Done'));
    await run(tester);
    expect(field.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('a chip brings back a keyboard that was put away',
      (WidgetTester tester) async {
    await pump(tester);
    await pickType(tester, 'Movie');
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.widgetWithText(ActionChip, 'ImdbId'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
