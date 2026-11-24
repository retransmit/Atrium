import 'package:atrium/src/screens/calendar_groups.dart';
import 'package:atrium/src/screens/calendar_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sonarr/service_sonarr.dart';

Instance _sonarr(String id) => Instance(
      id: id,
      name: id,
      kind: ServiceKind.sonarr,
      localUrl: 'http://$id.test',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

final Instance _a = _sonarr('sonarr-a');
final Instance _b = _sonarr('sonarr-b');

const SonarrSeries _bladeRunner =
    SonarrSeries(id: 7, title: 'Blade Runner 2099', monitored: true);
const SonarrSeries _stick = SonarrSeries(id: 8, title: 'Stick', monitored: true);

int _ids = 0;

SonarrCalendarEvent _ep(
  SonarrSeries series,
  int episode,
  DateTime airs, {
  Instance? instance,
  int season = 1,
  bool hasFile = false,
  bool monitored = true,
}) =>
    SonarrCalendarEvent(
      SonarrEpisode(
        id: ++_ids,
        seriesId: series.id,
        seasonNumber: season,
        episodeNumber: episode,
        title: 'Episode $episode',
        hasFile: hasFile,
        monitored: monitored,
        airDateUtc: airs.toUtc().toIso8601String(),
        series: series,
      ),
      instance ?? _a,
    );

String _code(CalendarEvent e) {
  final SonarrEpisode ep = (e as SonarrCalendarEvent).episode;
  return 'S${ep.seasonNumber}E${ep.episodeNumber}';
}

void main() {
  final DateTime day = DateTime(2026, 11, 25, 7, 30);

  group('grouping', () {
    test('one series on one day is one row, first episode first', () {
      final List<CalendarGroup> groups = groupCalendarEvents(<CalendarEvent>[
        _ep(_bladeRunner, 3, day),
        _ep(_bladeRunner, 1, day.add(const Duration(minutes: 30))),
        _ep(_bladeRunner, 2, day),
      ]);
      expect(groups, hasLength(1));
      final CalendarGroup g = groups.single;
      expect(_code(g.first), 'S1E1');
      expect(g.more, 2);
      expect(g.events.map(_code), <String>['S1E1', 'S1E2', 'S1E3']);
      // The earliest air time, not the first episode's.
      expect(g.date, day);
    });

    test('a later season sorts after an earlier one', () {
      final CalendarGroup g = groupCalendarEvents(<CalendarEvent>[
        _ep(_bladeRunner, 1, day, season: 2),
        _ep(_bladeRunner, 10, day, season: 1),
      ]).single;
      expect(_code(g.first), 'S1E10');
    });

    test('other days, other series and other instances stay apart', () {
      final List<CalendarGroup> groups = groupCalendarEvents(<CalendarEvent>[
        _ep(_bladeRunner, 1, day),
        _ep(_bladeRunner, 2, day.add(const Duration(days: 1))),
        _ep(_stick, 5, day),
        _ep(_bladeRunner, 1, day, instance: _b),
      ]);
      expect(groups, hasLength(4));
      expect(groups.every((CalendarGroup g) => g.more == 0), isTrue);
    });

    test('the same episode fetched twice counts once', () {
      // Two months' calendars can both carry an episode near the boundary,
      // as separate objects.
      SonarrCalendarEvent copy(int id, int n) => SonarrCalendarEvent(
            SonarrEpisode(
              id: id,
              seriesId: _bladeRunner.id,
              seasonNumber: 1,
              episodeNumber: n,
              title: 'Episode $n',
              airDateUtc: day.toUtc().toIso8601String(),
              series: _bladeRunner,
            ),
            _a,
          );
      final List<CalendarGroup> groups = groupCalendarEvents(<CalendarEvent>[
        copy(501, 1),
        copy(502, 2),
        copy(501, 1),
        copy(502, 2),
      ]);
      expect(groups.single.more, 1);
    });

    test('a single episode is a group of one', () {
      final CalendarGroup g =
          groupCalendarEvents(<CalendarEvent>[_ep(_stick, 5, day)]).single;
      expect(g.more, 0);
      expect(g.events, hasLength(1));
    });

    test('movies never group, even on one day', () {
      final Instance radarr = Instance(
        id: 'radarr',
        name: 'radarr',
        kind: ServiceKind.radarr,
        localUrl: 'http://radarr.test',
        externalUrl: '',
        urlMode: UrlMode.auto,
        auth: const InstanceAuth.apiKey(apiKey: 'k'),
      );
      RadarrCalendarEvent movie(int id) => RadarrCalendarEvent(
            RadarrMovie(
              id: id,
              title: 'Movie $id',
              inCinemas: day.toIso8601String(),
              monitored: true,
              hasFile: false,
            ),
            radarr,
            DateTime(day.year, day.month),
          );
      expect(
        groupCalendarEvents(<CalendarEvent>[movie(1), movie(2)]),
        hasLength(2),
      );
    });

    test('groups come out in time order', () {
      final List<CalendarGroup> groups = groupCalendarEvents(<CalendarEvent>[
        _ep(_stick, 5, day.add(const Duration(hours: 3))),
        _ep(_bladeRunner, 1, day),
        _ep(_bladeRunner, 2, day),
      ]);
      expect(groups.map((CalendarGroup g) => g.first.primaryTitle), <String>[
        'Blade Runner 2099',
        'Stick',
      ]);
    });
  });

  group('status', () {
    final DateTime now = day;
    final DateTime before = day.subtract(const Duration(hours: 1));
    final DateTime after = day.add(const Duration(hours: 1));

    CalendarStatus of(List<CalendarEvent> events) =>
        groupCalendarEvents(events).single.status(now);

    test('all downloaded reads Downloaded', () {
      expect(
        of(<CalendarEvent>[
          _ep(_bladeRunner, 1, before, hasFile: true),
          _ep(_bladeRunner, 2, before, hasFile: true),
        ]),
        CalendarStatus.downloaded,
      );
    });

    test('one aired without a file among upcoming ones reads Missing', () {
      expect(
        of(<CalendarEvent>[
          _ep(_bladeRunner, 1, before),
          _ep(_bladeRunner, 2, after),
          _ep(_bladeRunner, 3, after),
        ]),
        CalendarStatus.missing,
      );
    });

    test('downloaded and still to air reads Upcoming', () {
      expect(
        of(<CalendarEvent>[
          _ep(_bladeRunner, 1, before, hasFile: true),
          _ep(_bladeRunner, 2, after),
        ]),
        CalendarStatus.upcoming,
      );
    });

    test('a single episode keeps its own status', () {
      expect(of(<CalendarEvent>[_ep(_stick, 5, after)]),
          CalendarStatus.upcoming);
      expect(of(<CalendarEvent>[_ep(_stick, 5, before)]),
          CalendarStatus.missing);
    });

    test('monitored when any episode is', () {
      final CalendarGroup g = groupCalendarEvents(<CalendarEvent>[
        _ep(_bladeRunner, 1, day, monitored: false),
        _ep(_bladeRunner, 2, day),
      ]).single;
      expect(g.monitored, isTrue);
      expect(
        groupCalendarEvents(<CalendarEvent>[
          _ep(_bladeRunner, 1, day, monitored: false),
        ]).single.monitored,
        isFalse,
      );
    });

    test('all have files only when every episode has one', () {
      expect(
        groupCalendarEvents(<CalendarEvent>[
          _ep(_bladeRunner, 1, before, hasFile: true),
          _ep(_bladeRunner, 2, before),
        ]).single.allHaveFiles,
        isFalse,
      );
    });
  });
}
