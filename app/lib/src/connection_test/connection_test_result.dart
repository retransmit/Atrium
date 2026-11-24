import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The outcome of testing one URL of an instance before it is saved.
enum ConnectionOutcome { connected, authFailed, unreachable }

/// One URL test result: an [outcome] and a short human message.
class ConnectionTestResult {
  const ConnectionTestResult(this.outcome, this.message, {this.suggestedUrl});

  final ConnectionOutcome outcome;
  final String message;

  /// An address the service did answer at, when the one tested was close but
  /// not it. The form offers to switch to it.
  final String? suggestedUrl;
}

/// Maps a [Health] verdict from a lightweight probe to a [ConnectionTestResult].
ConnectionTestResult connectionResultFromHealth(Health health) {
  switch (health) {
    case Health.ok:
      return const ConnectionTestResult(
        ConnectionOutcome.connected,
        'Connected',
      );
    case Health.warning:
      return const ConnectionTestResult(
        ConnectionOutcome.authFailed,
        'Reachable, but the check did not pass',
      );
    case Health.error:
      return const ConnectionTestResult(
        ConnectionOutcome.unreachable,
        'Could not reach the server',
      );
    case Health.unknown:
      return const ConnectionTestResult(
        ConnectionOutcome.unreachable,
        'Could not determine the connection',
      );
  }
}

/// Maps an error thrown while verifying a session service (qBittorrent,
/// Jellyfin, Emby, Plex) to a [ConnectionTestResult]. A rejected credential
/// surfaces as [NetworkAuthException]; anything else is treated as a transport
/// or server problem.
ConnectionTestResult connectionResultFromError(Object error) {
  Object unwrapped = error;
  if (unwrapped is AsyncError) {
    unwrapped = unwrapped.error;
  }
  if (unwrapped is NetworkAuthException) {
    return const ConnectionTestResult(
      ConnectionOutcome.authFailed,
      'Reachable, but the credentials were rejected',
    );
  }
  final String errStr = unwrapped.toString().toLowerCase();
  if (errStr.contains('429') || errStr.contains('rate limit')) {
    return const ConnectionTestResult(
      ConnectionOutcome.authFailed,
      'Reachable, but rate limit exceeded on server',
    );
  }
  if (errStr.contains('401') || errStr.contains('403') || errStr.contains('unauthorized')) {
    return const ConnectionTestResult(
      ConnectionOutcome.authFailed,
      'Reachable, but the credentials were rejected',
    );
  }
  return const ConnectionTestResult(
    ConnectionOutcome.unreachable,
    'Could not reach the server',
  );
}
