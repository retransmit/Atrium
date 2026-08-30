import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the system inset under the navigation bar.
///
/// This has been broken twice. Material's NavigationBar wraps itself in a
/// SafeArea and then sizes to its height, so pinning the bar to a bare 80 eats
/// the inset out of the bar itself and clips the selection pill and icons. It
/// was fixed once, lost within the hour to a branch that predated the fix, and
/// never applied to the five service bars copied from the same shape. Nothing
/// caught either, because nothing was watching. This is what watches.
Widget _wrap({required double inset, bool visible = true}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: inset)),
        child: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: AtriumBottomNav(
            visible: visible,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const <NavigationDestination>[
              NavigationDestination(icon: Icon(Icons.dns), label: 'Array'),
              NavigationDestination(icon: Icon(Icons.speed), label: 'System'),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('the bar reserves the system inset on top of its own height',
      (WidgetTester tester) async {
    // Roughly a three-button navigation bar, the case that broke: its inset
    // runs to about twice a gesture bar's, so there was no slack to hide it.
    const double inset = 48;
    await tester.pumpWidget(_wrap(inset: inset));

    expect(
      tester.getSize(find.byType(AtriumBottomNav)).height,
      AtriumBottomNav.barHeight + inset,
      reason: 'the inset was taken out of the bar rather than added below it',
    );
  });

  testWidgets('a device with no inset gets just the bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(inset: 0));

    expect(
      tester.getSize(find.byType(AtriumBottomNav)).height,
      AtriumBottomNav.barHeight,
    );
  });

  testWidgets('the navigation bar itself is given the full height', (
    WidgetTester tester,
  ) async {
    // The clipping happened inside the bar, so the outer box being right is
    // not enough on its own.
    const double inset = 48;
    await tester.pumpWidget(_wrap(inset: inset));

    expect(
      tester.getSize(find.byType(NavigationBar)).height,
      AtriumBottomNav.barHeight + inset,
    );
  });

  testWidgets('hiding it collapses the bar completely', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(inset: 48, visible: false));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(AtriumBottomNav)).height, 0);
  });

  testWidgets('destinations reach the bar', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(inset: 48));

    expect(find.text('Array'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });
}
