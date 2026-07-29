import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/tracearr_active_sessions.dart';
import 'models/tracearr_session.dart';

/// Thin typed client over the Tracearr API.
class TracearrApi {
  TracearrApi(this._dio);

  final Dio _dio;

  /// Retrieves the active sessions from the internal Tracearr API.
  Future<TracearrActiveSessions> getActiveSessions() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('api/v1/sessions/active');
      if (resp.data is List) {
        return TracearrActiveSessions(
          sessions: (resp.data as List).map((dynamic e) => TracearrSession.fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
      return TracearrActiveSessions.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // TODO: Add more Tracearr endpoints here
}
