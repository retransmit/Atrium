import 'dart:convert';
import 'dart:typed_data';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_clients_fixtures.dart';
import 'support/adguard_home_test_instance.dart';

void main() {
  final AdguardHomeServiceCatalogue catalogue =
      AdguardHomeServiceCatalogue.fromJson(blockedServicesJson());

  /// Pumps the picker over a set the test can read back.
  Future<Set<String> Function()> pumpPicker(
    WidgetTester tester, {
    Set<String> selected = const <String>{},
    AdguardHomeServiceCatalogue? services,
    Size size = const Size(360, 2400),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    Set<String> now = selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext _, StateSetter setState) =>
                AdguardHomeServicePicker(
              catalogue: services ?? catalogue,
              selected: now,
              onChanged: (Set<String> next) => setState(() => now = next),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return () => now;
  }

  SwitchListTile tile(WidgetTester tester, String name) =>
      tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text(name),
          matching: find.byType(SwitchListTile),
        ),
      );

  testWidgets('lists the services under the groups that have any, in the '
      'server\'s order', (WidgetTester tester) async {
    await pumpPicker(tester);

    // Of the twelve groups, four hold the six services.
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Social networks'), findsOneWidget);
    expect(find.text('Streaming'), findsOneWidget);
    expect(find.text('Dating'), findsNothing);
    expect(find.text('Gaming'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('AI')).dy,
      lessThan(tester.getTopLeft(find.text('Gaming')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Gaming')).dy,
      lessThan(tester.getTopLeft(find.text('Social networks')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Social networks')).dy,
      lessThan(tester.getTopLeft(find.text('Streaming')).dy),
    );
    for (final String name in <String>[
      'TikTok',
      'YouTube',
      'Roblox',
      'Netflix',
      'Meta AI',
      'X (formerly Twitter)',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('shows which are blocked', (WidgetTester tester) async {
    await pumpPicker(tester, selected: <String>{'tiktok', 'netflix'});

    expect(tile(tester, 'TikTok').value, isTrue);
    expect(tile(tester, 'Netflix').value, isTrue);
    expect(tile(tester, 'YouTube').value, isFalse);
  });

  testWidgets('a switch blocks or unblocks its service and no other',
      (WidgetTester tester) async {
    final Set<String> Function() selected =
        await pumpPicker(tester, selected: <String>{'tiktok'});

    await tester.tap(find.text('YouTube'));
    await tester.pump();
    expect(selected(), <String>{'tiktok', 'youtube'});

    await tester.tap(find.text('TikTok'));
    await tester.pump();
    expect(selected(), <String>{'youtube'});
  });

  testWidgets('Block all and Unblock all do what they say',
      (WidgetTester tester) async {
    final Set<String> Function() selected =
        await pumpPicker(tester, selected: <String>{'tiktok'});

    await tester.tap(find.text('Block all'));
    await tester.pump();
    expect(selected(), <String>{
      'tiktok',
      'youtube',
      'roblox',
      'netflix',
      'meta_ai',
      'twitter',
    });

    await tester.tap(find.text('Unblock all'));
    await tester.pump();
    expect(selected(), isEmpty);
  });

  testWidgets('searching narrows the list by name, whatever the case',
      (WidgetTester tester) async {
    await pumpPicker(tester);

    await tester.enterText(find.byType(TextField), 'TUBE');
    await tester.pump();

    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('TikTok'), findsNothing);
    // Only the group of what is left.
    expect(find.text('Streaming'), findsOneWidget);
    expect(find.text('Social networks'), findsNothing);
  });

  testWidgets('searching finds a service by its id too',
      (WidgetTester tester) async {
    await pumpPicker(tester);

    await tester.enterText(find.byType(TextField), 'meta_ai');
    await tester.pump();

    expect(find.text('Meta AI'), findsOneWidget);
    expect(find.text('Roblox'), findsNothing);
  });

  testWidgets('while searching there is no Block all: it would block what is '
      'not shown', (WidgetTester tester) async {
    await pumpPicker(tester);

    await tester.enterText(find.byType(TextField), 'tik');
    await tester.pump();

    expect(find.text('Block all'), findsNothing);
    expect(find.text('Unblock all'), findsNothing);
  });

  testWidgets('a search that finds nothing says so, and can be cleared',
      (WidgetTester tester) async {
    await pumpPicker(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No service matches'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Block all'), findsOneWidget);
  });

  testWidgets('a blocked service the server no longer lists can still be '
      'unblocked', (WidgetTester tester) async {
    // The server refuses a client with a service it does not know, so one
    // that is left over has to be removable.
    final Set<String> Function() selected = await pumpPicker(
      tester,
      selected: <String>{'tiktok', 'gone_service'},
    );

    expect(find.text('No longer offered by the server'), findsOneWidget);
    expect(tile(tester, 'gone_service').value, isTrue);

    await tester.tap(find.text('gone_service'));
    await tester.pump();

    expect(selected(), <String>{'tiktok'});
    expect(find.text('gone_service'), findsNothing);
  });

  testWidgets('Unblock all takes off what the server no longer lists too',
      (WidgetTester tester) async {
    final Set<String> Function() selected = await pumpPicker(
      tester,
      selected: <String>{'tiktok', 'gone_service'},
    );

    await tester.tap(find.text('Unblock all'));
    await tester.pump();

    expect(selected(), isEmpty);
  });

  testWidgets('a service in no group, or in one the server does not list, is '
      'shown under Other', (WidgetTester tester) async {
    await pumpPicker(
      tester,
      services: AdguardHomeServiceCatalogue(
        services: <AdguardHomeBlockedService>[
          const AdguardHomeBlockedService(id: 'loose', name: 'Loose'),
          const AdguardHomeBlockedService(
            id: 'odd',
            name: 'Odd',
            groupId: 'unlisted',
          ),
          ...catalogue.services,
        ],
        groups: catalogue.groups,
      ),
    );

    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Loose'), findsOneWidget);
    expect(find.text('Odd'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Streaming')).dy,
      lessThan(tester.getTopLeft(find.text('Other')).dy),
    );
  });

  testWidgets('draws each icon from the SVG the server sent',
      (WidgetTester tester) async {
    await pumpPicker(tester);

    expect(find.byType(SvgPicture), findsNWidgets(6));
  });

  testWidgets('a service with no icon, or one that is no SVG, gets a plain '
      'one and the list still stands', (WidgetTester tester) async {
    await pumpPicker(
      tester,
      services: AdguardHomeServiceCatalogue(
        services: <AdguardHomeBlockedService>[
          const AdguardHomeBlockedService(id: 'bare', name: 'Bare'),
          AdguardHomeBlockedService(
            id: 'broken',
            name: 'Broken',
            icon: Uint8List.fromList(utf8.encode('this is not an image')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bare'), findsOneWidget);
    expect(find.text('Broken'), findsOneWidget);
    // One for the service with no icon, one for the icon that is no image.
    expect(find.byIcon(Icons.block), findsNWidgets(2));
  });

  testWidgets('an empty catalogue says the server offers none',
      (WidgetTester tester) async {
    await pumpPicker(tester, services: const AdguardHomeServiceCatalogue());

    expect(find.text('The server offers no services to block'), findsOneWidget);
  });

  for (final double width in <double>[320, 360, 411]) {
    for (final double scale in <double>[1, 1.3, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await pumpPicker(
          tester,
          selected: <String>{'twitter', 'gone_service'},
          size: Size(width, 2400),
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  }

  group('the screen around the picker', () {
    Future<List<Set<String>?>> pumpScreen(
      WidgetTester tester, {
      Set<String> selected = const <String>{},
      Object? failure,
    }) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final List<Set<String>?> results = <Set<String>?>[];
      int reads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            adguardHomeServicesProvider(adguardHomeTestInstance)
                .overrideWith((Ref ref) async {
              reads++;
              if (failure != null && reads == 1) throw failure;
              return catalogue;
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async => results.add(
                      await pushScreen<Set<String>>(
                        context,
                        AdguardHomeServicesScreen(
                          instance: adguardHomeTestInstance,
                          title: 'Blocked for Kids tablet',
                          selected: selected,
                        ),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('shows the catalogue with what is blocked',
        (WidgetTester tester) async {
      await pumpScreen(tester, selected: <String>{'tiktok'});

      expect(find.text('Blocked for Kids tablet'), findsOneWidget);
      expect(tile(tester, 'TikTok').value, isTrue);
      expect(tile(tester, 'YouTube').value, isFalse);
    });

    testWidgets('Done hands back what is blocked now',
        (WidgetTester tester) async {
      final List<Set<String>?> results =
          await pumpScreen(tester, selected: <String>{'tiktok'});

      await tester.tap(find.text('YouTube'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(results.single, <String>{'tiktok', 'youtube'});
    });

    testWidgets('going back hands it back too: a switch that was flipped is '
        'not lost', (WidgetTester tester) async {
      final List<Set<String>?> results =
          await pumpScreen(tester, selected: <String>{'tiktok'});

      await tester.tap(find.text('TikTok'));
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(results.single, isEmpty);
    });

    testWidgets('a catalogue that cannot be read says why and can be asked '
        'for again', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        failure: const AdguardHomeRequestRefused('catalogue unavailable'),
      );

      expect(find.text('catalogue unavailable'), findsOneWidget);
      expect(find.text('TikTok'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('TikTok'), findsOneWidget);
    });

    testWidgets('going back from a catalogue that could not be read changes '
        'nothing', (WidgetTester tester) async {
      final List<Set<String>?> results = await pumpScreen(
        tester,
        selected: <String>{'tiktok'},
        failure: const AdguardHomeRequestRefused('catalogue unavailable'),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(results.single, <String>{'tiktok'});
    });
  });
}
