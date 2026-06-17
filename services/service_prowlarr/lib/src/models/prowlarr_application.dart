import 'package:freezed_annotation/freezed_annotation.dart';

part 'prowlarr_application.freezed.dart';
part 'prowlarr_application.g.dart';

/// A configured application target from `GET /api/v1/applications` - a Sonarr,
/// Radarr, Lidarr, ... instance that Prowlarr pushes its indexers to.
///
/// This is a trimmed projection for the Apps list; the add/edit form
/// round-trips the full raw object (with its dynamic `fields`) instead.
@freezed
abstract class ProwlarrApplication with _$ProwlarrApplication {
  const factory ProwlarrApplication({
    required int id,
    @Default('') String name,
    @Default('') String implementation,
    @Default('') String implementationName,
    // ApplicationSyncLevel: disabled / addOnly / fullSync.
    @Default('') String syncLevel,
    @Default(<int>[]) List<int> tags,
  }) = _ProwlarrApplication;

  factory ProwlarrApplication.fromJson(Map<String, dynamic> json) =>
      _$ProwlarrApplicationFromJson(json);
}
