import 'package:flutter_test/flutter_test.dart';
import 'package:service_tracearr/src/models/tracearr_models.dart';
import 'package:service_tracearr/src/overview/daily_plays.dart';

TracearrActivityBucket _b(DateTime date, int count) =>
    TracearrActivityBucket(date: date, count: count);

List<int> _counts(List<TracearrActivityBucket> days) =>
    days.map((TracearrActivityBucket d) => d.count).toList();

void main() {
  // Tracearr sends bucket starts without a zone, already in the requested
  // timezone, so they parse as local times.
  final DateTime end = DateTime(2026, 11, 26, 21, 40);

  test('one entry per day for the seven days ending on the range end', () {
    final List<TracearrActivityBucket> days = dailyPlays(
      TracearrActivityTrend(period: 'week', rangeEnd: end),
    );

    expect(days.map((TracearrActivityBucket d) => d.date), <DateTime>[
      for (int day = 20; day <= 26; day++) DateTime(2026, 11, day),
    ]);
    expect(_counts(days), <int>[0, 0, 0, 0, 0, 0, 0]);
  });

  test('adds up the 6-hour buckets and every server in a day', () {
    final List<TracearrActivityBucket> days = dailyPlays(
      TracearrActivityTrend(
        period: 'week',
        rangeEnd: end,
        plays: <TracearrActivityBucket>[
          _b(DateTime(2026, 11, 25), 1),
          _b(DateTime(2026, 11, 25, 6), 2),
          // A second server's row for the same bucket.
          _b(DateTime(2026, 11, 25, 6), 4),
          _b(DateTime(2026, 11, 25, 18), 8),
          _b(DateTime(2026, 11, 26, 18), 3),
        ],
      ),
    );

    expect(_counts(days), <int>[0, 0, 0, 0, 0, 15, 3]);
  });

  test('a late-night play stays on its own day', () {
    final List<TracearrActivityBucket> days = dailyPlays(
      TracearrActivityTrend(
        period: 'week',
        rangeEnd: end,
        plays: <TracearrActivityBucket>[_b(DateTime(2026, 11, 26, 18), 1)],
      ),
    );

    expect(days.last.date, DateTime(2026, 11, 26));
    expect(days.last.count, 1);
  });

  test('drops the partial eighth day at the start of the range', () {
    final List<TracearrActivityBucket> days = dailyPlays(
      TracearrActivityTrend(
        period: 'week',
        rangeEnd: end,
        plays: <TracearrActivityBucket>[
          _b(DateTime(2026, 11, 19, 18), 9),
          _b(DateTime(2026, 11, 20), 1),
        ],
      ),
    );

    expect(_counts(days), <int>[1, 0, 0, 0, 0, 0, 0]);
  });

  test('reads a UTC range end in local time', () {
    final DateTime utcEnd = DateTime.utc(2026, 11, 26, 23, 30);
    final DateTime localEnd = utcEnd.toLocal();
    final List<TracearrActivityBucket> days = dailyPlays(
      TracearrActivityTrend(period: 'week', rangeEnd: utcEnd),
    );

    expect(
      days.last.date,
      DateTime(localEnd.year, localEnd.month, localEnd.day),
    );
  });

  test('without a range, ends today', () {
    final List<TracearrActivityBucket> days = dailyPlays(
      const TracearrActivityTrend(period: 'week'),
      now: end,
    );

    expect(days.last.date, DateTime(2026, 11, 26));
    expect(days, hasLength(7));
  });

  test('buckets with no date are ignored', () {
    final List<TracearrActivityBucket> days = dailyPlays(
      TracearrActivityTrend(
        period: 'week',
        rangeEnd: end,
        plays: const <TracearrActivityBucket>[
          TracearrActivityBucket(count: 5),
        ],
      ),
    );

    expect(_counts(days), <int>[0, 0, 0, 0, 0, 0, 0]);
  });

  test('days stay whole across a daylight saving change', () {
    // Seven calendar days, whatever the device's zone does in between.
    final List<TracearrActivityBucket> days = dailyPlays(
      TracearrActivityTrend(period: 'week', rangeEnd: DateTime(2026, 11, 3, 12)),
    );

    expect(days.map((TracearrActivityBucket d) => d.date), <DateTime>[
      DateTime(2026, 10, 28),
      DateTime(2026, 10, 29),
      DateTime(2026, 10, 30),
      DateTime(2026, 10, 31),
      DateTime(2026, 11),
      DateTime(2026, 11, 2),
      DateTime(2026, 11, 3),
    ]);
  });
}
