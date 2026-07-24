import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nzbget requests carry HTTP Basic auth from the userPass credentials',
      () {
    const AuthInterceptor interceptor = AuthInterceptor(
      kind: ServiceKind.nzbget,
      auth: InstanceAuth.userPass(username: 'nzbget', password: 'tegbzn6789'),
    );
    final RequestOptions options =
        RequestOptions(path: 'jsonrpc', method: 'POST');
    interceptor.onRequest(options, RequestInterceptorHandler());
    final String expected =
        'Basic ${base64Encode(utf8.encode('nzbget:tegbzn6789'))}';
    expect(options.headers['Authorization'], expected);
  });

  test('other userPass kinds are untouched by the interceptor', () {
    const AuthInterceptor interceptor = AuthInterceptor(
      kind: ServiceKind.jellyfin,
      auth: InstanceAuth.userPass(username: 'u', password: 'p'),
    );
    final RequestOptions options = RequestOptions(path: 'x');
    interceptor.onRequest(options, RequestInterceptorHandler());
    expect(options.headers.containsKey('Authorization'), isFalse);
  });
}
