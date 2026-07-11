/// Public surface of `service_seerr`.
///
/// Seerr / Jellyseerr API client (X-Api-Key via the shared Dio), models,
/// Riverpod providers, and the per-instance [SeerrHome] UI (request list
/// with approve / decline).
library;

export 'src/models/seerr_discover.dart';
export 'src/models/seerr_issue.dart';
export 'src/models/seerr_request.dart';
export 'src/models/seerr_service.dart';
export 'src/seerr_api.dart';
export 'src/seerr_home.dart';
export 'src/seerr_issue_detail_screen.dart';
export 'src/seerr_issues_screen.dart';
export 'src/seerr_item_detail.dart';
export 'src/seerr_providers.dart';
export 'src/seerr_report_issue_sheet.dart';
export 'src/seerr_search.dart';
