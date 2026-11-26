import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';

/// The SSH endpoints to try for a Docker host, in order, per its [UrlMode].
List<SshEndpoint> sshEndpointsFor(Instance instance) {
  final SshEndpoint? local = SshEndpoint.tryParse(instance.localUrl);
  final SshEndpoint? external = SshEndpoint.tryParse(instance.externalUrl);
  final List<SshEndpoint?> ordered = switch (instance.urlMode) {
    UrlMode.forceLocal => <SshEndpoint?>[local],
    UrlMode.forceExternal => <SshEndpoint?>[external],
    UrlMode.auto => <SshEndpoint?>[local, external],
  };
  return ordered.whereType<SshEndpoint>().toSet().toList();
}

/// Liveness of an SSH server without logging in: connects and waits for the
/// `SSH-` identification banner every server sends first (RFC 4253 §4.2).
///
/// No credentials are sent, so a dashboard refresh can never trip a
/// fail2ban-style lockout. Something that accepts the connection but is not
/// an SSH server (wrong port) reads as [Health.warning].
Future<Health> probeSshHost(
  Instance instance, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  Health result = Health.error;
  for (final SshEndpoint endpoint in sshEndpointsFor(instance)) {
    final Health health = await _probe(endpoint, timeout);
    if (health == Health.ok) {
      return health;
    }
    if (health == Health.warning) {
      result = health;
    }
  }
  return result;
}

Future<Health> _probe(SshEndpoint endpoint, Duration timeout) async {
  Socket? socket;
  try {
    socket = await Socket.connect(
      endpoint.host,
      endpoint.port,
      timeout: timeout,
    );
    final List<int> first = await socket.first.timeout(timeout);
    return latin1.decode(first, allowInvalid: true).startsWith('SSH-')
        ? Health.ok
        : Health.warning;
  } on TimeoutException {
    // Connected but silent: something listens there, but not sshd.
    return socket == null ? Health.error : Health.warning;
  } on Object {
    return Health.error;
  } finally {
    socket?.destroy();
  }
}
