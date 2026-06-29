import 'package:freezed_annotation/freezed_annotation.dart';

part 'sab_history.freezed.dart';
part 'sab_history.g.dart';

/// `GET /api?mode=history&output=json` -> `{ "history": { … } }`.
@freezed
abstract class SabHistoryResponse with _$SabHistoryResponse {
  const factory SabHistoryResponse({SabHistory? history}) = _SabHistoryResponse;

  factory SabHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$SabHistoryResponseFromJson(json);
}

@freezed
abstract class SabHistory with _$SabHistory {
  const factory SabHistory({
    @Default(<SabHistorySlot>[]) List<SabHistorySlot> slots,
    @JsonKey(name: 'day_size') @Default('') String daySize,
    @JsonKey(name: 'week_size') @Default('') String weekSize,
    @JsonKey(name: 'month_size') @Default('') String monthSize,
    @JsonKey(name: 'total_size') @Default('') String totalSize,
  }) = _SabHistory;

  factory SabHistory.fromJson(Map<String, dynamic> json) =>
      _$SabHistoryFromJson(json);
}

@freezed
abstract class SabHistorySlot with _$SabHistorySlot {
  const factory SabHistorySlot({
    @JsonKey(name: 'nzo_id') @Default('') String nzoId,
    @Default('') String name,
    /// Completed, Failed, Extracting, Verifying, Repairing, etc.
    @Default('') String status,
    @Default('') String category,
    /// Human size string, e.g. "1.2 GB".
    @Default('') String size,
    @Default(0) int bytes,
    @JsonKey(name: 'fail_message') @Default('') String failMessage,
    /// Unix epoch seconds when the item finished.
    @Default(0) int completed,
  }) = _SabHistorySlot;

  factory SabHistorySlot.fromJson(Map<String, dynamic> json) =>
      _$SabHistorySlotFromJson(json);
}
