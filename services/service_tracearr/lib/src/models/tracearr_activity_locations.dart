import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_activity_locations.freezed.dart';
part 'tracearr_activity_locations.g.dart';

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

@freezed
abstract class TracearrActivityLocation with _$TracearrActivityLocation {
  const TracearrActivityLocation._();

  const factory TracearrActivityLocation({
    @JsonKey(defaultValue: '') required String city,
    @JsonKey(defaultValue: '') required String region,
    @JsonKey(defaultValue: '') required String country,
    @JsonKey(fromJson: _parseDouble) double? lat,
    @JsonKey(fromJson: _parseDouble) double? lon,
    @JsonKey(defaultValue: 0) required int count,
    @JsonKey(defaultValue: <TracearrActivityLocationUser>[]) required List<TracearrActivityLocationUser> users,
  }) = _TracearrActivityLocation;

  factory TracearrActivityLocation.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityLocationFromJson(json);
}

@freezed
abstract class TracearrActivityLocationUser with _$TracearrActivityLocationUser {
  const factory TracearrActivityLocationUser({
    required String id,
    String? thumbUrl,
    String? serverId,
    required String username,
  }) = _TracearrActivityLocationUser;

  factory TracearrActivityLocationUser.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityLocationUserFromJson(json);
}

@freezed
abstract class TracearrActivityLocationsResponse with _$TracearrActivityLocationsResponse {
  const factory TracearrActivityLocationsResponse({
    @JsonKey(defaultValue: <TracearrActivityLocation>[]) required List<TracearrActivityLocation> data,
  }) = _TracearrActivityLocationsResponse;

  factory TracearrActivityLocationsResponse.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityLocationsResponseFromJson(json);
}
