import 'package:intl/intl.dart';

/// "just now", "5m ago", "3h ago", then a date such as "Nov 8, 14:05".
String gotifyRelativeTime(DateTime time, DateTime now) {
  final Duration age = now.difference(time);
  if (age.inMinutes < 1) return 'just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  return DateFormat.MMMd().add_Hm().format(time);
}
