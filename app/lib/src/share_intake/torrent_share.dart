import 'package:flutter/foundation.dart';

import 'title_share.dart';

/// A torrent another app handed to Atrium through the Android share sheet or
/// the "open with" chooser.
///
/// The platform side stays deliberately dumb: it reports what the intent
/// carried and leaves interpretation here, where it can be unit tested.
@immutable
sealed class TorrentShare {
  const TorrentShare();
}

/// A magnet URI, or an http(s) link to a `.torrent`. Every torrent client
/// Atrium drives accepts both in the same field.
final class TorrentShareLink extends TorrentShare {
  const TorrentShareLink(this.uri);

  final String uri;

  bool get isMagnet => uri.toLowerCase().startsWith('magnet:');

  @override
  bool operator ==(Object other) =>
      other is TorrentShareLink && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

/// The bytes of a `.torrent`, read natively because the `content://` read
/// grant belongs to the activity and Dart has no ContentResolver.
final class TorrentShareFile extends TorrentShare {
  const TorrentShareFile({required this.bytes, this.name});

  final Uint8List bytes;

  /// The file's display name when the provider exposed one. Shown to the user
  /// so they can see what they are about to add.
  final String? name;
}

/// One `.torrent` within a shared batch.
@immutable
class TorrentShareFileEntry {
  const TorrentShareFileEntry({required this.bytes, this.name});

  final Uint8List bytes;
  final String? name;
}

/// Several `.torrent` files shared at once.
///
/// Kept distinct from a queue of single files on purpose: a batch gets one
/// sheet and one set of options, because answering the same save-path question
/// fifty times is worse than not supporting batches at all.
final class TorrentShareFiles extends TorrentShare {
  const TorrentShareFiles({
    required this.files,
    this.skipped = 0,
    this.dropped = 0,
  });

  final List<TorrentShareFileEntry> files;

  /// Files in the batch that could not be read, so the count can be shown
  /// rather than them vanishing silently.
  final int skipped;

  /// Files beyond the batch ceiling that were never read at all.
  final int dropped;
}

/// Something arrived but cannot be added. Carries the message to show.
final class TorrentShareProblem extends TorrentShare {
  const TorrentShareProblem(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is TorrentShareProblem && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// Whether a shared title is a movie, a show, or not yet known.
enum TitleKind { movie, show, unknown }

/// A movie or show shared as text, to be looked up on Radarr or Sonarr.
///
/// It extends [TorrentShare] only because that is the share queue's item
/// type; it has nothing to do with torrents. It lives in this file because a
/// sealed class can only be extended from its own library. The parsing is in
/// `title_share.dart`.
final class TitleShare extends TorrentShare {
  const TitleShare({
    required this.kind,
    this.imdbId,
    this.tmdbId,
    this.letterboxdUrl,
    this.title,
  });

  final TitleKind kind;

  /// An IMDb title ID such as `tt0086567`.
  final String? imdbId;

  final int? tmdbId;

  /// A Letterboxd link not yet followed to its film page.
  final Uri? letterboxdUrl;

  /// What to search by when no ID resolves.
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is TitleShare &&
      other.kind == kind &&
      other.imdbId == imdbId &&
      other.tmdbId == tmdbId &&
      other.letterboxdUrl == letterboxdUrl &&
      other.title == title;

  @override
  int get hashCode => Object.hash(kind, imdbId, tmdbId, letterboxdUrl, title);
}

/// Decodes the map delivered over the `app.atrium/share` channel.
///
/// Returns null when the intent carried nothing to add - a plain launcher tap
/// is the common case, and must not raise anything in the UI.
TorrentShare? decodeTorrentShare(Object? payload) {
  if (payload is! Map) {
    return null;
  }
  switch (payload['kind']) {
    case 'magnet':
      final Object? uri = payload['uri'];
      if (uri is! String || uri.trim().isEmpty) {
        return null;
      }
      return TorrentShareLink(uri.trim());

    case 'text':
      final Object? value = payload['value'];
      if (value is! String) {
        return null;
      }
      // A torrent wins over a title, so torrent shares behave as before.
      final String? found = extractTorrentUri(value);
      if (found != null) {
        return TorrentShareLink(found);
      }
      final TitleShare? title = extractTitleShare(value);
      if (title != null) {
        return title;
      }
      return const TorrentShareProblem(
        'That share had no torrent and no movie or show in it, so there was '
        'nothing to add.',
      );

    case 'file':
      final Object? bytes = payload['bytes'];
      if (bytes is! Uint8List || bytes.isEmpty) {
        return null;
      }
      final Object? name = payload['name'];
      return TorrentShareFile(
        bytes: bytes,
        name: name is String && name.trim().isNotEmpty ? name.trim() : null,
      );

    case 'files':
      final Object? items = payload['items'];
      if (items is! List) {
        return null;
      }
      final List<TorrentShareFileEntry> files = <TorrentShareFileEntry>[];
      for (final Object? item in items) {
        if (item is! Map) {
          continue;
        }
        final Object? bytes = item['bytes'];
        if (bytes is! Uint8List || bytes.isEmpty) {
          continue;
        }
        final Object? name = item['name'];
        files.add(
          TorrentShareFileEntry(
            bytes: bytes,
            name: name is String && name.trim().isNotEmpty ? name.trim() : null,
          ),
        );
      }
      if (files.isEmpty) {
        return null;
      }
      return TorrentShareFiles(
        files: files,
        skipped: _asInt(payload['skipped']),
        dropped: _asInt(payload['dropped']),
      );

    case 'empty':
      return const TorrentShareProblem(
        'That file was empty, so there was nothing to add.',
      );

    case 'unreadable':
      return const TorrentShareProblem(
        'Atrium was not allowed to open that file. The app that shared it did '
        'not pass along permission to read it. Try saving the .torrent first, '
        'then opening it from your files.',
      );

    case 'tooLarge':
      return const TorrentShareProblem(
        'That file is far too large to be a .torrent, so nothing was added.',
      );

    default:
      return null;
  }
}

int _asInt(Object? value) => value is int ? value : 0;

/// Pulls a magnet URI or a link to a `.torrent` out of shared text.
///
/// Shared text is rarely just the link: browsers and tracker apps tend to send
/// a title, a newline and then the URL, so this scans rather than parsing the
/// whole string. Magnets win when both are present, since a magnet needs no
/// second request.
///
/// Only the first torrent in the text is taken. Sharing a blob holding several
/// at once is rare, and the alternative - opening a sheet per link off a single
/// share - is more startling than useful. Sharing them one at a time queues
/// properly and adds every one.
String? extractTorrentUri(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final int magnetAt = trimmed.toLowerCase().indexOf('magnet:?');
  if (magnetAt >= 0) {
    final String rest = trimmed.substring(magnetAt);
    final int end = rest.indexOf(RegExp(r'\s'));
    return end < 0 ? rest : rest.substring(0, end);
  }

  for (final String token in trimmed.split(RegExp(r'\s+'))) {
    final Uri? uri = Uri.tryParse(token);
    if (uri == null || !uri.hasScheme) {
      continue;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      continue;
    }
    if (uri.path.toLowerCase().endsWith('.torrent')) {
      return token;
    }
  }
  return null;
}
