import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_plex/service_plex.dart';

/// Answers the plex.tv routes the way the live service does.
///
/// The shapes below were taken from plex.tv: a fresh PIN carries a null
/// `authToken` until somebody links it, the PIN is bound to the client
/// identifier it was issued against (anything else is a 404), and the
/// resources route needs a token or answers 401.
class _PlexTv implements HttpClientAdapter {
  /// The install the PIN below was issued to.
  static const String issuedTo = 'atrium-test';

  final List<Uri> requested = <Uri>[];

  /// Set once the user has "linked" the PIN in a browser.
  String? linkedToken;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri);
    final String? client =
        options.headers['X-Plex-Client-Identifier'] as String?;
    final String path = options.uri.path;

    if (path == '/api/v2/pins' && options.method == 'POST') {
      return _json('''
{"id":123456789,"code":"abcd","product":"Atrium","trusted":false,
 "clientIdentifier":"$client","expiresIn":1800,
 "expiresAt":"${DateTime.now().toUtc().add(const Duration(minutes: 30)).toIso8601String()}",
 "authToken":null,"newRegistration":null}
''');
    }

    if (path == '/api/v2/pins/123456789') {
      if (client != issuedTo) {
        return _text(404, '{"message":"Route not found"}');
      }
      final String token =
          linkedToken == null ? 'null' : '"${linkedToken!}"';
      return _json('{"id":123456789,"code":"abcd","authToken":$token}');
    }

    if (path == '/api/v2/resources') {
      if ((options.headers['X-Plex-Token'] as String?) != linkedToken ||
          linkedToken == null) {
        return _text(401, '{"error":"unauthorized"}');
      }
      return _json('''
[{"name":"Living Room","provides":"server","owned":true,
  "clientIdentifier":"aaa","accessToken":"server-token",
  "connections":[
    {"protocol":"http","address":"192.168.0.12","port":32400,
     "uri":"http://192.168.0.12:32400","local":true,"relay":false},
    {"protocol":"https","address":"1.2.3.4","port":32400,
     "uri":"https://1-2-3-4.abc.plex.direct:32400","local":false,
     "relay":false}]},
 {"name":"Someone's phone","provides":"player,controller","owned":false,
  "clientIdentifier":"bbb","accessToken":"","connections":[]}]
''');
    }

    return _text(404, '{"message":"Route not found"}');
  }

  ResponseBody _json(String body) => ResponseBody.fromString(
        body,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );

  ResponseBody _text(int status, String body) => ResponseBody.fromString(
        body,
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

PlexAccountApi _apiFor(_PlexTv plex, {String client = 'atrium-test'}) {
  final Dio dio = Dio()..httpClientAdapter = plex;
  return PlexAccountApi(clientIdentifier: client, dio: dio);
}

void main() {
  test('a fresh PIN carries its code and an expiry', () async {
    final _PlexTv plex = _PlexTv();
    final PlexPin pin = await _apiFor(plex).createPin();

    expect(pin.id, '123456789');
    expect(pin.code, 'abcd');
    expect(pin.hasExpired, isFalse);
    expect(plex.requested.single.queryParameters['strong'], 'true');
  });

  test('polling returns nothing until the user links it', () async {
    final _PlexTv plex = _PlexTv();
    final PlexAccountApi api = _apiFor(plex);
    final PlexPin pin = await api.createPin();

    expect(await api.pollPin(pin), isNull);

    plex.linkedToken = 'account-token';
    expect(await api.pollPin(pin), 'account-token');
  });

  test('a PIN issued to another install is not ours to poll', () async {
    final _PlexTv plex = _PlexTv();
    final PlexPin pin = await _apiFor(plex).createPin();
    final PlexAccountApi other = _apiFor(plex, client: 'somebody-else');

    // plex.tv answers 404 rather than 401, which would read as a bad token.
    await expectLater(
      other.pollPin(pin),
      throwsA(
        isA<PlexAccountException>().having(
          (PlexAccountException e) => e.message,
          'message',
          'Plex forgot this sign-in. Start again.',
        ),
      ),
    );
  });

  test('only the servers on the account come back', () async {
    final _PlexTv plex = _PlexTv()..linkedToken = 'account-token';
    final List<PlexServer> servers =
        await _apiFor(plex).getServers('account-token');

    // The account's phone provides "player,controller", not "server".
    expect(servers.map((PlexServer s) => s.name), <String>['Living Room']);
    expect(servers.single.accessToken, 'server-token');
    expect(servers.single.owned, isTrue);
    expect(servers.single.connections, hasLength(2));
  });

  test('listing servers without a token says so', () async {
    final _PlexTv plex = _PlexTv();
    await expectLater(
      _apiFor(plex).getServers('not-a-token'),
      throwsA(
        isA<PlexAccountException>().having(
          (PlexAccountException e) => e.message,
          'message',
          'Plex rejected the sign-in. Try signing in again.',
        ),
      ),
    );
  });

  test('the sign-in link carries the code so nobody has to type it', () {
    final Uri url = plexAuthUri(clientIdentifier: 'abc-123', code: 'wxyz');

    expect(url.origin, 'https://app.plex.tv');
    expect(url.path, '/auth');
    final Uri fragment = Uri.parse(url.fragment);
    expect(fragment.queryParameters['clientID'], 'abc-123');
    expect(fragment.queryParameters['code'], 'wxyz');
    expect(fragment.queryParameters['context[device][product]'], 'Atrium');
  });
}
