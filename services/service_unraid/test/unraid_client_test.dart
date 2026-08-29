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

    test('asks for all three disk lists, not just the data disks', () {
      // `disks` holds only the data disks, so a query that stops there loses
      // every parity and cache disk without reporting anything wrong.
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'data': <String, dynamic>{
              'array': <String, dynamic>{'state': 'STARTED'},
            },
          });

      return UnraidClient(dio).getArray().then((_) {
        expect(lastQuery, contains('parities'));
        expect(lastQuery, contains('caches'));
        expect(lastQuery, contains('parityCheckStatus'));
        expect(lastQuery, contains('capacity'));
      });
    });
  });

  group('successful reads', () {
    test('an array comes back with its disks, parity kept apart', () async {
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'data': <String, dynamic>{
              'array': <String, dynamic>{
                'state': 'STARTED',
                'parities': <dynamic>[
                  <String, dynamic>{
                    'name': 'parity',
                    'type': 'PARITY',
                    'size': 6291424,
                    'status': 'DISK_OK',
                    'temp': 31,
                  },
                ],
                'disks': <dynamic>[
                  <String, dynamic>{
                    'name': 'disk1',
                    'type': 'DATA',
                    'size': 3145696,
                    'status': 'DISK_OK',
                    'temp': 42,
                  },
                  <String, dynamic>{
                    'name': 'disk2',
                    'type': 'DATA',
                    'size': 2097152,
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
      expect(array.parities.single.name, 'parity');
      expect(array.disks.first.sizeLabel, '3.0 GB');
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

    test('a key without the permission is told what is wrong', () async {
      // Unraid keys are scoped per resource, so a key that reads the array
      // fine can still be refused on a mutation. The raw "Forbidden resource"
      // gives nobody anything to act on.
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'errors': <dynamic>[
              <String, dynamic>{
                'message': 'Forbidden resource',
                'extensions': <String, dynamic>{'code': 'FORBIDDEN'},
              },
            ],
          });

      await expectLater(
        UnraidClient(dio).startContainer('srv:c1'),
        throwsA(
          isA<NetworkException>().having(
            (NetworkException e) => e.message,
            'message',
            contains('permission'),
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

  group('container actions', () {
    /// Answers every lifecycle mutation with the container in [state].
    void answerWith(String state) {
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'data': <String, dynamic>{
              'docker': <String, dynamic>{
                // The field name matches the mutation, so read it back off the
                // query rather than hard-coding one action's shape.
                if (lastQuery?.contains('start(') ?? false)
                  'start': <String, dynamic>{
                    'id': 'srv:c1',
                    'names': <dynamic>['/sonarr'],
                    'state': state,
                    'status': 'Up Less than a second',
                  },
                if (lastQuery?.contains('stop(') ?? false)
                  'stop': <String, dynamic>{
                    'id': 'srv:c1',
                    'names': <dynamic>['/sonarr'],
                    'state': state,
                    'status': 'Exited (0) 1 second ago',
                  },
              },
            },
          });
    }

    test('starting sends the id as a variable, not spliced into the query',
        () async {
      answerWith('RUNNING');

      final UnraidContainer c =
          await UnraidClient(dio).startContainer('srv:c1');

      expect(lastQuery, contains(r'$id: PrefixedID!'));
      expect(lastQuery, contains('start(id:'));
      expect(c.isRunning, isTrue);
    });

    test('stopping reads the new state back rather than refetching', () async {
      // The list takes a moment to catch up, and showing the old state right
      // after acting reads as the action having failed.
      answerWith('EXITED');

      final UnraidContainer c = await UnraidClient(dio).stopContainer('srv:c1');

      expect(lastQuery, contains('stop(id:'));
      expect(c.isRunning, isFalse);
      expect(c.displayName, 'sonarr');
    });

    test('an answer with no container is raised, not read as success',
        () async {
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'data': <String, dynamic>{'docker': <String, dynamic>{}},
          });

      await expectLater(
        UnraidClient(dio).startContainer('srv:c1'),
        throwsA(isA<NetworkException>()),
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

  group('virtual machine actions', () {
    /// The field names, the argument name and its type were read off a live
    /// server by probing, because the API refuses introspection. Getting one
    /// wrong is a request the server rejects outright, and nothing else in the
    /// suite would notice, so they are pinned here.
    const Map<String, String> actions = <String, String>{
      'start': 'start',
      'stop': 'stop',
      'pause': 'pause',
      'resume': 'resume',
      'reboot': 'reboot',
      'forceStop': 'forceStop',
      'reset': 'reset',
    };

    Future<bool> callByName(UnraidClient c, String name, String id) =>
        switch (name) {
          'start' => c.startVm(id),
          'stop' => c.stopVm(id),
          'pause' => c.pauseVm(id),
          'resume' => c.resumeVm(id),
          'reboot' => c.rebootVm(id),
          'forceStop' => c.forceStopVm(id),
          _ => c.resetVm(id),
        };

    for (final MapEntry<String, String> e in actions.entries) {
      test('${e.key} asks for vm { ${e.value} } with a PrefixedID', () async {
        respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
              'data': <String, dynamic>{
                'vm': <String, dynamic>{e.value: true},
              },
            });

        final bool ok = await callByName(UnraidClient(dio), e.key, 'srv/vm-1');

        expect(ok, isTrue);
        expect(lastQuery, contains('mutation(\$id: PrefixedID!)'));
        expect(lastQuery, contains('vm { ${e.value}(id: \$id) }'));
      });
    }

    test('a refusal is reported rather than read as success', () async {
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'errors': <dynamic>[
              <String, dynamic>{'message': 'VMs are not available'},
            ],
          });

      await expectLater(
        UnraidClient(dio).startVm('srv/vm-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('an explicit false is carried back, not swallowed', () async {
      respond = (HttpRequest req) => writeJson(req, <String, dynamic>{
            'data': <String, dynamic>{
              'vm': <String, dynamic>{'stop': false},
            },
          });

      expect(await UnraidClient(dio).stopVm('srv/vm-1'), isFalse);
    });
  });
}
