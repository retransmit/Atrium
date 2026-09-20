import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_navidrome/service_navidrome.dart';

/// A failed Subsonic envelope has to become a real error.
///
/// Subsonic answers 200 for everything, and the client parses optimistically:
/// when the key it wants is missing it returns an empty list. That is correct
/// for an empty library and wrong for a rejected credential, so before this
/// interceptor a wrong password rendered as "No albums found" on every tab
/// with nothing logged and no error shown anywhere.
void main() {
  Dio dioWith(Object? body, {int status = 200}) {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://navidrome.test/'))
      ..httpClientAdapter = _FixedAdapter(body, status)
      ..interceptors.add(const SubsonicErrorInterceptor());
    return dio;
  }

  Map<String, dynamic> failed(int code, String message) => <String, dynamic>{
        'subsonic-response': <String, dynamic>{
          'status': 'failed',
          'version': '1.16.1',
          'error': <String, dynamic>{'code': code, 'message': message},
        },
      };

  test('a rejected password becomes a DioException, not an empty result', () {
    expect(
      () => dioWith(failed(40, 'Wrong username or password'))
          .get<dynamic>('rest/getAlbumList.view'),
      throwsA(
        isA<DioException>().having(
          (DioException e) => '${e.error}',
          'error',
          allOf(contains('Wrong username or password'), contains('40')),
        ),
      ),
    );
  });

  test('an unauthenticated request becomes a DioException too', () {
    expect(
      () => dioWith(failed(10, "missing parameter: 'u'"))
          .get<dynamic>('rest/ping.view'),
      throwsA(isA<DioException>()),
    );
  });

  test('a successful envelope passes straight through', () async {
    final Response<dynamic> response = await dioWith(<String, dynamic>{
      'subsonic-response': <String, dynamic>{
        'status': 'ok',
        'albumList': <String, dynamic>{'album': <dynamic>[]},
      },
    }).get<dynamic>('rest/getAlbumList.view');

    expect(response.statusCode, 200);
    expect(
      (response.data as Map<String, dynamic>)['subsonic-response'],
      isA<Map<String, dynamic>>(),
    );
  });

  test('a genuinely empty library is not an error', () async {
    // The case the interceptor must not break: status ok, nothing in it.
    final Response<dynamic> response = await dioWith(<String, dynamic>{
      'subsonic-response': <String, dynamic>{'status': 'ok'},
    }).get<dynamic>('rest/getAlbumList.view');

    expect(response.statusCode, 200);
  });

  test('a non-map body is left alone', () async {
    // Cover art and stream endpoints answer with bytes rather than JSON.
    final Response<dynamic> response =
        await dioWith('not json').get<dynamic>('rest/getCoverArt.view');

    expect(response.data, 'not json');
  });

  test('an error without a code still carries its message', () {
    expect(
      () => dioWith(<String, dynamic>{
        'subsonic-response': <String, dynamic>{'status': 'failed'},
      }).get<dynamic>('rest/ping.view'),
      throwsA(
        isA<DioException>()
            .having((DioException e) => '${e.error}', 'error', isNotEmpty),
      ),
    );
  });
}

/// Answers every request with one fixed body.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.body, this.status);

  final Object? body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (body is String) {
      return ResponseBody.fromString(
        body! as String,
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/plain'],
        },
      );
    }
    return ResponseBody.fromString(
      _encode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  static String _encode(Object? value) =>
      const JsonEncoder().convert(value);

  @override
  void close({bool force = false}) {}
}
