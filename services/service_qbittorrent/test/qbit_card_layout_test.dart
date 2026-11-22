import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

import 'support/qbit_fixtures.dart';

const Instance _instance = Instance(
  id: 'test-qbit',
  name: 'Test qBittorrent',
  kind: ServiceKind.qbittorrent,
  localUrl: 'http://localhost',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

/// A torrent part way down, so the card shows both speeds, the ratio and
/// the ETA: the fullest bottom row a card has.
Map<String, dynamic> _downloading() => torrentRowJson(
      state: 'downloading',
      progress: 0.42,
      dlspeed: 12 * 1024 * 1024,
      upspeed: 640 * 1024,
      eta: 3 * 3600 + 25 * 60,
    );

Future<void> _openList(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 891);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        qbitRawTorrentsProvider(_instance).overrideWith(
          (Ref ref) async =>
              <QbitTorrent>[QbitTorrent.fromJson(_downloading())],
        ),
        qbitTransferProvider(_instance)
            .overrideWith((Ref ref) async => const QbitTransferInfo()),
      ],
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: const QbittorrentHome(instance: _instance),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  // The test font draws every letter as a wide block, so a phone width
  // would wrap here where Roboto fits. A wide screen stands in for "it fits".
  testWidgets('the bottom row stays on one line when it fits',
      (WidgetTester tester) async {
    await _openList(tester, width: 1000);
    final Rect down = tester.getRect(find.text('12.0 MB/s'));
    final Rect ratio = tester.getRect(find.text('0.00'));
    // Same line, with the ratio over at the right of the card.
    expect((ratio.center.dy - down.center.dy).abs(), lessThan(4));
    expect(ratio.left, greaterThan(1000 * 3 / 4));
  });

  // Only the list's own layout counts here: at these sizes the test font
  // also trips the settings tab, which a real font does not.
  for (final double scale in <double>[1.5, 2]) {
    testWidgets('the card fits a narrow phone at ${scale}x text',
        (WidgetTester tester) async {
      final List<String> errors = <String>[];
      final void Function(FlutterErrorDetails)? report = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails d) => errors.add('$d');
      await _openList(tester, width: 320, textScale: scale);
      FlutterError.onError = report;
      expect(
        errors.where((String e) => e.contains('qbittorrent_home.dart')),
        isEmpty,
      );
      expect(find.text('0.00'), findsOneWidget);
    });
  }
}
