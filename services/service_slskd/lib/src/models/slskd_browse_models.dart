/// Data models for slskd Browse and User Library exploration.
library;

import 'dart:convert';

import 'slskd_search_models.dart';

class SlskdDirectory {
  const SlskdDirectory({
    required this.name,
    this.files = const [],
    this.isLocked = false,
  });

  factory SlskdDirectory.fromJson(Map<String, dynamic> json) {
    final bool locked = (json['isLocked'] ?? json['IsLocked'] ?? json['locked'] ?? json['Locked'] ?? false) as bool? ?? false;
    final filesRaw = json['files'] ?? json['Files'];
    final List<SlskdSearchFile> filesList = [];
    if (filesRaw is Iterable) {
      for (final item in filesRaw) {
        if (item is Map<String, dynamic>) {
          filesList.add(SlskdSearchFile.fromJson(item, defaultLocked: locked));
        } else if (item is Map) {
          filesList.add(SlskdSearchFile.fromJson(item.cast<String, dynamic>(), defaultLocked: locked));
        }
      }
    }

    return SlskdDirectory(
      name: (json['name'] ?? json['Name'] ?? json['directory'] ?? json['Directory'] ?? '').toString(),
      files: filesList,
      isLocked: locked,
    );
  }

  final String name;
  final List<SlskdSearchFile> files;
  final bool isLocked;

  String get directoryBaseName {
    final normalized = name.replaceAll('\\', '/');
    final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : name;
  }

  int get totalSize => files.fold<int>(0, (sum, f) => sum + f.size);

  Map<String, dynamic> toJson() => {
        'name': name,
        'files': files.map((f) => f.toJson()).toList(),
        'isLocked': isLocked,
      };
}

class SlskdUserInfo {
  const SlskdUserInfo({
    required this.description,
    this.hasFreeUploadSlot = false,
    this.hasPicture = false,
    this.picture,
    this.queueLength = 0,
    this.uploadSlots = 0,
  });

  factory SlskdUserInfo.fromJson(Map<String, dynamic> json) {
    List<int>? pic;
    final picRaw = json['picture'] ?? json['Picture'];
    if (picRaw is String && picRaw.isNotEmpty) {
      try {
        pic = base64Decode(picRaw);
      } catch (_) {}
    } else if (picRaw is List) {
      pic = picRaw.map((e) => (e as num).toInt()).toList();
    }

    return SlskdUserInfo(
      description: (json['description'] ?? json['Description'] ?? '').toString(),
      hasFreeUploadSlot: (json['hasFreeUploadSlot'] ?? json['HasFreeUploadSlot'] ?? false) as bool? ?? false,
      hasPicture: (json['hasPicture'] ?? json['HasPicture'] ?? false) as bool? ?? false,
      picture: pic,
      queueLength: ((json['queueLength'] ?? json['QueueLength'] ?? 0) as num).toInt(),
      uploadSlots: ((json['uploadSlots'] ?? json['UploadSlots'] ?? 0) as num).toInt(),
    );
  }

  final String description;
  final bool hasFreeUploadSlot;
  final bool hasPicture;
  final List<int>? picture;
  final int queueLength;
  final int uploadSlots;

  Map<String, dynamic> toJson() => {
        'description': description,
        'hasFreeUploadSlot': hasFreeUploadSlot,
        'hasPicture': hasPicture,
        if (picture != null) 'picture': picture,
        'queueLength': queueLength,
        'uploadSlots': uploadSlots,
      };
}

class SlskdUserPresence {
  const SlskdUserPresence({
    required this.username,
    this.status = 0,
    this.averageSpeed = 0,
    this.countryCode,
    this.directoryCount = 0,
    this.fileCount = 0,
    this.uploadCount = 0,
    this.slotsFree,
    this.self,
  });

  factory SlskdUserPresence.fromJson(Map<String, dynamic> json) {
    int parseStatus(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      final s = v.toString().toLowerCase();
      if (s.contains('online') || s == '2') return 2;
      if (s.contains('away') || s == '1') return 1;
      return 0;
    }

    return SlskdUserPresence(
      username: (json['username'] ?? json['Username'] ?? '').toString(),
      status: parseStatus(json['status'] ?? json['Status']),
      averageSpeed: ((json['averageSpeed'] ?? json['AverageSpeed'] ?? 0) as num).toInt(),
      countryCode: (json['countryCode'] ?? json['CountryCode'])?.toString(),
      directoryCount: ((json['directoryCount'] ?? json['DirectoryCount'] ?? 0) as num).toInt(),
      fileCount: ((json['fileCount'] ?? json['FileCount'] ?? 0) as num).toInt(),
      uploadCount: ((json['uploadCount'] ?? json['UploadCount'] ?? 0) as num).toInt(),
      slotsFree: (json['slotsFree'] ?? json['SlotsFree']) != null
          ? ((json['slotsFree'] ?? json['SlotsFree']) as num).toInt()
          : null,
      self: (json['self'] ?? json['Self']) as bool?,
    );
  }

  final String username;

  /// 0 = offline, 1 = away, 2 = online
  final int status;
  final int averageSpeed;
  final String? countryCode;
  final int directoryCount;
  final int fileCount;
  final int uploadCount;
  final int? slotsFree;
  final bool? self;

  bool get isOnline => status == 2;
  bool get isAway => status == 1;
  bool get isOffline => !isOnline && !isAway;

  String get statusLabel {
    switch (status) {
      case 2:
        return 'Online';
      case 1:
        return 'Away';
      default:
        return 'Offline';
    }
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'status': status,
        'averageSpeed': averageSpeed,
        if (countryCode != null) 'countryCode': countryCode,
        'directoryCount': directoryCount,
        'fileCount': fileCount,
        'uploadCount': uploadCount,
        if (slotsFree != null) 'slotsFree': slotsFree,
        if (self != null) 'self': self,
      };
}

class SlskdUserStatus {
  const SlskdUserStatus({
    this.isPrivileged = false,
    this.presence = 'Offline',
  });

  factory SlskdUserStatus.fromJson(Map<String, dynamic> json) {
    return SlskdUserStatus(
      isPrivileged: (json['isPrivileged'] ?? json['IsPrivileged'] ?? false) as bool? ?? false,
      presence: (json['presence'] ?? json['Presence'] ?? 'Offline').toString(),
    );
  }

  final bool isPrivileged;
  final String presence;

  bool get isOnline => presence.toLowerCase().contains('online');
  bool get isAway => presence.toLowerCase().contains('away');
  bool get isOffline => !isOnline && !isAway;

  Map<String, dynamic> toJson() => {
        'isPrivileged': isPrivileged,
        'presence': presence,
      };
}

class SlskdDirectoryContentsRequest {
  const SlskdDirectoryContentsRequest({
    required this.directory,
  });

  final String directory;

  Map<String, dynamic> toJson() => {
        'directory': directory,
      };
}

/// Remote peer network endpoint information from GET /api/v0/users/{username}/endpoint.
class SlskdUserEndpoint {
  const SlskdUserEndpoint({
    required this.address,
    required this.port,
  });

  final String address;
  final int port;

  factory SlskdUserEndpoint.fromJson(dynamic json) {
    if (json == null) return const SlskdUserEndpoint(address: '', port: 0);
    if (json is String) {
      final lastColon = json.lastIndexOf(':');
      if (lastColon != -1) {
        return SlskdUserEndpoint(
          address: json.substring(0, lastColon),
          port: int.tryParse(json.substring(lastColon + 1)) ?? 0,
        );
      }
      return SlskdUserEndpoint(address: json, port: 0);
    }
    if (json is Map) {
      final addr = json['address'] ?? json['Address'];
      final String addressStr = addr is Map
          ? (addr['ip'] ?? addr['address'] ?? addr['ipAddress'] ?? addr['value'] ?? '').toString()
          : (addr ?? '').toString();
      final int port = json['port'] is num
          ? (json['port'] as num).toInt()
          : int.tryParse(json['port']?.toString() ?? '') ??
              (json['Port'] is num
                  ? (json['Port'] as num).toInt()
                  : int.tryParse(json['Port']?.toString() ?? '') ?? 0);
      return SlskdUserEndpoint(address: addressStr, port: port);
    }
    return const SlskdUserEndpoint(address: '', port: 0);
  }

  String get formatted => port > 0 ? '$address:$port' : address;

  Map<String, dynamic> toJson() => {
        'address': address,
        'port': port,
      };
}
