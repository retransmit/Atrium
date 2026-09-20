import 'package:core_networking/core_networking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

import 'support/fake_ombi.dart';
import 'support/ombi_fixtures.dart';
import 'support/ombi_test_instance.dart';
import 'support/pump.dart';

const String _pendingMovies =
    '/api/v2/Requests/movie/pending/25/0/requestedDate/desc';

void main() {
  late FakeOmbi fake;

  setUp(() {
    fake = FakeOmbi()
      ..on('GET', '/api/v1/Lidarr/enabled', false)
      ..on('GET', '/api/v1/Request/count', countsJson)
      ..on(
        'GET',
        _pendingMovies,
        pageJson(<Map<String, dynamic>>[movieRequestJson()]),
      );
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object __) => null,
        overrides: <Override>[
          instanceDioProvider(ombiTestInstance)
              .overrideWith((Ref ref) async => fakeOmbiDio(fake)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: OmbiHome(instance: ombiTestInstance)),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('a pending movie shows who asked, and Approve and Deny',
      (WidgetTester tester) async {
    await open(tester);

    expect(find.textContaining('Arrival'), findsOneWidget);
    expect(find.textContaining('alice'), findsOneWidget);
    expect(find.text('Pending Approval'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Deny'), findsOneWidget);
  });

  testWidgets('rows read like Ombi request list, 4K tag included',
      (WidgetTester tester) async {
    fake
      ..on(
        'GET',
        _pendingMovies,
        pageJson(<Map<String, dynamic>>[movieRequestJson(has4KRequest: true)]),
      )
      ..on(
        'GET',
        '/api/v2/Requests/movie/processing/25/0/requestedDate/desc',
        pageJson(<Map<String, dynamic>>[movieRequestJson(approved: true)]),
      );
    await open(tester);

    expect(find.text('Pending Approval'), findsOneWidget);
    expect(find.text('4K'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Processing'));
    await settle(tester);

    expect(find.text('Processing Request'), findsOneWidget);
    expect(find.text('4K'), findsNothing);
  });

  // Two tests rather than one re-pump: a second ProviderScope in the same
  // spot keeps the first one's container, and with it the cached answer.
  testWidgets('without Lidarr there is no Music segment',
      (WidgetTester tester) async {
    await open(tester);

    expect(find.text('Music'), findsNothing);
  });

  testWidgets('with Lidarr there is a Music segment',
      (WidgetTester tester) async {
    fake.on('GET', '/api/v1/Lidarr/enabled', true);
    await open(tester);

    expect(find.text('Music'), findsOneWidget);
  });

  testWidgets('Approve approves that request', (WidgetTester tester) async {
    fake.on('POST', '/api/v1/Request/movie/approve', engineOk());
    await open(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await settle(tester);

    expect(
      fake.to('POST', '/api/v1/Request/movie/approve').single.body,
      <String, dynamic>{'id': 11, 'is4K': false},
    );
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('Deny sends the reason typed into the dialog',
      (WidgetTester tester) async {
    fake.on('PUT', '/api/v1/Request/movie/deny', engineOk());
    await open(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Deny'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Already on Plex');
    await tester.tap(find.widgetWithText(FilledButton, 'Deny'));
    await settle(tester);

    expect(
      fake.to('PUT', '/api/v1/Request/movie/deny').single.body,
      <String, dynamic>{'id': 11, 'reason': 'Already on Plex', 'is4K': false},
    );
  });

  testWidgets('Delete asks first', (WidgetTester tester) async {
    fake.on('DELETE', '/api/v1/Request/movie/11', engineOk());
    await open(tester);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(fake.to('DELETE', '/api/v1/Request/movie/11'), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(fake.to('DELETE', '/api/v1/Request/movie/11'), hasLength(1));
  });

  testWidgets('a refusal from Ombi is shown in its own words',
      (WidgetTester tester) async {
    fake.on(
      'POST',
      '/api/v1/Request/movie/approve',
      engineError('Request not found'),
    );
    await open(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await settle(tester);

    expect(find.text('Request not found'), findsOneWidget);
  });

  testWidgets('the Denied chip asks for denied requests',
      (WidgetTester tester) async {
    fake.on(
      'GET',
      '/api/v2/Requests/movie/denied/25/0/requestedDate/desc',
      pageJson(<Map<String, dynamic>>[]),
    );
    await open(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Denied'));
    await settle(tester);

    expect(
      fake.to('GET', '/api/v2/Requests/movie/denied/25/0/requestedDate/desc'),
      hasLength(1),
    );
    expect(find.text('Nothing denied'), findsOneWidget);
  });

  testWidgets('a refused key says where the key lives',
      (WidgetTester tester) async {
    fake.on(
      'GET',
      _pendingMovies,
      <String, dynamic>{'error': 'no'},
      status: 401,
    );
    await open(tester);

    expect(
      find.text('Ombi refused the API key. It is under Settings, Ombi.'),
      findsOneWidget,
    );
  });
}
