/// Data models for slskd Transfers (Downloads and Uploads).
library;

enum TransferDirection {
  download,
  upload;

  static TransferDirection fromJson(dynamic value) {
    final str = value?.toString().toLowerCase() ?? '';
    if (str.contains('upload') || str == '1') {
      return TransferDirection.upload;
    }
    return TransferDirection.download;
  }

  String toJson() => name;
}

enum TransferCategory {
  inProgress,
  queued,
  completed,
  failed;

  static TransferCategory fromStateString(String state) {
    final s = state.toLowerCase();
    if (s.contains('cancel') ||
        s.contains('timedout') ||
        s.contains('timed out') ||
        s.contains('error') ||
        s.contains('reject') ||
        s.contains('abort') ||
        s.contains('failed') ||
        s.contains('fail')) {
      return TransferCategory.failed;
    }
    if (s.contains('succeeded') || s.contains('completed')) {
      return TransferCategory.completed;
    }
    if (s.contains('initializing') ||
        s.contains('inprogress') ||
        s.contains('in progress') ||
        s.contains('transferring') ||
        s.contains('running')) {
      return TransferCategory.inProgress;
    }
    return TransferCategory.queued;
  }
}

/// A peer transfer group paired with its transfer direction (Download or Upload)
/// for unified transfer activity views.
class SlskdPeerTransferGroup {
  const SlskdPeerTransferGroup({
    required this.direction,
    required this.user,
  });

  final TransferDirection direction;
  final SlskdUserTransfers user;
}

class SlskdUserTransfers {
  const SlskdUserTransfers({
    required this.username,
    required this.directories,
  });

  factory SlskdUserTransfers.fromJson(Map<String, dynamic> json) {
    final dirsRaw = json['directories'] ?? json['Directories'];
    final List<SlskdDirectoryTransfers> dirs = [];
    if (dirsRaw is Iterable) {
      for (final item in dirsRaw) {
        if (item is Map<String, dynamic>) {
          dirs.add(SlskdDirectoryTransfers.fromJson(item));
        } else if (item is Map) {
          dirs.add(SlskdDirectoryTransfers.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return SlskdUserTransfers(
      username: (json['username'] ?? json['Username'] ?? '').toString(),
      directories: dirs,
    );
  }

  final String username;
  final List<SlskdDirectoryTransfers> directories;

  int get totalFileCount => directories.fold<int>(0, (sum, d) => sum + d.files.length);
  int get totalFiles => totalFileCount;

  Map<String, dynamic> toJson() => {
        'username': username,
        'directories': directories.map((d) => d.toJson()).toList(),
      };

  int get totalBytes =>
      directories.fold<int>(0, (sum, dir) => sum + dir.totalBytes);

  int get transferredBytes =>
      directories.fold<int>(0, (sum, dir) => sum + dir.transferredBytes);

  double get averageSpeed =>
      directories.fold<double>(0.0, (sum, dir) => sum + dir.averageSpeed);

  /// Combined speed of the transfers running right now; see
  /// [SlskdTransfer.liveSpeed].
  double get liveSpeed => directories.fold<double>(
        0.0,
        (sum, dir) => sum + dir.files.fold<double>(0.0, (s, f) => s + f.liveSpeed),
      );
}

class SlskdDirectoryTransfers {
  const SlskdDirectoryTransfers({
    required this.directory,
    required this.fileCount,
    required this.files,
  });

  factory SlskdDirectoryTransfers.fromJson(Map<String, dynamic> json) {
    final filesRaw = json['files'] ?? json['Files'];
    final List<SlskdTransfer> filesList = [];
    if (filesRaw is Iterable) {
      for (final item in filesRaw) {
        if (item is Map<String, dynamic>) {
          filesList.add(SlskdTransfer.fromJson(item));
        } else if (item is Map) {
          filesList.add(SlskdTransfer.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return SlskdDirectoryTransfers(
      directory: (json['directory'] ?? json['Directory'] ?? '').toString(),
      fileCount: ((json['fileCount'] ?? json['FileCount'] ?? filesList.length) as num).toInt(),
      files: filesList,
    );
  }

  final String directory;
  final int fileCount;
  final List<SlskdTransfer> files;

  Map<String, dynamic> toJson() => {
        'directory': directory,
        'fileCount': fileCount,
        'files': files.map((f) => f.toJson()).toList(),
      };

  int get totalBytes => files.fold<int>(0, (sum, f) => sum + f.size);

  int get transferredBytes =>
      files.fold<int>(0, (sum, f) => sum + f.bytesTransferred);

  double get averageSpeed =>
      files.fold<double>(0.0, (sum, f) => sum + f.averageSpeed);
}

class SlskdTransfer {
  const SlskdTransfer({
    required this.id,
    this.batchId,
    required this.username,
    required this.direction,
    required this.filename,
    required this.size,
    required this.state,
    required this.requestedAt,
    this.enqueuedAt,
    this.startedAt,
    this.endedAt,
    this.nextAttemptAt,
    this.bytesTransferred = 0,
    this.averageSpeed = 0.0,
    this.placeInQueue,
    this.exception,
    this.attempts = 0,
    this.removed = false,
  });

  factory SlskdTransfer.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    final stateStr = (json['state'] ?? json['State'] ?? '').toString();

    return SlskdTransfer(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      batchId: (json['batchId'] ?? json['BatchId'])?.toString(),
      username: (json['username'] ?? json['Username'] ?? '').toString(),
      direction: TransferDirection.fromJson(json['direction'] ?? json['Direction']),
      filename: (json['filename'] ?? json['Filename'] ?? '').toString(),
      size: ((json['size'] ?? json['Size'] ?? 0) as num).toInt(),
      state: stateStr,
      requestedAt: parseDate(json['requestedAt'] ?? json['RequestedAt']) ?? DateTime.now(),
      enqueuedAt: parseDate(json['enqueuedAt'] ?? json['EnqueuedAt']),
      startedAt: parseDate(json['startedAt'] ?? json['StartedAt']),
      endedAt: parseDate(json['endedAt'] ?? json['EndedAt']),
      nextAttemptAt: parseDate(json['nextAttemptAt'] ?? json['NextAttemptAt']),
      bytesTransferred: ((json['bytesTransferred'] ?? json['BytesTransferred'] ?? 0) as num).toInt(),
      averageSpeed: ((json['averageSpeed'] ?? json['AverageSpeed'] ?? 0.0) as num).toDouble(),
      placeInQueue: (json['placeInQueue'] ?? json['PlaceInQueue']) != null
          ? ((json['placeInQueue'] ?? json['PlaceInQueue']) as num).toInt()
          : null,
      exception: (json['exception'] ?? json['Exception'])?.toString(),
      attempts: ((json['attempts'] ?? json['Attempts'] ?? 0) as num).toInt(),
      removed: (json['removed'] ?? json['Removed'] ?? false) as bool? ?? false,
    );
  }

  final String id;
  final String? batchId;
  final String username;
  final TransferDirection direction;
  final String filename;
  final int size;
  final String state;
  final DateTime requestedAt;
  final DateTime? enqueuedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? nextAttemptAt;
  final int bytesTransferred;
  final double averageSpeed;
  final int? placeInQueue;
  final String? exception;
  final int attempts;
  final bool removed;

  TransferCategory get category => TransferCategory.fromStateString(state);

  int get bytesRemaining => size > bytesTransferred ? size - bytesTransferred : 0;

  double get progress {
    if (size <= 0) return 0.0;
    final p = bytesTransferred / size;
    if (p < 0.0) return 0.0;
    if (p > 1.0) return 1.0;
    return p;
  }

  double get percentComplete => progress * 100.0;
  double get percentage => percentComplete;
  double get speed => averageSpeed;
  double get averageRate => averageSpeed;
  bool get isSuccessful => category == TransferCategory.completed;
  bool get isFailed => category == TransferCategory.failed;

  Duration? get elapsedTime =>
      startedAt == null ? null : (endedAt ?? DateTime.now()).difference(startedAt!);

  /// The speed of a transfer that is running, else 0. slskd keeps the final
  /// average on finished and failed transfers, which says nothing about now.
  double get liveSpeed => category == TransferCategory.inProgress &&
          averageSpeed.isFinite &&
          averageSpeed > 0
      ? averageSpeed
      : 0.0;

  Duration? get remainingTime {
    if (!averageSpeed.isFinite || averageSpeed <= 0 || bytesRemaining <= 0) return null;
    final int secs = (bytesRemaining / averageSpeed).round().clamp(0, 2592000);
    return Duration(seconds: secs);
  }

  String get fileBaseName {
    final normalized = filename.replaceAll('\\', '/');
    final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : filename;
  }

  bool get isTerminal =>
      category == TransferCategory.completed || category == TransferCategory.failed;

  bool get canCancel => !isTerminal;

  bool get canRetry =>
      category == TransferCategory.failed && direction == TransferDirection.download;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (batchId != null) 'batchId': batchId,
        'username': username,
        'direction': direction.toJson(),
        'filename': filename,
        'size': size,
        'state': state,
        'requestedAt': requestedAt.toIso8601String(),
        if (enqueuedAt != null) 'enqueuedAt': enqueuedAt!.toIso8601String(),
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        if (nextAttemptAt != null) 'nextAttemptAt': nextAttemptAt!.toIso8601String(),
        'bytesTransferred': bytesTransferred,
        'averageSpeed': averageSpeed,
        if (placeInQueue != null) 'placeInQueue': placeInQueue,
        if (exception != null) 'exception': exception,
        'attempts': attempts,
        'removed': removed,
      };
}

class EnqueueDownloadBatchItem {
  const EnqueueDownloadBatchItem({
    required this.filename,
    required this.size,
  });

  final String filename;
  final int size;

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'size': size,
      };
}

class EnqueueDownloadBatchOptions {
  const EnqueueDownloadBatchOptions({
    this.destination,
    this.externalId,
  });

  final String? destination;
  final String? externalId;

  Map<String, dynamic> toJson() => {
        if (destination != null) 'destination': destination,
        if (externalId != null) 'externalId': externalId,
      };
}

class EnqueueDownloadBatchRequest {
  const EnqueueDownloadBatchRequest({
    required this.username,
    required this.files,
    this.searchId,
    this.id,
    this.options = const EnqueueDownloadBatchOptions(),
  });

  final String username;
  final List<EnqueueDownloadBatchItem> files;
  final String? searchId;
  final String? id;
  final EnqueueDownloadBatchOptions options;

  Map<String, dynamic> toJson() => {
        'username': username,
        'files': files.map((f) => f.toJson()).toList(),
        if (searchId != null) 'searchId': searchId,
        if (id != null) 'id': id,
        'options': options.toJson(),
      };
}

class QueueDownloadRequest {
  const QueueDownloadRequest({
    required this.filename,
    required this.size,
  });

  final String filename;
  final int size;

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'size': size,
      };
}

class SlskdBatch {
  const SlskdBatch({
    required this.id,
    this.searchId,
    required this.username,
    required this.direction,
    required this.createdAt,
    this.transfers = const [],
    this.options = const EnqueueDownloadBatchOptions(),
  });

  factory SlskdBatch.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    final xfersRaw = json['transfers'] ?? json['Transfers'];
    final List<SlskdTransfer> xfers = [];
    if (xfersRaw is Iterable) {
      for (final item in xfersRaw) {
        if (item is Map<String, dynamic>) {
          xfers.add(SlskdTransfer.fromJson(item));
        }
      }
    }

    final optsRaw = json['options'] ?? json['Options'];
    final opts = optsRaw is Map<String, dynamic>
        ? EnqueueDownloadBatchOptions(
            destination: (optsRaw['destination'] ?? optsRaw['Destination'])?.toString(),
            externalId: (optsRaw['externalId'] ?? optsRaw['ExternalId'])?.toString(),
          )
        : const EnqueueDownloadBatchOptions();

    return SlskdBatch(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      searchId: (json['searchId'] ?? json['SearchId'])?.toString(),
      username: (json['username'] ?? json['Username'] ?? '').toString(),
      direction: TransferDirection.fromJson(json['direction'] ?? json['Direction']),
      createdAt: parseDate(json['createdAt'] ?? json['CreatedAt']) ?? DateTime.now(),
      transfers: xfers,
      options: opts,
    );
  }

  final String id;
  final String? searchId;
  final String username;
  final TransferDirection direction;
  final DateTime createdAt;
  final List<SlskdTransfer> transfers;
  final EnqueueDownloadBatchOptions options;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (searchId != null) 'searchId': searchId,
        'username': username,
        'direction': direction.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'transfers': transfers.map((t) => t.toJson()).toList(),
        'options': options.toJson(),
      };
}

class EnqueueDownloadBatchResponseFailure {
  const EnqueueDownloadBatchResponseFailure({
    required this.filename,
    this.message,
  });

  factory EnqueueDownloadBatchResponseFailure.fromJson(Map<String, dynamic> json) {
    return EnqueueDownloadBatchResponseFailure(
      filename: (json['filename'] ?? json['Filename'] ?? '').toString(),
      message: (json['message'] ?? json['Message'])?.toString(),
    );
  }

  final String filename;
  final String? message;

  Map<String, dynamic> toJson() => {
        'filename': filename,
        if (message != null) 'message': message,
      };
}

class EnqueueDownloadBatchResponse {
  const EnqueueDownloadBatchResponse({
    this.batch,
    this.failures = const [],
  });

  factory EnqueueDownloadBatchResponse.fromJson(Map<String, dynamic> json) {
    final batchRaw = json['batch'] ?? json['Batch'];
    final batch = batchRaw is Map<String, dynamic> ? SlskdBatch.fromJson(batchRaw) : null;

    final failsRaw = json['failures'] ?? json['Failures'];
    final List<EnqueueDownloadBatchResponseFailure> fails = [];
    if (failsRaw is Iterable) {
      for (final item in failsRaw) {
        if (item is Map<String, dynamic>) {
          fails.add(EnqueueDownloadBatchResponseFailure.fromJson(item));
        }
      }
    }

    return EnqueueDownloadBatchResponse(
      batch: batch,
      failures: fails,
    );
  }

  final SlskdBatch? batch;
  final List<EnqueueDownloadBatchResponseFailure> failures;

  Map<String, dynamic> toJson() => {
        if (batch != null) 'batch': batch!.toJson(),
        'failures': failures.map((f) => f.toJson()).toList(),
      };
}
