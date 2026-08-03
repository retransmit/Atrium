import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_session.freezed.dart';
part 'tracearr_session.g.dart';

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int _parseIntDefault(dynamic value) {
  return _parseInt(value) ?? 0;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

Map<String, dynamic>? _parseMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) return <String, dynamic>{'username': value};
  return null;
}

String? _parseString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  if (value is Map) {
    for (final String key in <String>[
      'username',
      'userName',
      'name',
      'title',
      'thumbUrl',
      'thumbPath',
      'thumb',
      'avatarUrl',
      'url',
      'id',
    ]) {
      if (value[key] != null) return value[key].toString();
    }
    return null;
  }
  return value.toString();
}

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
    @JsonKey(name: 'parentTitle') String? parentTitle,
    @JsonKey(name: 'originalTitle') String? originalTitle,
    @JsonKey(name: 'artist') String? artist,
    @JsonKey(name: 'artistName') String? artistName,
    @JsonKey(name: 'seasonNumber', fromJson: _parseInt) int? seasonNumber,
    @JsonKey(name: 'episodeNumber', fromJson: _parseInt) int? episodeNumber,
    @JsonKey(name: 'thumbPath') String? thumbPath,
    @JsonKey(name: 'progressMs', defaultValue: 0, fromJson: _parseIntDefault) required int progressMs,
    @JsonKey(name: 'totalDurationMs', defaultValue: 0, fromJson: _parseIntDefault) required int totalDurationMs,
    @JsonKey(name: 'ipAddress', defaultValue: '') required String ipAddress,
    @JsonKey(name: 'geoCity') String? geoCity,
    @JsonKey(name: 'geoRegion') String? geoRegion,
    @JsonKey(name: 'geoCountry') String? geoCountry,
    @JsonKey(name: 'geoLat', fromJson: _parseDouble) double? geoLat,
    @JsonKey(name: 'geoLon', fromJson: _parseDouble) double? geoLon,
    @JsonKey(name: 'geoAsnOrganization') String? geoAsnOrganization,
    @JsonKey(name: 'playerName', defaultValue: '') required String playerName,
    @JsonKey(name: 'product', defaultValue: '') required String product,
    @JsonKey(name: 'device', defaultValue: '') required String device,
    @JsonKey(name: 'platform', defaultValue: '') required String platform,
    @JsonKey(name: 'quality', defaultValue: '') required String quality,
    @JsonKey(name: 'isTranscode', defaultValue: false) required bool isTranscode,
    @JsonKey(name: 'videoDecision') String? videoDecision,
    @JsonKey(name: 'audioDecision') String? audioDecision,
    @JsonKey(name: 'startedAt') DateTime? startedAt,
    @JsonKey(name: 'stoppedAt') DateTime? stoppedAt,
    @JsonKey(name: 'username', fromJson: _parseString) String? username,
    @JsonKey(name: 'user', fromJson: _parseMap) Map<String, dynamic>? user,
    @JsonKey(name: 'userName', fromJson: _parseString) String? userName,
    @JsonKey(name: 'userThumb', fromJson: _parseString) String? userThumb,
    @JsonKey(name: 'userThumbUrl', fromJson: _parseString) String? userThumbUrl,
    @JsonKey(name: 'userThumbPath', fromJson: _parseString) String? userThumbPath,
    @JsonKey(name: 'avatarUrl', fromJson: _parseString) String? avatarUrl,
    @JsonKey(name: 'userId', fromJson: _parseString) String? userId,
    @JsonKey(name: 'serverUserId', fromJson: _parseString) String? serverUserId,
  }) = _TracearrSession;

  String get displayUser {
    if (user != null) {
      final String? name = (user!['username'] ??
              user!['userName'] ??
              user!['name'] ??
              user!['title'])
          ?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    final String? name = username ?? userName;
    if (name != null && name.isNotEmpty) return name;
    return playerName;
  }

  String? get displayUserThumb {
    if (user != null) {
      final String? thumb = (user!['thumbUrl'] ??
              user!['thumbPath'] ??
              user!['thumb'] ??
              user!['avatarUrl'] ??
              user!['avatar'])
          ?.toString();
      if (thumb != null && thumb.isNotEmpty) return thumb;
    }
    return userThumb ?? userThumbUrl ?? userThumbPath ?? avatarUrl;
  }

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
