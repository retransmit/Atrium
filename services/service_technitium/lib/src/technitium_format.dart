import 'package:intl/intl.dart';

final NumberFormat _compact = NumberFormat.compact();
final NumberFormat _percent = NumberFormat('0.0');

/// Formats large numbers compactly: 1200 → "1.2K", 3500000 → "3.5M".
String formatTechnitiumCompact(num value) => _compact.format(value);

/// Formats a percentage: 12.34 → "12.3%".
String formatTechnitiumPercent(double value) => '${_percent.format(value)}%';

/// Formats remaining duration on a countdown: 0:45, 12:34, 1:02:15.
String formatTechnitiumCountdown(Duration duration) {
  if (duration <= Duration.zero) return '0:00';
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);

  final String sec = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final String min = minutes.toString().padLeft(2, '0');
    return '$hours:$min:$sec';
  }
  return '$minutes:$sec';
}

/// Human readable label for dashboard stats periods.
String technitiumPeriodLabel(String period) => switch (period) {
      'LastHour' => 'Last hour',
      'LastDay' => 'Last 24 hours',
      'LastWeek' => 'Last 7 days',
      'LastMonth' => 'Last 30 days',
      _ => period,
    };
