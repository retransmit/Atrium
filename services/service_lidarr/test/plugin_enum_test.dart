import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

/// Lidarr's plugin builds serve enum values no released OpenAPI spec lists.
///
/// Tubifarry and friends register their own download protocols, so a release
/// off a plugin indexer comes back with `"protocol": "TorrentDownloadProtocol"`
/// rather than one of the three the spec declares. json_serializable throws on
/// a value it cannot map, and that took down the whole interactive search
/// rather than one field: issue #134.
void main() {
  group('enum values the spec has never seen', () {
    test('a plugin protocol parses instead of throwing', () {
      // Verbatim shape from a plugin indexer, trimmed to what matters.
      const String raw = '''
      {
        "guid": "tubifarry-1",
        "title": "Some Artist - Some Album [FLAC]",
        "protocol": "TorrentDownloadProtocol",
        "indexer": "Slskd",
        "size": 12345,
        "approved": true,
        "rejected": false
      }
      ''';

      final ReleaseResource release = ReleaseResource.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );

      expect(release.protocol, DownloadProtocol.torrent);
      expect(release.title, 'Some Artist - Some Album [FLAC]');
      expect(release.indexer, 'Slskd');
      expect(release.approved, isTrue);
    });

    test('the protocols the spec does list still map correctly', () {
      ReleaseResource of(String p) => ReleaseResource.fromJson(
            <String, dynamic>{'guid': 'g', 'protocol': p},
          );

      expect(of('torrent').protocol, DownloadProtocol.torrent);
      expect(of('usenet').protocol, DownloadProtocol.usenet);
      expect(of('unknown').protocol, DownloadProtocol.unknown);
    });

    test('newer builds spell the standard protocols out in full', () {
      // Not a plugin thing: nightly serialises the same two protocols as
      // `TorrentDownloadProtocol` and `UsenetDownloadProtocol` where the
      // released branch sends `torrent` and `usenet`. Losing that to
      // `unknown` would blank the protocol chip on every row.
      ReleaseResource of(String p) => ReleaseResource.fromJson(
            <String, dynamic>{'guid': 'g', 'protocol': p},
          );

      expect(of('TorrentDownloadProtocol').protocol, DownloadProtocol.torrent);
      expect(of('UsenetDownloadProtocol').protocol, DownloadProtocol.usenet);
      expect(of('UnknownDownloadProtocol').protocol, DownloadProtocol.unknown);
    });

    test('a genuinely new protocol still lands on unknown', () {
      // The six Tubifarry adds have no counterpart in the spec, so they can
      // only degrade, but they must not throw.
      for (final String p in <String>[
        'SoulseekDownloadProtocol',
        'QobuzDownloadProtocol',
        'LucidaDownloadProtocol',
        'SubSonicDownloadProtocol',
        'AmazonMusicDownloadProtocol',
        'YoutubeDownloadProtocol',
      ]) {
        final ReleaseResource r = ReleaseResource.fromJson(
          <String, dynamic>{'guid': 'g', 'protocol': p},
        );
        expect(r.protocol, DownloadProtocol.unknown, reason: p);
      }
    });

    test('a queue item on a plugin protocol parses too', () {
      // The queue is the other screen that reads a protocol off every row, so
      // an unmapped value there would empty Activity rather than one card.
      final QueueResource item = QueueResource.fromJson(<String, dynamic>{
        'id': 1,
        'title': 'Some Artist - Some Album',
        'protocol': 'SlskdDownloadProtocol',
      });

      expect(item.protocol, DownloadProtocol.unknown);
      expect(item.title, 'Some Artist - Some Album');
    });

    test('an unknown value anywhere else degrades the same way', () {
      // Not protocol-specific: any enum the server extends behaves this way,
      // which is the point of doing it in the generator rather than by hand.
      final BlocklistResource b = BlocklistResource.fromJson(<String, dynamic>{
        'id': 2,
        'sourceTitle': 'whatever',
        'protocol': 'SubsonicDownloadProtocol',
      });

      expect(b.protocol, DownloadProtocol.unknown);
      expect(b.sourceTitle, 'whatever');
    });
  });
}
