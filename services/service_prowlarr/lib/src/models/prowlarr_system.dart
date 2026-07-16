import 'package:freezed_annotation/freezed_annotation.dart';

part 'prowlarr_system.freezed.dart';
part 'prowlarr_system.g.dart';

/// `GET /api/v1/system/status`.
@freezed
abstract class ProwlarrSystemStatus with _$ProwlarrSystemStatus {
  const factory ProwlarrSystemStatus({
    @Default('') String version,
    @Default('') String appName,
    String? appData,
    String? osName,
    String? osVersion,
    @Default(false) bool isDocker,
    String? runtimeVersion,
    String? databaseType,
    String? databaseVersion,
    int? migrationVersion,
    String? packageVersion,
    String? packageAuthor,
    String? mode,
    String? startupPath,
    DateTime? startTime,
  }) = _ProwlarrSystemStatus;

  factory ProwlarrSystemStatus.fromJson(Map<String, dynamic> json) =>
      _$ProwlarrSystemStatusFromJson(json);
}

/// One entry from `GET /api/v1/health` (only warnings/errors are returned).
/// [type] is `notice` / `warning` / `error`.
@freezed
abstract class ProwlarrHealth with _$ProwlarrHealth {
  const factory ProwlarrHealth({
    @Default('') String source,
    @Default('') String type,
    @Default('') String message,
    String? wikiUrl,
  }) = _ProwlarrHealth;

  factory ProwlarrHealth.fromJson(Map<String, dynamic> json) =>
      _$ProwlarrHealthFromJson(json);
}

/// One scheduled task from `GET /api/v1/system/task`. Run it via
/// `POST /command { name: taskName }`. [interval] is in minutes.
@freezed
abstract class ProwlarrSystemTask with _$ProwlarrSystemTask {
  const factory ProwlarrSystemTask({
    required int id,
    @Default('') String name,
    @Default('') String taskName,
    @Default(0) int interval,
    DateTime? lastExecution,
    DateTime? nextExecution,
  }) = _ProwlarrSystemTask;

  factory ProwlarrSystemTask.fromJson(Map<String, dynamic> json) =>
      _$ProwlarrSystemTaskFromJson(json);
}

/// One backup from `GET /api/v1/system/backup`. [type] is
/// `scheduled` / `manual` / `update`.
@freezed
abstract class ProwlarrBackup with _$ProwlarrBackup {
  const factory ProwlarrBackup({
    required int id,
    @Default('') String name,
    String? path,
    String? type,
    DateTime? time,
  }) = _ProwlarrBackup;

  factory ProwlarrBackup.fromJson(Map<String, dynamic> json) =>
      _$ProwlarrBackupFromJson(json);
}
