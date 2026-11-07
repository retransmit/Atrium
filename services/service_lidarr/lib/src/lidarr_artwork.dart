import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:meta/meta.dart';

import 'generated/models/media_cover.dart';
import 'generated/models/media_cover_types.dart';

/// Artwork helpers for Lidarr items.
abstract final class LidarrArtwork {
  static const String _apiBase = 'api/v1';

  /// The URL each instance's API connection resolved to, by instance id,
  /// with the instance as it was when it connected.
  static final Map<String, (Instance, String)> _baseUrls =
      <String, (Instance, String)>{};

  /// Records that [instance] is being reached at [baseUrl], so its artwork
  /// is fetched from the same place as its data.
  static void rememberBaseUrl(Instance instance, String baseUrl) {
    if (baseUrl.isNotEmpty) {
      _baseUrls[instance.id] = (instance, baseUrl);
    }
  }

  /// Forgets every recorded URL.
  @visibleForTesting
  static void forgetBaseUrls() => _baseUrls.clear();

  /// The base to build [instance]'s artwork URLs on: the URL its API
  /// connection resolved to, local or external, or before there is one, the
  /// URL its mode points at. A URL recorded before the instance was edited
  /// is not used.
  static String _baseFor(Instance instance) {
    final (Instance, String)? resolved = _baseUrls[instance.id];
    if (resolved != null && resolved.$1 == instance) return resolved.$2;
    if (instance.urlMode == UrlMode.forceExternal &&
        instance.externalUrl.isNotEmpty) {
      return instance.externalUrl;
    }
    return instance.localUrl.isNotEmpty
        ? instance.localUrl
        : instance.externalUrl;
  }

  static bool _isRemote(String? url) =>
      url != null && url.isNotEmpty && url.startsWith('http');

  /// Builds an absolute, authenticated image URL for an item's [MediaCover].
  ///
  /// Lidarr hands out web paths, prefixed with its URL Base when one is set:
  /// `/base/MediaCover/<artistId>/poster.jpg`,
  /// `/base/MediaCover/Albums/<albumId>/cover.jpg`, and for art it has not
  /// cached, `/base/MediaCoverProxy/<hash>/<file>`. The web paths are served
  /// by its frontend, which ignores the API key and sends anything else to
  /// its login, as does a single sign-on portal guarding everything outside
  /// `/api`. So cached art is fetched from the matching `api/v1/mediacover`
  /// route instead, and uncached art from where Lidarr itself got it.
  static String? imageUrl({
    required Instance instance,
    required List<MediaCover>? images,
    required MediaCoverTypes coverType,
    int? width,
    bool preferRemote = false,
  }) {
    if (images == null || images.isEmpty) return null;

    final MediaCover? cover = images.firstWhereOrNull(
      (c) => c.coverType == coverType,
    );
    if (cover == null) return null;

    final String? remote = _isRemote(cover.remoteUrl) ? cover.remoteUrl : null;
    final String? localUrl = cover.url;
    final bool isProxy =
        localUrl != null && localUrl.toLowerCase().contains('/mediacoverproxy/');

    if ((preferRemote || isProxy) && remote != null) return remote;
    if (localUrl == null || localUrl.isEmpty) return remote;

    final String rawBase = _baseFor(instance);
    if (rawBase.isEmpty) return remote;

    String pathOrUrl = localUrl;

    // Width suffix (poster.jpg -> poster-250.jpg). Lidarr serves the full
    // size when a resized one does not exist. Never on proxied art.
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

    // Find the segment wherever the URL Base put it, and rebuild relative to
    // the instance's own URL, which already carries its subpath.
    final int coverIdx = pathOrUrl.toLowerCase().indexOf('/mediacover/');
    final String resolvedPath;
    if (coverIdx != -1) {
      final String tail =
          pathOrUrl.substring(coverIdx + '/MediaCover/'.length);
      resolvedPath = tail.toLowerCase().startsWith('albums/')
          ? '$_apiBase/mediacover/album/${tail.substring('albums/'.length)}'
          : '$_apiBase/mediacover/artist/$tail';
    } else {
      // Anything else is a web path from the host root, URL Base included.
      resolvedPath = pathOrUrl;
    }

    final String? apiKey = switch (instance.auth) {
      InstanceAuthApiKey(:final String apiKey) when apiKey.isNotEmpty => apiKey,
      _ => null,
    };
    final String separator = resolvedPath.contains('?') ? '&' : '?';
    final String withKey = apiKey != null
        ? '$resolvedPath${separator}apikey=$apiKey'
        : resolvedPath;

    final Uri base = Uri.parse(rawBase.endsWith('/') ? rawBase : '$rawBase/');
    return base.resolve(withKey).toString();
  }

  /// Poster / artwork image for an artist. Defaults to optimized 250px thumbnail.
  static String? artistPosterUrl(
    Instance instance,
    List<MediaCover>? images, {
    int? width = 250,
    bool preferRemote = false,
  }) =>
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.poster,
        width: width,
        preferRemote: preferRemote,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.cover,
        width: width,
        preferRemote: preferRemote,
      );

  /// Fanart / backdrop image for an artist with progressive fallback.
  static String? artistFanartUrl(
    Instance instance,
    List<MediaCover>? images, {
    int? width,
    bool preferRemote = false,
  }) =>
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.fanart,
        width: width,
        preferRemote: preferRemote,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.banner,
        width: width,
        preferRemote: preferRemote,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.poster,
        width: width,
        preferRemote: preferRemote,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.cover,
        width: width,
        preferRemote: preferRemote,
      );

  /// Cover artwork for an album. Defaults to optimized 250px thumbnail.
  static String? albumCoverUrl(
    Instance instance,
    List<MediaCover>? images, {
    int? width = 250,
    bool preferRemote = false,
  }) =>
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.cover,
        width: width,
        preferRemote: preferRemote,
      ) ??
      imageUrl(
        instance: instance,
        images: images,
        coverType: MediaCoverTypes.poster,
        width: width,
        preferRemote: preferRemote,
      );
}
