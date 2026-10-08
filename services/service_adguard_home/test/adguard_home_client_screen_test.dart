import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  const Key nameField = Key('adguard-client-name');
  const Key upstreamsField = Key('adguard-client-upstreams');
  const Key cacheField = Key('adguard-client-cache-size');
  Key idField(int row) => Key('adguard-client-id-$row');

  final Finder save = find.widgetWithText(FilledButton, 'Save');

  /// Opens the form from a screen with a button, the way the app does, and
  /// notes what the form hands back each time it closes.
  Future<({Pumped pumped, List<AdguardHomeClientOutcome?> outcomes})> open(
    WidgetTester tester, {
    AdguardHomeClient? client,
    String name = '',
    String id = '',
    Size size = const Size(360, 4000),
    double textScale = 1,
    Object? safeSearchError,
    bool settle = true,
  }) async {
    final List<AdguardHomeClientOutcome?> outcomes =
        <AdguardHomeClientOutcome?>[];
    final Pumped pumped = await pumpAdguardHome(
      tester,
      Builder(
        builder: (BuildContext context) => Center(
          child: TextButton(
            onPressed: () async => outcomes.add(
              await adguardHomeEditClient(
                context,
                instance: adguardHomeTestInstance,
                supportedTags: capturedClients().supportedTags,
                client: client,
                name: name,
                id: id,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
      size: size,
      textScale: textScale,
      safeSearchError: safeSearchError,
    );
    await tester.tap(find.text('Open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return (pumped: pumped, outcomes: outcomes);
  }

  String textOf(WidgetTester tester, Key key) =>
      tester.widget<TextField>(find.byKey(key)).controller!.text;

  SwitchListTile switchOf(WidgetTester tester, String title) =>
      tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(SwitchListTile),
        ),
      );

  FilterChip chip(WidgetTester tester, String tag) =>
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, tag));

  Future<void> flip(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pump();
  }

  group('a new client', () {
    testWidgets('starts empty, on the global settings',
        (WidgetTester tester) async {
      await open(tester);

      expect(find.text('New client'), findsOneWidget);
      expect(textOf(tester, nameField), isEmpty);
      expect(textOf(tester, idField(0)), isEmpty);
      expect(find.byKey(idField(1)), findsNothing);
      expect(switchOf(tester, 'Use global settings').value, isTrue);
      expect(switchOf(tester, 'Use global blocked services').value, isTrue);
      expect(switchOf(tester, 'Ignore in the query log').value, isFalse);
      expect(switchOf(tester, 'Ignore in statistics').value, isFalse);
      expect(textOf(tester, upstreamsField), isEmpty);
      expect(textOf(tester, cacheField), '0');
      // Nothing to delete yet.
      expect(find.byTooltip('Delete client'), findsNothing);
    });

    testWidgets('offers every tag the server supports, none picked',
        (WidgetTester tester) async {
      await open(tester);

      expect(find.byType(FilterChip), findsNWidgets(21));
      expect(chip(tester, 'device_tablet').selected, isFalse);
      expect(chip(tester, 'user_child').selected, isFalse);
    });

    testWidgets('starts from the safe search of the server',
        (WidgetTester tester) async {
      await open(tester);

      // As the web UI starts one: a copy of the server's own, to be changed
      // once the global settings are turned off.
      expect(switchOf(tester, 'Safe search').value, isTrue);
      for (final String engine in <String>[
        'Bing',
        'DuckDuckGo',
        'Ecosia',
        'Google',
        'Pixabay',
        'Yandex',
        'YouTube',
      ]) {
        expect(switchOf(tester, engine).value, isTrue, reason: engine);
      }
    });

    testWidgets('can come with a name and an identifier filled in',
        (WidgetTester tester) async {
      await open(tester, name: 'localhost', id: '127.0.0.1');

      expect(textOf(tester, nameField), 'localhost');
      expect(textOf(tester, idField(0)), '127.0.0.1');
    });

    testWidgets('says why when the server\'s settings cannot be read, and '
        'reads them again when asked', (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(
        tester,
        safeSearchError: const AdguardHomeRequestRefused('not now'),
      );

      expect(find.text('not now'), findsOneWidget);
      expect(find.byKey(nameField), findsNothing);
      expect(save, findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(nameField), findsOneWidget);
      expect(form.pumped.safeSearchReads, 2);
    });
  });

  group('a client that is there', () {
    testWidgets('is shown as the server has it', (WidgetTester tester) async {
      await open(tester, client: capturedClient('Kids tablet'));

      expect(find.text('Edit client'), findsOneWidget);
      expect(textOf(tester, nameField), 'Kids tablet');
      expect(textOf(tester, idField(0)), '192.168.50.0/28');
      expect(textOf(tester, idField(1)), 'aa:bb:cc:dd:ee:01');
      expect(chip(tester, 'device_tablet').selected, isTrue);
      expect(chip(tester, 'user_child').selected, isTrue);
      expect(chip(tester, 'device_phone').selected, isFalse);
      expect(switchOf(tester, 'Use global settings').value, isFalse);
      expect(
        switchOf(tester, 'Block domains using filters and hosts files').value,
        isTrue,
      );
      expect(switchOf(tester, 'Browsing security').value, isTrue);
      expect(switchOf(tester, 'Parental control').value, isTrue);
      expect(switchOf(tester, 'Safe search').value, isTrue);
      expect(switchOf(tester, 'Google').value, isTrue);
      expect(switchOf(tester, 'YouTube').value, isFalse);
      expect(switchOf(tester, 'Use global blocked services').value, isFalse);
      expect(find.byTooltip('Delete client'), findsOneWidget);
    });

    testWidgets('names the services blocked for it', (WidgetTester tester) async {
      await open(tester, client: capturedClient('Kids tablet'));

      // By name, from the catalogue, in the order the server has them.
      expect(find.text('TikTok, Roblox, YouTube'), findsOneWidget);
    });

    testWidgets('says that it has a pause schedule, which is kept',
        (WidgetTester tester) async {
      await open(tester, client: capturedClient('Kids tablet'));

      expect(
        find.textContaining(
          'Sat 09:00 to 17:00, Sun 09:00 to 17:00 (Europe/Berlin)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('without a pause schedule says nothing of one',
        (WidgetTester tester) async {
      await open(tester, client: capturedClient('Laptop'));

      expect(find.textContaining('pauses'), findsNothing);
    });

    testWidgets('shows its upstream servers one to a line, and the cache',
        (WidgetTester tester) async {
      await open(tester, client: capturedClient('Work phone'));

      expect(
        textOf(tester, upstreamsField),
        '1.1.1.1\n[/corp.example/]10.0.0.1',
      );
      expect(
        switchOf(tester, 'Cache the answers of these servers').value,
        isTrue,
      );
      expect(textOf(tester, cacheField), '4096');
      expect(switchOf(tester, 'Ignore in the query log').value, isTrue);
    });

    testWidgets('keeps a tag the server no longer supports, to be taken off',
        (WidgetTester tester) async {
      await open(
        tester,
        client: const AdguardHomeClient(<String, dynamic>{
          'name': 'Old',
          'ids': <dynamic>['10.0.0.1'],
          'tags': <dynamic>['device_fridge'],
        }),
      );

      expect(chip(tester, 'device_fridge').selected, isTrue);
      expect(find.byType(FilterChip), findsNWidgets(22));
    });
  });

  group('what depends on what', () {
    testWidgets('its own protection can only be set once the global settings '
        'are off', (WidgetTester tester) async {
      await open(tester);

      const List<String> own = <String>[
        'Block domains using filters and hosts files',
        'Browsing security',
        'Parental control',
        'Safe search',
        'Google',
      ];
      for (final String title in own) {
        expect(switchOf(tester, title).onChanged, isNull, reason: title);
      }

      await flip(tester, 'Use global settings');

      for (final String title in own) {
        expect(switchOf(tester, title).onChanged, isNotNull, reason: title);
      }
      // The other two are never part of the global settings.
      expect(switchOf(tester, 'Ignore in statistics').onChanged, isNotNull);
    });

    testWidgets('the search engines can only be set while safe search is on',
        (WidgetTester tester) async {
      await open(tester);
      await flip(tester, 'Use global settings');
      expect(switchOf(tester, 'Google').onChanged, isNotNull);

      await flip(tester, 'Safe search');

      expect(switchOf(tester, 'Safe search').value, isFalse);
      expect(switchOf(tester, 'Google').onChanged, isNull);
      // What was set for it is kept for when it is turned back on.
      expect(switchOf(tester, 'Google').value, isTrue);
    });

    testWidgets('its own services can only be picked once the global ones '
        'are off', (WidgetTester tester) async {
      await open(tester);

      ListTile services() => tester.widget<ListTile>(
            find.widgetWithText(ListTile, 'Blocked for this client'),
          );
      expect(services().enabled, isFalse);

      await flip(tester, 'Use global blocked services');

      expect(services().enabled, isTrue);
      expect(find.text('None'), findsOneWidget);
    });
  });

  group('identifiers and tags', () {
    testWidgets('a row can be added and typed in', (WidgetTester tester) async {
      await open(tester);

      await tester.tap(find.text('Add identifier'));
      await tester.pump();
      await tester.enterText(find.byKey(idField(1)), 'aa:bb:cc:dd:ee:02');

      expect(find.byKey(idField(1)), findsOneWidget);
      expect(textOf(tester, idField(1)), 'aa:bb:cc:dd:ee:02');
    });

    testWidgets('the only row cannot be removed', (WidgetTester tester) async {
      await open(tester);

      expect(find.byTooltip('Remove identifier'), findsNothing);
    });

    testWidgets('a row is removed, and the others keep what they held',
        (WidgetTester tester) async {
      await open(tester, client: capturedClient('Kids tablet'));

      await tester.tap(find.byTooltip('Remove identifier').first);
      await tester.pump();

      expect(textOf(tester, idField(0)), 'aa:bb:cc:dd:ee:01');
      expect(find.byKey(idField(1)), findsNothing);
      expect(find.byTooltip('Remove identifier'), findsNothing);
    });

    testWidgets('a tag is picked and unpicked by its chip',
        (WidgetTester tester) async {
      await open(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'os_android'));
      await tester.pump();
      expect(chip(tester, 'os_android').selected, isTrue);

      await tester.tap(find.widgetWithText(FilterChip, 'os_android'));
      await tester.pump();
      expect(chip(tester, 'os_android').selected, isFalse);
    });
  });

  testWidgets('the services are picked on their own screen and come back',
      (WidgetTester tester) async {
    await open(tester, client: capturedClient('Kids tablet'));

    await tester.tap(find.text('Blocked for this client'));
    await tester.pumpAndSettle();
    expect(find.text('Blocked for Kids tablet'), findsOneWidget);

    await tester.tap(find.text('Netflix'));
    await tester.pump();
    await tester.tap(find.text('TikTok'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // What is left keeps its place, and what was added comes after it.
    expect(find.text('Roblox, YouTube, Netflix'), findsOneWidget);
  });

  group('the catalogue of services', () {
    testWidgets('is not asked for by a client that blocks none of its own',
        (WidgetTester tester) async {
      // A few hundred kilobytes, for nothing to name.
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Laptop'));

      expect(find.text('None'), findsOneWidget);
      expect(form.pumped.servicesReads, 0);
    });

    testWidgets('is not asked for by a new client either',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester);

      expect(form.pumped.servicesReads, 0);
    });

    testWidgets('is asked for by a client that blocks some, to name them',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Kids tablet'));

      expect(find.text('TikTok, Roblox, YouTube'), findsOneWidget);
      expect(form.pumped.servicesReads, 1);
    });

    testWidgets('names what was picked for a client that had none, in the '
        'catalogue\'s order', (WidgetTester tester) async {
      await open(tester, client: capturedClient('Laptop'));

      await flip(tester, 'Use global blocked services');
      await tester.tap(find.text('Blocked for this client'));
      await tester.pumpAndSettle();
      // Picked the other way round.
      await tester.tap(find.text('Netflix'));
      await tester.pump();
      await tester.tap(find.text('TikTok'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('TikTok, Netflix'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('a new client sends what was typed and closes',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester);

      await tester.enterText(find.byKey(nameField), 'Kitchen');
      await tester.enterText(find.byKey(idField(0)), '10.0.0.4');
      await tester.tap(find.widgetWithText(FilterChip, 'device_tv'));
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      final SavedClient sent = form.pumped.actions.saved.single;
      expect(sent.originalName, isNull);
      expect(sent.after.name, 'Kitchen');
      expect(sent.after.cleanIds, <String>['10.0.0.4']);
      expect(sent.after.tags, <String>['device_tv']);
      expect(sent.after.useGlobalSettings, isTrue);
      expect(sent.after.safeSearch.engines, hasLength(7));
      expect(form.outcomes, <AdguardHomeClientOutcome?>[
        AdguardHomeClientOutcome.saved,
      ]);
      expect(find.text('New client'), findsNothing);
      expect(find.text('Client "Kitchen" added'), findsOneWidget);
    });

    testWidgets('a changed client says what it was called and what it started '
        'as', (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Kids tablet'));

      await tester.enterText(find.byKey(nameField), 'Tablet');
      await flip(tester, 'Ignore in statistics');
      await flip(tester, 'YouTube');
      await tester.enterText(find.byKey(upstreamsField), '9.9.9.9\n1.1.1.1');
      await tester.tap(save);
      await tester.pumpAndSettle();

      final SavedClient sent = form.pumped.actions.saved.single;
      // The server finds the client by the name it has now.
      expect(sent.originalName, 'Kids tablet');
      expect(sent.before.name, 'Kids tablet');
      expect(sent.before.ignoreStatistics, isFalse);
      expect(sent.after.name, 'Tablet');
      expect(sent.after.ignoreStatistics, isTrue);
      expect(sent.after.safeSearch.engines['youtube'], isTrue);
      expect(sent.after.upstreamLines, <String>['9.9.9.9', '1.1.1.1']);
      // Untouched.
      expect(sent.after.ids, sent.before.ids);
      expect(sent.after.blockedServices, sent.before.blockedServices);
      expect(form.outcomes.single, AdguardHomeClientOutcome.saved);
      expect(find.text('Client "Tablet" saved'), findsOneWidget);
    });

    testWidgets('with nothing changed closes and sends nothing',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Laptop'));

      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(form.pumped.actions.saved, isEmpty);
      expect(form.outcomes, <AdguardHomeClientOutcome?>[null]);
      expect(find.text('Edit client'), findsNothing);
    });

    testWidgets('without a name says so, sends nothing and stays',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester);

      await tester.enterText(find.byKey(idField(0)), '10.0.0.4');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Give the client a name.'), findsOneWidget);
      expect(form.pumped.actions.saved, isEmpty);
      expect(find.text('New client'), findsOneWidget);

      // The complaint goes as soon as it is put right.
      await tester.enterText(find.byKey(nameField), 'Kitchen');
      await tester.pump();
      expect(find.text('Give the client a name.'), findsNothing);

      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(form.pumped.actions.saved, hasLength(1));
    });

    testWidgets('a name of spaces is no name', (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester);

      await tester.enterText(find.byKey(nameField), '   ');
      await tester.enterText(find.byKey(idField(0)), '10.0.0.4');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Give the client a name.'), findsOneWidget);
      expect(form.pumped.actions.saved, isEmpty);
    });

    testWidgets('without an identifier says so and sends nothing',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester);

      await tester.enterText(find.byKey(nameField), 'Kitchen');
      await tester.enterText(find.byKey(idField(0)), '  ');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Add at least one identifier.'), findsOneWidget);
      expect(form.pumped.actions.saved, isEmpty);
    });

    testWidgets('with a cache size the server cannot hold says so',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Work phone'));

      await tester.enterText(find.byKey(cacheField), '4294967296');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.text('A whole number from 0 to 4294967295.'),
        findsOneWidget,
      );
      expect(form.pumped.actions.saved, isEmpty);
    });

    testWidgets('says what the server said when it turns the client down, and '
        'keeps what was typed', (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester);
      form.pumped.actions.writeFailure = const AdguardHomeRequestRefused(
        'adding client: another client uses the same name "Laptop"',
      );

      await tester.enterText(find.byKey(nameField), 'Laptop');
      await tester.enterText(find.byKey(idField(0)), '10.0.0.4');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Not saved'), findsOneWidget);
      expect(
        find.text('adding client: another client uses the same name "Laptop"'),
        findsOneWidget,
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('New client'), findsOneWidget);
      expect(textOf(tester, nameField), 'Laptop');
      expect(textOf(tester, idField(0)), '10.0.0.4');
      expect(form.outcomes, isEmpty);
      // And it can be tried again.
      form.pumped.actions.writeFailure = null;
      await tester.enterText(find.byKey(nameField), 'Laptop 2');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(form.outcomes.single, AdguardHomeClientOutcome.saved);
    });

    testWidgets('says so when the sign-in is refused',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Laptop'));
      form.pumped.actions.writeFailure = const AdguardHomeSignInRefused();

      await flip(tester, 'Ignore in statistics');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Not saved'), findsOneWidget);
      expect(find.text('AdGuard Home refused the sign-in.'), findsOneWidget);
    });

    testWidgets('says so when the client is gone from the server',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Laptop'));
      form.pumped.actions.writeFailure = const AdguardHomeClientGone('Laptop');

      await flip(tester, 'Ignore in statistics');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('The client "Laptop" is no longer on the server.'),
        findsOneWidget,
      );
    });

    testWidgets('tapped twice is sent once', (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Laptop'));
      form.pumped.actions.writeHold = Completer<void>();

      await flip(tester, 'Ignore in statistics');
      await tester.tap(save);
      await tester.pump();
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();

      expect(form.pumped.actions.saved, hasLength(1));
      // Nor can it be deleted, or left, while that is on its way.
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.delete_outline),
            )
            .onPressed,
        isNull,
      );
      await tester.pageBack();
      await tester.pump();
      expect(find.text('Edit client'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);

      form.pumped.actions.writeHold!.complete();
      await tester.pumpAndSettle();

      expect(form.outcomes, <AdguardHomeClientOutcome?>[
        AdguardHomeClientOutcome.saved,
      ]);
      expect(find.text('Edit client'), findsNothing);
    });
  });

  group('deleting', () {
    testWidgets('asks first, and Cancel sends nothing',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Kids tablet'));

      await tester.tap(find.byTooltip('Delete client'));
      await tester.pumpAndSettle();

      expect(find.text('Delete "Kids tablet"?'), findsOneWidget);
      expect(form.pumped.actions.calls, isEmpty);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(form.pumped.actions.calls, isEmpty);
      expect(find.text('Edit client'), findsOneWidget);
    });

    testWidgets('deletes by the name the client has on the server, and closes',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Kids tablet'));

      // Typed over, but not saved: the server still knows the old name.
      await tester.enterText(find.byKey(nameField), 'Tablet');
      await tester.tap(find.byTooltip('Delete client'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(form.pumped.actions.calls, <String>['delete client Kids tablet']);
      expect(form.outcomes.single, AdguardHomeClientOutcome.deleted);
      expect(find.text('Edit client'), findsNothing);
      expect(find.text('Client "Kids tablet" deleted'), findsOneWidget);
    });

    testWidgets('says why when the server will not, and stays',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Kids tablet'));
      form.pumped.actions.writeFailure =
          const AdguardHomeRequestRefused('Client not found');

      await tester.tap(find.byTooltip('Delete client'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Not deleted'), findsOneWidget);
      expect(find.text('Client not found'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Edit client'), findsOneWidget);
      expect(form.outcomes, isEmpty);
    });
  });

  group('leaving', () {
    testWidgets('with nothing changed leaves at once',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Laptop'));

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Edit client'), findsNothing);
      expect(find.text('Discard changes?'), findsNothing);
      expect(form.outcomes, <AdguardHomeClientOutcome?>[null]);
    });

    testWidgets('with a change asks, and staying keeps it',
        (WidgetTester tester) async {
      await open(tester, client: capturedClient('Laptop'));

      await tester.enterText(find.byKey(nameField), 'Old laptop');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(find.text('Edit client'), findsOneWidget);
      expect(textOf(tester, nameField), 'Old laptop');
    });

    testWidgets('with a change, Discard leaves and saves nothing',
        (WidgetTester tester) async {
      final ({
        Pumped pumped,
        List<AdguardHomeClientOutcome?> outcomes
      }) form = await open(tester, client: capturedClient('Laptop'));

      await flip(tester, 'Ignore in statistics');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Edit client'), findsNothing);
      expect(form.pumped.actions.saved, isEmpty);
      expect(form.outcomes, <AdguardHomeClientOutcome?>[null]);
    });

    testWidgets('a switch flipped and flipped back is no change',
        (WidgetTester tester) async {
      await open(tester, client: capturedClient('Laptop'));

      await flip(tester, 'Ignore in statistics');
      await flip(tester, 'Ignore in statistics');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit client'), findsNothing);
    });
  });

  for (final double width in <double>[320, 360, 411]) {
    for (final double scale in <double>[1, 1.3, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await open(
          tester,
          client: capturedClient('Kids tablet'),
          size: Size(width, 9000),
          textScale: scale,
        );
        // With the complaints showing too.
        await tester.enterText(find.byKey(nameField), '');
        await tester.enterText(find.byKey(cacheField), 'x');
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(find.text('Give the client a name.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
