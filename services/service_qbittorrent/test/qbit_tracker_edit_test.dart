import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

QbitTracker _t(String url, int tier) => QbitTracker(url: url, tier: tier);

const String _a = 'udp://a.example.org:1337/announce';
const String _b = 'https://b.example.org/announce';
const String _c = 'http://c.example.org/announce';
const String _d = 'udp://d.example.org:6969/announce';

/// Three trackers over two tiers, plus the synthetic rows qBittorrent sends.
final List<QbitTracker> _current = <QbitTracker>[
  const QbitTracker(url: '** [DHT] **'),
  const QbitTracker(url: '** [PeX] **'),
  _t(_a, 0),
  _t(_b, 0),
  _t(_c, 1),
];

/// Captures the outgoing request instead of hitting a server.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('the tracker text', () {
    test('lists real trackers tier by tier, a blank line between', () {
      expect(qbitTrackerText(_current), '$_a\n$_b\n\n$_c');
    });

    test('is empty for a torrent with only DHT and PeX', () {
      expect(qbitTrackerText(_current.take(2).toList()), '');
    });
  });

  group('an edit', () {
    test('unchanged text changes nothing', () {
      final QbitTrackerEdit edit =
          qbitTrackerEdit(_current, qbitTrackerText(_current));
      expect(edit.changes, isFalse);
      expect(edit.invalid, isEmpty);
    });

    test('a deleted line removes that tracker', () {
      final QbitTrackerEdit edit = qbitTrackerEdit(_current, '$_a\n\n$_c');
      expect(edit.removed, <String>[_b]);
      expect(edit.added, isEmpty);
    });

    test('a URL written beside existing ones joins their tier', () {
      final QbitTrackerEdit edit =
          qbitTrackerEdit(_current, '$_a\n$_b\n\n$_c\n$_d');
      expect(edit.added, <String>[_d]);
      // Tier 1, so one empty line before it.
      expect(edit.addText, '\n$_d');
    });

    test('a new group after the last becomes the next tier', () {
      final QbitTrackerEdit edit =
          qbitTrackerEdit(_current, '$_a\n$_b\n\n$_c\n\n$_d');
      expect(edit.addText, '\n\n$_d');
    });

    test('a URL in the first group goes to tier 0', () {
      final QbitTrackerEdit edit =
          qbitTrackerEdit(_current, '$_d\n$_a\n$_b\n\n$_c');
      expect(edit.addText, _d);
    });

    test('a changed URL is a removal and an addition', () {
      final QbitTrackerEdit edit =
          qbitTrackerEdit(_current, '$_a\n$_d\n\n$_c');
      expect(edit.removed, <String>[_b]);
      expect(edit.added, <String>[_d]);
      expect(edit.addText, _d);
    });

    test('a torrent with no trackers takes a whole list', () {
      final QbitTrackerEdit edit =
          qbitTrackerEdit(const <QbitTracker>[], '$_a\n$_b\n\n\n$_c');
      expect(edit.added, <String>[_a, _b, _c]);
      // Any run of blank lines is one tier break.
      expect(edit.addText, '$_a\n$_b\n\n$_c');
    });

    test('keeps tiers the server numbered with gaps', () {
      final List<QbitTracker> gapped = <QbitTracker>[_t(_a, 0), _t(_c, 3)];
      final QbitTrackerEdit edit = qbitTrackerEdit(gapped, '$_a\n\n$_c\n$_d');
      expect(edit.addText, '\n\n\n$_d');
    });

    test('ignores surrounding spaces and repeated URLs', () {
      final QbitTrackerEdit edit =
          qbitTrackerEdit(_current, '  $_a \n$_b\n$_d\n$_d\n\n$_c\n');
      expect(edit.added, <String>[_d]);
      expect(edit.removed, isEmpty);
    });

    test('holds back lines that are not tracker URLs', () {
      final QbitTrackerEdit edit = qbitTrackerEdit(
        _current,
        '$_a\n$_b\ntracker.example.org\nftp://x.example.org/\n\n$_c',
      );
      expect(edit.invalid, <String>['tracker.example.org', 'ftp://x.example.org/']);
      expect(edit.added, isEmpty);
    });

    test('accepts WebTorrent trackers', () {
      expect(qbitIsTrackerUrl('wss://tracker.example.org'), isTrue);
    });
  });

  group('the tracker row', () {
    test('reads the tier, and none for the synthetic rows of any server', () {
      expect(
        QbitTracker.fromJson(<String, dynamic>{'url': _a, 'tier': 2}).tier,
        2,
      );
      // qBittorrent 4.x sends an empty string for DHT, PeX and LSD.
      expect(
        QbitTracker.fromJson(<String, dynamic>{'url': '** [DHT] **', 'tier': ''})
            .tier,
        -1,
      );
      expect(
        QbitTracker.fromJson(<String, dynamic>{'url': '** [DHT] **', 'tier': -1})
            .tier,
        -1,
      );
    });
  });

  group('requests', () {
    late _RecordingAdapter adapter;
    late QbittorrentClient client;

    setUp(() {
      adapter = _RecordingAdapter();
      // An API key skips the cookie login, so each call is the only request.
      client = QbittorrentClient(
        dio: Dio(BaseOptions(baseUrl: 'https://qbit.example.test/'))
          ..httpClientAdapter = adapter,
        cookies: CookieJar(),
        username: '',
        password: '',
        apiKey: 'qbt_placeholder_not_a_secret',
      );
    });

    Map<String, dynamic> sent() =>
        Map<String, dynamic>.from(adapter.request!.data as Map);

    test('adding sends the tiered text as it is', () async {
      await client.addTrackers('h', '\n$_d');
      expect(adapter.request!.path, 'api/v2/torrents/addTrackers');
      expect(sent(), <String, dynamic>{'hash': 'h', 'urls': '\n$_d'});
    });

    test('removing sends the URLs joined by a bar', () async {
      await client.removeTrackers('h', <String>[_a, _b]);
      expect(adapter.request!.path, 'api/v2/torrents/removeTrackers');
      expect(sent(), <String, dynamic>{'hash': 'h', 'urls': '$_a|$_b'});
    });

    test('editing names the old URL both ways, for before and after 5.2',
        () async {
      await client.editTracker('h', _a, _d);
      expect(adapter.request!.path, 'api/v2/torrents/editTracker');
      expect(sent(), <String, dynamic>{
        'hash': 'h',
        'url': _a,
        'origUrl': _a,
        'newUrl': _d,
      });
    });
  });
}
