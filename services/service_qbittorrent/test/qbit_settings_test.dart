import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  String responseBody = 'Ok.';
  int statusCode = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(responseBody, statusCode);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late QbittorrentClient client;

  setUp(() {
    adapter = _RecordingAdapter();
    client = QbittorrentClient(
      dio: Dio(BaseOptions(baseUrl: 'https://qbit.example.test/'))
        ..httpClientAdapter = adapter,
      cookies: CookieJar(),
      username: '',
      password: '',
      apiKey: 'qbt_placeholder',
    );
  });

  group('QbittorrentClient settings & preferences API', () {
    test('getAppVersion calls api/v2/app/version', () async {
      adapter.responseBody = 'v5.0.0';
      final String version = await client.getAppVersion();

      expect(adapter.request!.path, 'api/v2/app/version');
      expect(version, 'v5.0.0');
    });

    test('getApiVersion calls api/v2/app/webapiVersion', () async {
      adapter.responseBody = '2.11.0';
      final String version = await client.getApiVersion();

      expect(adapter.request!.path, 'api/v2/app/webapiVersion');
      expect(version, '2.11.0');
    });

    test('getPreferences calls api/v2/app/preferences and parses json', () async {
      adapter.responseBody = jsonEncode(<String, dynamic>{
        'save_path': '/downloads',
        'listen_port': 6881,
        'dht': true,
        'dl_limit': 1048576,
      });

      final Map<String, dynamic> prefs = await client.getPreferences();

      expect(adapter.request!.path, 'api/v2/app/preferences');
      expect(prefs['save_path'], '/downloads');
      expect(prefs['listen_port'], 6881);
      expect(prefs['dht'], true);
      expect(prefs['dl_limit'], 1048576);
    });

    test('setPreferences sends form-urlencoded json payload', () async {
      final Map<String, dynamic> update = <String, dynamic>{
        'save_path': '/media/downloads',
        'listen_port': 6882,
        'current_network_interface': 'wg0',
        'current_interface_address': '10.0.0.2',
        'resume_data_storage_type': 1,
        'reannounce_when_address_changed': true,
        'enable_embedded_tracker': true,
        'embedded_tracker_port': 9000,
        'ignore_ssl_errors': true,
        'python_executable_path': '/usr/bin/python3',
      };

      await client.setPreferences(update);

      expect(adapter.request!.path, 'api/v2/app/setPreferences');
      expect(
        adapter.request!.contentType,
        Headers.formUrlEncodedContentType,
      );
      expect(
        adapter.request!.data,
        <String, dynamic>{'json': jsonEncode(update)},
      );
    });

    test('getNetworkInterfaces queries api/v2/app/networkInterfacesList', () async {
      adapter.responseBody = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'name': 'All interfaces', 'value': ''},
        <String, dynamic>{'name': 'eth0', 'value': 'eth0'},
        <String, dynamic>{'name': 'wg0 (VPN)', 'value': 'wg0'},
      ]);

      final List<Map<String, String>> ifaces = await client.getNetworkInterfaces();

      expect(adapter.request!.path, 'api/v2/app/networkInterfacesList');
      expect(ifaces.length, 3);
      expect(ifaces[1]['name'], 'eth0');
      expect(ifaces[2]['value'], 'wg0');
    });

    test('getNetworkInterfaceAddresses passes iface query parameter', () async {
      adapter.responseBody = jsonEncode(<String>[
        '192.168.1.50',
        'fe80::1',
      ]);

      final List<String> addrs =
          await client.getNetworkInterfaceAddresses(iface: 'eth0');

      expect(
        adapter.request!.path,
        'api/v2/app/networkInterfaceAddressesList',
      );
      expect(adapter.request!.queryParameters['iface'], 'eth0');
      expect(addrs, <String>['192.168.1.50', 'fe80::1']);
    });

    test('toggleAltSpeedLimits posts to api/v2/transfer/toggleSpeedLimitsMode',
        () async {
      await client.toggleAltSpeedLimits();

      expect(
        adapter.request!.path,
        'api/v2/transfer/toggleSpeedLimitsMode',
      );
    });

    test('getSpeedLimitsMode parses 1 as enabled and 0 as disabled', () async {
      adapter.responseBody = '1';
      final int mode = await client.getSpeedLimitsMode();

      expect(adapter.request!.path, 'api/v2/transfer/speedLimitsMode');
      expect(mode, 1);
    });
  });
}
