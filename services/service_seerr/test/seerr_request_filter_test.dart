import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

const Instance _instance = Instance(
  id: 'test-seerr',
  name: 'Test Seerr',
  kind: ServiceKind.seerr,
  localUrl: 'http://seerr.test',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

/// Two pending (the default status), then one each approved, declined,
/// failed and completed, in that order.
const List<SeerrRequest> _requests = <SeerrRequest>[
  SeerrRequest(id: 1),
  SeerrRequest(id: 2, status: 2),
  SeerrRequest(id: 3),
  SeerrRequest(id: 4, status: 3),
  SeerrRequest(id: 5, status: 4),
  SeerrRequest(id: 6, status: 5),
];

void main() {
  group('the filter', () {
    List<int> ids(SeerrRequestFilter filter) => <int>[
          for (final SeerrRequest r in filter.apply(_requests)) r.id,
        ];

    test('all keeps every request, failed ones included', () {
      expect(ids(SeerrRequestFilter.all), <int>[1, 2, 3, 4, 5, 6]);
    });

    test('each status chip keeps its own status, in order', () {
      expect(ids(SeerrRequestFilter.pending), <int>[1, 3]);
      expect(ids(SeerrRequestFilter.approved), <int>[2]);
      expect(ids(SeerrRequestFilter.declined), <int>[4]);
      expect(ids(SeerrRequestFilter.completed), <int>[6]);
      expect(ids(SeerrRequestFilter.failed), <int>[5]);
    });

    test('failed and completed have their own labels', () {
      expect(seerrRequestStatusStyle(4)?.label, 'Failed');
      expect(seerrRequestStatusStyle(5)?.label, 'Completed');
    });
  });

  group('the Requests tab', () {
    Future<void> pump(
      WidgetTester tester,
      List<SeerrRequest> requests, {
      void Function()? onRead,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seerrRequestsProvider.overrideWith((Ref ref, Instance i) async {
              onRead?.call();
              return requests;
            }),
            seerrIssuesProvider.overrideWith(
              (Ref ref, SeerrIssuesArgs a) async => const <SeerrIssue>[],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SeerrHome(instance: _instance)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The chip for [label], scrolled into view: the chip row is wider
    /// than a phone and scrolls sideways.
    Future<Finder> chip(WidgetTester tester, String label) async {
      final Finder chip = find.widgetWithText(FilterChip, label);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      return chip;
    }

    Future<void> pick(WidgetTester tester, String label) async {
      await tester.tap(await chip(tester, label));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on All, with a chip for each status',
        (WidgetTester tester) async {
      await pump(tester, _requests);

      for (final String label in <String>[
        'All',
        'Pending',
        'Approved',
        'Completed',
        'Declined',
        'Failed',
      ]) {
        expect(await chip(tester, label), findsOneWidget);
      }
      final FilterChip all = tester.widget(await chip(tester, 'All'));
      expect(all.selected, isTrue);
      expect(find.textContaining('Status: '), findsNWidgets(6));
      expect(find.text('Status: Failed'), findsOneWidget);
    });

    testWidgets('a chip shows only its status, without reading again',
        (WidgetTester tester) async {
      int reads = 0;
      await pump(tester, _requests, onRead: () => reads++);

      await pick(tester, 'Pending');
      expect(find.text('Status: Pending'), findsNWidgets(2));
      expect(find.textContaining('Status: '), findsNWidgets(2));

      await pick(tester, 'Approved');
      expect(find.text('Status: Approved'), findsOneWidget);
      expect(find.textContaining('Status: '), findsOneWidget);

      await pick(tester, 'Completed');
      expect(find.text('Status: Completed'), findsOneWidget);
      expect(find.textContaining('Status: '), findsOneWidget);

      await pick(tester, 'Declined');
      expect(find.text('Status: Declined'), findsOneWidget);
      expect(find.textContaining('Status: '), findsOneWidget);

      await pick(tester, 'Failed');
      expect(find.text('Status: Failed'), findsOneWidget);
      expect(find.textContaining('Status: '), findsOneWidget);

      await pick(tester, 'All');
      expect(find.textContaining('Status: '), findsNWidgets(6));
      expect(reads, 1);
    });

    testWidgets('the chip picked stays across a trip to another tab',
        (WidgetTester tester) async {
      await pump(tester, _requests);
      await pick(tester, 'Approved');

      await tester.tap(find.widgetWithText(Tab, 'Issues'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Requests'));
      await tester.pumpAndSettle();

      final FilterChip approved = tester.widget(await chip(tester, 'Approved'));
      expect(approved.selected, isTrue);
      expect(find.textContaining('Status: '), findsOneWidget);
    });

    testWidgets('the Issues chip picked stays across a trip as well',
        (WidgetTester tester) async {
      await pump(tester, _requests);
      await tester.tap(find.widgetWithText(Tab, 'Issues'));
      await tester.pumpAndSettle();
      await pick(tester, 'Open');

      await tester.tap(find.widgetWithText(Tab, 'Requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Issues'));
      await tester.pumpAndSettle();

      final FilterChip open = tester.widget(await chip(tester, 'Open'));
      expect(open.selected, isTrue);
    });

    testWidgets('an empty chip says what it has none of, chips still there',
        (WidgetTester tester) async {
      await pump(tester, const <SeerrRequest>[SeerrRequest(id: 2, status: 2)]);

      await pick(tester, 'Pending');

      expect(find.text('No pending requests'), findsOneWidget);
      expect(find.text('Nothing is waiting for approval.'), findsOneWidget);
      expect(await chip(tester, 'All'), findsOneWidget);
    });

    testWidgets('no requests at all says so under All',
        (WidgetTester tester) async {
      await pump(tester, const <SeerrRequest>[]);

      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.text('No requests'), findsOneWidget);
    });
  });
}
