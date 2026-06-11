import 'package:atrium/src/screens/library_screen.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Smoke test exercising the theme + a provider-free screen. Booting the full
// AtriumApp requires bootstrap()'s provider overrides (Hive + secure storage),
// which belong in an integration test, not a unit test.
void main() {
  testWidgets('Library screen renders its empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AtriumTheme.light(null), home: const LibraryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.byType(EmptyView), findsOneWidget);
  });
}
