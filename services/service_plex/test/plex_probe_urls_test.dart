import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_plex/service_plex.dart';

/// A network where only the addresses in [reachable] answer.
class _Network implements HttpClientAdapter {
  _Network(this.reachable);

  final Set<String> reachable;
  final List<String> tried = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String origin = '${options.uri.scheme}://${options.uri.host}'
        ':${options.uri.port}';
    tried.add('$origin${options.uri.path}');
    if (!reachable.contains(origin)) {
      throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 3),
        requestOptions: options,
      );
    }
    return ResponseBody.fromString(
      '{"MediaContainer":{"machineIdentifier":"abc"}}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PlexServer _server(
  List<Map<String, dynamic>> connections, {
  bool sameNetwork = true,
}) =>
    PlexServer.fromJson(<String, dynamic>{
      'name': 'Living Room',
      'provides': 'server',
      'owned': true,
      'clientIdentifier': 'aaa',
      'accessToken': 'server-token',
      'publicAddressMatches': sameNetwork,
      'connections': connections,
    });

Map<String, dynamic> _conn({
  required String protocol,
  required String address,
  required String uri,
  required bool local,
  bool relay = false,
  int port = 32400,
}) =>
    <String, dynamic>{
      'protocol': protocol,
      'address': address,
      'port': port,
      'uri': uri,
      'local': local,
      'relay': relay,
    };

Future<PlexServerUrls> _probe(PlexServer server, _Network network) =>
    probePlexServerUrls(
      server,
      dio: Dio()..httpClientAdapter = network,
      timeout: const Duration(milliseconds: 200),
    );

void main() {
  test('a server in a Docker bridge does not poison the local URL', () async {
    // Plex inside a bridge network advertises the container's address, which
    // nothing off the host can reach. Writing it into the local URL would
    // cost a timeout on every call, so the field is left empty instead.
    final _Network network = _Network(<String>{
      'https://157-119-178-90.hash.plex.direct:32400',
    });
    final PlexServerUrls urls = await _probe(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'https',
          address: '172.18.0.13',
          uri: 'https://172-18-0-13.hash.plex.direct:32400',
          local: true,
        ),
        _conn(
          protocol: 'https',
          address: '157.119.178.90',
          uri: 'https://157-119-178-90.hash.plex.direct:32400',
          local: false,
        ),
      ]),
      network,
    );

    expect(urls.localUrl, isNull);
    expect(urls.externalUrl, 'https://157-119-178-90.hash.plex.direct:32400');
  });

  test('a LAN address that answers is the one that gets used', () async {
    final _Network network = _Network(<String>{'http://192.168.0.12:32400'});
    final PlexServerUrls urls = await _probe(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'https',
          address: '172.18.0.13',
          uri: 'https://172-18-0-13.hash.plex.direct:32400',
          local: true,
        ),
        _conn(
          protocol: 'http',
          address: '192.168.0.12',
          uri: 'http://192.168.0.12:32400',
          local: true,
        ),
      ]),
      network,
    );

    expect(urls.localUrl, 'http://192.168.0.12:32400');
    // `identity` needs no token, so it can say whether anything is listening.
    expect(network.tried, contains('http://192.168.0.12:32400/identity'));
  });

  test('relay is only tried when no public address answers', () async {
    final _Network network = _Network(<String>{'https://hash.plex.direct:443'});
    final PlexServerUrls urls = await _probe(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'https',
          address: '1.2.3.4',
          uri: 'https://1-2-3-4.hash.plex.direct:32400',
          local: false,
        ),
        _conn(
          protocol: 'https',
          address: '10.0.0.1',
          uri: 'https://hash.plex.direct:443',
          local: false,
          relay: true,
          port: 443,
        ),
      ]),
      network,
    );

    expect(urls.externalUrl, 'https://hash.plex.direct:443');
    expect(urls.usesRelay, isTrue);
  });

  test('at home a silent public address is kept',
      () async {
    // A router will not usually turn a connection back on itself, so from
    // here the public address could not have answered even if it is fine.
    // The local one gets no such benefit of the doubt: URL selection probes
    // it first, and a dead entry costs a timeout on every call.
    final _Network network = _Network(<String>{});
    final PlexServerUrls urls = await _probe(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'http',
          address: '192.168.0.12',
          uri: 'http://192.168.0.12:32400',
          local: true,
        ),
        _conn(
          protocol: 'https',
          address: '1.2.3.4',
          uri: 'https://1-2-3-4.hash.plex.direct:32400',
          local: false,
        ),
      ]),
      network,
    );

    expect(urls.localUrl, isNull);
    expect(urls.externalUrl, 'https://1-2-3-4.hash.plex.direct:32400');
    expect(urls.externalUnverified, isTrue);
  });

  test('away from home a public address that stays silent is dropped',
      () async {
    // It had a fair chance here, so its silence means the port is not open,
    // whatever Plex advertises. Writing it would leave the user with a URL
    // that fails every time.
    final _Network network = _Network(<String>{});
    final PlexServerUrls urls = await _probe(
      _server(
        <Map<String, dynamic>>[
          _conn(
            protocol: 'https',
            address: '1.2.3.4',
            uri: 'https://1-2-3-4.hash.plex.direct:32400',
            local: false,
          ),
        ],
        sameNetwork: false,
      ),
      network,
    );

    expect(urls.externalUrl, isNull);
    expect(urls.externalUnverified, isFalse);
  });

  test('a relay that answers beats a public address that does not', () async {
    // The relay lives on Plex's own network, so unlike the server's public
    // address it can be reached from the LAN as well.
    final _Network network = _Network(<String>{'https://hash.plex.direct:443'});
    final PlexServerUrls urls = await _probe(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'https',
          address: '1.2.3.4',
          uri: 'https://1-2-3-4.hash.plex.direct:32400',
          local: false,
        ),
        _conn(
          protocol: 'https',
          address: '10.0.0.1',
          uri: 'https://hash.plex.direct:443',
          local: false,
          relay: true,
          port: 443,
        ),
      ]),
      network,
    );

    expect(urls.externalUrl, 'https://hash.plex.direct:443');
    expect(urls.usesRelay, isTrue);
    expect(urls.externalUnverified, isFalse);
  });
}
