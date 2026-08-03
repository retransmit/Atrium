import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How much longer to wait before retrying once a polled run has failed.
const int _errorBackoffFactor = 5;

/// Polling support for Riverpod providers.
extension PollingRef on Ref {
  /// Runs [body] now and re-runs this provider every [interval] afterwards,
  /// for as long as it is being watched.
  ///
  /// Prefer this over [pollEvery]. Because the work passes through here, the
  /// next tick can be armed **after the current run settles** rather than on a
  /// blind fixed cadence, which fixes two real failures:
  ///
  ///  * Work that takes longer than [interval] would otherwise be invalidated
  ///    mid-flight, restart, and never produce a value - an endless spinner on
  ///    any link slow enough to outrun the interval, which is exactly the
  ///    remote/mobile case. The cycle here is `work + interval`, never shorter
  ///    than the work itself.
  ///  * A run that throws waits [_errorBackoffFactor] times longer before
  ///    retrying, so a server that is down (or a password that is wrong) is not
  ///    hit once per interval forever. qBittorrent bans an IP after three bad
  ///    logins, so a tight retry loop is not merely wasteful there.
  ///
  /// ```dart
  /// final torrents = FutureProvider.autoDispose.family<List<T>, Instance>(
  ///   (Ref ref, Instance instance) => ref.polled(
  ///     const Duration(seconds: 3),
  ///     () async => (await ref.watch(clientProvider(instance).future)).list(),
  ///   ),
  /// );
  /// ```
  Future<T> polled<T>(Duration interval, Future<T> Function() body) async {
    try {
      final T value = await body();
      _schedulePoll(interval);
      return value;
    } catch (_) {
      _schedulePoll(interval * _errorBackoffFactor);
      rethrow;
    }
  }

  /// Re-runs this provider every [interval] for as long as it is being
  /// watched.
  ///
  /// Kept for providers that have not moved to [polled] yet. This ticks on a
  /// blind timer, so it can invalidate a run that is still in flight; see
  /// [polled] for why that matters and prefer it for new code.
  void pollEvery(Duration interval) => _schedulePoll(interval);

  /// Arms a single tick [delay] from now, skipping it while the app is
  /// backgrounded - a hidden app should not keep hitting servers or burning
  /// mobile data. The first tick after the app resumes refreshes as normal.
  void _schedulePoll(Duration delay) {
    Timer? timer;
    bool disposed = false;

    void arm(Duration d) {
      timer = Timer(d, () {
        if (disposed) return;
        final AppLifecycleState? state =
            SchedulerBinding.instance.lifecycleState;
        if (state == null || state == AppLifecycleState.resumed) {
          invalidateSelf();
        } else {
          // Backgrounded: leave the network alone and look again later. Re-arm
          // rather than recursing into _schedulePoll, which would register a
          // fresh dispose callback on every skipped tick.
          arm(d);
        }
      });
    }

    arm(delay);
    onDispose(() {
      disposed = true;
      timer?.cancel();
    });
  }
}
