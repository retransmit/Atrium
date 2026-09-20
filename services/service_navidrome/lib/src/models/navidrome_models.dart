import 'package:flutter/foundation.dart';

/// Helper to parse fields that can be either a List or a single Map (XML-to-JSON quirk in Subsonic).
List<Map<String, dynamic>> _extractListOfMaps(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
  }
  if (value is Map) {
    return <Map<String, dynamic>>[value.cast<String, dynamic>()];
  }
  return <Map<String, dynamic>>[];
}

String? _parseStarred(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value ? 'true' : null;
  if (value is String) return value.trim().isNotEmpty ? value.trim() : null;
  return value.toString();
}

int? _parseRating(dynamic userRating, dynamic rating) {
  final dynamic r = userRating ?? rating;
  if (r is num) return r.toInt();
  if (r is String) return int.tryParse(r);
  return null;
}

@immutable
class NavidromeArtist {
  const NavidromeArtist({
    required this.id,
    required this.name,
    this.albumCount = 0,
    this.coverArt,
    this.artistImageUrl,
    this.userRating,
    this.starred,
  });

  final String id;
  final String name;
  final int albumCount;
  final String? coverArt;
  final String? artistImageUrl;
  final int? userRating;
  final String? starred;

  bool get isStarred => starred != null && starred!.isNotEmpty;

  factory NavidromeArtist.fromJson(Map<String, dynamic> json) {
    return NavidromeArtist(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ??
          (json['title'] as String?) ??
          'Unknown Artist',
      albumCount: (json['albumCount'] as num?)?.toInt() ?? 0,
      coverArt: json['coverArt'] as String?,
      artistImageUrl: json['artistImageUrl'] as String?,
      userRating: _parseRating(json['userRating'], json['rating']),
      starred: _parseStarred(json['starred']),
    );
  }
}

@immutable
class NavidromeArtistIndex {
  const NavidromeArtistIndex({
    required this.name,
    required this.artists,
  });

  final String name;
  final List<NavidromeArtist> artists;

  factory NavidromeArtistIndex.fromJson(Map<String, dynamic> json) {
    final List<Map<String, dynamic>> artistList =
        _extractListOfMaps(json['artist']);
    return NavidromeArtistIndex(
      name: (json['name'] as String?) ?? '',
      artists: artistList.map(NavidromeArtist.fromJson).toList(),
    );
  }
}

@immutable
class NavidromeAlbum {
  const NavidromeAlbum({
    required this.id,
    required this.name,
    this.artist = 'Unknown Artist',
    this.artistId,
    this.coverArt,
    this.songCount = 0,
    this.duration = 0,
    this.year,
    this.genre,
    this.playCount = 0,
    this.userRating,
    this.starred,
  });

  final String id;
  final String name;
  final String artist;
  final String? artistId;
  final String? coverArt;
  final int songCount;
  final int duration; // In seconds
  final int? year;
  final String? genre;
  final int playCount;
  final int? userRating;
  final String? starred;

  bool get isStarred => starred != null && starred!.isNotEmpty;

  factory NavidromeAlbum.fromJson(Map<String, dynamic> json) {
    return NavidromeAlbum(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ??
          (json['title'] as String?) ??
          'Unknown Album',
      artist: (json['artist'] as String?) ?? 'Unknown Artist',
      artistId: json['artistId'] as String?,
      coverArt: json['coverArt'] as String?,
      songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      userRating: _parseRating(json['userRating'], json['rating']),
      starred: _parseStarred(json['starred']),
    );
  }
}

@immutable
class NavidromeSong {
  const NavidromeSong({
    required this.id,
    required this.title,
    this.album = '',
    this.albumId,
    this.artist = 'Unknown Artist',
    this.artistId,
    this.track,
    this.discNumber,
    this.year,
    this.genre,
    this.coverArt,
    this.duration = 0,
    this.bitRate,
    this.suffix,
    this.size,
    this.contentType,
    this.path,
    this.playCount = 0,
    this.userRating,
    this.starred,
  });

  final String id;
  final String title;
  final String album;
  final String? albumId;
  final String artist;
  final String? artistId;
  final int? track;
  final int? discNumber;
  final int? year;
  final String? genre;
  final String? coverArt;
  final int duration; // In seconds
  final int? bitRate; // In kbps
  final String? suffix; // e.g. "mp3", "flac"
  final int? size; // In bytes
  final String? contentType;
  final String? path;
  final int playCount;
  final int? userRating;
  final String? starred;

  bool get isStarred => starred != null && starred!.isNotEmpty;

  factory NavidromeSong.fromJson(Map<String, dynamic> json) {
    return NavidromeSong(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Unknown Title',
      album: (json['album'] as String?) ?? '',
      albumId: json['albumId'] as String?,
      artist: (json['artist'] as String?) ?? 'Unknown Artist',
      artistId: json['artistId'] as String?,
      track: (json['track'] as num?)?.toInt(),
      discNumber: (json['discNumber'] as num?)?.toInt(),
      year: (json['year'] as num?)?.toInt(),
      genre: json['genre'] as String?,
      coverArt: json['coverArt'] as String?,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      bitRate: (json['bitRate'] as num?)?.toInt(),
      suffix: json['suffix'] as String?,
      size: (json['size'] as num?)?.toInt(),
      contentType: json['contentType'] as String?,
      path: json['path'] as String?,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      userRating: _parseRating(json['userRating'], json['rating']),
      starred: _parseStarred(json['starred']),
    );
  }
}

@immutable
class NavidromePlaylist {
  const NavidromePlaylist({
    required this.id,
    required this.name,
    this.comment,
    this.owner,
    this.public = false,
    this.songCount = 0,
    this.duration = 0,
    this.coverArt,
  });

  final String id;
  final String name;
  final String? comment;
  final String? owner;
  final bool public;
  final int songCount;
  final int duration;
  final String? coverArt;

  factory NavidromePlaylist.fromJson(Map<String, dynamic> json) {
    return NavidromePlaylist(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Untitled Playlist',
      comment: json['comment'] as String?,
      owner: json['owner'] as String?,
      public: (json['public'] as bool?) ?? false,
      songCount: (json['songCount'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      coverArt: json['coverArt'] as String?,
    );
  }
}

@immutable
class NavidromeArtistInfo {
  const NavidromeArtistInfo({
    this.biography,
    this.musicBrainzId,
    this.lastFmUrl,
    this.smallImageUrl,
    this.mediumImageUrl,
    this.largeImageUrl,
  });

  final String? biography;
  final String? musicBrainzId;
  final String? lastFmUrl;
  final String? smallImageUrl;
  final String? mediumImageUrl;
  final String? largeImageUrl;

  factory NavidromeArtistInfo.fromJson(Map<String, dynamic> json) {
    return NavidromeArtistInfo(
      biography: json['biography'] as String?,
      musicBrainzId: json['musicBrainzId'] as String?,
      lastFmUrl: json['lastFmUrl'] as String?,
      smallImageUrl: json['smallImageUrl'] as String?,
      mediumImageUrl: json['mediumImageUrl'] as String?,
      largeImageUrl: json['largeImageUrl'] as String?,
    );
  }
}

@immutable
class NavidromeArtistDetail {
  const NavidromeArtistDetail({
    required this.artist,
    required this.albums,
    this.info,
  });

  final NavidromeArtist artist;
  final List<NavidromeAlbum> albums;
  final NavidromeArtistInfo? info;

  factory NavidromeArtistDetail.fromJson(
    Map<String, dynamic> json, {
    NavidromeArtistInfo? info,
  }) {
    final dynamic resp = json['subsonic-response'] ?? json;
    final Map<String, dynamic> map =
        resp is Map<String, dynamic> ? resp : const <String, dynamic>{};
    final Map<String, dynamic> artistMap =
        (map['artist'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    final List<Map<String, dynamic>> rawAlbums =
        _extractListOfMaps(artistMap['album']);

    return NavidromeArtistDetail(
      artist: NavidromeArtist.fromJson(artistMap),
      albums: rawAlbums.map(NavidromeAlbum.fromJson).toList(),
      info: info,
    );
  }

  NavidromeArtistDetail copyWith({
    NavidromeArtist? artist,
    List<NavidromeAlbum>? albums,
    NavidromeArtistInfo? info,
  }) {
    return NavidromeArtistDetail(
      artist: artist ?? this.artist,
      albums: albums ?? this.albums,
      info: info ?? this.info,
    );
  }
}

@immutable
class NavidromeAlbumDetail {
  const NavidromeAlbumDetail({
    required this.album,
    required this.songs,
  });

  final NavidromeAlbum album;
  final List<NavidromeSong> songs;

  factory NavidromeAlbumDetail.fromJson(Map<String, dynamic> json) {
    final dynamic resp = json['subsonic-response'] ?? json;
    final Map<String, dynamic> map =
        resp is Map<String, dynamic> ? resp : const <String, dynamic>{};
    final Map<String, dynamic> albumMap =
        (map['album'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    final List<Map<String, dynamic>> rawSongs =
        _extractListOfMaps(albumMap['song']);

    return NavidromeAlbumDetail(
      album: NavidromeAlbum.fromJson(albumMap),
      songs: rawSongs.map(NavidromeSong.fromJson).toList(),
    );
  }
}

@immutable
class NavidromePlaylistDetail {
  const NavidromePlaylistDetail({
    required this.playlist,
    required this.songs,
  });

  final NavidromePlaylist playlist;
  final List<NavidromeSong> songs;

  factory NavidromePlaylistDetail.fromJson(Map<String, dynamic> json) {
    final dynamic resp = json['subsonic-response'] ?? json;
    final Map<String, dynamic> map =
        resp is Map<String, dynamic> ? resp : const <String, dynamic>{};
    final Map<String, dynamic> plMap =
        (map['playlist'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    final List<Map<String, dynamic>> rawEntries =
        _extractListOfMaps(plMap['entry']);

    return NavidromePlaylistDetail(
      playlist: NavidromePlaylist.fromJson(plMap),
      songs: rawEntries.map(NavidromeSong.fromJson).toList(),
    );
  }
}

@immutable
class NavidromeSearchResult {
  const NavidromeSearchResult({
    this.artists = const <NavidromeArtist>[],
    this.albums = const <NavidromeAlbum>[],
    this.songs = const <NavidromeSong>[],
  });

  final List<NavidromeArtist> artists;
  final List<NavidromeAlbum> albums;
  final List<NavidromeSong> songs;

  bool get isEmpty => artists.isEmpty && albums.isEmpty && songs.isEmpty;

  factory NavidromeSearchResult.fromJson(Map<String, dynamic> json) {
    final dynamic resp = json['subsonic-response'] ?? json;
    final Map<String, dynamic> map =
        resp is Map<String, dynamic> ? resp : const <String, dynamic>{};
    final Map<String, dynamic> search =
        (map['searchResult3'] as Map<dynamic, dynamic>?)
                ?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    final List<Map<String, dynamic>> rawArtists =
        _extractListOfMaps(search['artist']);
    final List<Map<String, dynamic>> rawAlbums =
        _extractListOfMaps(search['album']);
    final List<Map<String, dynamic>> rawSongs =
        _extractListOfMaps(search['song']);

    return NavidromeSearchResult(
      artists: rawArtists.map(NavidromeArtist.fromJson).toList(),
      albums: rawAlbums.map(NavidromeAlbum.fromJson).toList(),
      songs: rawSongs.map(NavidromeSong.fromJson).toList(),
    );
  }
}
