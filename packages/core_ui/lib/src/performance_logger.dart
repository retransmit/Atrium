import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A utility to log performance metrics (e.g. image decode times and widget build times).
class PerformanceLogger {
  static void logDecodeStart(String imageUrl) {
    if (kDebugMode || kProfileMode) {
      developer.Timeline.startSync('Image Decode: $imageUrl');
      developer.log('Started decoding image: $imageUrl', name: 'PerformanceLogger');
    }
  }

  static void logDecodeEnd(String imageUrl) {
    if (kDebugMode || kProfileMode) {
      developer.Timeline.finishSync();
      developer.log('Finished decoding image: $imageUrl', name: 'PerformanceLogger');
    }
  }

  static void logBuildTime(String widgetName, Duration duration) {
    if (kDebugMode || kProfileMode) {
      developer.log('Widget $widgetName took ${duration.inMilliseconds}ms to build', name: 'PerformanceLogger');
    }
  }
}

/// A wrapper widget that logs its own build time.
class PerformanceLoggerWidget extends StatelessWidget {
  final String name;
  final Widget child;

  const PerformanceLoggerWidget({
    super.key,
    required this.name,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !kProfileMode) return child;
    
    final stopwatch = Stopwatch()..start();
    developer.Timeline.timeSync('Build: $name', () {
      // We don't actually pause execution, we just record the time
    });
    stopwatch.stop();
    PerformanceLogger.logBuildTime(name, stopwatch.elapsed);
    return child;
  }
}
