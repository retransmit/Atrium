import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

/// Manages Tracearr's internal session token (`.token`).
class TracearrAuthManager {
  TracearrAuthManager({
    required this.baseUrl,
    required this.auth,
    required Dio dio,
  }) : _dio = dio;

  final Uri baseUrl;
  final InstanceAuth auth;
  final Dio _dio;

  String? _sessionToken;

  /// Returns the current valid session token, or triggers a login flow
  /// if one hasn't been acquired yet or was cleared after a 401.
  Future<String> ensureToken() async {
    if (_sessionToken != null) {
      return _sessionToken!;
    }

    // Attempt login based on auth type
    switch (auth) {
      case InstanceAuthUserPass(:final String username, :final String password):
        _sessionToken = await _loginUserPass(username, password);
      default:
        throw StateError(
          'Tracearr does not support auth type: ${auth.runtimeType}',
        );
    }

    return _sessionToken!;
  }

  void clearToken() {
    _sessionToken = null;
  }

  Future<String> _loginUserPass(String username, String password) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        'api/v1/auth/sign-in/username',
        data: <String, dynamic>{
          'username': username,
          'password': password,
        },
      );
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final String? token = data['token'] as String?;
      if (token == null) {
        throw const NetworkAuthException(
          'Tracearr login succeeded but returned no token.',
        );
      }
      return token;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw const NetworkAuthException(
          'Tracearr rejected local credentials.',
        );
      }
      throw NetworkException.fromDio(e);
    }
  }
}
