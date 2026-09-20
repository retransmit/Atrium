import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_myspeed/service_myspeed.dart';

void main() {
  group('MySpeedStatus.fromResponse', () {
    test('parses boolean responses', () {
      expect(MySpeedStatus.fromResponse(true).isRunning, isTrue);
      expect(MySpeedStatus.fromResponse(false).isRunning, isFalse);
    });

    test('parses map with running boolean', () {
      expect(MySpeedStatus.fromResponse(<String, dynamic>{'running': true}).isRunning, isTrue);
      expect(MySpeedStatus.fromResponse(<String, dynamic>{'running': false}).isRunning, isFalse);
    });

    test('parses map with status string', () {
      final running = MySpeedStatus.fromResponse(<String, dynamic>{
        'status': 'running',
        'message': 'Testing download',
      });
      expect(running.isRunning, isTrue);
      expect(running.message, 'Testing download');

      final idle = MySpeedStatus.fromResponse(<String, dynamic>{
        'status': 'idle',
      });
      expect(idle.isRunning, isFalse);
    });

    test('parses string response', () {
      expect(MySpeedStatus.fromResponse('running').isRunning, isTrue);
      expect(MySpeedStatus.fromResponse('idle').isRunning, isFalse);
    });

    test('parses null safely', () {
      expect(MySpeedStatus.fromResponse(null).isRunning, isFalse);
    });
  });

  group('MySpeedTest.fromJson', () {
    test('parses speed test record correctly', () {
      final test = MySpeedTest.fromJson(<String, dynamic>{
        'id': 101,
        'download': 250.5,
        'upload': 50.1,
        'ping': 14.2,
        'jitter': 2.1,
        'created_at': '2026-09-20T12:00:00.000Z',
        'server': 'Cloudflare',
      });

      expect(test.id, '101');
      expect(test.download, 250.5);
      expect(test.upload, 50.1);
      expect(test.ping, 14.2);
      expect(test.jitter, 2.1);
      expect(test.formattedDownload, '250.5 Mbps');
      expect(test.formattedUpload, '50.1 Mbps');
      expect(test.formattedPing, '14 ms');
      expect(test.server, 'Cloudflare');
    });

    test('keeps the error a failed run carries', () {
      final MySpeedTest failed = MySpeedTest.fromJson(<String, dynamic>{
        'id': 7,
        'ping': null,
        'download': null,
        'upload': null,
        'error': 'Speedtest timed out',
        'created': '2026-09-20T15:00:32.908Z',
      });
      final MySpeedTest good = MySpeedTest.fromJson(<String, dynamic>{
        'id': 8,
        'ping': 32,
        'download': 47.76,
        'upload': 17.21,
        'error': null,
        'created': '2026-09-20T15:30:32.908Z',
      });

      expect(failed.error, 'Speedtest timed out');
      expect(good.error, isNull);
      expect(myspeedLatestGood(<MySpeedTest>[failed, good])?.id, '8');
      expect(myspeedLatestGood(<MySpeedTest>[failed]), isNull);
    });

    test('parses MySpeed API schema with created timestamp and serverName', () {
      final test = MySpeedTest.fromJson(<String, dynamic>{
        'id': 42,
        'download': 512.8,
        'upload': 105.4,
        'ping': 8.2,
        'jitter': 1.5,
        'time': 18,
        'created': '2026-09-20T12:00:00.000Z',
        'serverName': 'London Datacenter',
      });

      expect(test.id, '42');
      expect(test.download, 512.8);
      expect(test.upload, 105.4);
      expect(test.ping, 8.2);
      expect(test.jitter, 1.5);
      expect(test.duration, 18);
      expect(test.server, 'London Datacenter');
      expect(test.createdAt, isNotNull);
      expect(test.createdAt!.isUtc, isFalse);
      expect(test.formattedDate.isNotEmpty, isTrue);
    });
  });

  group('MySpeedConfig.fromResponse', () {
    test('parses map config', () {
      final config = MySpeedConfig.fromResponse(<String, dynamic>{
        'cron': '*/30 * * * *',
        'provider': 'ookla',
        'server': 'node-1',
        'custom_key': 'custom_val',
      });

      expect(config.cron, '*/30 * * * *');
      expect(config.provider, 'ookla');
      expect(config.server, 'node-1');
      expect(config.entries['custom_key'], 'custom_val');
    });

    test('parses list of key-values', () {
      final config = MySpeedConfig.fromResponse(<dynamic>[
        <String, dynamic>{'key': 'cron', 'value': '0 * * * *'},
        <String, dynamic>{'key': 'provider', 'value': 'librespeed'},
      ]);

      expect(config.cron, '0 * * * *');
      expect(config.provider, 'librespeed');
    });
  });

  group('MySpeedApi', () {
    test('getSpeedtestStatus calls api/speedtests/status', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          if (options.path.contains('status')) {
            return ResponseBody.fromString(
              '{"running": true, "message": "Ookla test in progress"}',
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>[Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString('{}', 200);
        },
      );

      final api = MySpeedApi(dio);
      final status = await api.getSpeedtestStatus();

      expect(status.isRunning, isTrue);
      expect(status.message, 'Ookla test in progress');
    });

    test('getSpeedtests sends the window, the limit and the start cursor',
        () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          expect(options.path, endsWith('api/speedtests'));
          expect(options.queryParameters, <String, dynamic>{
            'hours': 48,
            'limit': 1000,
            'start': 160,
          });
          return ResponseBody.fromString(
            '[{"id": 1, "download": 100.0, "upload": 20.0, "ping": 10.0}]',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      final api = MySpeedApi(dio);
      final history =
          await api.getSpeedtests(hours: 48, limit: 1000, start: 160);

      expect(history.length, 1);
      expect(history.first.download, 100.0);
    });

    test('get24HourSpeedtests asks for the whole day', () async {
      // The server caps a list at 10 rows unless a limit is sent.
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          expect(options.queryParameters, <String, dynamic>{
            'hours': 24,
            'limit': MySpeedApi.pageLimit,
          });
          return ResponseBody.fromString(
            '[{"id": 2, "download": 250.0, "upload": 50.0, "ping": 8.0}]',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      final api = MySpeedApi(dio);
      final results = await api.get24HourSpeedtests();

      expect(results.length, 1);
      expect(results.first.download, 250.0);
    });

    test('getConfig calls api/config', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          return ResponseBody.fromString(
            '{"cron": "0 * * * *", "provider": "ookla"}',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      final api = MySpeedApi(dio);
      final config = await api.getConfig();

      expect(config.cron, '0 * * * *');
      expect(config.provider, 'ookla');
    });

    test('runSpeedtest posts to api/speedtests/run', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          expect(options.method, 'POST');
          expect(options.path, endsWith('api/speedtests/run'));
          return ResponseBody.fromString('{"message": "Speedtest started"}', 200);
        },
      );

      final api = MySpeedApi(dio);
      await api.runSpeedtest();
    });

    test('getSpeedtestById returns test when found', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          expect(options.path, 'api/speedtests/42');
          return ResponseBody.fromString(
            '{"id": 42, "download": 250.5, "upload": 50.0, "ping": 8.0}',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      final api = MySpeedApi(dio);
      final test = await api.getSpeedtestById('42');
      expect(test, isNotNull);
      expect(test!.id, '42');
      expect(test.download, 250.5);
    });

    test('getSpeedtestById returns null on 404', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          return ResponseBody.fromString('{"error": "Not Found"}', 404);
        },
      );

      final api = MySpeedApi(dio);
      final test = await api.getSpeedtestById('999');
      expect(test, isNull);
    });

    test('getStorage calls api/storage and parses response', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          expect(options.path, 'api/storage');
          return ResponseBody.fromString(
            '{"size": 10485760, "testCount": 150}',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      final api = MySpeedApi(dio);
      final storage = await api.getStorage();
      expect(storage.size, 10485760);
      expect(storage.testCount, 150);
      expect(storage.formattedSize, '10.0 MB');
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.handler});

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
