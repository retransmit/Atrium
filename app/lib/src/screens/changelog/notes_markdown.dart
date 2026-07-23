import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// A run of note text with a bold flag, parsed from **bold** markdown.
class NoteSpan {
  const NoteSpan(this.text, this.bold);
  final String text;
  final bool bold;
}

/// Splits a line into bold and normal runs on `**...**`.
List<NoteSpan> parseInline(String text) {
  final List<NoteSpan> spans = <NoteSpan>[];
  final RegExp bold = RegExp(r'\*\*(.+?)\*\*');
  int index = 0;
  for (final RegExpMatch m in bold.allMatches(text)) {
    if (m.start > index) {
      spans.add(NoteSpan(text.substring(index, m.start), false));
    }
    spans.add(NoteSpan(m.group(1)!, true));
    index = m.end;
  }
  if (index < text.length) {
    spans.add(NoteSpan(text.substring(index), false));
  }
  if (spans.isEmpty) spans.add(NoteSpan(text, false));
  return spans;
}

/// Renders simple "What's new" markdown (bold spans, paragraphs, dash bullets)
/// into widgets using dynamic colors only. Not a general markdown engine; it
/// covers exactly what Atrium's release notes use. The input is untrusted, so
/// only text and bold are produced, never links or HTML.
List<Widget> buildNotes(String notes, ThemeData theme) {
  final ColorScheme scheme = theme.colorScheme;
  final TextStyle base =
      (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(color: scheme.onSurface);

  TextSpan lineSpan(String line) => TextSpan(
        style: base,
        children: <TextSpan>[
          for (final NoteSpan s in parseInline(line))
            TextSpan(
              text: s.text,
              style: s.bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
            ),
        ],
      );

  final List<Widget> widgets = <Widget>[];
  for (final String block in notes.trim().split(RegExp(r'\n\s*\n'))) {
    final String para = block.trim();
    if (para.isEmpty) continue;
    if (para.startsWith('- ')) {
      for (final String raw in para.split('\n')) {
        final String line = raw.trim();
        if (!line.startsWith('- ')) continue;
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 7, right: Insets.sm),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(child: Text.rich(lineSpan(line.substring(2)))),
            ],
          ),
        ));
      }
    } else {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: Text.rich(lineSpan(para.replaceAll('\n', ' '))),
      ));
    }
  }
  return widgets;
}
