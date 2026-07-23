import 'package:atrium/src/screens/changelog_screen.dart';
import 'package:atrium/src/update_check/update_available_banner.dart';
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

    expect(find.byType(UpdateAvailableBanner, skipOffstage: false),
        findsOneWidget);
    expect(find.text('v1.1.0'), findsOneWidget);
    // appVersion is 1.1.0, so exactly one card is Installed.
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('New'), findsWidgets);
  });
}
