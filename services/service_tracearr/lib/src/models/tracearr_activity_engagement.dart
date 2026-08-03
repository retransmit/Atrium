import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_activity_engagement.freezed.dart';
part 'tracearr_activity_engagement.g.dart';

@freezed
abstract class TracearrActivityEngagement with _$TracearrActivityEngagement {
  const TracearrActivityEngagement._();

  const factory TracearrActivityEngagement({
    @Default([]) List<TracearrTopContent> topContent,
    @Default([]) List<TracearrTopShow> topShows,
    @Default([]) List<TracearrEngagementBreakdown> engagementBreakdown,
    @Default([]) List<TracearrUserProfile> userProfiles,
    required TracearrEngagementSummary summary,
  }) = _TracearrActivityEngagement;

  factory TracearrActivityEngagement.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityEngagementFromJson(json);
}

@freezed
abstract class TracearrTopContent with _$TracearrTopContent {
  const TracearrTopContent._();

  const factory TracearrTopContent({
    required String ratingKey,
    required String title,
    String? showTitle,
    required String type,
    String? thumbPath,
    required String serverId,
    int? year,
    @Default(0) int totalPlays,
    @Default(0) double totalWatchHours,
    @Default(0) int uniqueViewers,
    @Default(0) int validSessions,
    @Default(0) int totalSessions,
    @Default(0) int completions,
    @Default(0) int rewatches,
    @Default(0) int abandonments,
    @Default(0) double completionRate,
    @Default(0) double abandonmentRate,
  }) = _TracearrTopContent;

  factory TracearrTopContent.fromJson(Map<String, dynamic> json) =>
      _$TracearrTopContentFromJson(json);
}

@freezed
abstract class TracearrTopShow with _$TracearrTopShow {
  const TracearrTopShow._();

  const factory TracearrTopShow({
    required String showTitle,
    String? thumbPath,
    required String serverId,
    int? year,
    @Default(0) int totalEpisodeViews,
    @Default(0) double totalWatchHours,
    @Default(0) int uniqueViewers,
    @Default(0) double avgEpisodesPerViewer,
    @Default(0) double avgCompletionRate,
    @Default(0) double bingeScore,
    @Default(0) int validSessions,
    @Default(0) int totalSessions,
  }) = _TracearrTopShow;

  factory TracearrTopShow.fromJson(Map<String, dynamic> json) =>
      _$TracearrTopShowFromJson(json);
}

@freezed
abstract class TracearrEngagementBreakdown with _$TracearrEngagementBreakdown {
  const TracearrEngagementBreakdown._();

  const factory TracearrEngagementBreakdown({
    required String tier,
    @Default(0) int count,
    @Default(0) double percentage,
  }) = _TracearrEngagementBreakdown;

  factory TracearrEngagementBreakdown.fromJson(Map<String, dynamic> json) =>
      _$TracearrEngagementBreakdownFromJson(json);
}

@freezed
abstract class TracearrUserProfile with _$TracearrUserProfile {
  const TracearrUserProfile._();

  const factory TracearrUserProfile({
    required String serverUserId,
    required String username,
    String? thumbUrl,
    String? serverId,
    String? identityName,
    @Default(0) int contentStarted,
    @Default(0) int totalPlays,
    @Default(0) double totalWatchHours,
    @Default(0) int validSessionCount,
    @Default(0) int totalSessionCount,
    @Default(0) int abandonedCount,
    @Default(0) int sampledCount,
    @Default(0) int engagedCount,
    @Default(0) int watchedCount,
    @Default(0) int rewatchedCount,
    @Default(0) double completionRate,
    String? behaviorType,
    String? favoriteMediaType,
  }) = _TracearrUserProfile;

  factory TracearrUserProfile.fromJson(Map<String, dynamic> json) =>
      _$TracearrUserProfileFromJson(json);
}

@freezed
abstract class TracearrEngagementSummary with _$TracearrEngagementSummary {
  const TracearrEngagementSummary._();

  const factory TracearrEngagementSummary({
    @Default(0) int totalPlays,
    @Default(0) int totalValidSessions,
    @Default(0) int totalAllSessions,
    @Default(0) double sessionInflationPct,
    @Default(0) double avgCompletionRate,
  }) = _TracearrEngagementSummary;

  factory TracearrEngagementSummary.fromJson(Map<String, dynamic> json) =>
      _$TracearrEngagementSummaryFromJson(json);
}
