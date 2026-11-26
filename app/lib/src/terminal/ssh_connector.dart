import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_storage/core_storage.dart';
import 'package:dartssh2/dartssh2.dart';

/// A server key the user has not seen before, or one that changed.
class HostKeyPrompt {
  const HostKeyPrompt({
    required this.endpoint,
    required this.entry,
    this.previous,
  });

  final SshEndpoint endpoint;

  /// `<type> <SHA256:...>` as presented by the server.
  final String entry;

  /// The pinned entry when the key changed; null on first contact.
  final String? previous;

  bool get changed => previous != null;
}

/// Asks the user whether to trust a host key. Returns true to trust it.
typedef HostKeyPrompter = Future<bool> Function(HostKeyPrompt prompt);

/// Trust-on-first-use pins of SSH host keys, like `~/.ssh/known_hosts`.
///
/// Kept in the settings box keyed by `host:port` rather than on the instance,
/// so the pin follows the server and survives editing or re-adding it.
class KnownHostsStore {
  KnownHostsStore(this._box);

  final Box<String> _box;

  static String _key(SshEndpoint e) => 'sshKnownHost:$e';

  String? lookup(SshEndpoint endpoint) => _box.get(_key(endpoint));

  Future<void> remember(SshEndpoint endpoint, String entry) =>
      _box.put(_key(endpoint), entry);
}

/// Why an SSH connection could not be made, worded for the user.
class SshConnectException implements Exception {
  const SshConnectException(this.message, {this.authFailed = false});

  final String message;

  /// The server was reached but refused the login (or its key).
  final bool authFailed;

  @override
  String toString() => message;
}

/// Connects and authenticates to [host] (a [ServiceKind.dockerHost]),
/// trying its endpoints in [UrlMode] order. Only an unreachable endpoint
/// falls through to the next one; a refused login or host key does not.
Future<({SSHClient client, SshEndpoint endpoint})> connectSsh(
  Instance host, {
  required KnownHostsStore knownHosts,
  required HostKeyPrompter onHostKey,
  void Function(String stage)? onProgress,
  Duration timeout = const Duration(seconds: 8),
  Duration fallbackTimeout = const Duration(seconds: 3),
}) async {
  final InstanceAuth auth = host.auth;
  if (auth is! InstanceAuthSsh || auth.username.trim().isEmpty) {
    throw const SshConnectException('No SSH username is set for this host.');
  }
  final List<SshEndpoint> endpoints = sshEndpointsFor(host);
  if (endpoints.isEmpty) {
    throw const SshConnectException('No SSH address is set for this host.');
  }

  List<SSHKeyPair>? identities;
  if (auth.privateKey.trim().isNotEmpty) {
    try {
      identities = SSHKeyPair.fromPem(
        auth.privateKey.trim(),
        auth.passphrase.isEmpty ? null : auth.passphrase,
      );
    } on Object catch (e) {
      throw SshConnectException(
        e is SSHKeyDecryptError || SSHKeyPair.isEncryptedPem(auth.privateKey)
            ? 'Could not decrypt the private key - check the passphrase.'
            : 'Could not read the private key.',
        authFailed: true,
      );
    }
  }

  Object? lastError;
  for (final SshEndpoint endpoint in endpoints) {
    onProgress?.call('Connecting to $endpoint...');
    // A LAN address that is not answering (away from home) should not hold
    // up the external one for the full timeout.
    final bool hasFallback = endpoint != endpoints.last;
    final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(
        endpoint.host,
        endpoint.port,
        timeout: hasFallback ? fallbackTimeout : timeout,
      );
    } on Object catch (e) {
      lastError = e;
      continue;
    }

    onProgress?.call('Securing the connection...');
    bool hostKeyRejected = false;
    final SSHClient client = SSHClient(
      socket,
      username: auth.username.trim(),
      identities: identities,
      onPasswordRequest:
          auth.password.isEmpty ? null : () => auth.password,
      onUserInfoRequest: auth.password.isEmpty
          ? null
          : (SSHUserInfoRequest request) => request.prompts
              .map((SSHUserInfoPrompt _) => auth.password)
              .toList(),
      onVerifyHostKey: (String type, Uint8List fingerprint) async {
        final String entry = '$type ${utf8.decode(fingerprint)}';
        final String? pinned = knownHosts.lookup(endpoint);
        if (pinned == entry) {
          onProgress?.call('Logging in as ${auth.username.trim()}...');
          return true;
        }
        onProgress?.call('Waiting for you to check the host key...');
        final bool trusted = await onHostKey(
          HostKeyPrompt(endpoint: endpoint, entry: entry, previous: pinned),
        );
        if (trusted) {
          await knownHosts.remember(endpoint, entry);
          onProgress?.call('Logging in as ${auth.username.trim()}...');
        } else {
          hostKeyRejected = true;
        }
        return trusted;
      },
      keepAliveInterval: const Duration(seconds: 15),
    );
    try {
      await client.authenticated;
      return (client: client, endpoint: endpoint);
    } on Object catch (e) {
      client.close();
      if (hostKeyRejected) {
        throw const SshConnectException(
          'The server\'s host key was not trusted.',
          authFailed: true,
        );
      }
      if (e is SSHAuthError) {
        throw SshConnectException(
          'Reachable, but the server refused the login for '
          '"${auth.username.trim()}".',
          authFailed: true,
        );
      }
      throw SshConnectException('SSH handshake with $endpoint failed: $e');
    }
  }
  throw SshConnectException(
    'Could not reach ${endpoints.join(' or ')}'
    '${lastError == null ? '' : ' ($lastError)'}.',
  );
}
