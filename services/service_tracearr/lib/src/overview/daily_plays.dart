import '../models/tracearr_models.dart';

/// Tracearr's weekly plays as seven local calendar days, oldest first,
/// ending on the day the range ends (or [now] when there is no range).
///
/// Tracearr sends a week as 6-hour buckets, one row per server, and only
/// for buckets with plays. Bucket starts carry no zone and are already in
/// the timezone the request named, so they read as local times. Every
/// bucket in a day is added up, days without plays count 0, and the partial
/// eighth day at the start of the range is left out.
List<TracearrActivityBucket> dailyPlays(
  TracearrActivityTrend trend, {
  DateTime? now,
}) {
  final DateTime end = (trend.rangeEnd ?? now ?? DateTime.now()).toLocal();
  // Built from calendar fields, so a daylight saving change cannot shift a
  // day off midnight.
  final List<DateTime> days = <DateTime>[
    for (int back = 6; back >= 0; back--)
      DateTime(end.year, end.month, end.day - back),
  ];
  final Map<DateTime, int> counts = <DateTime, int>{
    for (final DateTime day in days) day: 0,
  };
  for (final TracearrActivityBucket bucket in trend.plays) {
    final DateTime? start = bucket.date?.toLocal();
    if (start == null) {
      continue;
    }
    final DateTime day = DateTime(start.year, start.month, start.day);
    final int? sofar = counts[day];
    if (sofar != null) {
      counts[day] = sofar + bucket.count;
    }
  }
  return <TracearrActivityBucket>[
    for (final DateTime day in days)
      TracearrActivityBucket(date: day, count: counts[day]!),
  ];
}
