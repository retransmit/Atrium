import 'package:freezed_annotation/freezed_annotation.dart';

part 'seerr_counts.freezed.dart';
part 'seerr_counts.g.dart';

/// `GET /api/v1/request/count`
@freezed
abstract class SeerrCounts with _$SeerrCounts {
  const factory SeerrCounts({
    @Default(0) int total,
    @Default(0) int movie,
    @Default(0) int tv,
    @Default(0) int pending,
    @Default(0) int approved,
    @Default(0) int declined,
    @Default(0) int processing,
    @Default(0) int available,
    @Default(0) int completed,
  }) = _SeerrCounts;

  factory SeerrCounts.fromJson(Map<String, dynamic> json) =>
      _$SeerrCountsFromJson(json);
}
