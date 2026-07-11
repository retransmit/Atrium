import 'package:freezed_annotation/freezed_annotation.dart';

part 'seerr_request.freezed.dart';
part 'seerr_request.g.dart';

/// `GET /api/v1/request` → `{ "pageInfo": {…}, "results": [ … ] }`.
@freezed
abstract class SeerrRequestPage with _$SeerrRequestPage {
  const factory SeerrRequestPage({
    @Default(<SeerrRequest>[]) List<SeerrRequest> results,
  }) = _SeerrRequestPage;

  factory SeerrRequestPage.fromJson(Map<String, dynamic> json) =>
      _$SeerrRequestPageFromJson(json);
}

/// A media request.
///
/// `status`: 1 = pending approval, 2 = approved, 3 = declined.
@freezed
abstract class SeerrRequest with _$SeerrRequest {
  const factory SeerrRequest({
    required int id,
    @Default(1) int status,
    /// 'movie' or 'tv'.
    @Default('') String type,
    SeerrMedia? media,
    SeerrUser? requestedBy,
    String? createdAt,
  }) = _SeerrRequest;

  factory SeerrRequest.fromJson(Map<String, dynamic> json) =>
      _$SeerrRequestFromJson(json);
}

/// The media a request targets.
///
/// `status`: 1 unknown, 2 pending, 3 processing, 4 partially available,
/// 5 available.
@freezed
abstract class SeerrMedia with _$SeerrMedia {
  const factory SeerrMedia({
    /// Internal Seerr media DB id (what the issue endpoints key on).
    @JsonKey(name: 'id') int? id,
    @Default('') String mediaType,
    int? tmdbId,
    @Default(1) int status,
  }) = _SeerrMedia;

  factory SeerrMedia.fromJson(Map<String, dynamic> json) =>
      _$SeerrMediaFromJson(json);
}

@freezed
abstract class SeerrUser with _$SeerrUser {
  const factory SeerrUser({
    @Default('') String displayName,
    @Default('') String username,
  }) = _SeerrUser;

  factory SeerrUser.fromJson(Map<String, dynamic> json) =>
      _$SeerrUserFromJson(json);
}
