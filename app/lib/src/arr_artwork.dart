/// Artwork URLs for Sonarr and Radarr items, served by the instance itself.
///
/// Sonarr and Radarr each cache the artwork they fetch and serve it back under
/// `/MediaCover`, so `posterUrl` resolves to the user's own machine. The models
/// also carry a `remoteUrl` pointing straight at TheTVDB, TMDB or Fanart.tv;
/// reading that field renders the same picture but makes the device talk to a
/// third party, which then sees the IP and what is being browsed. Go through
/// these helpers rather than touching `remoteUrl`.
///
/// The exception is artwork for something not in the library yet, such as an
/// add-series search result. The server has nothing cached for it, so those
/// call sites pass `preferRemote: true` deliberately.
///
/// Each returns null while the API is still loading or when no image of the
/// requested type exists, and callers fall back to an icon.
library;

import 'package:collection/collection.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sonarr/service_sonarr.dart';

String? _sonarr(SonarrApi? api, List<SonarrImage> images, String coverType) {
  if (api == null) {
    return null;
  }
  final SonarrImage? image =
      images.firstWhereOrNull((SonarrImage im) => im.coverType == coverType);
  return image == null ? null : api.posterUrl(image);
}

String? _radarr(RadarrApi? api, List<RadarrImage> images, String coverType) {
  if (api == null) {
    return null;
  }
  final RadarrImage? image =
      images.firstWhereOrNull((RadarrImage im) => im.coverType == coverType);
  return image == null ? null : api.posterUrl(image);
}

/// Poster for a Sonarr series.
String? sonarrPosterUrl(SonarrApi? api, List<SonarrImage> images) =>
    _sonarr(api, images, 'poster');

/// Wide backdrop for a Sonarr series.
String? sonarrFanartUrl(SonarrApi? api, List<SonarrImage> images) =>
    _sonarr(api, images, 'fanart');

/// Poster for a Radarr movie.
String? radarrPosterUrl(RadarrApi? api, List<RadarrImage> images) =>
    _radarr(api, images, 'poster');

/// Wide backdrop for a Radarr movie.
String? radarrFanartUrl(RadarrApi? api, List<RadarrImage> images) =>
    _radarr(api, images, 'fanart');
