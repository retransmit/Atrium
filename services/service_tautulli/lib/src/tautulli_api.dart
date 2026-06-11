import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/tautulli_activity.dart';

/// Thin client over the Tautulli API.
///
/// Tautulli endpoints are `/api/v2?cmd=<command>` with the `apikey` query param
/// (appended by `core_networking`'s [AuthInterceptor]), so this rides the
/// shared `instanceDioProvider` Dio and just adds `cmd`.
class TautulliApi {
  TautulliApi(this._dio);

  final Dio _dio;

  Future<TautulliActivity> getActivity() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '/api/v2',
        queryParameters: <String, dynamic>{'cmd': 'get_activity'},
      );
      return TautulliActivityEnvelope.fromJson(
                resp.data as Map<String, dynamic>,
              ).response.data ??
          const TautulliActivity();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
