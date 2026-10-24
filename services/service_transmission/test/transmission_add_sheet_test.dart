import 'package:core_networking/core_networking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_transmission/service_transmission.dart';

import 'support/fake_transmission.dart';
import 'support/pump.dart';
import 'support/transmission_fixtures.dart';
import 'support/transmission_test_instance.dart';

void main() {
  late FakeTransmission fake;

  setUp(() {
    fake = FakeTransmission()
      ..on('session-get', sessionJson())
      ..onCall(
        'free-space',
        (Map<String, dynamic> args) => <String, Object?>{
          'size-bytes':
              args['path'] == '/downloads/complete' ? 5000000000 : -1,
        },
      )
      ..on('torrent-add', <String, Object?>{
        'torrent-added': <String, Object?>{
          'id': 9,
          'hashString': 'zzzz',
          'name': 'x',
        },
      })
      ..on('torrent-get', <String, Object?>{'torrents': <Object>[]});
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          instanceDioProvider(transmissionTestInstance)
              .overrideWith((Ref ref) async => fakeTransmissionDio(fake)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showTransmissionAddSheet(
                    context,
                    transmissionTestInstance,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    // Past the free-space debounce.
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
  }

  testWidgets('the folder is prefilled and its free space shown',
      (WidgetTester tester) async {
    await open(tester);

    expect(
      find.widgetWithText(TextField, '/downloads/complete'),
      findsOneWidget,
    );
    expect(find.text('${trFmtBytes(5000000000)} free'), findsOneWidget);
  });

  testWidgets('a folder the daemon cannot stat reads unknown',
      (WidgetTester tester) async {
    await open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, '/downloads/complete'),
      '/nowhere',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);

    expect(find.text('Free space unknown'), findsOneWidget);
  });

  testWidgets('Start when added follows the daemon and maps to paused',
      (WidgetTester tester) async {
    await open(tester);
    final SwitchListTile tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Start when added'),
    );
    expect(tile.value, isTrue);

    await tester.tap(find.text('Start when added'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'magnet: link or .torrent URL'),
      'magnet:?xt=urn:btih:zzzz',
    );
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    expect(fake.single('torrent-add').arguments['paused'], isTrue);
    expect(
      fake.single('torrent-add').arguments['download-dir'],
      '/downloads/complete',
    );
  });

  testWidgets('the fields read as boxes, not floating labels',
      (WidgetTester tester) async {
    // A fill alone left both fields looking like bare text on the sheet: the
    // fill was within a shade of the surface behind it. Each has to carry an
    // outline, and say so when focused.
    await open(tester);

    for (final String label in <String>[
      'magnet: link or .torrent URL',
      'Download folder (optional)',
    ]) {
      final TextField field = tester.widget<TextField>(
        find.widgetWithText(TextField, label),
      );
      final InputDecoration decoration = decorationOf(tester, field);
      expect(decoration.filled, isTrue, reason: '$label fill');
      final OutlineInputBorder border =
          decoration.border! as OutlineInputBorder;
      expect(
        border.borderSide.style,
        BorderStyle.solid,
        reason: '$label outline',
      );
      expect(
        decoration.focusedBorder,
        isA<OutlineInputBorder>(),
        reason: '$label focus ring',
      );
    }
  });
}

/// The decoration a [TextField] actually paints with, theme defaults applied.
InputDecoration decorationOf(WidgetTester tester, TextField field) {
  final BuildContext context = tester.element(find.byType(TextField).first);
  return (field.decoration ?? const InputDecoration())
      .applyDefaults(Theme.of(context).inputDecorationTheme);
}
