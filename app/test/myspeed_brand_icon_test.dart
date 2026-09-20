import 'package:core_models/core_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// MySpeed has its own icon in the service picker.
///
/// The picker loads `assets/service_icons/<kind>.png` and falls back to a
/// generic server icon when there is none.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the icon the picker asks for is bundled', () async {
    final ByteData icon = await rootBundle
        .load('assets/service_icons/${ServiceKind.myspeed.name}.png');

    expect(icon.lengthInBytes, greaterThan(0));
  });
}
