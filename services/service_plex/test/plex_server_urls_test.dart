import 'package:flutter_test/flutter_test.dart';
import 'package:service_plex/service_plex.dart';

PlexServer _server(List<Map<String, dynamic>> connections) =>
    PlexServer.fromJson(<String, dynamic>{
      'name': 'Living Room',
      'provides': 'server',
      'owned': true,
      'clientIdentifier': 'aaa',
      'accessToken': 'server-token',
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

void main() {
  test('the LAN address wins over the plex.direct name', () {
    final PlexServerUrls urls = resolvePlexServerUrls(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'http',
          address: '192.168.0.12',
          uri: 'http://192.168.0.12:32400',
          local: true,
        ),
        _conn(
          protocol: 'https',
          address: '192.168.0.12',
          uri: 'https://192-168-0-12.abc.plex.direct:32400',
          local: true,
        ),
      ]),
    );

    // plex.direct resolves a private address over public DNS, which routers
    // with rebind protection refuse to answer.
    expect(urls.localUrl, 'http://192.168.0.12:32400');
  });

  test('a server that requires secure connections keeps its name', () {
    final PlexServerUrls urls = resolvePlexServerUrls(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'https',
          address: '192.168.0.12',
          uri: 'https://192-168-0-12.abc.plex.direct:32400',
          local: true,
        ),
      ]),
    );

    expect(urls.localUrl, 'https://192-168-0-12.abc.plex.direct:32400');
  });

  test('the remote URL is the advertised one, not the bare address', () {
    final PlexServerUrls urls = resolvePlexServerUrls(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'https',
          address: '1.2.3.4',
          uri: 'https://1-2-3-4.abc.plex.direct:32400',
          local: false,
        ),
      ]),
    );

    // https://1.2.3.4:32400 would fail TLS: the certificate is issued for
    // the plex.direct name.
    expect(urls.externalUrl, 'https://1-2-3-4.abc.plex.direct:32400');
    expect(urls.usesRelay, isFalse);
  });

  test('relay fills in when there is no reachable public address', () {
    final PlexServerUrls urls = resolvePlexServerUrls(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'http',
          address: '192.168.0.12',
          uri: 'http://192.168.0.12:32400',
          local: true,
        ),
        _conn(
          protocol: 'https',
          address: '10.0.0.1',
          uri: 'https://abc.plex.direct:443',
          local: false,
          relay: true,
          port: 443,
        ),
      ]),
    );

    expect(urls.localUrl, 'http://192.168.0.12:32400');
    expect(urls.externalUrl, 'https://abc.plex.direct:443');
    expect(urls.usesRelay, isTrue);
  });

  test('a real remote connection is preferred over the relay', () {
    final PlexServerUrls urls = resolvePlexServerUrls(
      _server(<Map<String, dynamic>>[
        _conn(
          protocol: 'https',
          address: '10.0.0.1',
          uri: 'https://abc.plex.direct:443',
          local: false,
          relay: true,
          port: 443,
        ),
        _conn(
          protocol: 'https',
          address: '1.2.3.4',
          uri: 'https://1-2-3-4.abc.plex.direct:32400',
          local: false,
        ),
      ]),
    );

    expect(urls.externalUrl, 'https://1-2-3-4.abc.plex.direct:32400');
    expect(urls.usesRelay, isFalse);
  });

  test('a server with nothing to connect to fills in nothing', () {
    final PlexServerUrls urls = resolvePlexServerUrls(
      _server(<Map<String, dynamic>>[]),
    );

    expect(urls.localUrl, isNull);
    expect(urls.externalUrl, isNull);
    expect(urls.usesRelay, isFalse);
  });
}
