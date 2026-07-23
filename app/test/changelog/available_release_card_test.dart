import 'package:atrium/src/screens/changelog/available_release_card.dart';
import 'package:atrium/src/update_check/update_check_state.dart';
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

Future<void> _pump(WidgetTester tester, UpdateCheckState state) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        updateCheckProvider.overrideWith(() => _FixedChecker(state)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AvailableReleaseCard()),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the version, Available pill, notes and link',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const UpdateCheckState(
        status: UpdateStatus.updateAvailable,
        latestVersion: '1.2.0',
        latestDate: '2026-08-01',
        latestNotes: '**Nice thing.** Details.',
        releaseUrl: 'https://example/tag',
      ),
    );
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('2026-08-01'), findsOneWidget);
    expect(find.textContaining('Nice thing.'), findsOneWidget);
    expect(find.text('See full release'), findsOneWidget);
  });

  testWidgets('is hidden when there is no newer version',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const UpdateCheckState(status: UpdateStatus.upToDate, latestVersion: '1.1.0'),
    );
    expect(find.text('Available'), findsNothing);
    expect(find.text('See full release'), findsNothing);
  });

  testWidgets('shows only the link when notes are absent',
      (WidgetTester tester) async {
    await _pump(
      tester,
      const UpdateCheckState(
        status: UpdateStatus.updateAvailable,
        latestVersion: '1.2.0',
        releaseUrl: 'https://example/tag',
      ),
    );
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('See full release'), findsOneWidget);
    expect(find.textContaining('Nice thing.'), findsNothing);
  });
}
