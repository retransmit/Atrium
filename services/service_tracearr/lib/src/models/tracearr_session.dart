import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_session.freezed.dart';
part 'tracearr_session.g.dart';

@freezed
abstract class TracearrSession with _$TracearrSession {
  const TracearrSession._();

  const factory TracearrSession({
    @JsonKey(name: 'id', defaultValue: '') required String id,
    @JsonKey(name: 'serverId', defaultValue: '') required String serverId,
    @JsonKey(name: 'state', defaultValue: '') required String state,
    @JsonKey(name: 'mediaType', defaultValue: '') required String mediaType,
    @JsonKey(name: 'mediaTitle', defaultValue: '') required String mediaTitle,
    @JsonKey(name: 'grandparentTitle') String? grandparentTitle,
    @JsonKey(name: 'seasonNumber') int? seasonNumber,
    @JsonKey(name: 'episodeNumber') int? episodeNumber,
    @JsonKey(name: 'thumbPath') String? thumbPath,
    @JsonKey(name: 'progressMs', defaultValue: 0) required int progressMs,
    @JsonKey(name: 'totalDurationMs', defaultValue: 0) required int totalDurationMs,
    @JsonKey(name: 'ipAddress', defaultValue: '') required String ipAddress,
    @JsonKey(name: 'geoCity') String? geoCity,
    @JsonKey(name: 'geoRegion') String? geoRegion,
    @JsonKey(name: 'geoCountry') String? geoCountry,
    @JsonKey(name: 'playerName', defaultValue: '') required String playerName,
    @JsonKey(name: 'product', defaultValue: '') required String product,
    @JsonKey(name: 'device', defaultValue: '') required String device,
    @JsonKey(name: 'platform', defaultValue: '') required String platform,
    @JsonKey(name: 'quality', defaultValue: '') required String quality,
    @JsonKey(name: 'isTranscode', defaultValue: false) required bool isTranscode,
    @JsonKey(name: 'videoDecision') String? videoDecision,
    @JsonKey(name: 'audioDecision') String? audioDecision,
  }) = _TracearrSession;

  String get displayTitle {
    if (mediaType == 'episode' && grandparentTitle != null) {
      if (seasonNumber != null && episodeNumber != null) {
        final String s = seasonNumber!.toString().padLeft(2, '0');
        final String e = episodeNumber!.toString().padLeft(2, '0');
        return '$grandparentTitle - S${s}E$e - $mediaTitle';
      }
      return '$grandparentTitle - $mediaTitle';
    }
    return mediaTitle;
  }

  String get location {
    final List<String> parts = <String>[];
    if (geoCity != null && geoCity!.isNotEmpty) parts.add(geoCity!);
    if (geoRegion != null && geoRegion!.isNotEmpty) parts.add(geoRegion!);
    if (geoCountry != null && geoCountry!.isNotEmpty) parts.add(geoCountry!);
    if (parts.isEmpty) return ipAddress;
    return parts.join(', ');
  }

  double get progressPercent {
    if (totalDurationMs == 0) return 0.0;
    return (progressMs / totalDurationMs) * 100.0;
  }

  String get serverType {
    final String p = product.toLowerCase();
    if (p.contains('emby')) return 'emby';
    if (p.contains('plex')) return 'plex';
    if (p.contains('jellyfin')) return 'jellyfin';
    return 'unknown';
  }

  factory TracearrSession.fromJson(Map<String, dynamic> json) =>
      _$TracearrSessionFromJson(json);
}
