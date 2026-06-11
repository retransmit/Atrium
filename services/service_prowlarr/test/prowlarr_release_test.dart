import 'package:flutter_test/flutter_test.dart';
import 'package:service_prowlarr/service_prowlarr.dart';

// Trimmed but shape-faithful payloads from `GET /api/v1/search` - one torrent
// result with peers, one usenet result without them.
const Map<String, dynamic> torrentJson = <String, dynamic>{
  'guid': 'https://example-tracker.local/details/12345',
  'age': 0,
  'ageHours': 5.4,
  'ageMinutes': 324.2,
  'size': 1573741824,
  'indexerId': 2,
  'indexer': 'ExampleTracker',
  'title': 'Some.Show.S01E01.1080p.WEB.H264-GRP',
  'sortTitle': 'some show s01e01 1080p web h264 grp',
  'imdbId': 0,
  'publishDate': '2026-06-11T04:00:00Z',
  'downloadUrl': 'https://example-tracker.local/download/12345.torrent',
  'infoUrl': 'https://example-tracker.local/details/12345',
  'indexerFlags': <String>[],
  'categories': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 5000,
      'name': 'TV',
      'subCategories': <dynamic>[],
    },
  ],
  'protocol': 'torrent',
  'seeders': 42,
  'leechers': 7,
};

const Map<String, dynamic> usenetJson = <String, dynamic>{
  'guid': 'https://example-indexer.local/nzb/abcdef',
  'age': 3,
  'ageHours': 76.1,
  'size': 858993459,
  'indexerId': 5,
  'indexer': 'ExampleNzb',
  'title': 'Some.Movie.2026.1080p.BluRay.x264-GRP',
  'publishDate': '2026-06-08T01:00:00Z',
  'categories': <Map<String, dynamic>>[
    <String, dynamic>{'id': 2000, 'name': 'Movies'},
  ],
  'protocol': 'usenet',
  'grabs': 12,
};

void main() {
  test('parses a torrent search result', () {
    final ProwlarrRelease r = ProwlarrRelease.fromJson(torrentJson);
    expect(r.guid, 'https://example-tracker.local/details/12345');
    expect(r.indexerId, 2);
    expect(r.indexer, 'ExampleTracker');
    expect(r.isTorrent, isTrue);
    expect(r.seeders, 42);
    expect(r.leechers, 7);
    expect(r.size, 1573741824);
    expect(r.categories.single.name, 'TV');
    expect(r.publishDate, DateTime.utc(2026, 6, 11, 4));
    // Fresh release: hours, not "0d".
    expect(r.ageLabel, '5h');
  });

  test('parses a usenet search result without peer fields', () {
    final ProwlarrRelease r = ProwlarrRelease.fromJson(usenetJson);
    expect(r.isTorrent, isFalse);
    expect(r.seeders, isNull);
    expect(r.leechers, isNull);
    expect(r.grabs, 12);
    expect(r.ageLabel, '3d');
  });

  test('parses an indexer with privacy', () {
    final ProwlarrIndexer ix = ProwlarrIndexer.fromJson(<String, dynamic>{
      'id': 2,
      'name': 'ExampleTracker',
      'enable': true,
      'protocol': 'torrent',
      'privacy': 'private',
      'priority': 25,
    });
    expect(ix.privacy, 'private');
    expect(ix.enable, isTrue);
  });
}
