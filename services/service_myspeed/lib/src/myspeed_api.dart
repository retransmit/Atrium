import 'package:dio/dio.dart';

import 'models/myspeed_config.dart';
import 'models/myspeed_status.dart';
import 'models/myspeed_storage.dart';
import 'models/myspeed_test.dart';

/// API client for interacting with MySpeed (`gnmyt/myspeed`).
class MySpeedApi {
  const MySpeedApi(this._dio);

  final Dio _dio;

  /// Queries whether a speedtest is currently running via `GET /api/speedtests/status`.
  Future<MySpeedStatus> getSpeedtestStatus() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/speedtests/status',
    );
    return MySpeedStatus.fromResponse(response.data);
  }

  /// How far back the History tab reads, in hours. The server keeps tests
  /// for as long as its retention setting says, so this only has to be
  /// larger than that.
  static const int historyHours = 24 * 365 * 5;

  /// The most rows one list call asks for.
  static const int pageLimit = 1000;

  /// Fetches speedtests via `GET /api/speedtests`.
  ///
  /// Left alone, the server answers with the last 24 hours and at most 10
  /// rows. [hours] widens the window, [limit] raises the count, and [start]
  /// pages backwards: the rows before that test id.
  Future<List<MySpeedTest>> getSpeedtests({
    int? hours,
    int? limit,
    int? start,
  }) async {
    final Map<String, dynamic> params = <String, dynamic>{
      if (hours != null) 'hours': hours,
      if (limit != null) 'limit': limit,
      if (start != null) 'start': start,
    };

    final Response<dynamic> response = await _dio.get<dynamic>(
      'api/speedtests',
      queryParameters: params.isNotEmpty ? params : null,
    );

    return _parseTests(response.data);
  }

  /// The last 24 hours, whole: the server's default window with the row
  /// cap lifted.
  Future<List<MySpeedTest>> get24HourSpeedtests() =>
      getSpeedtests(hours: 24, limit: pageLimit);

  /// Fetches a single speedtest by its ID via `GET /api/speedtests/:id`.
  Future<MySpeedTest?> getSpeedtestById(String id) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>('api/speedtests/$id');
      final dynamic data = response.data;
      if (data == null) return null;
      if (data is Map) {
        final Map<String, dynamic> map = data.cast<String, dynamic>();
        if (map.containsKey('data') && map['data'] is Map) {
          return MySpeedTest.fromJson((map['data'] as Map).cast<String, dynamic>());
        }
        return MySpeedTest.fromJson(map);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// Fetches MySpeed server configuration via `GET /api/config`.
  Future<MySpeedConfig> getConfig() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/config');
    return MySpeedConfig.fromResponse(response.data);
  }

  /// Fetches storage usage information via `GET /api/storage`.
  Future<MySpeedStorage> getStorage() async {
    final Response<dynamic> response = await _dio.get<dynamic>('api/storage');
    return MySpeedStorage.fromJson(response.data);
  }

  /// Starts a speedtest via `POST /api/speedtests/run`. The server answers
  /// before the test ends; `getSpeedtestStatus` says when it has.
  Future<void> runSpeedtest() async {
    await _dio.post<dynamic>('api/speedtests/run');
  }

  List<MySpeedTest> _parseTests(dynamic data) {
    final List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List<dynamic>;
    } else if (data is Map && data['results'] is List) {
      list = data['results'] as List<dynamic>;
    } else {
      list = const <dynamic>[];
    }

    final List<MySpeedTest> tests = <MySpeedTest>[];
    for (final dynamic item in list) {
      if (item is Map) {
        tests.add(MySpeedTest.fromJson(item.cast<String, dynamic>()));
      }
    }

    // Sort descending by date (most recent first)
    tests.sort((a, b) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });

    return tests;
  }
}
