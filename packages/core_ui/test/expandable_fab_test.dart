import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The folded actions stay in the tree, scaled to nothing, so they have to be
/// kept from a screen reader by hand; and the main button is only a "+", so it
/// needs words of its own.
void main() {
  late int taps;

  Widget wrap() => MaterialApp(
        home: Scaffold(
          floatingActionButton: ExpandableFab(
            tooltip: 'Add torrent',
            builder: (BuildContext context, VoidCallback close) => <Widget>[
              FloatingActionButton(
                heroTag: null,
                tooltip: 'Magnet link',
                onPressed: () {
                  taps++;
                  close();
                },
                child: const Icon(Icons.link),
              ),
            ],
          ),
        ),
      );

  setUp(() => taps = 0);

  /// Whether anything in the semantics tree announces [text]. A button's
  /// tooltip reaches it as a tooltip, not a label, so both are checked.
  bool announced(WidgetTester tester, String text) {
    bool found = false;
    void visit(SemanticsNode node) {
      final SemanticsData data = node.getSemanticsData();
      if (data.tooltip == text || data.label == text) found = true;
      node.visitChildren((SemanticsNode child) {
        visit(child);
        return true;
      });
    }

    visit(tester.getSemantics(find.byType(Scaffold)));
    return found;
  }

  testWidgets('the main button is labelled, and says Close while open',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    expect(find.byTooltip('Add torrent'), findsOneWidget);

    await tester.tap(find.byTooltip('Add torrent'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('folded actions are hidden from a screen reader',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrap());
    expect(announced(tester, 'Magnet link'), isFalse);

    await tester.tap(find.byTooltip('Add torrent'));
    await tester.pumpAndSettle();
    expect(announced(tester, 'Magnet link'), isTrue);

    await tester.tap(find.byTooltip('Magnet link'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(announced(tester, 'Magnet link'), isFalse);
    semantics.dispose();
  });
}
