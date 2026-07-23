import 'package:atrium/src/update_check/update_check_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hasNewer is true only when latestVersion is above appVersion', () {
    // appVersion is 1.1.0.
    expect(
      const UpdateCheckState(
        status: UpdateStatus.updateAvailable,
        latestVersion: '1.2.0',
      ).hasNewer,
      isTrue,
    );
    expect(
      const UpdateCheckState(latestVersion: '1.1.0').hasNewer,
      isFalse,
    );
    expect(const UpdateCheckState().hasNewer, isFalse);
  });

  test('copyWith changes status and keeps the durable fields', () {
    const UpdateCheckState base = UpdateCheckState(
      status: UpdateStatus.updateAvailable,
      latestVersion: '1.2.0',
      releaseUrl: 'https://example/tag',
    );
    final UpdateCheckState next = base.copyWith(status: UpdateStatus.error);
    expect(next.status, UpdateStatus.error);
    expect(next.latestVersion, '1.2.0');
    expect(next.releaseUrl, 'https://example/tag');
    expect(next.hasNewer, isTrue);
  });
}
