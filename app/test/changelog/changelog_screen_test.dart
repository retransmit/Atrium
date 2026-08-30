import 'package:atrium/src/screens/changelog_screen.dart';
import 'package:atrium/src/screens/changelog/available_release_card.dart';
import 'package:atrium/src/update_check/app_version.dart';
import 'package:atrium/src/update_check/update_check_state.dart';
import 'package:atrium/src/update_check/update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

class _IdleUpdateChecker extends UpdateChecker {
  @override
  UpdateCheckState build() => const UpdateCheckState();
  @override
  Future<void> check() async {}
}

void main() {
  testWidgets('renders release cards with the Installed pill on the current version',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          updateCheckProvider.overrideWith(_IdleUpdateChecker.new),
        ],
        child: const MaterialApp(home: ChangelogScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(AvailableReleaseCard, skipOffstage: false),
        findsOneWidget);
    // Tied to appVersion rather than a frozen string: the newest release is
    // the installed one, and hardcoding it here means every release breaks
    // this test for no reason.
    expect(find.text('v$appVersion'), findsOneWidget);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('New'), findsWidgets);
  });
}
