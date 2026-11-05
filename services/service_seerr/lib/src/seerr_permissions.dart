import 'models/seerr_issue.dart';
import 'models/seerr_request.dart';

/// Seerr's permission bits, as `server/lib/permissions.ts` numbers them.
///
/// Only the ones the app checks are listed.
abstract final class SeerrPermission {
  static const int admin = 2;
  static const int manageRequests = 16;
  static const int request = 32;
  static const int request4k = 1024;
  static const int request4kMovie = 2048;
  static const int request4kTv = 4096;
  static const int requestAdvanced = 8192;
  static const int requestView = 16384;
  static const int requestMovie = 262144;
  static const int requestTv = 524288;
  static const int manageIssues = 1048576;
  static const int viewIssues = 2097152;
  static const int createIssues = 4194304;
}

/// What the signed-in user may do, read the way Seerr reads it.
///
/// Seerr lets an admin do everything, so each check passes for one. An API
/// key acts as Seerr's first user, the owner, which is always an admin, so an
/// API key instance keeps every action it had.
extension SeerrUserPermissions on SeerrUser {
  bool _any(List<int> bits) =>
      permissions & SeerrPermission.admin != 0 ||
      bits.any((int bit) => permissions & bit != 0);

  /// Approve, decline and retry any request, and remove any request.
  bool get canManageRequests => _any(<int>[SeerrPermission.manageRequests]);

  /// See everyone's requests rather than only their own.
  bool get canViewAllRequests => _any(<int>[
        SeerrPermission.manageRequests,
        SeerrPermission.requestView,
      ]);

  /// Request a movie (`movie`) or a series (`tv`), in 4K when [is4k].
  bool canRequest(String mediaType, {bool is4k = false}) {
    final bool tv = mediaType == 'tv';
    return _any(
      is4k
          ? <int>[
              SeerrPermission.request4k,
              tv ? SeerrPermission.request4kTv : SeerrPermission.request4kMovie,
            ]
          : <int>[
              SeerrPermission.request,
              tv ? SeerrPermission.requestTv : SeerrPermission.requestMovie,
            ],
    );
  }

  /// Pick the server, quality profile and root folder of a request. Seerr
  /// quietly drops these choices from anyone else.
  bool get canRequestAdvanced => _any(<int>[
        SeerrPermission.manageRequests,
        SeerrPermission.requestAdvanced,
      ]);

  /// Remove [request]. Besides a request manager, the requester may withdraw
  /// their own request while it still waits for approval.
  bool canDelete(SeerrRequest request) =>
      canManageRequests ||
      (request.requestedBy?.id == id && request.status == 1);

  /// Open the issues list at all.
  bool get canSeeIssues => _any(<int>[
        SeerrPermission.manageIssues,
        SeerrPermission.viewIssues,
        SeerrPermission.createIssues,
      ]);

  /// Report a new issue.
  bool get canReportIssues => _any(<int>[
        SeerrPermission.manageIssues,
        SeerrPermission.createIssues,
      ]);

  /// Comment on [issue], and resolve or reopen it. Seerr lets the reporter do
  /// both on their own issue, and an issue manager on any.
  bool canWorkOn(SeerrIssue issue) =>
      _any(<int>[SeerrPermission.manageIssues]) ||
      (canReportIssues && issue.createdBy?.id == id);
}
