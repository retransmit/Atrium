// app/test/update_check/update_check_widgets_test.dart
import 'package:atrium/src/update_check/update_available_banner.dart';
import 'package:atrium/src/update_check/update_check_state.dart';
import 'package:atrium/src/update_check/update_check_tile.dart';
import 'package:atrium/src/update_check/update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedChecker extends UpdateChecker {
  _FixedChecker(this._fixed);
  final UpdateCheckState _fixed;
  @override
  UpdateCheckState build() => _fixed;
  @override
  Future<void> check() async {}
}

Future<void> _pump(WidgetTester tester, UpdateCheckState state, Widget child) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        updateCheckProvider.overrideWith(() => _FixedChecker(state)),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets('tile shows Tap to check when idle', (WidgetTester tester) async {
    await _pump(tester, const UpdateCheckState(), const UpdateCheckTile());
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Tap to check'), findsOneWidget);
  });

  testWidgets('tile shows the available version and an open icon',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const UpdateCheckState(
        status: UpdateStatus.updateAvailable,
        latestVersion: '1.2.0',
        releaseUrl: 'https://example/tag',
      ),
      const UpdateCheckTile(),
    );
    expect(find.text('Version 1.2.0 is available'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  testWidgets('banner appears when a newer version is known',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const UpdateCheckState(
        status: UpdateStatus.updateAvailable,
        latestVersion: '1.2.0',
        releaseUrl: 'https://example/tag',
      ),
      const UpdateAvailableBanner(),
    );
    expect(find.text('Version 1.2.0 is available'), findsOneWidget);
    expect(find.text('View release'), findsOneWidget);
  });

  testWidgets('banner is hidden when up to date', (WidgetTester tester) async {
    await _pump(
      tester,
      const UpdateCheckState(status: UpdateStatus.upToDate, latestVersion: '1.1.0'),
      const UpdateAvailableBanner(),
    );
    expect(find.text('View release'), findsNothing);
  });
}
