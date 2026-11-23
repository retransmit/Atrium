import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/gotify_models.dart';

/// Client for Gotify's REST API, authenticated with a client token
/// (`X-Gotify-Key`, attached by [AuthInterceptor]).
///
/// An application token can only post messages; every call here needs a
/// client token.
class GotifyApi {
  const GotifyApi(this._dio);

  final Dio _dio;

  /// The most messages Gotify returns in one page.
  static const int maxPageSize = 200;

  Future<T> _send<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// `GET application`.
  Future<List<GotifyApplication>> getApplications() => _send(() async {
        final Response<dynamic> response =
            await _dio.get<dynamic>('application');
        final Object? data = response.data;
        if (data is! List) throw const GotifyUnexpectedAnswer();
        return <GotifyApplication>[
          for (final Object? item in data)
            if (item is Map)
              GotifyApplication.fromJson(item.cast<String, dynamic>()),
        ];
      });

  /// `GET message`, or `GET application/{appId}/message` for one
  /// application. Newest first; [since] returns only messages older than
  /// that id.
  Future<GotifyMessagePage> getMessages({
    int? appId,
    int limit = 50,
    int? since,
  }) =>
      _send(() async {
        final Response<dynamic> response = await _dio.get<dynamic>(
          appId == null ? 'message' : 'application/$appId/message',
          queryParameters: <String, dynamic>{
            'limit': limit.clamp(1, maxPageSize),
            if (since != null) 'since': since,
          },
        );
        return GotifyMessagePage.fromResponse(response.data);
      });

  /// `DELETE message/{id}`.
  Future<void> deleteMessage(int id) => _send(() async {
        await _dio.delete<dynamic>('message/$id');
      });

  /// `DELETE message`: every message of every application.
  Future<void> deleteAllMessages() => _send(() async {
        await _dio.delete<dynamic>('message');
      });

  /// `DELETE application/{appId}/message`.
  Future<void> deleteApplicationMessages(int appId) => _send(() async {
        await _dio.delete<dynamic>('application/$appId/message');
      });
}
