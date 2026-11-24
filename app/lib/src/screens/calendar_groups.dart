import 'calendar_screen.dart';

/// Where a release stands, as the calendar's badge and accent show it.
enum CalendarStatus { downloaded, upcoming, missing }

/// [event]'s own status at [now]: downloaded with a file, upcoming until it
/// airs, missing once it has aired without one.
CalendarStatus calendarStatusOf(CalendarEvent event, DateTime now) {
  if (event.hasFile) return CalendarStatus.downloaded;
  return event.date.isAfter(now)
      ? CalendarStatus.upcoming
      : CalendarStatus.missing;
}

/// One calendar row: a release, or every episode of one series that airs on
/// the same day on the same instance (a season dropped at once).
class CalendarGroup {
  CalendarGroup._(this.id, this.events);

  /// Stable across rebuilds and refreshes: the instance, the series and the
  /// day for a group of episodes, the item itself otherwise. Rows are keyed
  /// by it so an opened row stays with its own group.
  final Object id;

  /// Oldest episode first; a single release is a group of one.
  final List<CalendarEvent> events;

  /// The event the row is drawn from.
  CalendarEvent get first => events.first;

  /// How many more the row stands for, shown as "+N more".
  int get more => events.length - 1;

  /// The earliest air time in the group.
  DateTime get date => events
      .map((CalendarEvent e) => e.date)
      .reduce((DateTime a, DateTime b) => b.isBefore(a) ? b : a);

  /// Monitored when any of them is, since Sonarr will grab that one.
  bool get monitored => events.any((CalendarEvent e) => e.monitored);

  bool get allHaveFiles => events.every((CalendarEvent e) => e.hasFile);

  /// Missing if any has aired without a file, so a gap is never hidden
  /// behind a happier badge; then upcoming if any is still to air;
  /// downloaded only when every one has its file.
  CalendarStatus status(DateTime now) {
    final Iterable<CalendarStatus> all =
        events.map((CalendarEvent e) => calendarStatusOf(e, now));
    if (all.contains(CalendarStatus.missing)) return CalendarStatus.missing;
    if (all.contains(CalendarStatus.upcoming)) return CalendarStatus.upcoming;
    return CalendarStatus.downloaded;
  }
}

/// Folds [events] into calendar rows, in time order.
///
/// Episodes of the same series on the same instance and the same local day
/// share a row. Movies and albums keep one row each. An episode that arrives
/// twice, as it can from two months' calendars meeting at a boundary, counts
/// once.
List<CalendarGroup> groupCalendarEvents(Iterable<CalendarEvent> events) {
  final Map<Object, List<CalendarEvent>> byKey = <Object, List<CalendarEvent>>{};
  final Set<(String, int)> seenEpisodes = <(String, int)>{};
  for (final CalendarEvent e in events) {
    final DateTime local = e.date.toLocal();
    final DateTime day = DateTime(local.year, local.month, local.day);
    final Object key = switch (e) {
      SonarrCalendarEvent() => ('episodes', e.instance.id, e.episode.seriesId, day),
      RadarrCalendarEvent() => ('movie', e.instance.id, e.movie.id, day),
      LidarrCalendarEvent() => ('album', e.instance.id, e.album.id, day),
    };
    if (e is SonarrCalendarEvent &&
        !seenEpisodes.add((e.instance.id, e.episode.id))) {
      continue;
    }
    byKey.putIfAbsent(key, () => <CalendarEvent>[]).add(e);
  }
  final List<CalendarGroup> groups = <CalendarGroup>[
    for (final MapEntry<Object, List<CalendarEvent>> entry in byKey.entries)
      CalendarGroup._(entry.key, entry.value..sort(_episodeOrder)),
  ]..sort((CalendarGroup a, CalendarGroup b) => a.date.compareTo(b.date));
  return groups;
}

int _episodeOrder(CalendarEvent a, CalendarEvent b) {
  if (a is SonarrCalendarEvent && b is SonarrCalendarEvent) {
    final int bySeason =
        a.episode.seasonNumber.compareTo(b.episode.seasonNumber);
    if (bySeason != 0) return bySeason;
    return a.episode.episodeNumber.compareTo(b.episode.episodeNumber);
  }
  return a.date.compareTo(b.date);
}
