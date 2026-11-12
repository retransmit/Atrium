import 'dart:convert';
import 'dart:typed_data';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gotify/service_gotify.dart';

void main() {
  late _Adapter adapter;
  late GotifyApi api;

  void serve(Object? body, {int status = 200, String? contentType}) {
    adapter = _Adapter(
      (RequestOptions _) => ResponseBody.fromString(
        body is String ? body : jsonEncode(body),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[
            contentType ?? Headers.jsonContentType,
          ],
        },
      ),
    );
    api = GotifyApi(
      Dio(BaseOptions(baseUrl: 'http://gotify.test/'))
        ..httpClientAdapter = adapter,
    );
  }

  final Map<String, dynamic> page = <String, dynamic>{
    'messages': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 25,
        'appid': 5,
        'message': 'Backup finished',
        'title': 'Backup',
        'priority': 8,
        'date': '2026-11-08T10:00:00Z',
      },
      <String, dynamic>{
        'id': 24,
        'appid': 6,
        'message': 'Disk 80% full',
        'title': '',
        'priority': 2,
        'date': '2026-11-08T09:00:00Z',
      },
    ],
    'paging': <String, dynamic>{
      'size': 2,
      'since': 24,
      'limit': 2,
      'next': 'http://gotify.test/message?limit=2&since=24',
    },
  };

  test('reads a page of messages and where the next one starts', () async {
    serve(page);
    final GotifyMessagePage result = await api.getMessages(limit: 2);

    expect(adapter.requests.single.path, 'message');
    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'limit': 2,
    });
    expect(result.messages.map((GotifyMessage m) => m.id), <int>[25, 24]);
    expect(result.messages.first.title, 'Backup');
    expect(result.messages.first.level, GotifyPriority.high);
    expect(result.messages.last.title, isNull);
    expect(result.messages.last.level, GotifyPriority.low);
    expect(
      result.messages.first.date!.isAtSameMomentAs(DateTime.utc(2026, 11, 8, 10)),
      isTrue,
    );
    expect(result.nextSince, 24);
  });

  test('the last page has no next', () async {
    serve(<String, dynamic>{
      'messages': <Object>[],
      'paging': <String, dynamic>{'size': 0, 'since': 0, 'limit': 50},
    });
    expect((await api.getMessages()).nextSince, isNull);
  });

  test('one application and an older page use their own path and since',
      () async {
    serve(page);
    await api.getMessages(appId: 5, since: 24, limit: 999);

    final RequestOptions request = adapter.requests.single;
    expect(request.path, 'application/5/message');
    expect(request.queryParameters, <String, dynamic>{
      'limit': GotifyApi.maxPageSize,
      'since': 24,
    });
  });

  test('applications are listed', () async {
    serve(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 5,
        'token': 'AWx-secret',
        'name': 'Backups',
        'description': 'Nightly',
        'internal': false,
        'defaultPriority': 4,
      },
    ]);
    final List<GotifyApplication> apps = await api.getApplications();

    expect(adapter.requests.single.path, 'application');
    expect(apps.single.name, 'Backups');
    expect(apps.single.defaultPriority, 4);
  });

  test('deletes go to the right routes', () async {
    serve(null);
    await api.deleteMessage(25);
    await api.deleteApplicationMessages(5);
    await api.deleteAllMessages();

    expect(
      adapter.requests.map((RequestOptions r) => '${r.method} ${r.path}'),
      <String>[
        'DELETE message/25',
        'DELETE application/5/message',
        'DELETE message',
      ],
    );
  });

  test('a login page instead of the API is reported as such', () async {
    serve('<html>Sign in</html>', contentType: 'text/html');
    await expectLater(
      api.getMessages(),
      throwsA(isA<GotifyUnexpectedAnswer>()),
    );
  });

  test('a refused token becomes an auth error with Gotify\'s reason',
      () async {
    serve(
      <String, dynamic>{
        'error': 'Unauthorized',
        'errorCode': 401,
        'errorDescription': 'you need to provide a valid access token',
      },
      status: 401,
    );
    await expectLater(
      api.getApplications(),
      throwsA(isA<NetworkAuthException>()),
    );
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions) handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
