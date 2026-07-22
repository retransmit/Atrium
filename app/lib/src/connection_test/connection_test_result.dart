import 'package:core_models/core_models.dart';

/// The outcome of testing one URL of an instance before it is saved.
enum ConnectionOutcome { connected, authFailed, unreachable }

/// One URL test result: an [outcome] and a short human message.
class ConnectionTestResult {
  const ConnectionTestResult(this.outcome, this.message);

  final ConnectionOutcome outcome;
  final String message;
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
