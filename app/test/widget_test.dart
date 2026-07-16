import 'package:atrium/src/screens/activity_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Smoke test exercising the theme + a screen with no configured services.
// Booting the full AtriumApp requires bootstrap()'s provider overrides (Hive
// + secure storage), which belong in an integration test, not a unit test.
void main() {
  testWidgets('Activity screen renders its empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // No instances: the feed watches no sources and shows its empty
          // state without touching the (unbootstrapped) profile repository.
          activeInstancesProvider.overrideWith((Ref ref) => const <Instance>[]),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: const ActivityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.byType(EmptyView), findsOneWidget);
  });
}
