import 'package:intl/intl.dart';

import 'adguard_home_time_zones.dart';
import 'models/adguard_home_clients.dart';

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

/// Where the server learned of a runtime client, in words. A source this
/// app does not know is shown as the server sent it.
String adguardHomeClientSourceLabel(String source) => switch (source) {
      'ARP' => 'ARP table',
      'rDNS' => 'Reverse DNS',
      'etc/hosts' => 'Hosts file',
      _ => source,
    };

/// A search engine by the name it goes by. The server sends a key, such as
/// `duckduckgo`; one it adds later is at least capitalised.
String adguardHomeSearchEngineLabel(String key) => switch (key) {
      'duckduckgo' => 'DuckDuckGo',
      'youtube' => 'YouTube',
      _ => _sentence(key),
    };

/// A group of blockable services by name. The server sends only an id, such
/// as `social_network`.
String adguardHomeServiceGroupLabel(String id) => switch (id) {
      '' => 'Other',
      'ai' => 'AI',
      'cdn' => 'CDN',
      'messenger' => 'Messengers',
      'social_network' => 'Social networks',
      _ => _sentence(id),
    };

/// How many services a client has blocked for itself.
String adguardHomeServicesBlockedLabel(int count) => switch (count) {
      0 => 'No services blocked',
      1 => '1 service blocked',
      _ => '$count services blocked',
    };

/// When service blocking pauses, in a line: `Sat 09:00 to 17:00, Sun 09:00
/// to 17:00 (Europe/Berlin)`.
String formatAdguardHomePauses(
  List<AdguardHomeServicePause> pauses,
  String timeZone,
) {
  final String days = <String>[
    for (final AdguardHomeServicePause pause in pauses)
      '${_dayLabel(pause.day)} ${formatAdguardHomeClock(pause.start)} to '
          '${formatAdguardHomeClock(pause.end)}',
  ].join(', ');
  return timeZone.isEmpty ? days : '$days ($timeZone)';
}

String _dayLabel(String day) => switch (day) {
      'mon' => 'Mon',
      'tue' => 'Tue',
      'wed' => 'Wed',
      'thu' => 'Thu',
      'fri' => 'Fri',
      'sat' => 'Sat',
      'sun' => 'Sun',
      _ => day,
    };

/// A time of day from midnight. The end of the day is 24:00.
String formatAdguardHomeClock(Duration fromMidnight) {
  final int minutes = fromMidnight.inMinutes;
  return '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
}

/// A weekday by its whole name, from the server's `mon` to `sun`.
String adguardHomeWeekdayName(String day) => switch (day) {
      'mon' => 'Monday',
      'tue' => 'Tuesday',
      'wed' => 'Wednesday',
      'thu' => 'Thursday',
      'fri' => 'Friday',
      'sat' => 'Saturday',
      'sun' => 'Sunday',
      _ => day,
    };

/// One day's pause: its hours, or "All day" when it covers the whole of it.
String adguardHomePauseLabel(AdguardHomeServicePause pause) =>
    pause.start == Duration.zero && pause.end == const Duration(hours: 24)
        ? 'All day'
        : '${formatAdguardHomeClock(pause.start)} to '
            '${formatAdguardHomeClock(pause.end)}';

/// The time zone of a schedule. The server's own is named, not shown as
/// its keyword.
String adguardHomeTimeZoneLabel(String timeZone) =>
    timeZone.isEmpty || timeZone == adguardHomeServerTimeZone
        ? "The server's time zone"
        : timeZone;

/// `social_network` as `Social network`.
String _sentence(String key) {
  final String words = key.replaceAll('_', ' ').trim();
  if (words.isEmpty) return words;
  return words[0].toUpperCase() + words.substring(1);
}

/// How often the lists can be fetched again, in hours, as the web UI
/// offers them. Never is zero.
const List<int> adguardHomeIntervalOptions = <int>[0, 1, 12, 24, 72, 168];

/// How often the lists are fetched again, the way the web UI names it.
String adguardHomeIntervalLabel(int hours) => switch (hours) {
      0 => 'Never',
      1 => 'Every hour',
      72 => 'Every 3 days',
      168 => 'Every 7 days',
      _ => 'Every $hours hours',
    };

final DateFormat _date = DateFormat('d MMM y, HH:mm', 'en_US');

/// A date and time to the minute, in the device's own time.
String formatAdguardHomeDate(DateTime time) => _date.format(time.toLocal());

/// The period the statistics cover, the way the web UI names it.
String adguardHomePeriodLabel(Duration period) {
  final int hours = period.inHours;
  if (hours == 1) return 'Last hour';
  if (hours <= 24 || hours % 24 != 0) return 'Last $hours hours';
  return 'Last ${hours ~/ 24} days';
}

/// How long the query log or the statistics keep things, as the web UI
/// names its choices: "6 hours", "24 hours", "7 days", and any other
/// length in hours.
String adguardHomeRetentionLabel(Duration interval) {
  final int hours = interval.inHours;
  if (hours > 24 && hours % 24 == 0) {
    final int days = hours ~/ 24;
    return '$days days';
  }
  return hours == 1 ? '1 hour' : '$hours hours';
}

/// The retention choices the web UI offers for the query log.
const List<Duration> adguardHomeQueryLogRetentions = <Duration>[
  Duration(hours: 6),
  Duration(hours: 24),
  Duration(days: 7),
  Duration(days: 30),
  Duration(days: 90),
];

/// The retention choices the web UI offers for the statistics.
const List<Duration> adguardHomeStatsRetentions = <Duration>[
  Duration(hours: 24),
  Duration(days: 7),
  Duration(days: 30),
  Duration(days: 90),
];

/// A size in bytes as AdGuard Home's own defaults are thought of, in steps
/// of 1024: 4194304 is "4 MB".
String adguardHomeBytesLabel(int bytes) {
  const List<String> units = <String>['bytes', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return bytes == 1 ? '1 byte' : '$bytes bytes';
  String figure = value.toStringAsFixed(1);
  if (figure.endsWith('.0')) figure = figure.substring(0, figure.length - 2);
  return '$figure ${units[unit]}';
}
