import 'dart:convert';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';

/// A Navidrome that answers from a table instead of a network.
///
/// Answers are keyed by the Subsonic method name (`getArtists`, `getAlbum`),
/// and each one is wrapped in the envelope Navidrome 0.64 sends, so a test
/// only writes the part it is about.
class FakeNavidrome implements HttpClientAdapter {
  final Map<String, Map<String, dynamic>> _answers =
      <String, Map<String, dynamic>>{};

  /// Method names in the order they were called.
  final List<String> calls = <String>[];

  void on(String method, Map<String, dynamic> body) => _answers[method] = body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String method =
        options.uri.pathSegments.last.replaceAll('.view', '');
    calls.add(method);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'subsonic-response': <String, dynamic>{
          'status': 'ok',
          'version': '1.16.1',
          'type': 'navidrome',
          'serverVersion': '0.64.0',
          'openSubsonic': true,
          ...?_answers[method],
        },
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeNavidromeDio(FakeNavidrome fake) =>
    Dio(BaseOptions(baseUrl: 'http://navidrome.test/'))
      ..httpClientAdapter = fake;

const Instance navidromeTestInstance = Instance(
  id: 'navidrome-1',
  name: 'Navidrome',
  kind: ServiceKind.navidrome,
  localUrl: 'http://navidrome.test',
  externalUrl: '',
  urlMode: UrlMode.forceLocal,
  auth: InstanceAuth.userPass(username: 'demo', password: 'demo'),
);

/// `getArtists`, grouped the way Navidrome groups artists out of the box.
///
/// Its default `IndexGroups` is `A B ... W X-Z(XYZ) [Unknown]([)`: one group
/// a letter up to W, one group named `X-Z` for the last three, one named
/// `[Unknown]` for names that open with a bracket, and `#` for whatever is
/// left, which is where digits and every other script end up.
Map<String, dynamic> artistsJson(Map<String, List<String>> groups) =>
    <String, dynamic>{
      'artists': <String, dynamic>{
        'ignoredArticles': 'The El La Los Las Le Les Os As O A',
        'index': <Object>[
          for (final MapEntry<String, List<String>> group in groups.entries)
            <String, dynamic>{
              'name': group.key,
              'artist': <Object>[
                for (final String name in group.value)
                  <String, dynamic>{
                    'id': 'ar-${name.hashCode}',
                    'name': name,
                    'albumCount': 1,
                  },
              ],
            },
        ],
      },
    };

Map<String, dynamic> playlistJson({
  required String name,
  int songCount = 24,
  int duration = 5760,
  bool public = false,
}) =>
    <String, dynamic>{
      'id': 'pl-${name.hashCode}',
      'name': name,
      'songCount': songCount,
      'duration': duration,
      'public': public,
      'owner': 'demo',
      'created': '2026-08-01T09:00:00Z',
      'changed': '2026-09-20T18:30:00Z',
    };

Map<String, dynamic> playlistsJson(List<Map<String, dynamic>> playlists) =>
    <String, dynamic>{
      'playlists': <String, dynamic>{'playlist': playlists},
    };

/// `getArtist`. Navidrome sends `artistImageUrl` for an artist it has a
/// picture of and leaves it out for one it does not.
Map<String, dynamic> artistJson({String? imageUrl}) => <String, dynamic>{
      'artist': <String, dynamic>{
        'id': 'ar-1',
        'name': 'Pink Floyd',
        'albumCount': 1,
        'coverArt': 'ar-ar-1_0',
        if (imageUrl != null) 'artistImageUrl': imageUrl,
      },
    };

Map<String, dynamic> albumJson({
  String id = 'al-1',
  String name = 'The Dark Side of the Moon',
  String? coverArt,
}) =>
    <String, dynamic>{
      'album': <String, dynamic>{
        'id': id,
        'name': name,
        'artist': 'Pink Floyd',
        'artistId': 'ar-1',
        if (coverArt != null) 'coverArt': coverArt,
        'songCount': 1,
        'duration': 2580,
        'year': 1973,
        'genre': 'Progressive Rock',
        'song': <Object>[
          <String, dynamic>{
            'id': 'so-1',
            'title': 'Speak to Me',
            'album': name,
            'artist': 'Pink Floyd',
            'track': 1,
            'duration': 68,
            'suffix': 'flac',
            'albumId': id,
            'artistId': 'ar-1',
          },
        ],
      },
    };
