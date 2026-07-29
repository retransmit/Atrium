import 'package:atrium/src/dashboard/dashboard_widget_kind.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The customize sheet marks a widget "Not configured" unless one of its
/// [DashboardWidgetKindX.serviceKinds] has an instance, so a download client
/// missing from the downloads list can never surface the widget. Deriving the
/// expectation from the role keeps the next client from repeating that.
void main() {
  test('every download client kind configures the downloads widget', () {
    for (final ServiceKind kind in ServiceKind.values) {
      if (kind.role == ServiceRole.downloader) {
        expect(
          DashboardWidgetKind.downloads.serviceKinds,
          contains(kind),
          reason:
              '${kind.name} is a download client but does not configure the '
              'downloads widget',
        );
      }
    }
  });
}
