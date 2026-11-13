import 'package:atrium/src/share_intake/title_resolver.dart';
import 'package:atrium/src/share_intake/title_share.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sonarr/service_sonarr.dart';

Instance _instance(String id, ServiceKind kind) => Instance(
      id: id,
      name: id,
      kind: kind,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

final Instance _radarrA = _instance('radarr-a', ServiceKind.radarr);
final Instance _radarrB = _instance('radarr-b', ServiceKind.radarr);
final Instance _sonarr = _instance('sonarr', ServiceKind.sonarr);

const RadarrMovie _wargames = RadarrMovie(title: 'WarGames', tmdbId: 860);
const SonarrSeries _severance = SonarrSeries(title: 'Severance', tvdbId: 1);

/// Records every lookup as `instance id|term`.
class _Calls {
  final List<String> movies = <String>[];
  final List<String> series = <String>[];
}

Future<TitleResolution> _resolve(
  TitleShare share,
  _Calls calls, {
  List<Instance>? radarrs,
  List<Instance>? sonarrs,
  Map<String, Object> movieAnswers = const <String, Object>{},
  Map<String, Object> seriesAnswers = const <String, Object>{},
  LetterboxdReader? readLetterboxd,
}) =>
    resolveTitleShare(
      share,
      radarrs: radarrs ?? <Instance>[_radarrA],
      sonarrs: sonarrs ?? <Instance>[_sonarr],
      lookupMovies: (Instance i, String term) async {
        calls.movies.add('${i.id}|$term');
        final Object answer = movieAnswers[i.id] ?? <RadarrMovie>[];
        if (answer is Exception) throw answer;
        return answer as List<RadarrMovie>;
      },
      lookupSeries: (Instance i, String term) async {
        calls.series.add('${i.id}|$term');
        final Object answer = seriesAnswers[i.id] ?? <SonarrSeries>[];
        if (answer is Exception) throw answer;
        return answer as List<SonarrSeries>;
      },
      readLetterboxd: readLetterboxd ?? (Uri _) async => null,
    );

void main() {
  test('an IMDb movie asks only Radarr, by imdb: term', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      const TitleShare(kind: TitleKind.movie, imdbId: 'tt0086567'),
      calls,
      movieAnswers: <String, Object>{
        'radarr-a': <RadarrMovie>[_wargames],
      },
    );
    expect(calls.movies, <String>['radarr-a|imdb:tt0086567']);
    expect(calls.series, isEmpty);
    expect(r.byId, isTrue);
    expect(r.matches.single, isA<MovieMatch>());
    expect((r.matches.single as MovieMatch).movie, _wargames);
    expect(r.matches.single.source, _radarrA);
  });

  test('an unknown-kind IMDb ID asks both', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      const TitleShare(kind: TitleKind.unknown, imdbId: 'tt11280740'),
      calls,
      seriesAnswers: <String, Object>{
        'sonarr': <SonarrSeries>[_severance],
      },
    );
    expect(calls.movies, <String>['radarr-a|imdb:tt11280740']);
    expect(calls.series, <String>['sonarr|imdb:tt11280740']);
    expect(r.matches.single, isA<SeriesMatch>());
  });

  test('a TMDB ID is searched as tmdb:', () async {
    final _Calls calls = _Calls();
    await _resolve(
      const TitleShare(kind: TitleKind.show, tmdbId: 1396),
      calls,
    );
    expect(calls.series, <String>['sonarr|tmdb:1396']);
    expect(calls.movies, isEmpty);
  });

  test('a TVDB ID asks Sonarr by tvdb: term', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      const TitleShare(kind: TitleKind.show, tvdbId: 81189),
      calls,
    );
    expect(calls.series, <String>['sonarr|tvdb:81189']);
    expect(calls.movies, isEmpty);
    expect(r.byId, isTrue);
  });

  test('Letterboxd supplies a TMDB ID and kind', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      TitleShare(
        kind: TitleKind.unknown,
        letterboxdUrl: Uri.parse('https://boxd.it/29qU'),
      ),
      calls,
      readLetterboxd: (Uri _) async =>
          (tmdbId: 860, imdbId: null, kind: TitleKind.movie),
    );
    expect(calls.movies, <String>['radarr-a|tmdb:860']);
    expect(calls.series, isEmpty);
    expect(r.byId, isTrue);
  });

  test('a Letterboxd show asks only Sonarr, by its IMDb ID', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      TitleShare(
        kind: TitleKind.unknown,
        letterboxdUrl: Uri.parse('https://boxd.it/hIUy'),
      ),
      calls,
      readLetterboxd: (Uri _) async =>
          (tmdbId: 87108, imdbId: 'tt7366338', kind: TitleKind.show),
    );
    expect(calls.movies, isEmpty);
    expect(calls.series, <String>['sonarr|imdb:tt7366338']);
    expect(r.byId, isTrue);
  });

  test('a Letterboxd IMDb ID of unknown kind asks both', () async {
    final _Calls calls = _Calls();
    await _resolve(
      TitleShare(
        kind: TitleKind.unknown,
        letterboxdUrl: Uri.parse('https://boxd.it/hIUy'),
      ),
      calls,
      readLetterboxd: (Uri _) async =>
          (tmdbId: null, imdbId: 'tt7366338', kind: TitleKind.unknown),
    );
    expect(calls.movies, <String>['radarr-a|imdb:tt7366338']);
    expect(calls.series, <String>['sonarr|imdb:tt7366338']);
  });

  test('Letterboxd unreadable falls back to the title', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      TitleShare(
        kind: TitleKind.unknown,
        letterboxdUrl: Uri.parse('https://boxd.it/29qU'),
        title: 'WarGames',
      ),
      calls,
    );
    expect(calls.movies, <String>['radarr-a|WarGames']);
    expect(calls.series, <String>['sonarr|WarGames']);
    expect(r.byId, isFalse);
  });

  test('an unreachable instance falls through to the next', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      const TitleShare(kind: TitleKind.movie, title: 'WarGames'),
      calls,
      radarrs: <Instance>[_radarrA, _radarrB],
      movieAnswers: <String, Object>{
        'radarr-a': Exception('down'),
        'radarr-b': <RadarrMovie>[_wargames],
      },
    );
    expect(r.matches.single.source, _radarrB);
    expect(r.unreachable, <Instance>[_radarrA]);
  });

  test('every instance down lists them all, with no matches', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      const TitleShare(kind: TitleKind.movie, title: 'WarGames'),
      calls,
      radarrs: <Instance>[_radarrA, _radarrB],
      movieAnswers: <String, Object>{
        'radarr-a': Exception('down'),
        'radarr-b': Exception('down'),
      },
    );
    expect(r.matches, isEmpty);
    expect(r.unreachable, <Instance>[_radarrA, _radarrB]);
  });

  test('no instances for the kind gives no matches', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      const TitleShare(kind: TitleKind.show, title: 'Severance'),
      calls,
      sonarrs: <Instance>[],
    );
    expect(r.matches, isEmpty);
    expect(calls.movies, isEmpty);
    expect(calls.series, isEmpty);
  });

  test('movies come before shows', () async {
    final _Calls calls = _Calls();
    final TitleResolution r = await _resolve(
      const TitleShare(kind: TitleKind.unknown, title: 'Fargo'),
      calls,
      movieAnswers: <String, Object>{
        'radarr-a': <RadarrMovie>[_wargames],
      },
      seriesAnswers: <String, Object>{
        'sonarr': <SonarrSeries>[_severance],
      },
    );
    expect(r.matches.first, isA<MovieMatch>());
    expect(r.matches.last, isA<SeriesMatch>());
  });
}
