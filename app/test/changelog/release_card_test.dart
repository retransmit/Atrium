import 'package:atrium/src/screens/changelog/release_card.dart';
import 'package:atrium/src/screens/changelog/release_notes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const ReleaseNote _note = ReleaseNote(
  version: '1.2.0',
  date: '2026-08-01',
  groups: <ChangeGroup>[
    ChangeGroup(ChangeCategory.added, <String>['A new thing']),
    ChangeGroup(ChangeCategory.fixed, <String>['A fixed thing']),
  ],
);

Future<void> _pump(WidgetTester tester, {required bool installed}) {
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: Scaffold(
        body: ReleaseCard(note: _note, installed: installed),
      ),
    ),
  );
}

void main() {
  testWidgets('renders version, date, category labels and bullets',
      (WidgetTester tester) async {
    await _pump(tester, installed: false);
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('2026-08-01'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('A new thing'), findsOneWidget);
    expect(find.text('A fixed thing'), findsOneWidget);
    expect(find.text('Installed'), findsNothing);
  });

  testWidgets('shows the Installed pill only when installed',
      (WidgetTester tester) async {
    await _pump(tester, installed: true);
    expect(find.text('Installed'), findsOneWidget);
  });

  testWidgets('category label uses the dynamic scheme role, not a fixed color',
      (WidgetTester tester) async {
    final ColorScheme scheme =
        ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
    await _pump(tester, installed: false);
    final Text newLabel = tester.widget<Text>(find.text('New'));
    expect(newLabel.style?.color, scheme.tertiary);
    final Text fixedLabel = tester.widget<Text>(find.text('Fixed'));
    expect(fixedLabel.style?.color, scheme.primary);
  });

  test('categoryColor and categoryLabel cover the improved arm', () {
    final ColorScheme scheme =
        ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
    expect(categoryColor(ChangeCategory.improved, scheme), scheme.secondary);
    expect(categoryLabel(ChangeCategory.improved), 'Improved');
  });
}
