import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_technitium/service_technitium.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.handler);
  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? data, [int status = 200]) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );
}

void main() {
  group('TechnitiumApi', () {
    test('getStatus returns TechnitiumStatus', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          expect(opt.path, 'api/status');
          return _json(<String, dynamic>{
            'status': 'ok',
            'response': <String, dynamic>{
              'version': '13.0.0',
              'uptime': 3600,
            },
          });
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      final TechnitiumStatus status = await api.getStatus();
      expect(status.version, '13.0.0');
      expect(status.uptimeSeconds, 3600);
    });

    test('getStats fetches dashboard statistics', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          expect(opt.path, 'api/dashboard/stats/get');
          expect(opt.queryParameters['type'], 'LastDay');
          return _json(<String, dynamic>{
            'status': 'ok',
            'response': <String, dynamic>{
              'stats': <String, dynamic>{
                'totalQueries': 500,
                'blockedQueries': 50,
              },
            },
          });
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      final TechnitiumStats stats = await api.getStats();
      expect(stats.totalQueries, 500);
      expect(stats.blockedQueries, 50);
    });

    test('getSettings fetches configuration', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          expect(opt.path, 'api/settings/get');
          return _json(<String, dynamic>{
            'status': 'ok',
            'response': <String, dynamic>{
              'enableBlocking': true,
              'blockingType': 'NxDomain',
            },
          });
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      final TechnitiumSettings settings = await api.getSettings();
      expect(settings.enableBlocking, isTrue);
      expect(settings.blockingType, 'NxDomain');
    });

    test('mutations call expected endpoints', () async {
      final List<String> calledPaths = <String>[];
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          calledPaths.add(opt.path);
          return _json(<String, dynamic>{'status': 'ok'});
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      await api.setBlocking(enabled: true);
      await api.temporaryDisableBlocking(minutes: 10);
      await api.forceUpdateBlockLists();
      await api.flushDnsCache();
      await api.addBlockedZone('bad.com');
      await api.deleteBlockedZone('bad.com');

      expect(calledPaths, <String>[
        'api/settings/set',
        'api/settings/temporaryDisableBlocking',
        'api/settings/forceUpdateBlockLists',
        'api/cache/flush',
        'api/blocked/add',
        'api/blocked/delete',
      ]);
    });

    test('listBlockedZones parses api/blocked/export plain text', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          expect(opt.path, 'api/blocked/export');
          return ResponseBody.fromString(
            'ads.example.com\ntelemetry.example.com\n',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['text/plain'],
            },
          );
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      final List<TechnitiumBlockedZone> zones = await api.listBlockedZones();
      expect(zones.length, 2);
      expect(zones[0].domain, 'ads.example.com');
      expect(zones[1].domain, 'telemetry.example.com');
    });

    test('listBlockedZones falls back to api/blocked/list object shape',
        () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          if (opt.path == 'api/blocked/export') {
            return ResponseBody.fromString('Not Found', 404);
          }
          expect(opt.path, 'api/blocked/list');
          return _json(<String, dynamic>{
            'status': 'ok',
            'response': <String, dynamic>{
              'domain': '',
              'zones': <String>['ads.example.com', 'tracker.example.com'],
              'records': <dynamic>[],
            },
          });
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      final List<TechnitiumBlockedZone> zones = await api.listBlockedZones();
      expect(zones.length, 2);
      expect(zones[0].domain, 'ads.example.com');
      expect(zones[1].domain, 'tracker.example.com');
    });

    test('getQueryLogs discovers query logger app and passes parameters',
        () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          if (opt.path == 'api/apps/list') {
            return _json(<String, dynamic>{
              'status': 'ok',
              'response': <String, dynamic>{
                'apps': <dynamic>[
                  <String, dynamic>{
                    'name': 'Query Logs (Sqlite)',
                    'dnsApps': <dynamic>[
                      <String, dynamic>{
                        'classPath': 'QueryLogsSqlite.App',
                        'isQueryLogger': true,
                      },
                    ],
                  },
                ],
              },
            });
          }
          expect(opt.path, 'api/logs/query');
          expect(opt.queryParameters['name'], 'Query Logs (Sqlite)');
          expect(opt.queryParameters['classPath'], 'QueryLogsSqlite.App');
          expect(opt.queryParameters['pageNumber'], 2);
          expect(opt.queryParameters['filter'], 'Blocked');
          return _json(<String, dynamic>{
            'status': 'ok',
            'response': <String, dynamic>{
              'pageNumber': 2,
              'totalPages': 4,
              'totalEntries': 100,
              'entries': <dynamic>[],
            },
          });
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      final TechnitiumQueryLogPage page = await api.getQueryLogs(
        pageNumber: 2,
        filter: 'Blocked',
      );
      expect(page.pageNumber, 2);
      expect(page.totalPages, 4);
    });

    test('throws TechnitiumAuthException on token failure', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          return _json(<String, dynamic>{
            'status': 'error',
            'errorMessage': 'Invalid token provided',
          });
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      expect(
        api.getStatus,
        throwsA(isA<TechnitiumAuthException>()),
      );
    });

    test('throws TechnitiumAuthException on invalid-token status', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          return _json(<String, dynamic>{
            'status': 'invalid-token',
          });
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      expect(
        api.getSettings,
        throwsA(isA<TechnitiumAuthException>()),
      );
    });

    test('throws TechnitiumAuthException on 401 HTTP status', () async {
      final Dio dio = Dio()
        ..httpClientAdapter = _MockAdapter((RequestOptions opt) {
          return _json(<String, dynamic>{'message': 'Unauthorized'}, 401);
        });

      final TechnitiumApi api = TechnitiumApi(dio);
      expect(
        api.getStatus,
        throwsA(isA<TechnitiumAuthException>()),
      );
    });
  });
}
