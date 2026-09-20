import 'package:flutter_test/flutter_test.dart';

/// Pumps a few frames. The screens show spinners while loading, and a
/// spinner never lets `pumpAndSettle` settle.
Future<void> settle(WidgetTester tester, {int frames = 6}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
