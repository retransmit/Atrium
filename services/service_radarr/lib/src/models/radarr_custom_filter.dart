import 'package:freezed_annotation/freezed_annotation.dart';

part 'radarr_custom_filter.freezed.dart';
part 'radarr_custom_filter.g.dart';

@freezed
abstract class RadarrCustomFilter with _$RadarrCustomFilter {
  const factory RadarrCustomFilter({
    required int id,
    String? type,
    String? label,
    List<dynamic>? filters,
  }) = _RadarrCustomFilter;

  factory RadarrCustomFilter.fromJson(Map<String, dynamic> json) =>
      _$RadarrCustomFilterFromJson(json);
}
