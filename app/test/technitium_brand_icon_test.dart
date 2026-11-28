import 'package:core_models/core_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the icon the picker asks for is bundled', () async {
    final ByteData icon = await rootBundle
        .load('assets/service_icons/${ServiceKind.technitium.name}.png');

    expect(icon.lengthInBytes, greaterThan(0));
  });
}
