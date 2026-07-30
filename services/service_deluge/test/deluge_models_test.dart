import 'package:flutter_test/flutter_test.dart';
import 'package:service_deluge/service_deluge.dart';

/// Defaults are deliberately values no test passes explicitly, so that a test
/// spelling out `state:` or `id:` is saying something rather than repeating the
/// default.
DelugeTorrent _torrent({
  String id = 'unnamed',
  String state = 'Queued',
  int queue = 9,
  String label = '',
  String trackerHost = 'tracker.example',
  int totalWanted = 100,
  double progress = 50,
  int timeAdded = 0,
}) {
  return DelugeTorrent(
    id: id,
    name: 'name-$id',
    state: state,
    queue: queue,
    label: label,
    trackerHost: trackerHost,
    totalWanted: totalWanted,
    progress: progress,
    timeAdded: timeAdded,
  );
}

void main() {
  group('DelugeTorrent.fromStatus', () {
    test('folds the infohash in and reads a 0-100 progress', () {
      final DelugeTorrent t = DelugeTorrent.fromStatus('abc123', <String, dynamic>{
        'name': 'Sunshine',
        'state': 'Seeding',
        'progress': 100.0,
        'total_wanted': 6395774138,
        'download_payload_rate': 0,
      });
      expect(t.id, 'abc123');
      expect(t.name, 'Sunshine');
      expect(t.isSeeding, isTrue);
      // Deluge reports percent, not a fraction.
      expect(t.progress, 100.0);
      expect(t.progressFraction, 1.0);
      expect(t.totalWanted, 6395774138);
    });

    test('tolerates keys the daemon omitted', () {
      // A daemon without the Label plugin returns no `label` at all even when
      // asked for it, and an unfinished add can be missing most fields.
      final DelugeTorrent t =
          DelugeTorrent.fromStatus('h', <String, dynamic>{'name': 'x'});
      expect(t.label, '');
      expect(t.state, '');
      expect(t.progress, 0);
      expect(t.queue, -1);
      expect(t.isFinished, isFalse);
    });

    test('progressFraction clamps out-of-range values', () {
      expect(_torrent(progress: 120).progressFraction, 1.0);
      expect(_torrent(progress: -5).progressFraction, 0.0);
    });
  });

  group('DelugeTorrentDetail.fromStatus', () {
    test('zips the parallel file arrays together', () {
      final DelugeTorrentDetail d =
          DelugeTorrentDetail.fromStatus(<String, dynamic>{
        'num_files': 2,
        'total_size': 300,
        'private': false,
        'files': <dynamic>[
          <String, dynamic>{'index': 0, 'path': 'dir/a.mkv', 'size': 100},
          <String, dynamic>{'index': 1, 'path': 'dir/b.mkv', 'size': 200},
        ],
        'file_progress': <dynamic>[1.0, 0.5],
        'file_priorities': <dynamic>[4, 0],
      });
      expect(d.files, hasLength(2));
      expect(d.files[0].displayName, 'a.mkv');
      expect(d.files[0].progress, 1.0);
      expect(d.files[0].priority, 4);
      expect(d.files[1].progress, 0.5);
      expect(d.files[1].priority, 0);
      expect(delugeFilePriorityLabel(d.files[1].priority), 'Skip');
    });

    test('bounds-checks short or missing progress arrays', () {
      // A torrent whose metadata has not arrived can report files with no
      // matching progress/priority entries; indexing blindly would throw.
      final DelugeTorrentDetail d =
          DelugeTorrentDetail.fromStatus(<String, dynamic>{
        'files': <dynamic>[
          <String, dynamic>{'index': 0, 'path': 'a', 'size': 1},
          <String, dynamic>{'index': 1, 'path': 'b', 'size': 2},
        ],
        'file_progress': <dynamic>[0.25],
      });
      expect(d.files, hasLength(2));
      expect(d.files[0].progress, 0.25);
      expect(d.files[1].progress, 0);
      expect(d.files[1].priority, 4);
    });

    test('reads trackers and peers, and copes with neither', () {
      final DelugeTorrentDetail d =
          DelugeTorrentDetail.fromStatus(<String, dynamic>{
        'trackers': <dynamic>[
          <String, dynamic>{
            'url': 'udp://t.example:6969/announce',
            'tier': 1,
            'verified': true,
            'message': '',
            // last_error is a nested object that must simply be ignored.
            'last_error': <String, dynamic>{'value': 0},
          },
        ],
      });
      expect(d.trackers, hasLength(1));
      expect(d.trackers.first.tier, 1);
      expect(d.trackers.first.verified, isTrue);
      expect(d.peers, isEmpty);
      expect(d.files, isEmpty);
    });
  });

  group('DelugeFilterTree', () {
    test('parses buckets and reports no labels without the plugin', () {
      final DelugeFilterTree tree =
          DelugeFilterTree.fromJson(const <String, dynamic>{
        'state': <dynamic>[
          <dynamic>['All', 1],
          <dynamic>['Seeding', 1],
          <dynamic>['Paused', 0],
        ],
        'tracker_host': <dynamic>[
          <dynamic>['All', 1],
          <dynamic>['gbitt.info', 1],
        ],
      });
      expect(tree.states, hasLength(3));
      expect(tree.states[1], const DelugeFilterBucket(name: 'Seeding', count: 1));
      expect(tree.trackerHosts, hasLength(2));
      expect(tree.labels, isEmpty);
      expect(tree.hasLabels, isFalse);
    });

    test('skips malformed pairs instead of throwing', () {
      final DelugeFilterTree tree =
          DelugeFilterTree.fromJson(const <String, dynamic>{
        'state': <dynamic>[
          <dynamic>['Good', 2],
          <dynamic>['MissingCount'],
          'not-a-pair',
          <dynamic>[5, 5],
        ],
      });
      expect(tree.states, hasLength(1));
      expect(tree.states.single.name, 'Good');
    });
  });

  group('filterDelugeTorrents', () {
    final List<DelugeTorrent> torrents = <DelugeTorrent>[
      _torrent(id: 'a', state: 'Downloading', trackerHost: 'x.example'),
      _torrent(id: 'b', state: 'Seeding', trackerHost: 'y.example'),
      _torrent(id: 'c', state: 'Paused', trackerHost: 'x.example'),
    ];

    test('the default filter keeps everything', () {
      expect(filterDelugeTorrents(torrents, const DelugeFilter()), hasLength(3));
    });

    test('"All" is a wildcard, not a literal state', () {
      // state defaults to 'All', so this also proves 'All' is not matched
      // against the state string literally - nothing is in state "All".
      final List<DelugeTorrent> out = filterDelugeTorrents(
        torrents,
        const DelugeFilter(trackerHost: 'x.example'),
      );
      expect(out.map((DelugeTorrent t) => t.id), <String>['a', 'c']);
    });

    test('narrows by state', () {
      final List<DelugeTorrent> out = filterDelugeTorrents(
        torrents,
        const DelugeFilter(state: 'Seeding'),
      );
      expect(out.single.id, 'b');
    });
  });

  group('sortDelugeTorrents', () {
    test('pushes unqueued torrents to the end of a queue sort', () {
      // queue == -1 means "not queued"; a naive numeric sort would rank it
      // above position 0.
      final List<DelugeTorrent> out = sortDelugeTorrents(
        <DelugeTorrent>[
          _torrent(id: 'unqueued', queue: -1),
          _torrent(id: 'second', queue: 1),
          _torrent(id: 'first', queue: 0),
        ],
        DelugeSortField.queue,
        descending: false,
      );
      expect(
        out.map((DelugeTorrent t) => t.id),
        <String>['first', 'second', 'unqueued'],
      );
    });

    test('sorts by size and reverses when descending', () {
      final List<DelugeTorrent> input = <DelugeTorrent>[
        _torrent(id: 'mid', totalWanted: 20),
        _torrent(id: 'big', totalWanted: 30),
        _torrent(id: 'small', totalWanted: 10),
      ];
      expect(
        sortDelugeTorrents(input, DelugeSortField.size, descending: false)
            .map((DelugeTorrent t) => t.id),
        <String>['small', 'mid', 'big'],
      );
      expect(
        sortDelugeTorrents(input, DelugeSortField.size, descending: true)
            .map((DelugeTorrent t) => t.id),
        <String>['big', 'mid', 'small'],
      );
    });

    test('does not mutate the input list', () {
      final List<DelugeTorrent> input = <DelugeTorrent>[
        _torrent(id: 'b', totalWanted: 20),
        _torrent(id: 'a', totalWanted: 10),
      ];
      sortDelugeTorrents(input, DelugeSortField.size, descending: false);
      expect(input.first.id, 'b');
    });
  });

  group('formatters', () {
    test('bytes and rates', () {
      expect(delugeFmtBytes(0), '0 B');
      expect(delugeFmtBytes(512), '512 B');
      expect(delugeFmtBytes(2048), '2.0 KB');
      expect(delugeFmtRate(0), '0 B/s');
      expect(delugeFmtRate(1024 * 1024 * 2), '2.0 MB/s');
    });

    test('eta renders 0 as a dash rather than "0s"', () {
      // Deluge reports 0 for seeding and paused torrents.
      expect(delugeFmtEta(0), '-');
      expect(delugeFmtEta(45), '45s');
      expect(delugeFmtEta(90), '1m 30s');
      expect(delugeFmtEta(3600), '1h');
      expect(delugeFmtEta(90000), '1d 1h');
    });

    test('limits treat -1 as unlimited and 0 as stopped', () {
      expect(delugeFmtLimitKib(-1), 'Unlimited');
      expect(delugeFmtLimitKib(0), 'Stopped');
      expect(delugeFmtLimitKib(512), '512 KB/s');
      expect(delugeFmtLimitKib(2048), '2 MB/s');
    });
  });
}
