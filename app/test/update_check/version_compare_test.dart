import 'package:atrium/src/update_check/version_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compareVersions orders versions numerically', () {
    expect(compareVersions('1.2.0', '1.1.0'), 1);
    expect(compareVersions('1.1.0', '1.2.0'), -1);
    expect(compareVersions('1.1.0', '1.1.0'), 0);
  });

  test('compareVersions tolerates a v prefix and a missing patch', () {
    expect(compareVersions('v1.1.1', '1.1.0'), 1);
    expect(compareVersions('1.1', '1.1.0'), 0);
  });

  test('compareVersions is numeric, not lexicographic', () {
    expect(compareVersions('1.10.0', '1.9.0'), 1);
  });

  test('compareVersions treats unparseable input as zeros', () {
    expect(compareVersions('garbage', '1.0.0'), -1);
  });
}
