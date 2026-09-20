import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_plex/service_plex.dart';

/// plex.tv, with the linking step under the test's control.
class _PlexTv implements HttpClientAdapter {
  String? linkedToken;
  bool serversFail = false;

  static const String _servers = '''
[{"name":"Living Room","provides":"server","owned":true,
  "clientIdentifier":"aaa","accessToken":"server-token",
  "connections":[
    {"protocol":"http","address":"192.168.0.12","port":32400,
     "uri":"http://192.168.0.12:32400","local":true,"relay":false},
    {"protocol":"https","address":"10.0.0.1","port":443,
     "uri":"https://abc.plex.direct:443","local":false,"relay":true}]}]
''';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.uri.path;
    if (path == '/api/v2/pins' && options.method == 'POST') {
      return _body(
        200,
        '{"id":1,"code":"abcd","expiresIn":1800,"authToken":null}',
      );
    }
    if (path == '/api/v2/pins/1') {
      final String token = linkedToken == null ? 'null' : '"$linkedToken"';
      return _body(200, '{"id":1,"code":"abcd","authToken":$token}');
    }
    if (path == '/api/v2/resources') {
      return serversFail ? _body(500, '{"error":"boom"}') : _body(200, _servers);
    }
    return _body(404, '{"message":"Route not found"}');
  }

  ResponseBody _body(int status, String body) => ResponseBody.fromString(
        body,
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late _PlexTv plex;
  late List<Uri> opened;
  late List<PlexSignInResult?> results;

  setUp(() {
    plex = _PlexTv();
    opened = <Uri>[];
    results = <PlexSignInResult?>[];
  });

  /// The sheet spins a progress indicator while it waits, so the tree never
  /// goes quiet and `pumpAndSettle` would sit there until it gave up.
  Future<void> advance(
    WidgetTester tester, [
    Duration step = const Duration(milliseconds: 400),
  ]) async {
    await tester.pump();
    await tester.pump(step);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  results.add(
                    await showPlexSignInSheet(
                      context: context,
                      clientIdentifier: 'atrium-test',
                      apiFactory: () => PlexAccountApi(
                        clientIdentifier: 'atrium-test',
                        dio: Dio()..httpClientAdapter = plex,
                      ),
                      launch: (Uri url) async {
                        opened.add(url);
                        return true;
                      },
                      probe: (PlexServer server) async =>
                          resolvePlexServerUrls(server),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await advance(tester);
    await advance(tester);
  }

  /// Links the PIN the way a user would in their browser, then lets the next
  /// poll pick it up.
  Future<void> link(WidgetTester tester, String token) async {
    plex.linkedToken = token;
    await tester.pump(const Duration(seconds: 2));
    await advance(tester);
    await advance(tester);
  }

  testWidgets('the browser opens on its own, with the link to fall back on',
      (WidgetTester tester) async {
    await openSheet(tester);

    expect(opened, hasLength(1));
    expect(opened.single.origin, 'https://app.plex.tv');
    expect(find.text('Waiting for Plex'), findsOneWidget);

    // plex.tv/link only takes the four character kind of code, and this one
    // is a strong PIN, so the fallback has to be the link itself.
    expect(find.textContaining('plex.tv/link'), findsNothing);
    expect(find.text('Copy the sign-in link'), findsOneWidget);
  });

  testWidgets('picking a server hands back its own token and both URLs',
      (WidgetTester tester) async {
    await openSheet(tester);
    await link(tester, 'account-token');

    expect(find.text('Living Room'), findsOneWidget);
    // The row lists what Plex advertises: a LAN address and a relay, with no
    // public address of its own.
    expect(find.text('local • relay'), findsOneWidget);

    await tester.tap(find.text('Living Room'));
    await advance(tester);
    await advance(tester);

    final PlexSignInResult result = results.single!;
    expect(result.token, 'server-token');
    expect(result.localUrl, 'http://192.168.0.12:32400');
    expect(result.externalUrl, 'https://abc.plex.direct:443');
    expect(result.usesRelay, isTrue);
    expect(result.serverName, 'Living Room');
  });

  testWidgets('a failed server list still leaves the token in hand',
      (WidgetTester tester) async {
    plex.serversFail = true;
    await openSheet(tester);
    await link(tester, 'account-token');

    expect(find.textContaining('HTTP 500'), findsOneWidget);

    await tester.tap(find.text('Just use the token'));
    await advance(tester);
    await advance(tester);

    final PlexSignInResult result = results.single!;
    expect(result.token, 'account-token');
    expect(result.localUrl, isNull);
    expect(result.externalUrl, isNull);
  });
}
