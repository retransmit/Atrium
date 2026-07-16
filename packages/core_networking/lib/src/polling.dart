import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Polling support for Riverpod providers.
extension PollingRef on Ref {
  /// Re-runs this provider every [interval] for as long as it is being
  /// watched.
  ///
  /// Pair with `autoDispose` so polling stops the moment the last listener
  /// (screen) goes away:
  ///
  /// ```dart
  /// final FutureProvider.autoDispose.family<...> torrents = FutureProvider
  ///     .autoDispose.family((ref, instance) async {
  ///   ref.pollEvery(const Duration(seconds: 3));
  ///   ...
  /// });
  /// ```
  ///
  /// Ticks are skipped while the app is backgrounded - a hidden app should
  /// not keep hitting servers or burning mobile data. The first tick after
  /// the app resumes refreshes as normal. UIs that use `AsyncValueView`
  /// (skipLoadingOnRefresh) re-render data in place without flashing a
  /// spinner.
  void pollEvery(Duration interval) {
    final Timer timer = Timer.periodic(interval, (_) {
      final AppLifecycleState? state = SchedulerBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) {
        invalidateSelf();
      }
    });
    onDispose(timer.cancel);
  }
}
