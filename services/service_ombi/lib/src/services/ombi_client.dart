import 'package:dio/dio.dart';

import '../generated/api/raw_calendar_api.dart';
import '../generated/api/raw_identity_api.dart';
import '../generated/api/raw_issues_api.dart';
import '../generated/api/raw_lidarr_api.dart';
import '../generated/api/raw_music_request_api.dart';
import '../generated/api/raw_plex_api.dart';
import '../generated/api/raw_radarr_api.dart';
import '../generated/api/raw_request_api.dart';
import '../generated/api/raw_requests_api.dart';
import '../generated/api/raw_search_api.dart';
import '../generated/api/raw_settings_api.dart';
import '../generated/api/raw_sonarr_api.dart';
import 'ombi_request_service.dart';
import 'ombi_search_service.dart';
import 'ombi_settings_service.dart';

/// Central client for Ombi API services.
class OmbiClient {
  OmbiClient({
    Dio? dio,
    required this.baseUrl,
    this.apiKey,
  }) : dio = dio ?? Dio() {
    this.dio.options.baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    if (apiKey != null && apiKey!.isNotEmpty) {
      this.dio.options.headers['ApiKey'] = apiKey;
    }
    _wire();
  }

  /// Over an instance's Dio, which already carries the base URL, the
  /// `ApiKey` header and the certificate and URL-selection settings, so
  /// none of them are touched here.
  OmbiClient.fromDio(this.dio)
      : baseUrl = dio.options.baseUrl,
        apiKey = null {
    _wire();
  }

  final Dio dio;
  final String baseUrl;
  final String? apiKey;

  late final RawSearchApi rawSearchApi;
  late final RawRequestApi rawRequestApi;
  late final RawRequestsApi rawRequestsApi;
  late final RawSettingsApi rawSettingsApi;
  late final RawIdentityApi rawIdentityApi;
  late final RawCalendarApi rawCalendarApi;
  late final RawIssuesApi rawIssuesApi;
  late final RawSonarrApi rawSonarrApi;
  late final RawRadarrApi rawRadarrApi;
  late final RawPlexApi rawPlexApi;
  late final RawMusicRequestApi rawMusicRequestApi;
  late final RawLidarrApi rawLidarrApi;

  late final OmbiSearchService searchService;
  late final OmbiRequestService requestService;
  late final OmbiSettingsService settingsService;

  void _wire() {
    rawSearchApi = RawSearchApi(dio);
    rawRequestApi = RawRequestApi(dio);
    rawRequestsApi = RawRequestsApi(dio);
    rawSettingsApi = RawSettingsApi(dio);
    rawIdentityApi = RawIdentityApi(dio);
    rawCalendarApi = RawCalendarApi(dio);
    rawIssuesApi = RawIssuesApi(dio);
    rawSonarrApi = RawSonarrApi(dio);
    rawRadarrApi = RawRadarrApi(dio);
    rawPlexApi = RawPlexApi(dio);
    rawMusicRequestApi = RawMusicRequestApi(dio);
    rawLidarrApi = RawLidarrApi(dio);

    searchService = OmbiSearchService(rawSearchApi);
    requestService = OmbiRequestService(
      rawRequestApi,
      rawRequestsApi,
      rawMusicRequestApi,
      rawLidarrApi,
    );
    settingsService = OmbiSettingsService(rawSettingsApi);
  }
}
