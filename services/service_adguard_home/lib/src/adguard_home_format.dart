import 'package:intl/intl.dart';

final NumberFormat _whole = NumberFormat.decimalPattern('en_US');
final NumberFormat _compact = NumberFormat.compact(locale: 'en_US');

/// A count written out in full, `5,690`.
String formatAdguardHomeCount(num value) => _whole.format(value);

/// A count for a small space, `5.69K`.
String formatAdguardHomeCompact(num value) => _compact.format(value);

/// A share from 0 to 100 with at most two decimals, `13.01%`.
String formatAdguardHomePercent(double percent) {
  if (percent <= 0) return '0%';
  final String text =
      percent.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$text%';
}

/// A share from 0 to 100 for a small space: whole from ten up, `36%`, and
/// with one decimal below that, `4.2%`.
String formatAdguardHomeCompactPercent(double percent) {
  if (percent <= 0) return '0%';
  // From here up one decimal would round to 10.0.
  if (percent >= 9.95) return '${percent.round()}%';
  final String text =
      percent.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  return '$text%';
}

/// A DNS processing time in whole milliseconds, `67 ms`.
String formatAdguardHomeProcessingTime(Duration time) =>
    '${(time.inMicroseconds / 1000).round()} ms';

/// Time left on a pause, `0:30`, `9:41` or `1:02:03`.
///
/// Rounds up, so the last second shows as `0:01` rather than `0:00`, and
/// never goes below zero.
String formatAdguardHomeCountdown(Duration left) {
  final int total =
      left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  final int hours = total ~/ 3600;
  final int minutes = (total % 3600) ~/ 60;
  final String seconds = (total % 60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// The period the statistics cover, the way the web UI names it.
String adguardHomePeriodLabel(Duration period) {
  final int hours = period.inHours;
  if (hours == 1) return 'Last hour';
  if (hours <= 24 || hours % 24 != 0) return 'Last $hours hours';
  return 'Last ${hours ~/ 24} days';
}
