import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/unraid_models.dart';

/// Client for Unraid's GraphQL API.
///
/// Unraid is the only service Atrium talks to over GraphQL: one endpoint,
/// POST only, every query in the request body. Auth rides on the `x-api-key`
/// header, which the shared [AuthInterceptor] already sends for the api-key
/// style, so nothing extra is needed here.
///
/// The queries below were written against real responses from a live 7.x
/// server. The published docs describe a flatter schema, with containers at
/// the top level rather than under `docker`, which does not match what is
/// served.
class UnraidClient {
  UnraidClient(this._dio);

  final Dio _dio;

  static const String _endpoint = 'graphql';

  /// Runs [query] and returns its `data` object.
  ///
  /// GraphQL answers 200 even when it refuses the request, putting the reason
  /// in an `errors` array instead of the status line. Treating that as success
  /// is the classic way to end up rendering an empty screen and calling it
  /// healthy, so an errors array is raised here rather than passed on.
  Future<Map<String, dynamic>> _query(String query) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        _endpoint,
        data: <String, dynamic>{'query': query},
        options: Options(contentType: Headers.jsonContentType),
      );

      final dynamic body = resp.data;
      if (body is! Map<String, dynamic>) {
        throw const NetworkUnknownException(
          'Unraid returned something other than a GraphQL response. Check the '
          'URL points at the server itself and not a proxy error page.',
        );
      }

      final dynamic errors = body['errors'];
      if (errors is List && errors.isNotEmpty) {
        final dynamic first = errors.first;
        final String message = first is Map<String, dynamic>
            ? (first['message']?.toString() ?? 'Unknown GraphQL error')
            : first.toString();
        throw NetworkUnknownException(message);
      }

      final dynamic data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw const NetworkUnknownException(
          'Unraid answered without any data.',
        );
      }
      return data;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Array state and its disks.
  Future<UnraidArray> getArray() async {
    final Map<String, dynamic> data = await _query(
      '{ array { state disks { name size status temp } } }',
    );
    final dynamic array = data['array'];
    if (array is! Map<String, dynamic>) {
      throw const NetworkUnknownException(
        'Unraid did not return an array. The API key may not carry the '
        'permission to read it.',
      );
    }
    return UnraidArray.fromJson(array);
  }

  /// Every Docker container the server knows about, running or not.
  Future<List<UnraidContainer>> getContainers() async {
    final Map<String, dynamic> data = await _query(
      '{ docker { containers { id names state status autoStart } } }',
    );
    final dynamic docker = data['docker'];
    if (docker is! Map<String, dynamic>) {
      throw const NetworkUnknownException(
        'Unraid did not return any Docker data. The API key may not carry the '
        'permission to read it.',
      );
    }
    return (docker['containers'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(UnraidContainer.fromJson)
        .toList();
  }
}
