import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state_views.dart';
import 'package:core_ui/core_ui.dart';

/// Renders a Riverpod [AsyncValue] with consistent loading / error / data
/// handling so screens don't each reinvent the `.when(...)` boilerplate.
///
/// ```dart
/// AsyncValueView<List<Series>>(
///   value: ref.watch(seriesProvider(instanceId)),
///   onRetry: () => ref.invalidate(seriesProvider(instanceId)),
///   data: (series) => SeriesGrid(series),
/// )
/// ```
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  /// Custom loading widget; defaults to a centered spinner.
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: data,
      loading: () =>
          loading ?? const Center(child: ExpressiveProgressIndicator()),
      error: (Object error, StackTrace _) => ErrorView(
        message: _describe(error),
        onRetry: onRetry,
      ),
    );
  }

  String _describe(Object error) {
    // NetworkException (from core_networking) already carries a friendly
    // `message`; fall back to toString for anything else.
    try {
      final dynamic dyn = error;
      // ignore: avoid_dynamic_calls
      final Object? msg = dyn.message;
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    } on NoSuchMethodError {
      // not a message-bearing error
    }
    return error.toString();
  }
}
