import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

/// Thin typed client over the Tracearr API.
class TracearrApi {
  TracearrApi(this._dio);

  final Dio _dio;

  /// Retrieves the active sessions from the internal Tracearr API.
  Future<Map<String, dynamic>> getActiveSessions() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('api/v1/sessions/active');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // TODO: Add more Tracearr endpoints here
}
