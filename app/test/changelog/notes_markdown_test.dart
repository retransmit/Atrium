import 'package:atrium/src/screens/changelog/notes_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseInline splits bold spans from normal text', () {
    final List<NoteSpan> spans = parseInline('**Lead.** and rest');
    expect(spans.length, 2);
    expect(spans[0].text, 'Lead.');
    expect(spans[0].bold, isTrue);
    expect(spans[1].text, ' and rest');
    expect(spans[1].bold, isFalse);
  });

  test('parseInline returns a single normal run when there is no bold', () {
    final List<NoteSpan> spans = parseInline('plain text');
    expect(spans.length, 1);
    expect(spans.single.bold, isFalse);
  });

  testWidgets('buildNotes renders paragraphs and a bullet',
      (WidgetTester tester) async {
    final List<Widget> widgets = buildNotes(
      '**First.** one\n\n- a bullet',
      ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4))),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets)),
    ));
    expect(find.textContaining('First.'), findsOneWidget);
    expect(find.textContaining('a bullet'), findsOneWidget);
  });
}
