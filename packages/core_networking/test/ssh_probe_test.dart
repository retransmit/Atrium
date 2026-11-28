import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_test/flutter_test.dart';

Instance _host(String local, {String external = '', UrlMode mode = UrlMode.auto}) =>
    Instance(
      id: 'h',
      name: 'Host',
      kind: ServiceKind.dockerHost,
      localUrl: local,
      externalUrl: external,
      urlMode: mode,
      auth: const InstanceAuth.ssh(username: 'u'),
    );

/// A one-shot TCP server that writes [greeting] (or nothing) on connect.
Future<ServerSocket> _server(String? greeting) async {
  final ServerSocket server =
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((Socket s) {
    if (greeting != null) {
      s.write(greeting);
    }
  });
  return server;
}

void main() {
  test('sshEndpointsFor follows the URL mode', () {
    final Instance host = _host('10.0.0.2', external: 'ssh://ex.com:2222');
    expect(sshEndpointsFor(host), const <SshEndpoint>[
      SshEndpoint('10.0.0.2'),
      SshEndpoint('ex.com', 2222),
    ]);
    expect(
      sshEndpointsFor(host.copyWith(urlMode: UrlMode.forceExternal)),
      const <SshEndpoint>[SshEndpoint('ex.com', 2222)],
    );
  });

  test('an SSH banner is ok, another protocol a warning, nothing an error',
      () async {
    final ServerSocket ssh = await _server('SSH-2.0-OpenSSH_9.6\r\n');
    final ServerSocket http = await _server('HTTP/1.1 400 Bad Request\r\n');
    final ServerSocket closed =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final int closedPort = closed.port;
    await closed.close();
    addTearDown(() async {
      await ssh.close();
      await http.close();
    });

    expect(await probeSshHost(_host('127.0.0.1:${ssh.port}')), Health.ok);
    expect(
      await probeSshHost(_host('127.0.0.1:${http.port}')),
      Health.warning,
    );
    expect(
      await probeSshHost(
        _host('127.0.0.1:$closedPort'),
        timeout: const Duration(seconds: 1),
      ),
      Health.error,
    );
    // Auto mode falls back to the external address when the LAN one is down.
    expect(
      await probeSshHost(
        _host('127.0.0.1:$closedPort', external: '127.0.0.1:${ssh.port}'),
        timeout: const Duration(seconds: 1),
      ),
      Health.ok,
    );
  });
}
