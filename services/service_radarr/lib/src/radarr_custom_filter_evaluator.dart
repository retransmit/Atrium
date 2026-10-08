import 'package:collection/collection.dart';

import 'models/radarr_custom_filter.dart';
import 'models/radarr_movie.dart';

/// The `type` a custom filter for the movie list is saved under.
///
/// Radarr's filter builder saves one as `movieIndex`, and its movie list
/// also takes the name of the section behind it. Every other type belongs
/// to another screen: interactive search saves `releases`, Discover
/// `discoverMovie`.
const Set<String> radarrMovieCustomFilterTypes = <String>{
  'movieIndex',
  'movies',
};

/// The filters in [all] that belong on the movie list, by label as
/// Radarr's own filter menu orders them: without regard to case, and with
/// a run of digits counted as a number.
List<RadarrCustomFilter> radarrMovieCustomFilters(
  Iterable<RadarrCustomFilter> all,
) {
  return all
      .where(
        (RadarrCustomFilter f) =>
            radarrMovieCustomFilterTypes.contains(f.type) &&
            (f.label ?? '').isNotEmpty,
      )
      .toList()
    ..sort(
      (RadarrCustomFilter a, RadarrCustomFilter b) =>
          compareAsciiLowerCaseNatural(a.label!, b.label!),
    );
}

/// Whether [movie] passes every rule of [filter], judged the way Radarr's
/// own movie list judges it.
///
/// A rule is `{key, value, type}`. This follows the web UI rule for rule,
/// quirks included, so that a filter shows the same movies here as there:
///
///  - the builder saves a value as a list of alternatives, any of which may
///    match, except under `notEqual` and `notContains`, where none may;
///  - `equal` is exact, case included, while `contains` on text and the
///    starts and ends tests ignore case;
///  - a rule the movie cannot be tested against rejects it: a key Radarr
///    does not filter on, or a property the server left out, such as the
///    certification of a movie that has none.
///
/// [now] is the moment the relative date rules ("in the last 7 days") are
/// measured from.
bool matchesRadarrCustomFilter(
  RadarrMovie movie,
  RadarrCustomFilter filter, {
  DateTime? now,
}) {
  final DateTime clock = now ?? DateTime.now();
  for (final Object? rule in filter.filters ?? const <Object?>[]) {
    if (rule is! Map) return false;
    final Object? key = rule['key'];
    final Object? type = rule['type'] ?? 'equal';
    if (key is! String || type is! String) return false;
    final _Test? test = _movieTest(movie, key, type, clock);
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

/// The test for [key] on [movie], or null where it cannot be tested.
_Test? _movieTest(
  RadarrMovie movie,
  String key,
  String type,
  DateTime now,
) {
  final RadarrRatings? ratings = movie.ratings;
  final RadarrMovieStatistics? stats = movie.statistics;
  switch (key) {
    // Keys Radarr works a value out for.
    case 'added':
      return _dateTest(movie.added, type, now);
    case 'inCinemas':
      return _dateTest(movie.inCinemas, type, now);
    case 'physicalRelease':
      return _dateTest(movie.physicalRelease, type, now);
    case 'digitalRelease':
      return _dateTest(movie.digitalRelease, type, now);
    case 'releaseDate':
      return _dateTest(movie.releaseDate, type, now);
    case 'collection':
      return _valueTest(movie.collection?.title ?? '', type);
    case 'originalLanguage':
      return _valueTest(movie.originalLanguage?.name ?? '', type);
    case 'releaseGroups':
      return _valueTest(stats?.releaseGroups ?? const <String>[], type);
    case 'movieFileQualities':
      return _valueTest(
        <int>[
          for (final RadarrMovieFileQuality quality
              in stats?.movieFileQualities ?? const <RadarrMovieFileQuality>[])
            quality.id,
        ],
        type,
      );
    case 'sizeOnDisk':
      // Radarr reads the statistics. A server old enough to send none
      // still sends the size on the movie itself.
      return _valueTest(stats?.sizeOnDisk ?? movie.sizeOnDisk, type);
    case 'tmdbRating':
      // The two shown as a percentage are filtered as one.
      return _valueTest((ratings?.tmdb?.value ?? 0) * 10, type);
    case 'tmdbVotes':
      return _valueTest(ratings?.tmdb?.votes ?? 0, type);
    case 'imdbRating':
      return _valueTest(ratings?.imdb?.value ?? 0, type);
    case 'imdbVotes':
      return _valueTest(ratings?.imdb?.votes ?? 0, type);
    case 'rottenTomatoesRating':
      return _valueTest(ratings?.rottenTomatoes?.value ?? 0, type);
    case 'traktRating':
      return _valueTest((ratings?.trakt?.value ?? 0) * 10, type);
    case 'traktVotes':
      return _valueTest(ratings?.trakt?.votes ?? 0, type);

    // Plain properties, tested only where the movie has one.
    case 'monitored':
      return _valueTest(movie.monitored, type);
    case 'hasFile':
      return _valueTest(movie.hasFile, type);
    case 'isAvailable':
      return _propertyTest(movie.isAvailable, type);
    case 'minimumAvailability':
      return _propertyTest(movie.minimumAvailability, type);
    case 'title':
      return _valueTest(movie.title, type);
    case 'originalTitle':
      return _propertyTest(movie.originalTitle, type);
    case 'status':
      return _propertyTest(movie.status, type);
    case 'studio':
      return _propertyTest(movie.studio, type);
    case 'qualityProfileId':
      return _propertyTest(movie.qualityProfileId, type);
    case 'year':
      return _propertyTest(movie.year, type);
    case 'runtime':
      return _propertyTest(movie.runtime, type);
    case 'path':
      return _propertyTest(movie.path, type);
    case 'genres':
      return _valueTest(movie.genres, type);
    case 'keywords':
      return _propertyTest(movie.keywords, type);
    case 'popularity':
      return _propertyTest(movie.popularity, type);
    case 'certification':
      return _propertyTest(movie.certification, type);
    case 'tags':
      return _valueTest(movie.tags, type);
  }
  return null;
}

_Test? _propertyTest(Object? itemValue, String type) =>
    itemValue == null ? null : _valueTest(itemValue, type);

/// The test of [type] against [item], or null for a type Radarr has none
/// for.
///
/// A test that does not apply to what it is given, such as `startsWith` on
/// a number, fails either way round: Radarr's own page stops with an error
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

/// The test of [type] against the date in [itemValue]. Radarr has a date
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
