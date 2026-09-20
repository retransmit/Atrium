import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

/// Answers the two network interface routes the way qBittorrent 5.2.3 does.
///
/// The bodies and status codes below were taken from a live server: any
/// route it does not have is a 404, and the address route is a 400 unless
/// `iface` is sent, where an empty value lists every address.
class _Qbittorrent implements HttpClientAdapter {
  final List<Uri> requested = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri);
    final Map<String, String> query = options.uri.queryParameters;
    return switch (options.uri.path) {
      '/api/v2/app/networkInterfaceList' => _json(
          '[{"name":"lo","value":"lo"},{"name":"eth0","value":"eth0"}]',
        ),
      '/api/v2/app/networkInterfaceAddressList' => switch (query['iface']) {
          null => _text(400, 'Missing required parameters: iface'),
          '' => _json('["127.0.0.1","::1","172.20.0.2"]'),
          'eth0' => _json('["172.20.0.2"]'),
          _ => _json('[]'),
        },
      _ => _text(404, 'Endpoint does not exist'),
    };
  }

  ResponseBody _json(String body) => ResponseBody.fromString(
        body,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  ResponseBody _text(int status, String body) => ResponseBody.fromString(
        body,
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/plain; charset=UTF-8'],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// The Advanced settings pickers list the host's interfaces and addresses.
///
/// They never listed anything: the client asked for networkInterfacesList
/// and networkInterfaceAddressesList, routes qBittorrent does not have, and
/// returned an empty list when both came back 404.
void main() {
  late _Qbittorrent qbittorrent;
  late QbittorrentClient client;

  setUp(() {
    qbittorrent = _Qbittorrent();
    client = QbittorrentClient(
      dio: Dio(BaseOptions(baseUrl: 'https://qbit.example.test/'))
        ..httpClientAdapter = qbittorrent,
      cookies: CookieJar(),
      username: '',
      password: '',
      apiKey: 'k',
    );
  });

  test('lists the network interfaces', () async {
    expect(
      await client.getNetworkInterfaces(),
      <Map<String, String>>[
        <String, String>{'name': 'lo', 'value': 'lo'},
        <String, String>{'name': 'eth0', 'value': 'eth0'},
      ],
    );
  });

  test('lists every address when no interface is chosen', () async {
    // "Any interface" is the default, and qBittorrent needs iface sent
    // empty to answer it rather than refusing the request.
    expect(
      await client.getNetworkInterfaceAddresses(),
      <String>['127.0.0.1', '::1', '172.20.0.2'],
    );
    expect(await client.getNetworkInterfaceAddresses(iface: ''), hasLength(3));
    expect(
      qbittorrent.requested.map((Uri uri) => uri.queryParameters['iface']),
      everyElement(''),
    );
  });

  test('lists the addresses of the chosen interface', () async {
    expect(
      await client.getNetworkInterfaceAddresses(iface: 'eth0'),
      <String>['172.20.0.2'],
    );
  });
}
