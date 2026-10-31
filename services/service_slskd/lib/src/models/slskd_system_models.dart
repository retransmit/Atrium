/// Data models for slskd System, Server, Shares, and Logs.
library;

class SlskdConnectionWatchdogState {
  const SlskdConnectionWatchdogState({
    this.isEnabled = false,
    this.isAttemptingConnection = false,
    this.isAwaitingVpn = false,
    this.nextAttemptAt,
  });

  factory SlskdConnectionWatchdogState.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    return SlskdConnectionWatchdogState(
      isEnabled: (json['isEnabled'] ?? json['IsEnabled'] ?? false) as bool? ?? false,
      isAttemptingConnection: (json['isAttemptingConnection'] ?? json['IsAttemptingConnection'] ?? false) as bool? ?? false,
      isAwaitingVpn: (json['isAwaitingVpn'] ?? json['IsAwaitingVpn'] ?? false) as bool? ?? false,
      nextAttemptAt: parseDate(json['nextAttemptAt'] ?? json['NextAttemptAt']),
    );
  }

  final bool isEnabled;
  final bool isAttemptingConnection;
  final bool isAwaitingVpn;
  final DateTime? nextAttemptAt;

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'isAttemptingConnection': isAttemptingConnection,
        'isAwaitingVpn': isAwaitingVpn,
        if (nextAttemptAt != null) 'nextAttemptAt': nextAttemptAt!.toIso8601String(),
      };
}

class SlskdApplicationState {
  const SlskdApplicationState({
    required this.version,
    required this.server,
    required this.user,
    required this.shares,
    this.vpn,
    this.pendingReconnect = false,
    this.pendingRestart = false,
    this.connectionWatchdog,
    this.rooms = const [],
  });

  factory SlskdApplicationState.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> asStringMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
      return const <String, dynamic>{};
    }

    final dogRaw = json['connectionWatchdog'] ?? json['ConnectionWatchdog'];
    final vpnRaw = json['vpn'] ?? json['Vpn'];

    return SlskdApplicationState(
      version: SlskdVersionState.fromJson(
        asStringMap(json['version'] ?? json['Version']),
      ),
      server: SlskdServerStatus.fromJson(
        asStringMap(json['server'] ?? json['Server']),
      ),
      user: SlskdUserState.fromJson(
        asStringMap(json['user'] ?? json['User']),
      ),
      shares: SlskdSharesState.fromJson(
        asStringMap(json['shares'] ?? json['Shares']),
      ),
      vpn: vpnRaw != null ? SlskdVpnState.fromJson(asStringMap(vpnRaw)) : null,
      pendingReconnect: (json['pendingReconnect'] ?? json['PendingReconnect'] ?? false) as bool? ?? false,
      pendingRestart: (json['pendingRestart'] ?? json['PendingRestart'] ?? false) as bool? ?? false,
      connectionWatchdog: dogRaw != null
          ? SlskdConnectionWatchdogState.fromJson(asStringMap(dogRaw))
          : null,
      rooms: ((json['rooms'] ?? json['Rooms']) is Iterable)
          ? ((json['rooms'] ?? json['Rooms']) as Iterable)
              .map((dynamic e) => e.toString())
              .toList()
          : const <String>[],
    );
  }

  final SlskdVersionState version;
  final SlskdServerStatus server;
  final SlskdUserState user;
  final SlskdSharesState shares;
  final SlskdVpnState? vpn;
  final bool pendingReconnect;
  final bool pendingRestart;
  final SlskdConnectionWatchdogState? connectionWatchdog;
  final List<String> rooms;

  Map<String, dynamic> toJson() => {
        'version': version.toJson(),
        'server': server.toJson(),
        'user': user.toJson(),
        'shares': shares.toJson(),
        if (vpn != null) 'vpn': vpn!.toJson(),
        'pendingReconnect': pendingReconnect,
        'pendingRestart': pendingRestart,
        if (connectionWatchdog != null) 'connectionWatchdog': connectionWatchdog!.toJson(),
        'rooms': rooms,
      };
}

class SlskdVersionState {
  const SlskdVersionState({
    required this.current,
    this.full,
    this.latest,
    this.isUpdateAvailable,
    this.isCanary = false,
    this.isDevelopment = false,
  });

  factory SlskdVersionState.fromJson(Map<String, dynamic> json) {
    return SlskdVersionState(
      current: (json['current'] ?? json['Current'] ?? '0.0.0').toString(),
      full: (json['full'] ?? json['Full'])?.toString(),
      latest: (json['latest'] ?? json['Latest'])?.toString(),
      isUpdateAvailable: (json['isUpdateAvailable'] ?? json['IsUpdateAvailable']) as bool?,
      isCanary: (json['isCanary'] ?? json['IsCanary'] ?? false) as bool? ?? false,
      isDevelopment: (json['isDevelopment'] ?? json['IsDevelopment'] ?? false) as bool? ?? false,
    );
  }

  final String current;
  final String? full;
  final String? latest;
  final bool? isUpdateAvailable;
  final bool isCanary;
  final bool isDevelopment;

  Map<String, dynamic> toJson() => {
        'current': current,
        if (full != null) 'full': full,
        if (latest != null) 'latest': latest,
        if (isUpdateAvailable != null) 'isUpdateAvailable': isUpdateAvailable,
        'isCanary': isCanary,
        'isDevelopment': isDevelopment,
      };
}

class SlskdServerStatus {
  const SlskdServerStatus({
    required this.address,
    required this.state,
    this.isConnected = false,
    this.isConnecting = false,
    this.isLoggedIn = false,
    this.isLoggingIn = false,
    this.isTransitioning = false,
  });

  factory SlskdServerStatus.fromJson(Map<String, dynamic> json) {
    final stateStr = (json['state'] ?? json['State'] ?? '').toString();
    final stateLower = stateStr.toLowerCase();

    final bool connected = (json['isConnected'] ?? json['IsConnected']) as bool? ??
        (!stateLower.contains('disconnected') &&
            (stateLower.contains('connected') || stateLower.contains('loggedin')));
    final bool loggedIn = (json['isLoggedIn'] ?? json['IsLoggedIn']) as bool? ??
        stateLower.contains('loggedin');
    final bool connecting = (json['isConnecting'] ?? json['IsConnecting']) as bool? ??
        (!stateLower.contains('disconnecting') && stateLower.contains('connecting'));
    final bool loggingIn = (json['isLoggingIn'] ?? json['IsLoggingIn']) as bool? ??
        stateLower.contains('loggingin');

    return SlskdServerStatus(
      address: (json['address'] ?? json['Address'] ?? 'vps.slsknet.org').toString(),
      state: stateStr,
      isConnected: connected,
      isLoggedIn: loggedIn,
      isConnecting: connecting,
      isLoggingIn: loggingIn,
      isTransitioning: (json['isTransitioning'] ?? json['IsTransitioning']) as bool? ??
          (connecting || loggingIn || stateLower.contains('disconnecting')),
    );
  }

  final String address;
  final String state;
  final bool isConnected;
  final bool isConnecting;
  final bool isLoggedIn;
  final bool isLoggingIn;
  final bool isTransitioning;

  bool get isDisconnecting => state.toLowerCase().contains('disconnecting');

  Map<String, dynamic> toJson() => {
        'address': address,
        'state': state,
        'isConnected': isConnected,
        'isConnecting': isConnecting,
        'isLoggedIn': isLoggedIn,
        'isLoggingIn': isLoggingIn,
        'isTransitioning': isTransitioning,
      };
}

class SlskdUserState {
  const SlskdUserState({
    required this.username,
    this.isPrivileged = false,
    this.privilegesRemaining = 0,
    this.averageSpeed = 0,
    this.directoryCount = 0,
    this.fileCount = 0,
    this.uploadCount = 0,
  });

  factory SlskdUserState.fromJson(Map<String, dynamic> json) {
    final privRaw = json['privileges'] ?? json['Privileges'];
    final priv = privRaw is Map<String, dynamic>
        ? privRaw
        : (privRaw is Map ? privRaw.cast<String, dynamic>() : const <String, dynamic>{});

    final statsRaw = json['statistics'] ?? json['Statistics'];
    final stats = statsRaw is Map<String, dynamic>
        ? statsRaw
        : (statsRaw is Map ? statsRaw.cast<String, dynamic>() : const <String, dynamic>{});

    return SlskdUserState(
      username: (json['username'] ?? json['Username'] ?? '').toString(),
      isPrivileged: (priv['isPrivileged'] ?? priv['IsPrivileged'] ?? false) as bool? ?? false,
      privilegesRemaining: ((priv['privilegesRemaining'] ?? priv['PrivilegesRemaining'] ?? 0) as num).toInt(),
      averageSpeed: ((stats['averageSpeed'] ?? stats['AverageSpeed'] ?? 0) as num).toInt(),
      directoryCount: ((stats['directoryCount'] ?? stats['DirectoryCount'] ?? 0) as num).toInt(),
      fileCount: ((stats['fileCount'] ?? stats['FileCount'] ?? 0) as num).toInt(),
      uploadCount: ((stats['uploadCount'] ?? stats['UploadCount'] ?? 0) as num).toInt(),
    );
  }

  final String username;
  final bool isPrivileged;
  final int privilegesRemaining;
  final int averageSpeed;
  final int directoryCount;
  final int fileCount;
  final int uploadCount;

  Map<String, dynamic> toJson() => {
        'username': username,
        'privileges': {
          'isPrivileged': isPrivileged,
          'privilegesRemaining': privilegesRemaining,
        },
        'statistics': {
          'averageSpeed': averageSpeed,
          'directoryCount': directoryCount,
          'fileCount': fileCount,
          'uploadCount': uploadCount,
        },
      };
}

class SlskdSharesState {
  const SlskdSharesState({
    this.scanPending = false,
    this.scanning = false,
    this.ready = true,
    this.faulted = false,
    this.cancelled = false,
    this.scanProgress = 0.0,
    this.directories = 0,
    this.files = 0,
  });

  factory SlskdSharesState.fromJson(Map<String, dynamic> json) {
    return SlskdSharesState(
      scanPending: (json['scanPending'] ?? json['ScanPending'] ?? false) as bool? ?? false,
      scanning: (json['scanning'] ?? json['Scanning'] ?? false) as bool? ?? false,
      ready: (json['ready'] ?? json['Ready'] ?? true) as bool? ?? true,
      faulted: (json['faulted'] ?? json['Faulted'] ?? false) as bool? ?? false,
      cancelled: (json['cancelled'] ?? json['Cancelled'] ?? false) as bool? ?? false,
      scanProgress: ((json['scanProgress'] ?? json['ScanProgress'] ?? 0.0) as num).toDouble(),
      directories: ((json['directories'] ?? json['Directories'] ?? 0) as num).toInt(),
      files: ((json['files'] ?? json['Files'] ?? 0) as num).toInt(),
    );
  }

  final bool scanPending;
  final bool scanning;
  final bool ready;
  final bool faulted;
  final bool cancelled;
  final double scanProgress;
  final int directories;
  final int files;

  Map<String, dynamic> toJson() => {
        'scanPending': scanPending,
        'scanning': scanning,
        'ready': ready,
        'faulted': faulted,
        'cancelled': cancelled,
        'scanProgress': scanProgress,
        'directories': directories,
        'files': files,
      };
}

class SlskdVpnState {
  const SlskdVpnState({
    this.isReady = false,
    this.isConnected = false,
    this.publicIpAddress,
    this.location,
    this.forwardedPort,
  });

  factory SlskdVpnState.fromJson(Map<String, dynamic> json) {
    return SlskdVpnState(
      isReady: (json['isReady'] ?? json['IsReady'] ?? false) as bool? ?? false,
      isConnected: (json['isConnected'] ?? json['IsConnected'] ?? false) as bool? ?? false,
      publicIpAddress: (json['publicIPAddress'] ?? json['PublicIPAddress'] ?? json['publicIpAddress'])?.toString(),
      location: (json['location'] ?? json['Location'])?.toString(),
      forwardedPort: (json['forwardedPort'] ?? json['ForwardedPort']) != null
          ? ((json['forwardedPort'] ?? json['ForwardedPort']) as num).toInt()
          : null,
    );
  }

  final bool isReady;
  final bool isConnected;
  final String? publicIpAddress;
  final String? location;
  final int? forwardedPort;

  Map<String, dynamic> toJson() => {
        'isReady': isReady,
        'isConnected': isConnected,
        if (publicIpAddress != null) 'publicIpAddress': publicIpAddress,
        if (location != null) 'location': location,
        if (forwardedPort != null) 'forwardedPort': forwardedPort,
      };
}

class SlskdLocalShare {
  const SlskdLocalShare({
    required this.id,
    required this.name,
    required this.path,
    this.isExcluded = false,
    this.remotePath,
    this.raw,
    this.directories,
    this.files,
  });

  factory SlskdLocalShare.fromJson(Map<String, dynamic> json) {
    return SlskdLocalShare(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      name: (json['alias'] ?? json['Alias'] ?? json['name'] ?? json['Name'] ?? '').toString(),
      path: (json['localPath'] ?? json['LocalPath'] ?? json['path'] ?? json['Path'] ?? '').toString(),
      isExcluded: (json['isExcluded'] ?? json['IsExcluded'] ?? false) as bool? ?? false,
      remotePath: (json['remotePath'] ?? json['RemotePath'])?.toString(),
      raw: (json['raw'] ?? json['Raw'])?.toString(),
      directories: (json['directories'] ?? json['Directories']) != null
          ? ((json['directories'] ?? json['Directories']) as num).toInt()
          : null,
      files: (json['files'] ?? json['Files']) != null
          ? ((json['files'] ?? json['Files']) as num).toInt()
          : null,
    );
  }

  final String id;
  final String name;
  final String path;
  final bool isExcluded;
  final String? remotePath;
  final String? raw;
  final int? directories;
  final int? files;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'isExcluded': isExcluded,
        if (remotePath != null) 'remotePath': remotePath,
        if (raw != null) 'raw': raw,
        if (directories != null) 'directories': directories,
        if (files != null) 'files': files,
      };
}

class SlskdLogRecord {
  const SlskdLogRecord({
    required this.timestamp,
    required this.level,
    this.context,
    this.subContext,
    required this.message,
  });

  factory SlskdLogRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    return SlskdLogRecord(
      timestamp: parseDate(json['timestamp'] ?? json['Timestamp']) ?? DateTime.now(),
      level: (json['level'] ?? json['Level'] ?? 'Information').toString(),
      context: (json['context'] ?? json['Context'])?.toString(),
      subContext: (json['subContext'] ?? json['SubContext'])?.toString(),
      message: (json['message'] ?? json['Message'] ?? '').toString(),
    );
  }

  final DateTime timestamp;
  final String level;
  final String? context;
  final String? subContext;
  final String message;

  bool get isError =>
      level.equalsIgnoreCase('error') || level.equalsIgnoreCase('fatal');
  bool get isWarning => level.equalsIgnoreCase('warning');
  bool get isDebug =>
      level.equalsIgnoreCase('debug') || level.equalsIgnoreCase('verbose');

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level,
        if (context != null) 'context': context,
        if (subContext != null) 'subContext': subContext,
        'message': message,
      };
}

extension on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}

/// Represents a file on the daemon host filesystem (from FilesController).
class SlskdDiskFile {
  const SlskdDiskFile({
    required this.name,
    required this.fullName,
    required this.length,
    this.createdAt,
    this.modifiedAt,
  });

  factory SlskdDiskFile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    return SlskdDiskFile(
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['FullName'] ?? '').toString(),
      length: ((json['length'] ?? json['Length'] ?? 0) as num).toInt(),
      createdAt: parseDate(json['createdAt'] ?? json['CreatedAt']),
      modifiedAt: parseDate(json['modifiedAt'] ?? json['ModifiedAt']),
    );
  }

  final String name;
  final String fullName;
  final int length;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  Map<String, dynamic> toJson() => {
        'name': name,
        'fullName': fullName,
        'length': length,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
      };
}

/// Represents a directory on the daemon host filesystem (from FilesController).
class SlskdDiskDirectory {
  const SlskdDiskDirectory({
    required this.name,
    required this.fullName,
    this.createdAt,
    this.modifiedAt,
    this.files = const <SlskdDiskFile>[],
    this.directories = const <SlskdDiskDirectory>[],
  });

  factory SlskdDiskDirectory.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    final rawFiles = json['files'] ?? json['Files'];
    final List<SlskdDiskFile> filesList = [];
    if (rawFiles is Iterable) {
      for (final item in rawFiles) {
        if (item is Map<String, dynamic>) {
          filesList.add(SlskdDiskFile.fromJson(item));
        } else if (item is Map) {
          filesList.add(SlskdDiskFile.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    final rawDirs = json['directories'] ?? json['Directories'];
    final List<SlskdDiskDirectory> dirsList = [];
    if (rawDirs is Iterable) {
      for (final item in rawDirs) {
        if (item is Map<String, dynamic>) {
          dirsList.add(SlskdDiskDirectory.fromJson(item));
        } else if (item is Map) {
          dirsList.add(SlskdDiskDirectory.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return SlskdDiskDirectory(
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['FullName'] ?? '').toString(),
      createdAt: parseDate(json['createdAt'] ?? json['CreatedAt']),
      modifiedAt: parseDate(json['modifiedAt'] ?? json['ModifiedAt']),
      files: filesList,
      directories: dirsList,
    );
  }

  final String name;
  final String fullName;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final List<SlskdDiskFile> files;
  final List<SlskdDiskDirectory> directories;

  Map<String, dynamic> toJson() => {
        'name': name,
        'fullName': fullName,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
        'files': files.map((f) => f.toJson()).toList(),
        'directories': directories.map((d) => d.toJson()).toList(),
      };
}
