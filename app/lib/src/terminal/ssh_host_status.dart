import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preferences.dart';
import 'terminal_hub.dart';

/// The outcome of the last real login to a Docker host - from the terminal,
/// the container picker or Test connection. Only real logins count: the
/// health probe never logs in, so this is how a refused password reaches the
/// status dot without the probe hammering the server with attempts.
@immutable
class SshLoginRecord {
  const SshLoginRecord({
    required this.ok,
    required this.at,
    required this.username,
    this.message,
  });

  factory SshLoginRecord.fromJson(Map<String, dynamic> json) => SshLoginRecord(
        ok: json['ok'] == true,
        at: DateTime.tryParse(json['at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        username: json['username'] as String? ?? '',
        message: json['message'] as String?,
      );

  final bool ok;
  final DateTime at;
  final String username;

  /// Why the login was refused; null when it worked.
  final String? message;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ok': ok,
        'at': at.toIso8601String(),
        'username': username,
        if (message != null) 'message': message,
      };
}

/// Last login per Docker host id, kept in the settings box so a refused
/// login still shows after a restart. Holds no secrets.
final NotifierProvider<SshLoginRecords, Map<String, SshLoginRecord>>
    sshLoginRecordsProvider =
    NotifierProvider<SshLoginRecords, Map<String, SshLoginRecord>>(
  SshLoginRecords.new,
);

class SshLoginRecords extends Notifier<Map<String, SshLoginRecord>> {
  static const String _prefix = 'sshLastLogin:';

  @override
  Map<String, SshLoginRecord> build() {
    final Map<String, SshLoginRecord> out = <String, SshLoginRecord>{};
    final Box<String> box = ref.read(settingsBoxProvider);
    for (final dynamic key in box.keys) {
      final String? raw = key is String && key.startsWith(_prefix)
          ? box.get(key)
          : null;
      if (raw != null) {
        try {
          out[(key as String).substring(_prefix.length)] =
              SshLoginRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } on Object {
          // A record that does not parse is just forgotten.
        }
      }
    }
    return out;
  }

  Future<void> record(String hostId, SshLoginRecord login) async {
    state = <String, SshLoginRecord>{...state, hostId: login};
    await ref
        .read(settingsBoxProvider)
        .put('$_prefix$hostId', jsonEncode(login.toJson()));
  }

  /// Forgets the host's last login, after its address or login is edited.
  Future<void> clear(String hostId) async {
    if (!state.containsKey(hostId)) return;
    state = Map<String, SshLoginRecord>.of(state)..remove(hostId);
    await ref.read(settingsBoxProvider).delete('$_prefix$hostId');
  }
}

/// The dot for a Docker host, from the SSH banner probe and what the app
/// knows from real logins.
///
/// A server that answers but refused the last login is amber, like a service
/// whose API key is rejected; otherwise the probe decides. (An open terminal
/// session is green before this is asked.)
Health dockerHostHealth({
  required Health probe,
  SshLoginRecord? lastLogin,
}) {
  if (probe == Health.ok && lastLogin != null && !lastLogin.ok) {
    return Health.warning;
  }
  return probe;
}

/// One line saying why a Docker host's dot is the colour it is, from the
/// dot's own [health] (see [dockerHostHealth]) and the last login.
String describeDockerHost({
  required Health health,
  required SshStatus session,
  SshEndpoint? endpoint,
  SshLoginRecord? lastLogin,
  required DateTime now,
}) {
  if (session == SshStatus.connected) {
    return endpoint == null ? 'Connected now' : 'Connected now to $endpoint';
  }
  final bool refused = lastLogin != null && !lastLogin.ok;
  return switch (health) {
    Health.ok => lastLogin == null
        ? 'SSH answering - not logged in yet'
        : 'SSH answering - last login OK ${timeAgo(lastLogin.at, now)}',
    Health.warning when refused =>
      'SSH answering - login refused for ${lastLogin.username} '
          '${timeAgo(lastLogin.at, now)}',
    Health.warning =>
      'Something answers on that port, but it is not an SSH server',
    Health.error => 'Not reachable',
    Health.unknown => 'Not checked yet',
  };
}

String timeAgo(DateTime at, DateTime now) {
  final Duration d = now.difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}
