import 'dart:convert';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/bazarr_models.dart';

/// Thin client over the Bazarr API.
///
/// Auth is an API-key header (added by `core_networking`'s [AuthInterceptor]),
/// so this rides the shared `instanceDioProvider` Dio.
class BazarrApi {
  BazarrApi(this._dio);

  final Dio _dio;

  Future<BazarrBadges> getBadges() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('api/badges');
      return BazarrBadges.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<BazarrWantedEpisode>> getWantedEpisodes() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/episodes/wanted',
        queryParameters: <String, dynamic>{'start': 0, 'length': -1},
      );
      return BazarrWantedEpisodes.fromJson(resp.data as Map<String, dynamic>)
          .data;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<BazarrWantedMovie>> getWantedMovies() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/movies/wanted',
        queryParameters: <String, dynamic>{'start': 0, 'length': -1},
      );
      return BazarrWantedMovies.fromJson(resp.data as Map<String, dynamic>)
          .data;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// All series (Sonarr-backed) with subtitle status. `length=-1` returns the
  /// whole list; Bazarr's series rows are lightweight (no episodes).
  Future<List<BazarrSeries>> getSeries() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/series',
        queryParameters: <String, dynamic>{'start': 0, 'length': -1},
      );
      final List<dynamic> data =
          (resp.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data
          .map((dynamic e) => BazarrSeries.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// All movies (Radarr-backed) with their present/missing subtitle lists.
  Future<List<BazarrMovie>> getMovies() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/movies',
        queryParameters: <String, dynamic>{'start': 0, 'length': -1},
      );
      final List<dynamic> data =
          (resp.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data
          .map((dynamic e) => BazarrMovie.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Episodes for one series (`seriesid[]=`), each with subtitle status.
  Future<List<BazarrEpisode>> getEpisodes(int seriesId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/episodes',
        queryParameters: <String, dynamic>{'seriesid[]': seriesId},
      );
      final List<dynamic> data =
          (resp.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data
          .map((dynamic e) => BazarrEpisode.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Manual subtitle search for one episode (`GET /providers/episodes`). Hits
  /// live providers, so it gets a long receive timeout.
  Future<List<BazarrSubtitleSearchResult>> searchEpisodeSubtitles(
    int episodeId,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/providers/episodes',
        queryParameters: <String, dynamic>{'episodeid': episodeId},
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      return _parseResults(resp.data);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Manual subtitle search for one movie (`GET /providers/movies`).
  Future<List<BazarrSubtitleSearchResult>> searchMovieSubtitles(
    int radarrId,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/providers/movies',
        queryParameters: <String, dynamic>{'radarrid': radarrId},
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      return _parseResults(resp.data);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  List<BazarrSubtitleSearchResult> _parseResults(dynamic data) {
    final List<dynamic> list = data is Map<String, dynamic>
        ? ((data['data'] as List<dynamic>?) ?? const <dynamic>[])
        : (data as List<dynamic>);
    return list
        .map(
          (dynamic e) =>
              BazarrSubtitleSearchResult.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// Downloads a chosen manual-search result for an episode
  /// (`POST /providers/episodes`). Round-trips the result's provider/token/flags.
  Future<void> downloadEpisodeSubtitle({
    required int seriesId,
    required int episodeId,
    required BazarrSubtitleSearchResult result,
  }) async {
    try {
      await _dio.post<dynamic>(
        'api/providers/episodes',
        queryParameters: <String, dynamic>{
          'seriesid': seriesId,
          'episodeid': episodeId,
          'hi': result.hearingImpaired,
          'forced': result.forced,
          'original_format': result.originalFormat,
          'provider': result.provider,
          'subtitle': result.subtitle,
        },
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Downloads a chosen manual-search result for a movie
  /// (`POST /providers/movies`).
  Future<void> downloadMovieSubtitle({
    required int radarrId,
    required BazarrSubtitleSearchResult result,
  }) async {
    try {
      await _dio.post<dynamic>(
        'api/providers/movies',
        queryParameters: <String, dynamic>{
          'radarrid': radarrId,
          'hi': result.hearingImpaired,
          'forced': result.forced,
          'original_format': result.originalFormat,
          'provider': result.provider,
          'subtitle': result.subtitle,
        },
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes a downloaded subtitle from an episode (`DELETE /episodes/subtitles`).
  Future<void> deleteEpisodeSubtitle({
    required int seriesId,
    required int episodeId,
    required BazarrSubtitle subtitle,
  }) async {
    try {
      await _dio.delete<dynamic>(
        'api/episodes/subtitles',
        queryParameters: <String, dynamic>{
          'seriesid': seriesId,
          'episodeid': episodeId,
          'language':
              subtitle.code2.isNotEmpty ? subtitle.code2 : subtitle.code3,
          'forced': subtitle.forced ? 'True' : 'False',
          'hi': subtitle.hi ? 'True' : 'False',
          'path': subtitle.path ?? '',
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes a downloaded subtitle from a movie (`DELETE /movies/subtitles`).
  Future<void> deleteMovieSubtitle({
    required int radarrId,
    required BazarrSubtitle subtitle,
  }) async {
    try {
      await _dio.delete<dynamic>(
        'api/movies/subtitles',
        queryParameters: <String, dynamic>{
          'radarrid': radarrId,
          'language':
              subtitle.code2.isNotEmpty ? subtitle.code2 : subtitle.code3,
          'forced': subtitle.forced ? 'True' : 'False',
          'hi': subtitle.hi ? 'True' : 'False',
          'path': subtitle.path ?? '',
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Episode subtitle history (`GET /episodes/history`), newest first.
  Future<List<BazarrHistoryItem>> getEpisodeHistory({int length = 50}) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/episodes/history',
        queryParameters: <String, dynamic>{'start': 0, 'length': length},
      );
      return _parseHistory(resp.data, isMovie: false);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Movie subtitle history (`GET /movies/history`), newest first.
  Future<List<BazarrHistoryItem>> getMovieHistory({int length = 50}) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/movies/history',
        queryParameters: <String, dynamic>{'start': 0, 'length': length},
      );
      return _parseHistory(resp.data, isMovie: true);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  List<BazarrHistoryItem> _parseHistory(dynamic data, {required bool isMovie}) {
    final List<dynamic> list = data is Map<String, dynamic>
        ? ((data['data'] as List<dynamic>?) ?? const <dynamic>[])
        : (data as List<dynamic>);
    return list
        .map(
          (dynamic e) => BazarrHistoryItem.fromJson(e as Map<String, dynamic>)
              .copyWith(isMovie: isMovie),
        )
        .toList();
  }

  /// Blacklisted episode subtitles (`GET /episodes/blacklist`). No paging params
  /// are sent: Bazarr 500s on an empty movies blacklist when they are present.
  Future<List<BazarrBlacklistItem>> getEpisodeBlacklist() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('api/episodes/blacklist');
      return _parseBlacklist(resp.data, isMovie: false);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Blacklisted movie subtitles (`GET /movies/blacklist`).
  Future<List<BazarrBlacklistItem>> getMovieBlacklist() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('api/movies/blacklist');
      return _parseBlacklist(resp.data, isMovie: true);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  List<BazarrBlacklistItem> _parseBlacklist(
    dynamic data, {
    required bool isMovie,
  }) {
    final List<dynamic> list = data is Map<String, dynamic>
        ? ((data['data'] as List<dynamic>?) ?? const <dynamic>[])
        : (data as List<dynamic>);
    return list
        .map(
          (dynamic e) => BazarrBlacklistItem.fromJson(e as Map<String, dynamic>)
              .copyWith(isMovie: isMovie),
        )
        .toList();
  }

  /// Removes a blacklisted episode subtitle (`DELETE /episodes/blacklist`).
  Future<void> removeEpisodeBlacklist({
    required String provider,
    required String subsId,
  }) async {
    try {
      await _dio.delete<dynamic>(
        'api/episodes/blacklist',
        queryParameters: <String, dynamic>{
          'provider': provider,
          'subs_id': subsId,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Removes a blacklisted movie subtitle (`DELETE /movies/blacklist`).
  Future<void> removeMovieBlacklist({
    required String provider,
    required String subsId,
  }) async {
    try {
      await _dio.delete<dynamic>(
        'api/movies/blacklist',
        queryParameters: <String, dynamic>{
          'provider': provider,
          'subs_id': subsId,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- System ---

  /// System status (versions, OS, database, uptime).
  Future<BazarrSystemStatus> getSystemStatus() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('api/system/status');
      final dynamic data = resp.data;
      final Map<String, dynamic> obj = data is Map<String, dynamic>
          ? ((data['data'] as Map<String, dynamic>?) ?? data)
          : <String, dynamic>{};
      return BazarrSystemStatus.fromJson(obj);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Active health issues (`GET /system/health`); empty when healthy.
  Future<List<BazarrHealthItem>> getSystemHealth() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('api/system/health');
      return _listFrom(resp.data)
          .map(
            (dynamic e) => BazarrHealthItem.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Scheduled tasks (`GET /system/tasks`).
  Future<List<BazarrSystemTask>> getSystemTasks() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('api/system/tasks');
      return _listFrom(resp.data)
          .map(
            (dynamic e) => BazarrSystemTask.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Runs a scheduled task now (`POST /system/tasks?taskid=`).
  Future<void> runTask(String taskId) async {
    try {
      await _dio.post<dynamic>(
        'api/system/tasks',
        queryParameters: <String, dynamic>{'taskid': taskId},
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Subtitle provider statuses (`GET /providers`).
  Future<List<BazarrProviderStatus>> getProviderStatuses() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('api/providers');
      return _listFrom(resp.data)
          .map(
            (dynamic e) =>
                BazarrProviderStatus.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Resets throttled providers (`POST /providers?action=reset`).
  Future<void> resetProviders() async {
    try {
      await _dio.post<dynamic>(
        'api/providers',
        queryParameters: <String, dynamic>{'action': 'reset'},
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Existing backups (`GET /system/backups`).
  Future<List<BazarrBackup>> getBackups() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('api/system/backups');
      return _listFrom(resp.data)
          .map((dynamic e) => BazarrBackup.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Creates a backup now (`POST /system/backups`).
  Future<void> createBackup() async {
    try {
      await _dio.post<dynamic>('api/system/backups');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes a backup (`DELETE /system/backups?filename=`).
  Future<void> deleteBackup(String filename) async {
    try {
      await _dio.delete<dynamic>(
        'api/system/backups',
        queryParameters: <String, dynamic>{'filename': filename},
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Recent log lines (`GET /system/logs`), newest first.
  Future<List<BazarrLogEntry>> getLogs() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('api/system/logs');
      return _listFrom(resp.data)
          .map(
              (dynamic e) => BazarrLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Clears the logs (`DELETE /system/logs`).
  Future<void> clearLogs() async {
    try {
      await _dio.delete<dynamic>('api/system/logs');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Settings: languages ---

  /// All subtitle languages (`GET /system/languages`) with their enabled flag.
  Future<List<BazarrLanguage>> getLanguages() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('api/system/languages');
      return _listFrom(resp.data)
          .map(
              (dynamic e) => BazarrLanguage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Sets the full set of enabled languages (`POST /system/settings`,
  /// form-urlencoded, `languages-enabled` repeated for each code). A partial
  /// POST: only this field changes, the rest of the config is untouched.
  Future<void> setEnabledLanguages(List<String> codes) async {
    try {
      await _dio.post<dynamic>(
        'api/system/settings',
        data: <String, dynamic>{'languages-enabled': codes},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          listFormat: ListFormat.multi,
        ),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Settings: providers ---

  /// The full settings object (`GET /system/settings`). Used for
  /// `general.enabled_providers` and per-provider config sections.
  Future<Map<String, dynamic>> getBazarrSettings() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('api/system/settings');
      final dynamic data = resp.data;
      if (data is Map<String, dynamic>) {
        return (data['data'] as Map<String, dynamic>?) ?? data;
      }
      return <String, dynamic>{};
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Sets the full set of enabled providers (`settings-general-enabled_providers`
  /// repeated, form-urlencoded). Partial POST: only this field changes.
  Future<void> setEnabledProviders(List<String> keys) async {
    try {
      await _dio.post<dynamic>(
        'api/system/settings',
        data: <String, dynamic>{'settings-general-enabled_providers': keys},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          listFormat: ListFormat.multi,
        ),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Saves one provider's config: each [fields] entry is posted as
  /// `settings-<provider>-<key>` (form-urlencoded).
  Future<void> setProviderConfig(
    String provider,
    Map<String, String> fields,
  ) async {
    try {
      final Map<String, String> body = <String, String>{
        for (final MapEntry<String, String> e in fields.entries)
          'settings-$provider-${e.key}': e.value,
      };
      await _dio.post<dynamic>(
        'api/system/settings',
        data: body,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Settings: language profiles ---

  /// All language profiles (`GET /system/languages/profiles`).
  Future<List<BazarrLanguageProfile>> getProfiles() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('api/system/languages/profiles');
      return _listFrom(resp.data)
          .map(
            (dynamic e) =>
                BazarrLanguageProfile.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Saves the full set of profiles (`languages-profiles` JSON in the settings
  /// POST). NOTE: Bazarr persists the profiles but returns 500 from a post-save
  /// hook, so a 500 here is treated as success (other failures rethrow).
  Future<void> setProfiles(List<BazarrLanguageProfile> profiles) async {
    final String json = jsonEncode(
      profiles.map((BazarrLanguageProfile p) => p.toJson()).toList(),
    );
    try {
      await _dio.post<dynamic>(
        'api/system/settings',
        data: <String, dynamic>{'languages-profiles': json},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 500) {
        return; // saved despite the post-save hook error
      }
      throw NetworkException.fromDio(e);
    }
  }

  List<dynamic> _listFrom(dynamic data) => data is Map<String, dynamic>
      ? ((data['data'] as List<dynamic>?) ?? const <dynamic>[])
      : (data as List<dynamic>);
}
