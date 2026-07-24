import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_nzbget/service_nzbget.dart';

import 'support/fake_http_client_adapter.dart';

NzbgetApi _api(
  ({int status, Object? data}) Function(RequestOptions) factory, {
  List<RequestOptions>? log,
}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://nzbget.local:6789/'));
  final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(factory);
  dio.httpClientAdapter = adapter;
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
  return NzbgetApi(dio);
}

Map<String, dynamic> _rpcBody(RequestOptions o) =>
    jsonDecode(o.data is String ? o.data as String : jsonEncode(o.data))
        as Map<String, dynamic>;

void main() {
  test('getGroups posts a listgroups envelope and parses groups', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final NzbgetApi api = _api(
      (RequestOptions o) => (
        status: 200,
        data: <String, dynamic>{
          'result': <Map<String, dynamic>>[
            <String, dynamic>{
              'NZBID': 7,
              'NZBName': 'Linux.ISO',
              'Status': 'DOWNLOADING',
              'FileSizeMB': 1000,
              'RemainingSizeMB': 250,
              'DownloadedSizeMB': 750,
              'Category': 'iso',
              'MaxPriority': 0,
              'Health': 1000,
            },
          ],
        },
      ),
      log: log,
    );
    final List<NzbgetGroup> groups = await api.getGroups();
    expect(log.single.path, 'jsonrpc');
    expect(log.single.method, 'POST');
    expect(_rpcBody(log.single)['method'], 'listgroups');
    expect(groups.single.nzbId, 7);
    expect(groups.single.progress, closeTo(0.75, 0.001));
    expect(groups.single.isPaused, isFalse);
  });

  test('editQueue sends command, param and ids and accepts result true',
      () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final NzbgetApi api = _api(
      (RequestOptions o) => (status: 200, data: <String, dynamic>{'result': true}),
      log: log,
    );
    await api.setPriority(<int>[3, 4], 100);
    final Map<String, dynamic> body = _rpcBody(log.single);
    expect(body['method'], 'editqueue');
    expect(body['params'], <dynamic>['GroupSetPriority', '100', <dynamic>[3, 4]]);
  });

  test('a result of false throws NzbgetRpcException', () async {
    final NzbgetApi api = _api(
      (RequestOptions o) => (status: 200, data: <String, dynamic>{'result': false}),
    );
    expect(() => api.deleteItems(<int>[1]), throwsA(isA<NzbgetRpcException>()));
  });

  test('an error object throws NzbgetRpcException with the message', () async {
    final NzbgetApi api = _api(
      (RequestOptions o) => (
        status: 200,
        data: <String, dynamic>{
          'error': <String, dynamic>{'code': 1, 'message': 'Access denied'},
        },
      ),
    );
    expect(
      api.getStatus,
      throwsA(
        predicate(
          (Object? e) =>
              e is NzbgetRpcException && e.message.contains('Access denied'),
        ),
      ),
    );
  });

  test('append sends the 9-arg envelope and returns the new id', () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final NzbgetApi api = _api(
      (RequestOptions o) => (status: 200, data: <String, dynamic>{'result': 42}),
      log: log,
    );
    final int id = await api.append(
      name: 'file.nzb',
      content: 'aGVsbG8=',
      category: 'tv',
      priority: 50,
      addPaused: true,
    );
    expect(id, 42);
    expect(_rpcBody(log.single)['params'], <dynamic>[
      'file.nzb', 'aGVsbG8=', 'tv', 50, false, true, '', 0, 'SCORE',
    ]);
  });

  test('append result of 0 throws (server rejected the nzb)', () async {
    final NzbgetApi api = _api(
      (RequestOptions o) => (status: 200, data: <String, dynamic>{'result': 0}),
    );
    expect(
      () => api.append(name: 'x.nzb', content: 'u'),
      throwsA(isA<NzbgetRpcException>()),
    );
  });

  test('getCategories parses CategoryN.Name entries from config', () async {
    final NzbgetApi api = _api(
      (RequestOptions o) => (
        status: 200,
        data: <String, dynamic>{
          'result': <Map<String, dynamic>>[
            <String, dynamic>{'Name': 'Category1.Name', 'Value': 'movies'},
            <String, dynamic>{'Name': 'Category1.DestDir', 'Value': ''},
            <String, dynamic>{'Name': 'Category2.Name', 'Value': 'tv'},
            <String, dynamic>{'Name': 'ControlPort', 'Value': '6789'},
          ],
        },
      ),
    );
    expect(await api.getCategories(), <String>['movies', 'tv']);
  });

  test('history posts the hidden=false param and maps status getters',
      () async {
    final List<RequestOptions> log = <RequestOptions>[];
    final NzbgetApi api = _api(
      (RequestOptions o) => (
        status: 200,
        data: <String, dynamic>{
          'result': <Map<String, dynamic>>[
            <String, dynamic>{
              'NZBID': 9,
              'Name': 'Old.Download',
              'Status': 'FAILURE/PAR',
              'HistoryTime': 1753300000,
              'FileSizeMB': 700,
              'Category': '',
            },
          ],
        },
      ),
      log: log,
    );
    final List<NzbgetHistoryEntry> entries = await api.getHistory();
    expect(_rpcBody(log.single)['params'], <dynamic>[false]);
    expect(entries.single.isFailure, isTrue);
    expect(entries.single.isSuccess, isFalse);
  });
}
