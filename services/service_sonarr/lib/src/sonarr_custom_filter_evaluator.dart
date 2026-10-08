import 'package:collection/collection.dart';

import 'generated/models/custom_filter_resource.dart';
import 'models/sonarr_series.dart';

/// The `type` a custom filter for the series list is saved under.
///
/// Sonarr's filter builder saves one as `series`, and its series list also
/// takes the name of its own section. Every other type belongs to another
/// screen: interactive search saves `releases`, the calendar `calendar`.
const Set<String> sonarrSeriesCustomFilterTypes = <String>{
  'series',
  'seriesIndex',
};

/// The filters in [all] that belong on the series list, by label as
/// Sonarr's own filter menu orders them: without regard to case, and with
/// a run of digits counted as a number.
List<CustomFilterResource> sonarrSeriesCustomFilters(
  Iterable<CustomFilterResource> all,
) {
  return all
      .where(
        (CustomFilterResource f) =>
            sonarrSeriesCustomFilterTypes.contains(f.type) &&
            (f.label ?? '').isNotEmpty,
      )
      .toList()
    ..sort(
      (CustomFilterResource a, CustomFilterResource b) =>
          compareAsciiLowerCaseNatural(a.label!, b.label!),
    );
}

/// Whether [series] passes every rule of [filter], judged the way Sonarr's
/// own series list judges it.
///
/// A rule is `{key, value, type}`. This follows the web UI rule for rule,
/// quirks included, so that a filter shows the same series here as there:
///
///  - the builder saves a value as a list of alternatives, any of which may
///    match, except under `notEqual` and `notContains`, where none may;
///  - `equal` is exact, case included, while `contains` on text and the
///    starts and ends tests ignore case;
///  - a rule the series cannot be tested against rejects it: a key Sonarr
///    does not filter on, or a property the server left out, such as the
///    network of a series that has none.
///
/// [now] is the moment the relative date rules ("in the last 7 days") are
/// measured from.
bool matchesSonarrCustomFilter(
  SonarrSeries series,
  CustomFilterResource filter, {
  DateTime? now,
}) {
  final DateTime clock = now ?? DateTime.now();
  for (final Object? rule in filter.filters ?? const <Object?>[]) {
    if (rule is! Map) return false;
    final Object? key = rule['key'];
    final Object? type = rule['type'] ?? 'equal';
    if (key is! String || type is! String) return false;
    final _Test? test = _seriesTest(series, key, type, clock);
    if (test == null || !_passes(test, rule['value'], type)) return false;
  }
  return true;
}

/// Tests one value of a rule against whatever the rule's key reads.
typedef _Test = bool Function(Object? filterValue);

bool _passes(_Test test, Object? value, String type) {
  if (value is List) {
    return type == 'notEqual' || type == 'notContains'
        ? value.every(test)
        : value.any(test);
  }
  return test(value);
}

/// The test for [key] on [series], or null where it cannot be tested.
_Test? _seriesTest(
  SonarrSeries series,
  String key,
  String type,
  DateTime now,
) {
  final SonarrSeriesStatistics? stats = series.statistics;
  switch (key) {
    // Keys Sonarr works a value out for.
    case 'episodeProgress':
      final int count = stats?.episodeCount ?? 0;
      return _valueTest(
        count == 0 ? 100 : stats!.episodeFileCount / count * 100,
        type,
      );
    case 'missing':
      // Sonarr never looks at the value here: the key exists for its own
      // Missing filter, which only ever asks for true.
      final bool missing =
          stats != null && stats.episodeCount - stats.episodeFileCount > 0;
      return (_) => missing;
    case 'nextAiring':
      return _dateTest(series.nextAiring, type, now);
    case 'previousAiring':
      return _dateTest(series.previousAiring, type, now);
    case 'added':
      return _dateTest(series.added, type, now);
    case 'ratings':
      // Shown, and so filtered, as a percentage.
      return _valueTest((series.ratings?.value ?? 0) * 10, type);
    case 'ratingVotes':
      return _valueTest(series.ratings?.votes ?? 0, type);
    case 'originalLanguage':
      return _valueTest(series.originalLanguage?.name ?? '', type);
    case 'releaseGroups':
      return _valueTest(stats?.releaseGroups ?? const <String>[], type);
    case 'seasonCount':
      return _valueTest(stats?.seasonCount ?? 0, type);
    case 'sizeOnDisk':
      return _valueTest(stats?.sizeOnDisk ?? 0, type);
    case 'hasMissingSeason':
      return _valueTest(_hasMissingSeason(series), type);
    case 'seasonsMonitoredStatus':
      return _valueTest(_seasonsMonitoredStatus(series), type);

    // Plain properties, tested only where the series has one.
    case 'monitored':
      return _valueTest(series.monitored, type);
    case 'status':
      return _propertyTest(series.status, type);
    case 'seriesType':
      return _propertyTest(series.seriesType, type);
    case 'title':
      return _valueTest(series.title, type);
    case 'network':
      return _propertyTest(series.network, type);
    case 'qualityProfileId':
      return _propertyTest(series.qualityProfileId, type);
    case 'path':
      return _propertyTest(series.path, type);
    case 'rootFolderPath':
      return _propertyTest(series.rootFolderPath, type);
    case 'genres':
      return _valueTest(series.genres, type);
    case 'certification':
      return _propertyTest(series.certification, type);
    case 'tags':
      return _valueTest(series.tags, type);
    case 'useSceneNumbering':
      return _propertyTest(series.useSceneNumbering, type);
    case 'year':
      return _propertyTest(series.year, type);
  }
  return null;
}

/// A season that has aired in full and has no file at all. Specials do not
/// count.
bool _hasMissingSeason(SonarrSeries series) {
  return series.seasons.any((SonarrSeason season) {
    final SonarrSeasonStatistics? stats = season.statistics;
    final int total = stats?.totalEpisodeCount ?? 0;
    return season.seasonNumber > 0 &&
        total > 0 &&
        (stats?.episodeCount ?? 0) == total &&
        (stats?.episodeFileCount ?? 0) == 0;
  });
}

/// `all`, `partial` or `none`, by how many seasons are monitored. Specials
/// do not count.
String _seasonsMonitoredStatus(SonarrSeries series) {
  int monitored = 0;
  int unmonitored = 0;
  for (final SonarrSeason season in series.seasons) {
    if (season.seasonNumber <= 0) continue;
    if (season.monitored) {
      monitored++;
    } else {
      unmonitored++;
    }
  }
  if (monitored == 0) return 'none';
  return unmonitored == 0 ? 'all' : 'partial';
}

_Test? _propertyTest(Object? itemValue, String type) =>
    itemValue == null ? null : _valueTest(itemValue, type);

/// The test of [type] against [item], or null for a type Sonarr has none
/// for.
///
/// A test that does not apply to what it is given, such as `startsWith` on
/// a number, fails either way round: Sonarr's own page stops with an error
/// there, so there is no answer to agree with.
_Test? _valueTest(Object item, String type) {
  switch (type) {
    case 'contains':
      return (Object? value) => _contains(item, value) ?? false;
    case 'notContains':
      return (Object? value) => !(_contains(item, value) ?? true);
    case 'equal':
      return (Object? value) => item == value;
    case 'notEqual':
      return (Object? value) => item != value;
    case 'greaterThan':
    case 'greaterThanOrEqual':
    case 'lessThan':
    case 'lessThanOrEqual':
      return (Object? value) => _ordered(item, value, type);
    case 'startsWith':
      return (Object? value) =>
          _text(item, value, (String a, String b) => a.startsWith(b)) ??
          false;
    case 'notStartsWith':
      return (Object? value) =>
          !(_text(item, value, (String a, String b) => a.startsWith(b)) ??
              true);
    case 'endsWith':
      return (Object? value) =>
          _text(item, value, (String a, String b) => a.endsWith(b)) ?? false;
    case 'notEndsWith':
      return (Object? value) =>
          !(_text(item, value, (String a, String b) => a.endsWith(b)) ??
              true);
  }
  return null;
}

/// Whether a list holds [value] exactly, or a text holds it ignoring case.
bool? _contains(Object item, Object? value) {
  if (item is List) return item.contains(value);
  if (item is String && value is String) {
    return item.toLowerCase().contains(value.toLowerCase());
  }
  return null;
}

bool? _text(
  Object item,
  Object? value,
  bool Function(String item, String value) test,
) {
  if (item is! String || value is! String) return null;
  return test(item.toLowerCase(), value.toLowerCase());
}

/// The ordering tests, as JavaScript makes them: two texts by code unit,
/// anything else as numbers, and never true against something that is not
/// a number.
bool _ordered(Object item, Object? value, String type) {
  final int order;
  if (item is String && value is String) {
    order = item.compareTo(value);
  } else {
    final num? a = _number(item);
    final num? b = _number(value);
    if (a == null || b == null) return false;
    order = a < b ? -1 : (a > b ? 1 : 0);
  }
  return switch (type) {
    'greaterThan' => order > 0,
    'greaterThanOrEqual' => order >= 0,
    'lessThan' => order < 0,
    _ => order <= 0,
  };
}

/// [value] as the number JavaScript would compare it as. The builder turns
/// what is typed into a number field with `parseInt`, and an entry that is
/// not a number is saved as null, which compares as zero.
num? _number(Object? value) {
  if (value == null) return 0;
  if (value is bool) return value ? 1 : 0;
  if (value is String) {
    final String text = value.trim();
    return text.isEmpty ? 0 : _number(num.tryParse(text) ?? double.nan);
  }
  return value is num && !value.isNaN ? value : null;
}

/// The test of [type] against the date in [itemValue]. Sonarr has a date
/// test for these six types alone, and none passes without a date.
_Test _dateTest(String? itemValue, String type, DateTime now) {
  final DateTime? date =
      itemValue == null ? null : DateTime.tryParse(itemValue);
  if (date == null) return (_) => false;
  switch (type) {
    case 'lessThan':
      return (Object? value) {
        final DateTime? other = _date(value);
        return other != null && date.isBefore(other);
      };
    case 'greaterThan':
      return (Object? value) {
        final DateTime? other = _date(value);
        return other != null && date.isAfter(other);
      };
    case 'inLast':
      return (Object? value) =>
          date.isAfter(_offset(now, value, -1)) && date.isBefore(now);
    case 'notInLast':
      return (Object? value) => date.isBefore(_offset(now, value, -1));
    case 'inNext':
      return (Object? value) =>
          date.isAfter(now) && date.isBefore(_offset(now, value, 1));
    case 'notInNext':
      return (Object? value) => date.isAfter(_offset(now, value, 1));
  }
  return (_) => false;
}

/// The day the builder's date field saves, `yyyy-mm-dd`, read as midnight
/// in this device's time zone.
DateTime? _date(Object? value) {
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.round());
  return null;
}

/// [now] moved by a relative rule's `{time, value}`, the way the web UI
/// moves it: seconds, minutes and hours as elapsed time, days, weeks and
/// months on the calendar, at the same time of day.
DateTime _offset(DateTime now, Object? value, int direction) {
  final DateTime local = now.toLocal();
  if (value is! Map) return local;
  final Object? count = value['value'];
  final num amount = (count is num ? count : 0) * direction;
  switch (value['time']) {
    case 'seconds':
      return local.add(_elapsed(amount, Duration.microsecondsPerSecond));
    case 'minutes':
      return local.add(_elapsed(amount, Duration.microsecondsPerMinute));
    case 'hours':
      return local.add(_elapsed(amount, Duration.microsecondsPerHour));
    case 'days':
      return _addDays(local, amount.round());
    case 'weeks':
      return _addDays(local, (amount * 7).round());
    case 'months':
      return _addMonths(local, amount.round());
  }
  return local;
}

Duration _elapsed(num amount, int microsecondsEach) =>
    Duration(microseconds: (amount * microsecondsEach).round());

DateTime _addDays(DateTime time, int days) => DateTime(
      time.year,
      time.month,
      time.day + days,
      time.hour,
      time.minute,
      time.second,
      time.millisecond,
      time.microsecond,
    );

/// [months] later on the same day of the month, or on the month's last day
/// where it has no such day.
DateTime _addMonths(DateTime time, int months) {
  final int index = time.month - 1 + months;
  final int year = time.year + (index / 12).floor();
  final int month = index % 12 + 1;
  final int lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(
    year,
    month,
    time.day < lastDay ? time.day : lastDay,
    time.hour,
    time.minute,
    time.second,
    time.millisecond,
    time.microsecond,
  );
}
