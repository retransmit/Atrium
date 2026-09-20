import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Navidrome is the one kind whose credentials ride in the query string.
///
/// The shared health probe and the connection tester build their requests from
/// [AuthInterceptor] alone, so if it does not sign a Subsonic request those
/// two send an anonymous one. Subsonic answers that with a 200 and a `failed`
/// envelope rather than a 401, which is how a wrong password came to read as
/// Online on the dashboard and Connected in the connection test.
void main() {
  const String password = 'hunter2';
  const InstanceAuth auth =
      InstanceAuth.userPass(username: 'aariz', password: password);

  RequestOptions sign(InstanceAuth withAuth, {ServiceKind? kind}) {
    final RequestOptions options = RequestOptions(path: 'rest/ping.view');
    AuthInterceptor(kind: kind ?? ServiceKind.navidrome, auth: withAuth)
        .onRequest(options, RequestInterceptorHandler());
    return options;
  }

  test('it signs a navidrome request with user, token and salt', () {
    final RequestOptions options = sign(auth);

    expect(options.queryParameters['u'], 'aariz');
    expect(options.queryParameters['s'], isA<String>());
    expect(options.queryParameters['t'], isA<String>());

    // The token is the MD5 of the password with the salt appended, which is
    // the whole of Subsonic's token scheme.
    final String salt = options.queryParameters['s'] as String;
    expect(
      options.queryParameters['t'],
      md5.convert(utf8.encode('$password$salt')).toString(),
    );
  });

  test('it sends the protocol fields Subsonic refuses a request without', () {
    final RequestOptions options = sign(auth);

    expect(options.queryParameters['v'], subsonicApiVersion);
    expect(options.queryParameters['c'], subsonicClientName);
    expect(options.queryParameters['f'], 'json');
  });

  test('the password never appears in the request', () {
    final RequestOptions options = sign(auth);

    expect(
      options.queryParameters.values.map((Object? v) => '$v'),
      isNot(contains(password)),
    );
    expect(
      options.headers.values.map((Object? v) => '$v'),
      isNot(contains(password)),
    );
  });

  test('the salt is different every time', () {
    // A salt that repeats gives anyone who captures one request unlimited
    // time to precompute against a single fixed hash.
    final Set<String> salts = <String>{
      for (int i = 0; i < 50; i++) sign(auth).queryParameters['s'] as String,
    };

    expect(salts.length, 50);
    expect(salts.first.length, greaterThanOrEqualTo(16));
  });

  test('no password means no token, but still a username', () {
    final RequestOptions options = sign(
      const InstanceAuth.userPass(username: 'aariz', password: ''),
    );

    expect(options.queryParameters['u'], 'aariz');
    expect(options.queryParameters.containsKey('t'), isFalse);
    expect(options.queryParameters.containsKey('s'), isFalse);
  });

  test('it signs nothing for a kind that is not navidrome', () {
    // The other user/password services either use HTTP Basic or a session
    // their own module manages; none of them want these parameters.
    for (final ServiceKind kind in <ServiceKind>[
      ServiceKind.jellyfin,
      ServiceKind.emby,
      ServiceKind.qbittorrent,
      ServiceKind.nzbget,
    ]) {
      expect(
        sign(auth, kind: kind).queryParameters.containsKey('t'),
        isFalse,
        reason: '${kind.name} should not be signed as Subsonic',
      );
    }
  });

  test('it sets no headers, so nothing collides with a proxy credential', () {
    // Reverse-proxy auth lives in headers. Because Subsonic signs in the
    // query string instead, a user's Authorization or Proxy-Authorization
    // header survives untouched to the proxy in front of Navidrome.
    expect(sign(auth).headers, isEmpty);
    expect(serviceAuthHeaderNames(ServiceKind.navidrome, auth), isEmpty);
  });
}
