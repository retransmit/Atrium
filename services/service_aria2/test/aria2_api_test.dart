import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_aria2/service_aria2.dart';

import 'support/fake_http_client_adapter.dart';

Aria2Api _api(
  ({int status, Object? data}) Function(RequestOptions) factory, {
  String secret = '',
  List<RequestOptions>? log,
}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://aria2.local:6800/'));
  dio.httpClientAdapter = FakeHttpClientAdapter(factory);
  if (log != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions o, RequestInterceptorHandler h) {
          log.add(o);
          h.next(o);
        },
      ),
    );
  }
  return Aria2Api(dio, secret: secret);
}

Map<String, dynamic> _body(RequestOptions o) =>
    jsonDecode(o.data is String ? o.data as String : jsonEncode(o.data))
        as Map<String, dynamic>;

/// One download as aria2 sends it: every number is a string.
Map<String, dynamic> _download({
  String gid = '2089b05ecca3d829',
  String status = 'active',
  String total = '1000',
  String completed = '250',
  String speed = '100',
}) {
  return <String, dynamic>{
    'gid': gid,
    'status': status,
    'totalLength': total,
    'completedLength': completed,
    'uploadLength': '0',
    'downloadSpeed': speed,
    'uploadSpeed': '0',
    'connections': '4',
    'numSeeders': '0',
    'seeder': 'false',
    'errorCode': '0',
    'errorMessage': '',
    'dir': '/downloads',
    'files': <Map<String, dynamic>>[
      <String, dynamic>{
        'index': '0',
        'path': '/downloads/big.iso',
        'length': total,
        'completedLength': completed,
        'selected': 'true',
        'uris': <Map<String, dynamic>>[
          <String, dynamic>{'uri': 'https://host/big.iso', 'status': 'used'},
        ],
      },
    ],
  };
}

void main() {
  test(
    'getSnapshot batches the five calls into one system.multicall',
    () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final Aria2Api api = _api(
        (RequestOptions o) => (
          status: 200,
          data: <String, dynamic>{
            'id': 'atrium',
            'jsonrpc': '2.0',
            'result': <dynamic>[
              <dynamic>[
                <String, dynamic>{
                  'downloadSpeed': '2048',
                  'uploadSpeed': '64',
                  'numActive': '1',
                  'numWaiting': '0',
                  'numStopped': '1',
                  'numStoppedTotal': '7',
                },
              ],
              <dynamic>[
                <String, dynamic>{
                  'version': '1.37.0',
                  'enabledFeatures': <String>['HTTP', 'BitTorrent'],
                },
              ],
              // The three list calls come back as a one-item array holding the
              // array of downloads.
              <dynamic>[
                <dynamic>[_download()],
              ],
              <dynamic>[],
              <dynamic>[
                <dynamic>[_download(gid: 'aaaa', status: 'complete')],
              ],
            ],
          },
        ),
        log: log,
      );

      final Aria2Snapshot snapshot = await api.getSnapshot();

      expect(log.single.path, 'jsonrpc');
      expect(log.single.method, 'POST');
      final Map<String, dynamic> body = _body(log.single);
      expect(body['method'], 'system.multicall');
      expect(body['jsonrpc'], '2.0');
      expect(body['id'], isNotNull);

      final List<dynamic> calls =
          (body['params'] as List<dynamic>).single as List<dynamic>;
      expect(
        calls.map((dynamic c) => (c as Map<String, dynamic>)['methodName']),
        <String>[
          'aria2.getGlobalStat',
          'aria2.getVersion',
          'aria2.tellActive',
          'aria2.tellWaiting',
          'aria2.tellStopped',
        ],
      );

      // Verify that snapshotKeys and offset -1 are passed to avoid transferring heavy fields
      expect(
        (calls[2] as Map<String, dynamic>)['params'],
        <dynamic>[Aria2Api.snapshotKeys],
      );
      expect(
        (calls[3] as Map<String, dynamic>)['params'],
        <dynamic>[0, 1000, Aria2Api.snapshotKeys],
      );
      expect(
        (calls[4] as Map<String, dynamic>)['params'],
        <dynamic>[-1, 200, Aria2Api.snapshotKeys],
      );

      // The daemon's own numbers arrive as strings.
      expect(snapshot.stat.downloadSpeed, 2048);
      expect(snapshot.stat.numStoppedTotal, 7);
      expect(snapshot.version.version, '1.37.0');
      expect(snapshot.version.enabledFeatures, <String>['HTTP', 'BitTorrent']);
      expect(snapshot.active.single.gid, '2089b05ecca3d829');
      expect(snapshot.active.single.progress, closeTo(0.25, 0.001));
      expect(snapshot.stopped.single.gid, 'aaaa');
    },
  );

  test(
    'the secret rides in the nested calls, not on the multicall itself',
    () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final Aria2Api api = _api(
        (RequestOptions o) => (
          status: 200,
          data: <String, dynamic>{
            'result': <dynamic>[
              <dynamic>[<String, dynamic>{}],
              <dynamic>[<String, dynamic>{}],
              <dynamic>[],
              <dynamic>[],
              <dynamic>[],
            ],
          },
        ),
        secret: 'hunter2',
        log: log,
      );
      await api.getSnapshot();

      final Map<String, dynamic> body = _body(log.single);
      expect(body['params'], isNot(contains('token:hunter2')));
      final List<dynamic> calls =
          (body['params'] as List<dynamic>).single as List<dynamic>;
      for (final dynamic call in calls) {
        final List<dynamic> params =
            (call as Map<String, dynamic>)['params'] as List<dynamic>;
        expect(params.first, 'token:hunter2');
      }
    },
  );

  test('without a secret no token parameter is sent at all', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) =>
          (status: 200, data: <String, dynamic>{'result': <String, dynamic>{}}),
      log: log,
    );
    await api.getVersion();
    expect(_body(log.single)['params'], isEmpty);
  });

  test('an error envelope throws Aria2RpcException with the message', () async {
    final Aria2Api api = _api(
      (RequestOptions o) => (
        status: 200,
        data: <String, dynamic>{
          'id': 'atrium',
          'jsonrpc': '2.0',
          'error': <String, dynamic>{'code': 1, 'message': 'Unauthorized'},
        },
      ),
    );
    expect(
      api.getVersion,
      throwsA(
        predicate(
          (Object? e) => e is Aria2RpcException && e.message == 'Unauthorized',
        ),
      ),
    );
  });

  test(
    'a refused secret (HTTP 400) still surfaces the daemon\'s message',
    () async {
      final Aria2Api api = _api(
        (RequestOptions o) => (
          status: 400,
          data: <String, dynamic>{
            'id': 'atrium',
            'jsonrpc': '2.0',
            'error': <String, dynamic>{'code': 1, 'message': 'Unauthorized'},
          },
        ),
      );
      expect(
        api.getVersion,
        throwsA(
          predicate(
            (Object? e) =>
                e is Aria2RpcException && e.message == 'Unauthorized',
          ),
        ),
      );
    },
  );

  test('a fault struct inside a multicall answer throws', () async {
    final Aria2Api api = _api(
      (RequestOptions o) => (
        status: 200,
        data: <String, dynamic>{
          'result': <dynamic>[
            <String, dynamic>{'code': 1, 'message': 'Unauthorized'},
            <dynamic>[],
            <dynamic>[],
            <dynamic>[],
            <dynamic>[],
          ],
        },
      ),
    );
    expect(api.getSnapshot, throwsA(isA<Aria2RpcException>()));
  });

  test('only a missing GID reads as gone, not any code 1', () {
    // aria2 sends code 1 for every failure, a refused secret included.
    expect(
      const Aria2RpcException('GID 2089b05ecca3d829 is not found', code: 1)
          .isGidNotFound,
      isTrue,
    );
    expect(
      const Aria2RpcException('Unauthorized', code: 1).isGidNotFound,
      isFalse,
    );
    expect(
      const Aria2RpcException('Invalid GID xyz', code: 1).isGidNotFound,
      isFalse,
    );
  });

  test('addUri sends the uris and options and returns the new gid', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) =>
          (status: 200, data: <String, dynamic>{'result': '2089b05ecca3d829'}),
      log: log,
    );
    final String gid = await api.addUri(
      <String>['https://host/file.iso'],
      options: <String, String>{'dir': '/downloads', 'pause': 'true'},
    );
    expect(gid, '2089b05ecca3d829');
    final Map<String, dynamic> body = _body(log.single);
    expect(body['method'], 'aria2.addUri');
    expect(body['params'], <dynamic>[
      <String>['https://host/file.iso'],
      <String, String>{'dir': '/downloads', 'pause': 'true'},
    ]);
  });

  test('addTorrent sends the base64 payload and the source list', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) =>
          (status: 200, data: <String, dynamic>{'result': 'abc123'}),
      log: log,
    );
    await api.addTorrent('ZDE2aXQ=');
    final Map<String, dynamic> body = _body(log.single);
    expect(body['method'], 'aria2.addTorrent');
    // The list of sources goes out even when it is empty: aria2 reads the
    // options by position, so leaving the list out would hand it the options
    // as the list of sources and it would answer 'The parameter at 1 has
    // wrong type.'
    expect(body['params'], <dynamic>['ZDE2aXQ=', <String>[]]);
  });

  test(
    'addTorrent keeps the options in the slot aria2 reads them from',
    () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final Aria2Api api = _api(
        (RequestOptions o) =>
            (status: 200, data: <String, dynamic>{'result': 'abc123'}),
        log: log,
      );
      await api.addTorrent(
        'ZDE2aXQ=',
        options: <String, String>{'dir': '/downloads'},
      );
      expect(_body(log.single)['params'], <dynamic>[
        'ZDE2aXQ=',
        <String>[],
        <String, String>{'dir': '/downloads'},
      ]);

      await api.addTorrent(
        'ZDE2aXQ=',
        uris: <String>['https://seed/file.iso'],
        options: <String, String>{'dir': '/downloads'},
        position: 2,
      );
      expect(_body(log.last)['params'], <dynamic>[
        'ZDE2aXQ=',
        <String>['https://seed/file.iso'],
        <String, String>{'dir': '/downloads'},
        2,
      ]);

      // A position without options still needs the empty options in front of
      // it, or the position lands in the options' slot.
      await api.addTorrent('ZDE2aXQ=', position: 3);
      expect(_body(log.last)['params'], <dynamic>[
        'ZDE2aXQ=',
        <String>[],
        <String, String>{},
        3,
      ]);
    },
  );

  test('addUri keeps the position in the slot aria2 reads it from', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) =>
          (status: 200, data: <String, dynamic>{'result': 'abc123'}),
      log: log,
    );
    await api.addUri(<String>['https://host/file.iso'], position: 1);
    expect(_body(log.single)['params'], <dynamic>[
      <String>['https://host/file.iso'],
      <String, String>{},
      1,
    ]);
  });

  test('the daemon-wide commands use the documented method names', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) =>
          (status: 200, data: <String, dynamic>{'result': 'OK'}),
      log: log,
    );
    await api.pauseAll();
    await api.unpauseAll();
    await api.purgeDownloadResult();
    await api.setGlobalDownloadLimit(1024 * 1024);
    await api.changePosition('gid1', 0, 'POS_SET');
    await api.removeDownloadResult('gid2');

    expect(log.map((RequestOptions o) => _body(o)['method']), <String>[
      'aria2.pauseAll',
      'aria2.unpauseAll',
      'aria2.purgeDownloadResult',
      'aria2.changeGlobalOption',
      'aria2.changePosition',
      'aria2.removeDownloadResult',
    ]);
    expect((_body(log[3])['params'] as List<dynamic>).single, <String, String>{
      'max-overall-download-limit': '1048576',
    });
    expect(_body(log[4])['params'], <dynamic>['gid1', 0, 'POS_SET']);
  });

  test('the secret is prepended to a plain call', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) => (
        status: 200,
        data: <String, dynamic>{
          'result': <String, dynamic>{'version': '1.37.0'},
        },
      ),
      secret: 's3cret',
      log: log,
    );
    await api.getVersion();
    expect(_body(log.single)['params'], <dynamic>['token:s3cret']);
  });

  test('tellStatus asks for one download by gid', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) =>
          (status: 200, data: <String, dynamic>{'result': _download()}),
      log: log,
    );
    final Aria2Download download = await api.tellStatus('2089b05ecca3d829');
    expect(_body(log.single)['method'], 'aria2.tellStatus');
    expect(_body(log.single)['params'], <dynamic>['2089b05ecca3d829']);
    expect(download.gid, '2089b05ecca3d829');
  });

  test('a body that is not JSON is reported as such', () async {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://aria2.local:6800/'));
    dio.httpClientAdapter = FakeHttpClientAdapter(
      (RequestOptions o) => (status: 200, data: 'not json at all'),
    );
    // The fake encodes its payload as JSON, so a string body arrives as a
    // JSON string literal - which is what the decoder has to survive.
    final Aria2Api api = Aria2Api(dio);
    expect(api.getVersion, throwsA(isA<Aria2RpcException>()));
  });

  test('getPeers parses peer list', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) => (
        status: 200,
        data: <String, dynamic>{
          'result': <dynamic>[
            <String, dynamic>{
              'peerId': 'peer123',
              'ip': '1.2.3.4',
              'port': '6881',
              'bitfield': 'ff',
              'amChoking': 'false',
              'peerChoking': 'false',
              'downloadSpeed': '1024',
              'uploadSpeed': '512',
              'seeder': 'true',
            },
          ],
        },
      ),
      log: log,
    );
    final List<Aria2Peer> peers = await api.getPeers('2089b05ecca3d829');
    expect(_body(log.single)['method'], 'aria2.getPeers');
    expect(peers.length, 1);
    expect(peers.first.ip, '1.2.3.4');
    expect(peers.first.port, 6881);
    expect(peers.first.seeder, true);
    expect(peers.first.downloadSpeed, 1024);
  });

  test('getServers parses connected servers', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) => (
        status: 200,
        data: <String, dynamic>{
          'result': <dynamic>[
            <String, dynamic>{
              'index': '1',
              'servers': <dynamic>[
                <String, dynamic>{
                  'uri': 'http://mirror1.com/file',
                  'currentUri': 'http://mirror1.com/file',
                  'downloadSpeed': '5000',
                },
              ],
            },
          ],
        },
      ),
      log: log,
    );
    final List<Aria2Server> servers = await api.getServers('2089b05ecca3d829');
    expect(_body(log.single)['method'], 'aria2.getServers');
    expect(servers.length, 1);
    expect(servers.first.servers.first.uri, 'http://mirror1.com/file');
    expect(servers.first.servers.first.downloadSpeed, 5000);
  });

  test(
    'saveSession, shutdown, and forcePauseAll call expected RPC methods',
    () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final Aria2Api api = _api(
        (RequestOptions o) =>
            (status: 200, data: <String, dynamic>{'result': 'OK'}),
        log: log,
      );
      await api.saveSession();
      await api.shutdown();
      await api.forceShutdown();
      await api.forcePauseAll();

      expect(_body(log[0])['method'], 'aria2.saveSession');
      expect(_body(log[1])['method'], 'aria2.shutdown');
      expect(_body(log[2])['method'], 'aria2.forceShutdown');
      expect(_body(log[3])['method'], 'aria2.forcePauseAll');
    },
  );

  test(
    'changeUri sends proper arguments and returns deleted/added counts',
    () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final Aria2Api api = _api(
        (RequestOptions o) => (
          status: 200,
          data: <String, dynamic>{
            'result': <dynamic>[1, 2],
          },
        ),
        log: log,
      );
      final List<int> res = await api.changeUri(
        'gid123',
        1,
        delUris: <String>['http://old.com'],
        addUris: <String>['http://new1.com', 'http://new2.com'],
      );
      expect(_body(log.single)['method'], 'aria2.changeUri');
      expect(res, <int>[1, 2]);
    },
  );

  test('addUri accepts header list in options map', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final Aria2Api api = _api(
      (RequestOptions o) =>
          (status: 200, data: <String, dynamic>{'result': 'gid123'}),
      log: log,
    );
    await api.addUri(
      <String>['https://host/file.iso'],
      options: <String, dynamic>{
        'header': <String>['Authorization: Bearer xyz', 'Cookie: session=1'],
      },
    );
    final Map<String, dynamic> body = _body(log.single);
    expect(body['params'], <dynamic>[
      <String>['https://host/file.iso'],
      <String, dynamic>{
        'header': <String>['Authorization: Bearer xyz', 'Cookie: session=1'],
      },
    ]);
  });

  test(
    'pauseGids batches calls in multicall and reports success and fault counts',
    () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final Aria2Api api = _api(
        (RequestOptions o) => (
          status: 200,
          data: <String, dynamic>{
            'result': <dynamic>[
              <dynamic>['OK'],
              // A failed call, in the shape aria2 sends it over JSON-RPC.
              <String, dynamic>{
                'code': 1,
                'message': 'GID gid2 is not found',
              },
            ],
          },
        ),
        log: log,
      );
      final ({int succeeded, int failed}) res = await api.pauseGids(<String>[
        'gid1',
        'gid2',
      ]);
      expect(res.succeeded, 1);
      expect(res.failed, 1);

      final Map<String, dynamic> body = _body(log.single);
      expect(body['method'], 'system.multicall');
      final List<dynamic> calls =
          (body['params'] as List<dynamic>).single as List<dynamic>;
      expect(calls.length, 2);
      expect((calls[0] as Map<String, dynamic>)['methodName'], 'aria2.pause');
      expect((calls[0] as Map<String, dynamic>)['params'], <dynamic>['gid1']);
      expect((calls[1] as Map<String, dynamic>)['methodName'], 'aria2.pause');
      expect((calls[1] as Map<String, dynamic>)['params'], <dynamic>['gid2']);
    },
  );

  test(
    'removeGids batches remove for active and removeDownloadResult for stopped',
    () async {
      final List<RequestOptions> log = <RequestOptions>[];
      final Aria2Api api = _api(
        (RequestOptions o) => (
          status: 200,
          data: <String, dynamic>{
            'result': <dynamic>[
              <dynamic>['OK'],
              <dynamic>['OK'],
            ],
          },
        ),
        log: log,
      );
      final ({int succeeded, int failed}) res = await api.removeGids(
        activeOrWaitingGids: <String>['live1'],
        stoppedGids: <String>['stopped1'],
      );
      expect(res.succeeded, 2);
      expect(res.failed, 0);

      final Map<String, dynamic> body = _body(log.single);
      expect(body['method'], 'system.multicall');
      final List<dynamic> calls =
          (body['params'] as List<dynamic>).single as List<dynamic>;
      expect(calls.length, 2);
      expect((calls[0] as Map<String, dynamic>)['methodName'], 'aria2.remove');
      expect((calls[0] as Map<String, dynamic>)['params'], <dynamic>['live1']);
      expect(
        (calls[1] as Map<String, dynamic>)['methodName'],
        'aria2.removeDownloadResult',
      );
      expect(
        (calls[1] as Map<String, dynamic>)['params'],
        <dynamic>['stopped1'],
      );
    },
  );
}
