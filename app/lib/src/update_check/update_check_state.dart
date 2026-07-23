import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'version_compare.dart';

/// Where the manual update check currently stands.
enum UpdateStatus { idle, checking, upToDate, updateAvailable, error }

/// The outcome of the last check, plus the last known latest release.
///
/// [status] is the live/transient state driving the Settings tile. The durable
/// fields survive across launches and drive the Change log via [hasNewer], so a
/// failed check does not erase a known "available". [latestNotes] is the
/// extracted "What's new" of the available release, [latestDate] its publish
/// date.
@immutable
class UpdateCheckState {
  const UpdateCheckState({
    this.status = UpdateStatus.idle,
    this.latestVersion,
    this.releaseUrl,
    this.checkedAt,
    this.latestNotes,
    this.latestDate,
  });

  final UpdateStatus status;
  final String? latestVersion;
  final String? releaseUrl;
  final DateTime? checkedAt;
  final String? latestNotes;
  final String? latestDate;

  /// True when the last known latest release is newer than the running app.
  bool get hasNewer =>
      latestVersion != null && compareVersions(latestVersion!, appVersion) > 0;

  UpdateCheckState copyWith({UpdateStatus? status}) => UpdateCheckState(
        status: status ?? this.status,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        checkedAt: checkedAt,
        latestNotes: latestNotes,
        latestDate: latestDate,
      );
}
