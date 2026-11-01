/// Data models for slskd Search.
library;

import '../slskd_format.dart';

class SlskdSearchRequest {
  const SlskdSearchRequest({
    required this.searchText,
    this.id,
    this.fileLimit,
    this.filterResponses,
    this.maximumPeerQueueLength,
    this.minimumPeerUploadSpeed,
    this.minimumResponseFileCount,
    this.responseLimit,
    this.searchTimeout,
  });

  final String searchText;
  final String? id;
  final int? fileLimit;
  final bool? filterResponses;
  final int? maximumPeerQueueLength;
  final int? minimumPeerUploadSpeed;
  final int? minimumResponseFileCount;
  final int? responseLimit;
  final int? searchTimeout;

  Map<String, dynamic> toJson() => {
        'searchText': searchText,
        if (id != null) 'id': id,
        if (fileLimit != null) 'fileLimit': fileLimit,
        if (filterResponses != null) 'filterResponses': filterResponses,
        if (maximumPeerQueueLength != null)
          'maximumPeerQueueLength': maximumPeerQueueLength,
        if (minimumPeerUploadSpeed != null)
          'minimumPeerUploadSpeed': minimumPeerUploadSpeed,
        if (minimumResponseFileCount != null)
          'minimumResponseFileCount': minimumResponseFileCount,
        if (responseLimit != null) 'responseLimit': responseLimit,
        if (searchTimeout != null) 'searchTimeout': searchTimeout,
      };
}

class SlskdSearch {
  const SlskdSearch({
    required this.id,
    required this.searchText,
    required this.state,
    this.isComplete = false,
    this.fileCount = 0,
    this.lockedFileCount = 0,
    this.responseCount = 0,
    required this.startedAt,
    this.endedAt,
    this.token = 0,
    this.responses = const [],
  });

  factory SlskdSearch.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    final stateStr = (json['state'] ?? json['State'] ?? '').toString();
    final bool? rawComplete = (json['isComplete'] ?? json['IsComplete']) as bool?;
    final bool complete = rawComplete ??
        (stateStr.toLowerCase().contains('complete') ||
            stateStr.toLowerCase().contains('succeed') ||
            stateStr.toLowerCase().contains('timedout') ||
            stateStr.toLowerCase().contains('error') ||
            stateStr.toLowerCase().contains('fail') ||
            stateStr.toLowerCase().contains('cancel'));

    final resRaw = json['responses'] ?? json['Responses'];
    final List<SlskdSearchResponse> resList = [];
    if (resRaw is Iterable) {
      for (final item in resRaw) {
        if (item is Map<String, dynamic>) {
          resList.add(SlskdSearchResponse.fromJson(item));
        } else if (item is Map) {
          resList.add(SlskdSearchResponse.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return SlskdSearch(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      searchText: (json['searchText'] ?? json['SearchText'] ?? '').toString(),
      state: stateStr,
      isComplete: complete,
      fileCount: ((json['fileCount'] ?? json['FileCount'] ?? 0) as num).toInt(),
      lockedFileCount: ((json['lockedFileCount'] ?? json['LockedFileCount'] ?? 0) as num).toInt(),
      responseCount: ((json['responseCount'] ?? json['ResponseCount'] ?? 0) as num).toInt(),
      startedAt: parseDate(json['startedAt'] ?? json['StartedAt']) ?? DateTime.now(),
      endedAt: parseDate(json['endedAt'] ?? json['EndedAt']),
      token: ((json['token'] ?? json['Token'] ?? 0) as num).toInt(),
      responses: resList,
    );
  }

  final String id;
  final String searchText;
  final String state;
  final bool isComplete;
  final int fileCount;
  final int lockedFileCount;
  final int responseCount;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int token;
  final List<SlskdSearchResponse> responses;

  /// slskd could not run the search, most often because it is not logged in
  /// to Soulseek. Such a search is also complete, with no responses.
  bool get isErrored =>
      state.toLowerCase().contains('error') || state.toLowerCase().contains('fail');

  Map<String, dynamic> toJson() => {
        'id': id,
        'searchText': searchText,
        'state': state,
        'isComplete': isComplete,
        'fileCount': fileCount,
        'lockedFileCount': lockedFileCount,
        'responseCount': responseCount,
        'startedAt': startedAt.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        'token': token,
        'responses': responses.map((r) => r.toJson()).toList(),
      };
}

class SlskdSearchResponse {
  const SlskdSearchResponse({
    required this.username,
    required this.fileCount,
    required this.lockedFileCount,
    required this.hasFreeUploadSlot,
    required this.queueLength,
    required this.uploadSpeed,
    required this.token,
    this.files = const [],
    this.lockedFiles = const [],
  });

  factory SlskdSearchResponse.fromJson(Map<String, dynamic> json) {
    List<SlskdSearchFile> parseFiles(dynamic raw, {bool defaultLocked = false}) {
      final List<SlskdSearchFile> list = [];
      if (raw is Iterable) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            list.add(SlskdSearchFile.fromJson(item, defaultLocked: defaultLocked));
          } else if (item is Map) {
            list.add(SlskdSearchFile.fromJson(item.cast<String, dynamic>(), defaultLocked: defaultLocked));
          }
        }
      }
      return list;
    }

    return SlskdSearchResponse(
      username: (json['username'] ?? json['Username'] ?? '').toString(),
      fileCount: ((json['fileCount'] ?? json['FileCount'] ?? 0) as num).toInt(),
      lockedFileCount: ((json['lockedFileCount'] ?? json['LockedFileCount'] ?? 0) as num).toInt(),
      hasFreeUploadSlot: (json['hasFreeUploadSlot'] ?? json['HasFreeUploadSlot'] ?? false) as bool? ?? false,
      queueLength: ((json['queueLength'] ?? json['QueueLength'] ?? 0) as num).toInt(),
      uploadSpeed: ((json['uploadSpeed'] ?? json['UploadSpeed'] ?? 0) as num).toInt(),
      token: ((json['token'] ?? json['Token'] ?? 0) as num).toInt(),
      files: parseFiles(json['files'] ?? json['Files']),
      lockedFiles: parseFiles(json['lockedFiles'] ?? json['LockedFiles'], defaultLocked: true),
    );
  }

  final String username;
  final int fileCount;
  final int lockedFileCount;
  final bool hasFreeUploadSlot;
  final int queueLength;
  final int uploadSpeed;
  final int token;
  final List<SlskdSearchFile> files;
  final List<SlskdSearchFile> lockedFiles;

  Map<String, dynamic> toJson() => {
        'username': username,
        'fileCount': fileCount,
        'lockedFileCount': lockedFileCount,
        'hasFreeUploadSlot': hasFreeUploadSlot,
        'queueLength': queueLength,
        'uploadSpeed': uploadSpeed,
        'token': token,
        'files': files.map((f) => f.toJson()).toList(),
        'lockedFiles': lockedFiles.map((f) => f.toJson()).toList(),
      };
}

class SlskdSearchFile {
  const SlskdSearchFile({
    required this.filename,
    required this.size,
    required this.extension,
    this.bitDepth,
    this.bitRate,
    this.code = 0,
    this.isVariableBitRate,
    this.length,
    this.sampleRate,
    this.isLocked = false,
  });

  factory SlskdSearchFile.fromJson(Map<String, dynamic> json, {bool defaultLocked = false}) {
    int? parseOptionalInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return SlskdSearchFile(
      filename: (json['filename'] ?? json['Filename'] ?? '').toString(),
      size: ((json['size'] ?? json['Size'] ?? 0) as num).toInt(),
      extension: (json['extension'] ?? json['Extension'] ?? '').toString(),
      bitDepth: parseOptionalInt(json['bitDepth'] ?? json['BitDepth']),
      bitRate: parseOptionalInt(json['bitRate'] ?? json['BitRate']),
      code: ((json['code'] ?? json['Code'] ?? 0) as num).toInt(),
      isVariableBitRate: (json['isVariableBitRate'] ?? json['IsVariableBitRate']) as bool?,
      length: parseOptionalInt(json['length'] ?? json['Length']),
      sampleRate: parseOptionalInt(json['sampleRate'] ?? json['SampleRate']),
      isLocked: (json['isLocked'] ?? json['IsLocked']) as bool? ?? defaultLocked,
    );
  }

  final String filename;
  final int size;
  final String extension;
  final int? bitDepth;
  final int? bitRate;
  final int code;
  final bool? isVariableBitRate;
  final int? length;
  final int? sampleRate;
  final bool isLocked;

  String get trackTitle {
    final normalized = filename.replaceAll('\\', '/');
    final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : filename;
  }

  String get albumDirectory {
    final sep = filename.contains('\\') ? '\\' : '/';
    final normalized = filename.replaceAll('\\', '/');
    final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length > 1) {
      return parts.sublist(0, parts.length - 1).join(sep);
    }
    return '';
  }

  String get formattedDuration {
    if (length == null || length! <= 0) return '';
    final minutes = length! ~/ 60;
    final seconds = length! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize => slskdFormatBytes(size);

  String get qualityBadge {
    final ext = extension.toUpperCase();
    if (ext == 'FLAC') {
      if (bitDepth != null && bitDepth! > 16) {
        return 'FLAC $bitDepth-bit';
      }
      return 'FLAC';
    }
    if (bitRate != null && bitRate! > 0) {
      final vbr = isVariableBitRate == true ? ' VBR' : '';
      return '$ext ${bitRate}k$vbr';
    }
    return ext.isNotEmpty ? ext : 'AUDIO';
  }

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'size': size,
        'extension': extension,
        if (bitDepth != null) 'bitDepth': bitDepth,
        if (bitRate != null) 'bitRate': bitRate,
        'code': code,
        if (isVariableBitRate != null) 'isVariableBitRate': isVariableBitRate,
        if (length != null) 'length': length,
        if (sampleRate != null) 'sampleRate': sampleRate,
        'isLocked': isLocked,
      };
}
