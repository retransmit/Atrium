import 'dart:convert';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_emby/service_emby.dart';

const String _base = 'http://emby.example.test:8096';
const String _token = 'session-token-1';

/// Answers sign-in and one playing session, nothing else.
class _FakeEmby implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final Object body = switch (options.path) {
      'Users/AuthenticateByName' => <String, Object>{
          'AccessToken': _token,
          'ServerId': 'srv',
          'User': <String, Object>{'Id': 'user-1', 'Name': 'atrium-test'},
        },
      'Sessions' => <Object>[
          <String, Object>{
            'Id': 's1',
            'UserName': 'atrium-test',
            'Client': 'Web',
            'DeviceName': 'Browser',
            'NowPlayingItem': <String, Object>{
              'Id': 'movie-1',
              'Name': 'Big Buck Bunny',
              'Type': 'Movie',
              'RunTimeTicks': 6000000000,
              'ImageTags': <String, String>{'Primary': 'p1'},
              'BackdropImageTags': <String>['b1'],
            },
            'PlayState': <String, Object>{'PositionTicks': 0, 'IsPaused': false},
          },
        ],
      _ => <String, Object>{},
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late EmbyClient client;

  setUp(() async {
    ArtworkHeaders.update(
      instances: const <Instance>[
        Instance(
          id: 'emby',
          name: 'Emby',
          kind: ServiceKind.emby,
          localUrl: _base,
          externalUrl: '',
          urlMode: UrlMode.auto,
          auth: InstanceAuth.userPass(username: 'atrium-test', password: 'pw'),
        ),
      ],
      global: const <String, String>{},
    );
    final Dio dio = Dio(BaseOptions(baseUrl: '$_base/'))
      ..httpClientAdapter = _FakeEmby();
    client = EmbyClient(
      dio: dio,
      baseUrl: Uri.parse('$_base/'),
      username: 'atrium-test',
      password: 'pw',
      deviceId: 'device-1',
    );
    await client.login();
  });

  tearDown(ArtworkHeaders.reset);

  const EmbyItem movie = EmbyItem(
    id: 'movie-1',
    type: 'Movie',
    imageTags: <String, String>{'Primary': 'p1', 'Banner': 'n1'},
    backdropImageTags: <String>['b1'],
  );

  /// The token stays out of [url], and the artwork lookup sends it as a
  /// header instead.
  void expectHeaderNotQuery(String? url) {
    expect(url, isNotNull);
    expect(url, startsWith(_base));
    expect(url, isNot(contains(_token)));
    expect(url, isNot(contains('api_key')));
    expect(ArtworkHeaders.forUrl(url)?['X-Emby-Token'], _token);
  }

  test('posters', () => expectHeaderNotQuery(client.imageUrl(movie)));
  test('banners', () => expectHeaderNotQuery(client.bannerImageUrl(movie)));
  test('backdrops', () => expectHeaderNotQuery(client.backdropImageUrl(movie)));
  test(
    'untagged images',
    () => expectHeaderNotQuery(client.untaggedImageUrl('movie-1', 'Primary')),
  );

  test('now-playing artwork', () async {
    final List<ActiveSession> sessions = await client.getSessions();
    expect(sessions, hasLength(1));
    expectHeaderNotQuery(sessions.single.posterUrl);
    expectHeaderNotQuery(sessions.single.backdropUrl);
  });

  test('the token goes nowhere but its own server', () {
    expect(
      ArtworkHeaders.forUrl('https://image.tmdb.org/t/p/w500/abc.jpg'),
      isNull,
    );
  });
}
