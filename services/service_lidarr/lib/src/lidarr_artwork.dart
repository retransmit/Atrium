import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';

import 'generated/models/media_cover.dart';
import 'generated/models/media_cover_types.dart';

/// Artwork helpers for Lidarr items.
abstract final class LidarrArtwork {
  static const String _apiBase = 'api/v1';

  /// Builds an absolute, authenticated image URL for an item's [MediaCover].
  static String? imageUrl({
    required Instance instance,
    required List<MediaCover>? images,
    required MediaCoverTypes coverType,
    int? width,
    bool preferRemote = false,
    String? baseUrl,
  }) {
    if (images == null || images.isEmpty) return null;

    final MediaCover? cover = images.firstWhereOrNull(
      (c) => c.coverType == coverType,
    );
    if (cover == null) return null;

    final bool isProxy = cover.url != null &&
        cover.url!.toLowerCase().contains('/mediacoverproxy/');

    if ((preferRemote || isProxy) &&
        cover.remoteUrl != null &&
        cover.remoteUrl!.isNotEmpty &&
        cover.remoteUrl!.startsWith('http')) {
      return cover.remoteUrl;
    }

    final String? localUrl = cover.url;
    if (localUrl == null || localUrl.isEmpty) {
      if (cover.remoteUrl != null &&
          cover.remoteUrl!.isNotEmpty &&
          cover.remoteUrl!.startsWith('http')) {
        return cover.remoteUrl;
      }
      return null;
    }

    final String rawBase = (baseUrl != null && baseUrl.isNotEmpty)
        ? baseUrl
        : switch (instance.urlMode) {
            UrlMode.forceExternal => instance.externalUrl.isNotEmpty
                ? instance.externalUrl
                : instance.localUrl,
            UrlMode.forceLocal => instance.localUrl.isNotEmpty
                ? instance.localUrl
                : instance.externalUrl,
            UrlMode.auto => instance.localUrl.isNotEmpty
                ? instance.localUrl
                : instance.externalUrl,
          };
    if (rawBase.isEmpty) {
      if (cover.remoteUrl != null &&
          cover.remoteUrl!.isNotEmpty &&
          cover.remoteUrl!.startsWith('http')) {
        return cover.remoteUrl;
      }
      return null;
    }

    String pathOrUrl = localUrl;

    // Width suffix handling (e.g. poster.jpg -> poster-250.jpg)
    // Only apply width suffixes to local /MediaCover/ paths, never /MediaCoverProxy/
    if (width != null && !isProxy) {
      final int queryIdx = pathOrUrl.indexOf('?');
      final String pathPart =
          queryIdx == -1 ? pathOrUrl : pathOrUrl.substring(0, queryIdx);
      final String queryPart =
          queryIdx == -1 ? '' : pathOrUrl.substring(queryIdx);

      final int dotIdx = pathPart.lastIndexOf('.');
      if (dotIdx != -1) {
        final String basePart = pathPart.substring(0, dotIdx);
        final String extPart = pathPart.substring(dotIdx);
        if (!basePart.endsWith('-$width')) {
          pathOrUrl = '$basePart-$width$extPart$queryPart';
        }
      }
    }

    // Lidarr prefixes its configured URL Base onto images[].url, so this
    // arrives as either /MediaCover/... or /base/MediaCover/.... Match
    // the segment wherever it starts and rebuild relative to the API:
    // the frontend /MediaCover route is served by the web UI, which
    // ignores the api key and 302s to the login page.
    final int coverIdx = pathOrUrl.toLowerCase().indexOf('/mediacover/');
    if (coverIdx != -1) {
      final String tail =
          pathOrUrl.substring(coverIdx + '/mediacover/'.length);
      final String lowerTail = tail.toLowerCase();
      final String apiTail;
      if (lowerTail.startsWith('albums/')) {
        apiTail = 'album/${tail.substring('albums/'.length)}';
      } else if (lowerTail.startsWith('album/')) {
        apiTail = 'album/${tail.substring('album/'.length)}';
      } else if (lowerTail.startsWith('artists/')) {
        apiTail = 'artist/${tail.substring('artists/'.length)}';
      } else if (lowerTail.startsWith('artist/')) {
        apiTail = 'artist/${tail.substring('artist/'.length)}';
      } else {
        apiTail = 'artist/$tail';
      }
      pathOrUrl = '$_apiBase/mediacover/$apiTail';
    }

    final String? apiKey = switch (instance.auth) {
      InstanceAuthApiKey(:final String apiKey) => apiKey,
      _ => null,
    };

    final String cleanPath =
        pathOrUrl.startsWith('/') ? pathOrUrl.substring(1) : pathOrUrl;
    final String separator = cleanPath.contains('?') ? '&' : '?';
    final String resolvedPath = apiKey != null && apiKey.isNotEmpty
        ? '$cleanPath${separator}apikey=$apiKey'
        : cleanPath;

    final Uri base = Uri.parse(rawBase.endsWith('/') ? rawBase : '$rawBase/');
    return base.resolve(resolvedPath).toString();
  }

  /// Poster / artwork image for an artist. Defaults to optimized 250px thumbnail.
  static String? artistPosterUrl(
    Instance instance,
    List<MediaCover>? images, {
    int? width = 250,
    bool preferRemote = false,
    String? baseUrl,
  }) =>
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.poster,
        width: width,
        preferRemote: preferRemote,
        baseUrl: baseUrl,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.cover,
        width: width,
        preferRemote: preferRemote,
        baseUrl: baseUrl,
      );

  /// Fanart / backdrop image for an artist with progressive fallback.
  static String? artistFanartUrl(
    Instance instance,
    List<MediaCover>? images, {
    int? width,
    bool preferRemote = false,
    String? baseUrl,
  }) =>
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.fanart,
        width: width,
        preferRemote: preferRemote,
        baseUrl: baseUrl,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.banner,
        width: width,
        preferRemote: preferRemote,
        baseUrl: baseUrl,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.poster,
        width: width,
        preferRemote: preferRemote,
        baseUrl: baseUrl,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.cover,
        width: width,
        preferRemote: preferRemote,
        baseUrl: baseUrl,
      );

  /// Cover artwork for an album. Defaults to optimized 250px thumbnail.
  static String? albumCoverUrl(
    Instance instance,
    List<MediaCover>? images, {
    int? width = 250,
    bool preferRemote = false,
    String? baseUrl,
  }) =>
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.cover,
        width: width,
        preferRemote: preferRemote,
        baseUrl: baseUrl,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.poster,
        width: width,
        preferRemote: preferRemote,
        baseUrl: baseUrl,
      );
}
