import 'package:freezed_annotation/freezed_annotation.dart';

import 'seerr_request.dart';

part 'seerr_issue.freezed.dart';
part 'seerr_issue.g.dart';

/// `GET /api/v1/issue` -> `{ "pageInfo": {...}, "results": [ ... ] }`.
@freezed
abstract class SeerrIssuePage with _$SeerrIssuePage {
  const factory SeerrIssuePage({
    @Default(<SeerrIssue>[]) List<SeerrIssue> results,
  }) = _SeerrIssuePage;

  factory SeerrIssuePage.fromJson(Map<String, dynamic> json) =>
      _$SeerrIssuePageFromJson(json);
}

/// A reported media issue.
///
/// `issueType`: 1 video, 2 audio, 3 subtitles, 4 other.
/// `status`: 1 open, 2 resolved.
@freezed
abstract class SeerrIssue with _$SeerrIssue {
  const SeerrIssue._();

  const factory SeerrIssue({
    required int id,
    @JsonKey(name: 'issueType') @Default(4) int issueType,
    @Default(1) int status,
    SeerrMedia? media,
    @JsonKey(name: 'createdBy') SeerrUser? createdBy,
    int? problemSeason,
    @Default(<SeerrIssueComment>[]) List<SeerrIssueComment> comments,
    String? createdAt,
  }) = _SeerrIssue;

  factory SeerrIssue.fromJson(Map<String, dynamic> json) =>
      _$SeerrIssueFromJson(json);

  bool get isOpen => status == 1;

  String get typeLabel {
    switch (issueType) {
      case 1:
        return 'Video';
      case 2:
        return 'Audio';
      case 3:
        return 'Subtitles';
      default:
        return 'Other';
    }
  }
}

/// A comment on an issue.
@freezed
abstract class SeerrIssueComment with _$SeerrIssueComment {
  const factory SeerrIssueComment({
    @Default(0) int id,
    @Default('') String message,
    SeerrUser? user,
    String? createdAt,
  }) = _SeerrIssueComment;

  factory SeerrIssueComment.fromJson(Map<String, dynamic> json) =>
      _$SeerrIssueCommentFromJson(json);
}
