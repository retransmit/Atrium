import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_unraid/service_unraid.dart';

/// Drives [UnraidClient] over real HTTP against a stand-in server.
///
/// The model tests cover parsing from fixed JSON. These cover the parts that
/// only exist once a request is actually on the wire: the shape of the POST,
/// and what happens when the server answers 200 while refusing the request,
/// which is GraphQL's normal way of reporting failure.
void main() {
  late HttpServer server;
  late Dio dio;

  /// Set by each test to decide what the server answers.
  late FutureOr<void> Function(HttpRequest req) respond;

  /// What the last request carried, so the wire format can be asserted.
  String? lastMethod;
  String? lastPath;
  String? lastContentType;
  String? lastQuery;

  void writeJson(HttpRequest req, Object payload, {int status = 200}) {
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
  }

  setUp(() async {
    lastMethod = lastPath = lastContentType = lastQuery = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((HttpRequest req) async {
        final String body = await utf8.decoder.bind(req).join();
        lastMethod = req.method;
        lastPath = req.uri.path;
        lastContentType = req.headers.contentType?.mimeType;
        try {
          lastQuery =
              (jsonDecode(body) as Map<String, dynamic>)['query'] as String?;
        } on FormatException {
          lastQuery = null;
        }
        await respond(req);
        await req.response.close();
      }),
    );
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}/'));
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
  });

  group('the request Unraid receives', () {
    test('is a POST to /graphql carrying the query as JSON', () async {
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'data': <String, dynamic>{
              'array': <String, dynamic>{'state': 'STARTED'},
            },
          });

      await UnraidClient(dio).getArray();

      expect(lastMethod, 'POST');
      expect(lastPath, '/graphql');
      expect(lastContentType, 'application/json');
      expect(lastQuery, contains('array'));
      expect(lastQuery, contains('disks'));
    });
  });

  group('successful reads', () {
    test('an array comes back with its disks', () async {
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'data': <String, dynamic>{
              'array': <String, dynamic>{
                'state': 'STARTED',
                'disks': <dynamic>[
                  <String, dynamic>{
                    'name': 'disk1',
                    'size': '3 TB',
                    'status': 'DISK_OK',
                    'temp': 42,
                  },
                  <String, dynamic>{
                    'name': 'disk2',
                    'size': '2 TB',
                    'status': 'DISK_DSBL',
                    'temp': 39,
                  },
                ],
              },
            },
          });

      final UnraidArray array = await UnraidClient(dio).getArray();

      expect(array.isStarted, isTrue);
      expect(array.disks, hasLength(2));
      expect(array.unhealthyDisks.single.name, 'disk2');
    });

    test('containers come back from under docker, not the top level', () async {
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'data': <String, dynamic>{
              'docker': <String, dynamic>{
                'containers': <dynamic>[
                  <String, dynamic>{
                    'id': 'a1',
                    'names': <dynamic>['/plex'],
                    'state': 'RUNNING',
                    'status': 'Up 3 hours (unhealthy)',
                    'autoStart': true,
                  },
                ],
              },
            },
          });

      final List<UnraidContainer> containers =
          await UnraidClient(dio).getContainers();

      expect(lastQuery, contains('docker'));
      expect(containers.single.displayName, 'plex');
      expect(containers.single.isUnhealthy, isTrue);
    });

    test('a server with no containers is empty, not an error', () async {
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'data': <String, dynamic>{
              'docker': <String, dynamic>{'containers': <dynamic>[]},
            },
          });

      expect(await UnraidClient(dio).getContainers(), isEmpty);
    });
  });

  group('failures that arrive as HTTP 200', () {
    test('a refused API key is raised, not read as an empty result', () async {
      // The case this whole guard exists for: Unraid returns 200 and puts the
      // refusal in the body, so anything checking only the status believes it.
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'errors': <dynamic>[
              <String, dynamic>{'message': 'Unauthorized'},
            ],
          });

      await expectLater(
        UnraidClient(dio).getArray(),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.toString(),
            'message',
            contains('Unauthorized'),
          ),
        ),
      );
    });

    test('a proxy error page is called out as not being the server', () async {
      respond = (HttpRequest req) {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('<html>502 Bad Gateway</html>');
      };

      await expectLater(
        UnraidClient(dio).getArray(),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.toString(),
            'message',
            contains('proxy'),
          ),
        ),
      );
    });

    test('a key that cannot read the array says so', () async {
      respond = (HttpRequest req) =>
          writeJson(req, <String, dynamic>{'data': <String, dynamic>{}});

      await expectLater(
        UnraidClient(dio).getArray(),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.toString(),
            'message',
            contains('permission'),
          ),
        ),
      );
    });
  });

  group('transport failures', () {
    test('an HTTP error becomes a NetworkException', () async {
      respond = (HttpRequest req) => writeJson(
            req,
            <String, dynamic>{'errors': <dynamic>[]},
            status: 500,
          );

      await expectLater(
        UnraidClient(dio).getArray(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('an unreachable server becomes a NetworkException', () async {
      await server.close(force: true);

      await expectLater(
        UnraidClient(dio).getArray(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
