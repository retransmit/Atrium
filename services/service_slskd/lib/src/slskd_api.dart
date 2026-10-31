import 'dart:convert';

import 'package:dio/dio.dart';

import 'models/slskd_models.dart';

/// Full-parity typed HTTP Client for the slskd REST API (v0).
class SlskdApi {
  // ---------------------------------------------------------------------------
  // JSON Parsing Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Iterable) return data.toList();
    return const <dynamic>[];
  }

  SlskdApi(this._dio);

  final Dio _dio;

  // ---------------------------------------------------------------------------
  // System, Server, Shares, and Logs
  // ---------------------------------------------------------------------------

  /// Fetches complete application state (version, server, user, shares, vpn).
  Future<SlskdApplicationState> getApplicationState() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/v0/application');
    return SlskdApplicationState.fromJson(_asMap(response.data));
  }

  /// Checks for updates against GitHub releases.
  Future<SlskdVersionState> checkVersion({bool forceCheck = false}) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/v0/application/version/latest',
      queryParameters: <String, dynamic>{'forceCheck': forceCheck},
    );
    return SlskdVersionState.fromJson(_asMap(response.data));
  }

  /// Initiates connection or reconnect to the Soulseek server.
  Future<void> reconnectServer() async {
    await _dio.put<void>('api/v0/server');
  }

  /// Disconnects from the Soulseek server.
  Future<void> disconnectServer({
    String message = 'Client disconnected from Atrium',
  }) async {
    await _dio.delete<void>(
      'api/v0/server',
      data: jsonEncode(message),
      options: Options(contentType: 'application/json'),
    );
  }

  /// Lists all local file shares grouped by host name.
  Future<Map<String, List<SlskdLocalShare>>> getShares() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/v0/shares');
    final Map<String, List<SlskdLocalShare>> result = {};
    if (response.data is Map) {
      final map = response.data as Map;
      for (final entry in map.entries) {
        final host = entry.key.toString();
        final List<SlskdLocalShare> shares = [];
        if (entry.value is Iterable) {
          for (final item in entry.value as Iterable) {
            if (item is Map<String, dynamic>) {
              shares.add(SlskdLocalShare.fromJson(item));
            } else if (item is Map) {
              shares.add(SlskdLocalShare.fromJson(item.cast<String, dynamic>()));
            }
          }
        }
        result[host] = shares;
      }
    }
    return result;
  }

  /// Initiates a scan of local shared folders.
  Future<void> scanShares() async {
    await _dio.put<void>('api/v0/shares');
  }

  /// Cancels an active share scan.
  Future<void> cancelShareScan() async {
    await _dio.delete<void>('api/v0/shares');
  }

  /// Returns a list of all shared directories and files across all configured shares.
  Future<List<SlskdDirectory>> getAllSharedContents() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/v0/shares/contents');
    return _parseDirectoryList(response.data);
  }

  /// Gets the contents of the share associated with [id].
  Future<List<SlskdDirectory>> getShareContents(String id) async {
    try {
      final encodedId = Uri.encodeComponent(id);
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/shares/$encodedId/contents');
      return _parseDirectoryList(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const <SlskdDirectory>[];
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Host Filesystem (Downloads & Incomplete Folders)
  // ---------------------------------------------------------------------------

  /// Lists the contents of the downloads directory (or a subdirectory within it).
  Future<SlskdDiskDirectory?> getDownloadsDirectory({
    String? subdirectory,
    bool recursive = false,
  }) async {
    try {
      final String path;
      if (subdirectory != null && subdirectory.isNotEmpty) {
        final b64 = Uri.encodeComponent(base64.encode(utf8.encode(subdirectory)));
        path = 'api/v0/files/downloads/directories/$b64';
      } else {
        path = 'api/v0/files/downloads/directories';
      }
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: <String, dynamic>{'recursive': recursive},
      );
      if (response.data is Map<String, dynamic>) {
        return SlskdDiskDirectory.fromJson(response.data as Map<String, dynamic>);
      }
      if (response.data is Map) {
        return SlskdDiskDirectory.fromJson((response.data as Map).cast<String, dynamic>());
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Deletes a subdirectory within the downloads directory.
  Future<void> deleteDownloadDirectory(String subdirectory) async {
    if (subdirectory.trim().isEmpty) {
      throw ArgumentError.value(subdirectory, 'subdirectory', 'Directory path cannot be empty');
    }
    final b64 = Uri.encodeComponent(base64.encode(utf8.encode(subdirectory)));
    await _dio.delete<void>('api/v0/files/downloads/directories/$b64');
  }

  /// Deletes a file within the downloads directory.
  Future<void> deleteDownloadFile(String fileName) async {
    if (fileName.trim().isEmpty) {
      throw ArgumentError.value(fileName, 'fileName', 'File name cannot be empty');
    }
    final b64 = Uri.encodeComponent(base64.encode(utf8.encode(fileName)));
    await _dio.delete<void>('api/v0/files/downloads/files/$b64');
  }

  /// Lists the contents of the incomplete downloads directory (or a subdirectory).
  Future<SlskdDiskDirectory?> getIncompleteDirectory({
    String? subdirectory,
    bool recursive = false,
  }) async {
    try {
      final String path;
      if (subdirectory != null && subdirectory.isNotEmpty) {
        final b64 = Uri.encodeComponent(base64.encode(utf8.encode(subdirectory)));
        path = 'api/v0/files/incomplete/directories/$b64';
      } else {
        path = 'api/v0/files/incomplete/directories';
      }
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: <String, dynamic>{'recursive': recursive},
      );
      if (response.data is Map<String, dynamic>) {
        return SlskdDiskDirectory.fromJson(response.data as Map<String, dynamic>);
      }
      if (response.data is Map) {
        return SlskdDiskDirectory.fromJson((response.data as Map).cast<String, dynamic>());
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Deletes a subdirectory within the incomplete directory.
  Future<void> deleteIncompleteDirectory(String subdirectory) async {
    if (subdirectory.trim().isEmpty) {
      throw ArgumentError.value(subdirectory, 'subdirectory', 'Directory path cannot be empty');
    }
    final b64 = Uri.encodeComponent(base64.encode(utf8.encode(subdirectory)));
    await _dio.delete<void>('api/v0/files/incomplete/directories/$b64');
  }

  /// Deletes a file within the incomplete directory.
  Future<void> deleteIncompleteFile(String fileName) async {
    if (fileName.trim().isEmpty) {
      throw ArgumentError.value(fileName, 'fileName', 'File name cannot be empty');
    }
    final b64 = Uri.encodeComponent(base64.encode(utf8.encode(fileName)));
    await _dio.delete<void>('api/v0/files/incomplete/files/$b64');
  }

  // ---------------------------------------------------------------------------
  // Logs (Live & Historical Files)
  // ---------------------------------------------------------------------------

  /// Lists the log files currently on disk on the daemon host.
  Future<List<SlskdDiskFile>> getLogFiles() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/logs/files');
      final List<SlskdDiskFile> files = [];
      if (response.data is Iterable) {
        for (final item in response.data as Iterable) {
          if (item is Map<String, dynamic>) {
            files.add(SlskdDiskFile.fromJson(item));
          } else if (item is Map) {
            files.add(SlskdDiskFile.fromJson(item.cast<String, dynamic>()));
          }
        }
      }
      return files;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const <SlskdDiskFile>[];
      rethrow;
    }
  }

  /// Retrieves the specified log file from disk as plain text.
  Future<String> getLogFileContent(String filename) async {
    final encoded = Uri.encodeComponent(filename);
    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/v0/logs/files/$encoded',
      options: Options(responseType: ResponseType.plain),
    );
    return response.data?.toString() ?? '';
  }

  /// Retrieves recent application logs. Calls primary `api/v0/logs/live` (supported in modern slskd)
  /// with legacy fallback to `api/v0/logs` for pre-0.20 daemons.
  Future<List<SlskdLogRecord>> getLogs() async {
    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>('api/v0/logs/live');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        response = await _dio.get<dynamic>('api/v0/logs');
      } else {
        rethrow;
      }
    }
    final List<SlskdLogRecord> logs = [];
    if (response.data is Iterable) {
      for (final item in response.data as Iterable) {
        if (item is Map<String, dynamic>) {
          logs.add(SlskdLogRecord.fromJson(item));
        } else if (item is Map) {
          logs.add(SlskdLogRecord.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return logs;
  }

  // ---------------------------------------------------------------------------
  // Transfers (Downloads & Uploads)
  // ---------------------------------------------------------------------------

  /// Lists all downloads grouped by user and directory.
  Future<List<SlskdUserTransfers>> getDownloads({bool includeRemoved = false}) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/v0/transfers/downloads',
      queryParameters: <String, dynamic>{'includeRemoved': includeRemoved},
    );
    return _parseUserTransfersList(response.data);
  }

  /// Lists all uploads grouped by user and directory.
  Future<List<SlskdUserTransfers>> getUploads({bool includeRemoved = false}) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/v0/transfers/uploads',
      queryParameters: <String, dynamic>{'includeRemoved': includeRemoved},
    );
    return _parseUserTransfersList(response.data);
  }

  /// Cancels the specified download. If [remove] is true, the transfer is discarded.
  Future<void> cancelDownload(String username, String id, {bool remove = false}) async {
    final encodedUser = Uri.encodeComponent(username);
    final encodedId = Uri.encodeComponent(id);
    await _dio.delete<void>(
      'api/v0/transfers/downloads/$encodedUser/$encodedId',
      queryParameters: <String, dynamic>{'remove': remove},
    );
  }

  /// Cancels the specified upload. If [remove] is true, the transfer is discarded.
  Future<void> cancelUpload(String username, String id, {bool remove = false}) async {
    final encodedUser = Uri.encodeComponent(username);
    final encodedId = Uri.encodeComponent(id);
    await _dio.delete<void>(
      'api/v0/transfers/uploads/$encodedUser/$encodedId',
      queryParameters: <String, dynamic>{'remove': remove},
    );
  }

  /// Clears all completed downloads.
  Future<void> clearCompletedDownloads() async {
    await _dio.delete<void>('api/v0/transfers/downloads/all/completed');
  }

  /// Clears all completed uploads.
  Future<void> clearCompletedUploads() async {
    await _dio.delete<void>('api/v0/transfers/uploads/all/completed');
  }

  /// Retrieves the current queue position for a download.
  Future<int?> getPlaceInQueue(String username, String id) async {
    try {
      final encodedUser = Uri.encodeComponent(username);
      final encodedId = Uri.encodeComponent(id);
      final Response<dynamic> response = await _dio.get<dynamic>(
        'api/v0/transfers/downloads/$encodedUser/$encodedId/position',
      );
      if (response.data != null) {
        if (response.data is num) {
          return (response.data as num).toInt();
        }
        return int.tryParse(response.data.toString());
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Enqueues downloads for a user.
  ///
  /// Routes through `/api/v0/transfers/downloads/batches` (the recommended modern
  /// endpoint upstream, replacing the obsolete direct user route).
  Future<EnqueueDownloadBatchResponse> enqueueDownloads(
    String username,
    List<QueueDownloadRequest> requests,
  ) async {
    return enqueueBatch(
      EnqueueDownloadBatchRequest(
        username: username,
        files: requests
            .map((r) => EnqueueDownloadBatchItem(filename: r.filename, size: r.size))
            .toList(),
      ),
    );
  }

  /// Enqueues a batch of files to download from a peer.
  Future<EnqueueDownloadBatchResponse> enqueueBatch(
    EnqueueDownloadBatchRequest request,
  ) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      'api/v0/transfers/downloads/batches',
      data: request.toJson(),
    );
    if (response.data is Map<String, dynamic>) {
      return EnqueueDownloadBatchResponse.fromJson(response.data as Map<String, dynamic>);
    }
    if (response.data is Map) {
      return EnqueueDownloadBatchResponse.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    }
    return const EnqueueDownloadBatchResponse();
  }

  /// Gets the transfer leaderboard of top peers for [direction] ('Download' or 'Upload').
  Future<List<SlskdTransferSummary>> getTransferLeaderboard({
    required String direction,
    DateTime? start,
    DateTime? end,
    int limit = 25,
    int offset = 0,
    String sortBy = 'Count',
    String sortOrder = 'DESC',
  }) async {
    final queryParams = <String, dynamic>{
      'direction': direction,
      'limit': limit,
      'offset': offset,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    if (start != null) queryParams['start'] = start.toUtc().toIso8601String();
    if (end != null) queryParams['end'] = end.toUtc().toIso8601String();

    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/v0/telemetry/reports/transfers/leaderboard',
      queryParameters: queryParams,
    );
    final List<SlskdTransferSummary> list = [];
    if (response.data is Iterable) {
      for (final item in response.data as Iterable) {
        if (item is Map<String, dynamic>) {
          list.add(SlskdTransferSummary.fromJson(item));
        } else if (item is Map) {
          list.add(SlskdTransferSummary.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return list;
  }

  /// Gets Pareto breakdown of top transfer failure reasons.
  Future<List<SlskdTransferExceptionSummary>> getTransferExceptionsPareto({
    required String direction,
    DateTime? start,
    DateTime? end,
    String? username,
    int limit = 25,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'direction': direction,
      'limit': limit,
      'offset': offset,
    };
    if (start != null) queryParams['start'] = start.toUtc().toIso8601String();
    if (end != null) queryParams['end'] = end.toUtc().toIso8601String();
    if (username != null) queryParams['username'] = username;

    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/v0/telemetry/reports/transfers/exceptions/pareto',
      queryParameters: queryParams,
    );
    final List<SlskdTransferExceptionSummary> list = [];
    if (response.data is Iterable) {
      for (final item in response.data as Iterable) {
        if (item is Map<String, dynamic>) {
          list.add(SlskdTransferExceptionSummary.fromJson(item));
        } else if (item is Map) {
          list.add(SlskdTransferExceptionSummary.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return list;
  }

  /// Gets most frequently downloaded directories.
  Future<List<SlskdTransferDirectorySummary>> getTransferDirectories({
    DateTime? start,
    DateTime? end,
    String? username,
    int limit = 25,
    int offset = 0,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (start != null) queryParams['start'] = start.toUtc().toIso8601String();
    if (end != null) queryParams['end'] = end.toUtc().toIso8601String();
    if (username != null) queryParams['username'] = username;

    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/v0/telemetry/reports/transfers/directories',
      queryParameters: queryParams,
    );
    final List<SlskdTransferDirectorySummary> list = [];
    if (response.data is Iterable) {
      for (final item in response.data as Iterable) {
        if (item is Map<String, dynamic>) {
          list.add(SlskdTransferDirectorySummary.fromJson(item));
        } else if (item is Map) {
          list.add(SlskdTransferDirectorySummary.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return list;
  }

  /// Gets Prometheus KPIs formatted as JSON dictionary.
  Future<Map<String, SlskdPrometheusMetric>> getPrometheusKpis() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        'api/v0/telemetry/metrics/kpis',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final Map<String, SlskdPrometheusMetric> map = {};
      if (response.data is Map) {
        for (final entry in (response.data as Map).entries) {
          if (entry.value is Map<String, dynamic>) {
            map[entry.key.toString()] =
                SlskdPrometheusMetric.fromJson(entry.value as Map<String, dynamic>);
          } else if (entry.value is Map) {
            map[entry.key.toString()] = SlskdPrometheusMetric.fromJson(
                (entry.value as Map).cast<String, dynamic>());
          }
        }
      }
      return map;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const {};
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Searches
  // ---------------------------------------------------------------------------

  /// Initiates a new search across the Soulseek network.
  Future<SlskdSearch> initiateSearch(SlskdSearchRequest request) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      'api/v0/searches',
      data: request.toJson(),
    );
    if (response.data is Map<String, dynamic>) {
      return SlskdSearch.fromJson(response.data as Map<String, dynamic>);
    }
    if (response.data is Map) {
      return SlskdSearch.fromJson((response.data as Map).cast<String, dynamic>());
    }
    throw const FormatException(
      'Failed to initiate search: unexpected response payload from slskd daemon.',
    );
  }

  /// Retrieves all active and recent searches.
  Future<List<SlskdSearch>> getSearches() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/v0/searches');
    final List<SlskdSearch> searches = [];
    if (response.data is Iterable) {
      for (final item in response.data as Iterable) {
        if (item is Map<String, dynamic>) {
          searches.add(SlskdSearch.fromJson(item));
        } else if (item is Map) {
          searches.add(SlskdSearch.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return searches;
  }

  /// Retrieves file responses for the search matching [id].
  Future<List<SlskdSearchResponse>> getSearchResponses(String id) async {
    try {
      final encodedId = Uri.encodeComponent(id);
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/searches/$encodedId/responses');
      final List<SlskdSearchResponse> responses = [];
      if (response.data is Iterable) {
        for (final item in response.data as Iterable) {
          if (item is Map<String, dynamic>) {
            responses.add(SlskdSearchResponse.fromJson(item));
          } else if (item is Map) {
            responses.add(SlskdSearchResponse.fromJson(_asMap(item)));
          }
        }
      }
      return responses;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const <SlskdSearchResponse>[];
      rethrow;
    }
  }

  /// Deletes the search matching [id].
  Future<void> deleteSearch(String id) async {
    final encodedId = Uri.encodeComponent(id);
    await _dio.delete<void>('api/v0/searches/$encodedId');
  }

  /// Cancels / stops an active search matching [id].
  Future<void> stopSearch(String id) async {
    final encodedId = Uri.encodeComponent(id);
    await _dio.put<void>('api/v0/searches/$encodedId');
  }

  // ---------------------------------------------------------------------------
  // Browse & Users
  // ---------------------------------------------------------------------------

  /// Retrieves the entire file share tree of the specified remote [username].
  ///
  /// A 404 is not swallowed: slskd sends it when the peer is offline, and the
  /// Browse tab has to say so rather than show an empty share.
  Future<List<SlskdDirectory>> browseUser(String username) async {
    final encodedUser = Uri.encodeComponent(username);
    final Response<dynamic> response = await _dio.get<dynamic>('api/v0/users/$encodedUser/browse');
    return _parseDirectoryList(response.data);
  }

  /// Retrieves the status of the current browse operation for [username], if any (0.0 to 1.0 or 0 to 100).
  Future<double?> getBrowseStatus(String username) async {
    try {
      final encodedUser = Uri.encodeComponent(username);
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/users/$encodedUser/browse/status');
      if (response.data is num) {
        return (response.data as num).toDouble();
      }
      if (response.data is Map) {
        final map = response.data as Map;
        final v = map['percentComplete'] ??
            map['PercentComplete'] ??
            map['progress'] ??
            map['Progress'];
        if (v is num) return v.toDouble();
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Retrieves bio, profile picture, and upload slot information for [username].
  Future<SlskdUserInfo> getUserInfo(String username) async {
    try {
      final encodedUser = Uri.encodeComponent(username);
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/users/$encodedUser/info');
      if (response.data is Map<String, dynamic>) {
        return SlskdUserInfo.fromJson(response.data as Map<String, dynamic>);
      }
      if (response.data is Map) {
        return SlskdUserInfo.fromJson((response.data as Map).cast<String, dynamic>());
      }
      return const SlskdUserInfo(description: '');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const SlskdUserInfo(description: '');
      }
      rethrow;
    }
  }

  /// Retrieves presence status (online, away, offline) and privilege state for [username].
  Future<SlskdUserStatus> getUserStatus(String username) async {
    try {
      final encodedUser = Uri.encodeComponent(username);
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/users/$encodedUser/status');
      if (response.data is Map<String, dynamic>) {
        return SlskdUserStatus.fromJson(response.data as Map<String, dynamic>);
      }
      if (response.data is Map) {
        return SlskdUserStatus.fromJson((response.data as Map).cast<String, dynamic>());
      }
      return const SlskdUserStatus();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const SlskdUserStatus();
      }
      rethrow;
    }
  }

  /// Retrieves the remote IP address and Soulseek port for [username].
  Future<SlskdUserEndpoint?> getUserEndpoint(String username) async {
    try {
      final encodedUser = Uri.encodeComponent(username);
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/users/$encodedUser/endpoint');
      if (response.data == null) return null;
      if (response.data is Map || response.data is String) {
        return SlskdUserEndpoint.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Community (Chat Rooms & Direct Messages)
  // ---------------------------------------------------------------------------

  /// Retrieves all available public and private chat rooms on the Soulseek network.
  Future<List<SlskdRoomInfo>> getAvailableRooms() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/v0/rooms/available');
    final List<SlskdRoomInfo> rooms = [];
    if (response.data is Iterable) {
      for (final item in response.data as Iterable) {
        if (item is Map<String, dynamic>) {
          rooms.add(SlskdRoomInfo.fromJson(item));
        } else if (item is Map) {
          rooms.add(SlskdRoomInfo.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return rooms;
  }

  /// Gets the names of all currently joined chat rooms.
  Future<List<String>> getJoinedRoomNames() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/v0/rooms/joined');
    final List<String> names = [];
    if (response.data is Iterable) {
      for (final item in response.data as Iterable) {
        names.add(item.toString());
      }
    }
    return names;
  }

  /// Gets the room details (users and recent messages) for [roomName].
  Future<SlskdRoom?> getRoom(String roomName) async {
    try {
      final encodedRoom = Uri.encodeComponent(roomName);
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/rooms/joined/$encodedRoom');
      if (response.data is Map<String, dynamic>) {
        return SlskdRoom.fromJson(response.data as Map<String, dynamic>);
      }
      if (response.data is Map) {
        return SlskdRoom.fromJson((response.data as Map).cast<String, dynamic>());
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Gets recent messages for [roomName].
  Future<List<SlskdRoomMessage>> getRoomMessages(String roomName) async {
    try {
      final encodedRoom = Uri.encodeComponent(roomName);
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/rooms/joined/$encodedRoom/messages');
      final List<SlskdRoomMessage> messages = [];
      if (response.data is Iterable) {
        for (final item in response.data as Iterable) {
          if (item is Map<String, dynamic>) {
            messages.add(SlskdRoomMessage.fromJson(item));
          } else if (item is Map) {
            messages.add(SlskdRoomMessage.fromJson(_asMap(item)));
          }
        }
      }
      return messages;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const <SlskdRoomMessage>[];
      rethrow;
    }
  }

  /// Gets the list of users present in [roomName].
  Future<List<SlskdUserPresence>> getRoomUsers(String roomName) async {
    try {
      final encodedRoom = Uri.encodeComponent(roomName);
      final Response<dynamic> response = await _dio.get<dynamic>('api/v0/rooms/joined/$encodedRoom/users');
      final List<SlskdUserPresence> users = [];
      if (response.data is Iterable) {
        for (final item in response.data as Iterable) {
          if (item is Map<String, dynamic>) {
            users.add(SlskdUserPresence.fromJson(item));
          } else if (item is Map) {
            users.add(SlskdUserPresence.fromJson(_asMap(item)));
          }
        }
      }
      return users;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const <SlskdUserPresence>[];
      rethrow;
    }
  }

  /// Joins a chat room by [roomName].
  Future<SlskdRoom?> joinRoom(String roomName) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      'api/v0/rooms/joined',
      data: jsonEncode(roomName),
      options: Options(contentType: 'application/json'),
    );
    if (response.data is Map<String, dynamic>) {
      return SlskdRoom.fromJson(response.data as Map<String, dynamic>);
    }
    if (response.data is Map) {
      return SlskdRoom.fromJson((response.data as Map).cast<String, dynamic>());
    }
    return null;
  }

  /// Leaves a chat room by [roomName].
  Future<void> leaveRoom(String roomName) async {
    final encodedRoom = Uri.encodeComponent(roomName);
    await _dio.delete<void>('api/v0/rooms/joined/$encodedRoom');
  }

  /// Sends a message to [roomName].
  Future<void> sendRoomMessage(String roomName, String message) async {
    final encodedRoom = Uri.encodeComponent(roomName);
    await _dio.post<void>(
      'api/v0/rooms/joined/$encodedRoom/messages',
      data: jsonEncode(message),
      options: Options(contentType: 'application/json'),
    );
  }

  /// Sets the topic ticker for [roomName].
  Future<void> setRoomTicker(String roomName, String ticker) async {
    final encodedRoom = Uri.encodeComponent(roomName);
    await _dio.post<void>(
      'api/v0/rooms/joined/$encodedRoom/ticker',
      data: jsonEncode(ticker),
      options: Options(contentType: 'application/json'),
    );
  }

  /// Adds [username] as a member to the private room [roomName].
  Future<void> addPrivateRoomMember(String roomName, String username) async {
    final encodedRoom = Uri.encodeComponent(roomName);
    await _dio.post<void>(
      'api/v0/rooms/joined/$encodedRoom/members',
      data: jsonEncode(username),
      options: Options(contentType: 'application/json'),
    );
  }

  /// Retrieves all direct message conversations.
  Future<List<SlskdConversation>> getConversations({
    bool includeInactive = false,
    bool unAcknowledgedOnly = false,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/v0/conversations',
      queryParameters: <String, dynamic>{
        'includeInactive': includeInactive,
        'unAcknowledgedOnly': unAcknowledgedOnly,
      },
    );
    final List<SlskdConversation> conversations = [];
    if (response.data is Iterable) {
      for (final item in response.data as Iterable) {
        if (item is Map<String, dynamic>) {
          final convo = SlskdConversation.fromJson(item);
          // Filter out '..' which appears due to a Soulseek protocol quirk
          // during transient room/peer navigation state transitions.
          if (convo.username != '..') {
            conversations.add(convo);
          }
        } else if (item is Map) {
          final convo = SlskdConversation.fromJson(item.cast<String, dynamic>());
          // Filter out '..' which appears due to a Soulseek protocol quirk
          // during transient room/peer navigation state transitions.
          if (convo.username != '..') {
            conversations.add(convo);
          }
        }
      }
    }
    return conversations;
  }

  /// Retrieves private messages exchanged with [username].
  Future<List<SlskdPrivateMessage>> getConversationMessages(String username) async {
    try {
      final encodedUser = Uri.encodeComponent(username);
      final Response<dynamic> response = await _dio.get<dynamic>(
        'api/v0/conversations/$encodedUser/messages',
      );
      final List<SlskdPrivateMessage> messages = [];
      if (response.data is Iterable) {
        for (final item in response.data as Iterable) {
          if (item is Map<String, dynamic>) {
            messages.add(SlskdPrivateMessage.fromJson(item));
          } else if (item is Map) {
            messages.add(SlskdPrivateMessage.fromJson(item.cast<String, dynamic>()));
          }
        }
      }
      return messages;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const <SlskdPrivateMessage>[];
      }
      rethrow;
    }
  }

  /// Sends a direct private message to [username].
  Future<void> sendPrivateMessage(String username, String message) async {
    final encodedUser = Uri.encodeComponent(username);
    await _dio.post<void>(
      'api/v0/conversations/$encodedUser',
      data: jsonEncode(message),
      options: Options(contentType: 'application/json'),
    );
  }

  /// Acknowledges all messages from [username].
  Future<void> acknowledgeAllMessages(String username) async {
    final encodedUser = Uri.encodeComponent(username);
    await _dio.put<void>('api/v0/conversations/$encodedUser');
  }

  /// Closes an active conversation with [username].
  Future<void> closeConversation(String username) async {
    final encodedUser = Uri.encodeComponent(username);
    await _dio.delete<void>('api/v0/conversations/$encodedUser');
  }

  // ---------------------------------------------------------------------------
  // Options & Configuration (Phase 5)
  // ---------------------------------------------------------------------------

  /// Gets current application options (redacted).
  Future<Map<String, dynamic>> getOptions() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/v0/options');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    if (response.data is Map) {
      return (response.data as Map).cast<String, dynamic>();
    }
    return const {};
  }

  // ---------------------------------------------------------------------------
  // Advanced Diagnostics & Relay (Phase 6)
  // ---------------------------------------------------------------------------

  /// Forces garbage collection in the .NET CLR runtime.
  Future<void> collectGarbage() async {
    await _dio.post<void>('api/v0/application/gc');
  }

  /// Performs a loopback diagnostic echo test.
  Future<void> loopbackTest(dynamic body) async {
    await _dio.post<void>('api/v0/application/loopback', data: body);
  }

  /// Gets low-level internal Soulseek transfers from the debug endpoint.
  Future<Map<String, dynamic>> getDebugTransfers() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/v0/debug/transfers');
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    if (response.data is Map) {
      return (response.data as Map).cast<String, dynamic>();
    }
    return const {};
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  List<SlskdUserTransfers> _parseUserTransfersList(dynamic data) {
    return _asList(data)
        .map((dynamic item) => SlskdUserTransfers.fromJson(_asMap(item)))
        .toList();
  }

  List<SlskdDirectory> _parseDirectoryList(dynamic data) {
    final List<SlskdDirectory> list = [];
    if (data is Iterable) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          list.add(SlskdDirectory.fromJson(item));
        } else if (item is Map) {
          list.add(SlskdDirectory.fromJson(item.cast<String, dynamic>()));
        }
      }
    } else if (data is Map) {
      final rawDirs = data['directories'] ?? data['Directories'];
      if (rawDirs is Iterable) {
        for (final item in rawDirs) {
          if (item is Map<String, dynamic>) {
            list.add(SlskdDirectory.fromJson(item));
          } else if (item is Map) {
            list.add(SlskdDirectory.fromJson(item.cast<String, dynamic>()));
          }
        }
      }
      final rawLocked = data['lockedDirectories'] ?? data['LockedDirectories'];
      if (rawLocked is Iterable) {
        for (final item in rawLocked) {
          if (item is Map<String, dynamic>) {
            final dirMap = Map<String, dynamic>.from(item);
            dirMap['isLocked'] = true;
            list.add(SlskdDirectory.fromJson(dirMap));
          } else if (item is Map) {
            final dirMap = Map<String, dynamic>.from(item.cast<String, dynamic>());
            dirMap['isLocked'] = true;
            list.add(SlskdDirectory.fromJson(dirMap));
          }
        }
      }
    }
    return list;
  }
}
