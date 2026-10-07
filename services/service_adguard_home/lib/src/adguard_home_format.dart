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

/// How long an answer took, as the web UI writes it: with two decimals
/// under a millisecond, `0.12 ms`, and whole and rounded down from one up,
/// `28 ms`. Empty where the server gave no number.
String formatAdguardHomeElapsed(Duration? elapsed) {
  if (elapsed == null) return '';
  final double ms = elapsed.inMicroseconds / 1000;
  if (ms < 1) return '${ms.toStringAsFixed(2)} ms';
  return '${formatAdguardHomeCount(ms.floor())} ms';
}

final DateFormat _timeOfDay = DateFormat('HH:mm:ss', 'en_US');
final DateFormat _dayAndTime = DateFormat('d MMM HH:mm:ss', 'en_US');
final DateFormat _dateAndTime = DateFormat('d MMM y HH:mm:ss', 'en_US');
final DateFormat _moment = DateFormat('d MMM y, HH:mm:ss.SSS', 'en_US');

/// When a query came in, for a row of the log, in the device's own time:
/// the time of day for one from today ([now] says which day that is), with
/// the date in front for an older one. Empty for no time.
String formatAdguardHomeLogTime(DateTime? time, DateTime now) {
  if (time == null) return '';
  final DateTime local = time.toLocal();
  final DateTime today = now.toLocal();
  if (local.year != today.year) return _dateAndTime.format(local);
  if (local.month != today.month || local.day != today.day) {
    return _dayAndTime.format(local);
  }
  return _timeOfDay.format(local);
}

/// When a query came in, in full, to the millisecond. Empty for no time.
String formatAdguardHomeLogMoment(DateTime? time) =>
    time == null ? '' : _moment.format(time.toLocal());

/// The way a query arrived, in the web UI's words. One this app does not
/// know is shown as the server sent it.
String adguardHomeProtocolLabel(String protocol) => switch (protocol) {
      '' => 'Plain DNS',
      'doh' => 'DNS-over-HTTPS',
      'dot' => 'DNS-over-TLS',
      'doq' => 'DNS-over-QUIC',
      'dnscrypt' => 'DNSCrypt',
      _ => protocol,
    };

/// The period the statistics cover, the way the web UI names it.
String adguardHomePeriodLabel(Duration period) {
  final int hours = period.inHours;
  if (hours == 1) return 'Last hour';
  if (hours <= 24 || hours % 24 != 0) return 'Last $hours hours';
  return 'Last ${hours ~/ 24} days';
}
