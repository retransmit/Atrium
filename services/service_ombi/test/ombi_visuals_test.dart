import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

void main() {
  Future<Size> artworkBox(WidgetTester tester, OmbiMediaKind kind) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: OmbiPoster(url: null, kind: kind, width: 76)),
      ),
    );
    return tester.getSize(find.byType(OmbiPoster));
  }

  testWidgets('a film poster stands two wide to three tall',
      (WidgetTester tester) async {
    final Size box = await artworkBox(tester, OmbiMediaKind.movie);

    expect(box.width, 76);
    expect(box.height, moreOrLessEquals(114));
  });

  testWidgets('a show poster stands two wide to three tall',
      (WidgetTester tester) async {
    final Size box = await artworkBox(tester, OmbiMediaKind.tv);

    expect(box.width, 76);
    expect(box.height, moreOrLessEquals(114));
  });

  // Album covers are square: a poster-shaped box would cut their sides off.
  testWidgets('an album cover is square', (WidgetTester tester) async {
    final Size box = await artworkBox(tester, OmbiMediaKind.music);

    expect(box.width, 76);
    expect(box.height, moreOrLessEquals(76));
  });
}
