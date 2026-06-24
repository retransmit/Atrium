import 'package:freezed_annotation/freezed_annotation.dart';

part 'radarr_system.freezed.dart';
part 'radarr_system.g.dart';

@freezed
abstract class RadarrSystemStatus with _$RadarrSystemStatus {
  const factory RadarrSystemStatus({
    @Default('') String version,
    @Default('') String appName,
    @Default('') String osName,
    @Default('') String osVersion,
    @Default(false) bool isDocker,
    String? databaseType,
    String? databaseVersion,
    String? runtimeVersion,
    String? runtimeName,
  }) = _RadarrSystemStatus;

  factory RadarrSystemStatus.fromJson(Map<String, dynamic> json) =>
      _$RadarrSystemStatusFromJson(json);
}

@freezed
abstract class RadarrDiskSpace with _$RadarrDiskSpace {
  const factory RadarrDiskSpace({
    @Default('') String path,
    @Default('') String label,
    @Default(0) int freeSpace,
    @Default(0) int totalSpace,
  }) = _RadarrDiskSpace;

  factory RadarrDiskSpace.fromJson(Map<String, dynamic> json) =>
      _$RadarrDiskSpaceFromJson(json);
}

@freezed
abstract class RadarrHealth with _$RadarrHealth {
  const factory RadarrHealth({
    @Default('') String source,
    @Default('') String type,
    @Default('') String message,
    String? wikiUrl,
  }) = _RadarrHealth;

  factory RadarrHealth.fromJson(Map<String, dynamic> json) =>
      _$RadarrHealthFromJson(json);
}

@freezed
abstract class RadarrSystemTask with _$RadarrSystemTask {
  const factory RadarrSystemTask({
    required int id,
    @Default('') String name,
    @Default('') String taskName,
    @Default(0) int interval,
    DateTime? lastExecution,
    DateTime? nextExecution,
  }) = _RadarrSystemTask;

  factory RadarrSystemTask.fromJson(Map<String, dynamic> json) =>
      _$RadarrSystemTaskFromJson(json);
}

@freezed
abstract class RadarrBackup with _$RadarrBackup {
  const factory RadarrBackup({
    required int id,
    @Default('') String name,
    @Default('') String path,
    @Default('') String type,
    DateTime? time,
  }) = _RadarrBackup;

  factory RadarrBackup.fromJson(Map<String, dynamic> json) =>
      _$RadarrBackupFromJson(json);
}
