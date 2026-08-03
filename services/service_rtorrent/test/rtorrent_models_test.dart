import 'package:flutter_test/flutter_test.dart';
import 'package:service_rtorrent/service_rtorrent.dart';

/// A `d.multicall2` row in [RtorrentTorrent.fields] order. Defaults are values
/// no test passes explicitly, so a test spelling out a field is saying
/// something rather than repeating the default.
List<Object?> _row({
  String hash = 'HASH',
  String name = 'name',
  int size = 100,
  int completed = 50,
  int left = 50,
  int down = 0,
  int up = 0,
  int uploaded = 0,
  int ratio = 0,
  int isActive = 0,
  int isOpen = 0,
  int complete = 0,
  int hashing = 0,
  String message = '',
  int peersConnected = 0,
  int peersComplete = 0,
  String directory = '/downloads',
  String label = '',
  int priority = 2,
  int state = 0,
}) {
  return <Object?>[
    hash,
    name,
    size,
    completed,
    left,
    down,
    up,
    uploaded,
    ratio,
    isActive,
    isOpen,
    complete,
    hashing,
    message,
    peersConnected,
    peersComplete,
    directory,
    label,
    priority,
    state,
  ];
}

RtorrentTorrent _t({
  String name = 'name',
  int size = 100,
  int completed = 50,
  int? left,
  int down = 0,
  int up = 0,
  int ratio = 0,
  int isActive = 0,
  int isOpen = 0,
  int complete = 0,
  int hashing = 0,
  String message = '',
  String label = '',
  int priority = 2,
  int state = 0,
}) {
  return RtorrentTorrent.fromRow(
    _row(
      name: name,
      size: size,
      completed: completed,
      // rTorrent's left_bytes is size minus completed, so a fixture that does
      // not say otherwise should be internally consistent.
      left: left ?? size - completed,
      down: down,
      up: up,
      ratio: ratio,
      isActive: isActive,
      isOpen: isOpen,
      complete: complete,
      hashing: hashing,
      message: message,
      label: label,
      priority: priority,
      state: state,
    ),
  );
}

void main() {
  group('RtorrentTorrent.fromRow', () {
    test('maps every field by position', () {
      final RtorrentTorrent t = RtorrentTorrent.fromRow(
        _row(
          hash: 'ABC123',
          name: 'Ubuntu',
          size: 2000,
          completed: 500,
          left: 1500,
          down: 10,
          up: 20,
          uploaded: 400,
          ratio: 1250,
          isActive: 1,
          isOpen: 1,
          peersConnected: 8,
          peersComplete: 3,
          directory: '/downloads/ubuntu',
          label: 'linux',
          priority: 3,
          state: 1,
        ),
      );
      expect(t.hash, 'ABC123');
      expect(t.name, 'Ubuntu');
      expect(t.sizeBytes, 2000);
      expect(t.completedBytes, 500);
      expect(t.leftBytes, 1500);
      expect(t.downRate, 10);
      expect(t.upRate, 20);
      expect(t.uploadedTotal, 400);
      expect(t.isActive, isTrue);
      expect(t.isOpen, isTrue);
      expect(t.peersConnected, 8);
      expect(t.peersComplete, 3);
      expect(t.directory, '/downloads/ubuntu');
      expect(t.label, 'linux');
      expect(t.priority, 3);
      expect(t.state, 1);
    });

    // rTorrent's d.ratio is per-mille, so a raw value shown as-is would claim a
    // ratio a thousand times too high.
    test('converts the per-mille ratio', () {
      expect(_t(ratio: 1250).ratio, 1.25);
      expect(_t().ratio, 0);
      expect(_t(ratio: 500).ratio, 0.5);
    });

    test('progress is a 0-1 fraction', () {
      expect(_t(size: 200).progress, 0.25);
      expect(_t(size: 0, completed: 0).progress, 0);
    });

    // An rTorrent build missing one command returns a shorter row rather than
    // failing the call, and one absent field should not blank the list.
    test('tolerates a short row', () {
      final RtorrentTorrent t =
          RtorrentTorrent.fromRow(<Object?>['HASH', 'name', 100]);
      expect(t.hash, 'HASH');
      expect(t.name, 'name');
      expect(t.sizeBytes, 100);
      expect(t.completedBytes, 0);
      expect(t.directory, '');
    });

    test('accepts numeric fields arriving as strings', () {
      final RtorrentTorrent t =
          RtorrentTorrent.fromRow(<Object?>['H', 'n', '250', '125']);
      expect(t.sizeBytes, 250);
      expect(t.completedBytes, 125);
      expect(t.progress, 0.5);
    });
  });

  group('status', () {
    test('an error message outranks every other flag', () {
      final RtorrentTorrent t = _t(
        message: 'Tracker gave a warning',
        state: 1,
        isOpen: 1,
        isActive: 1,
      );
      expect(t.status, RtorrentStatus.error);
      expect(t.hasError, isTrue);
    });

    test('hashing outranks running', () {
      expect(
        _t(hashing: 1, state: 1, isOpen: 1, isActive: 1).status,
        RtorrentStatus.checking,
      );
    });

    test('state 0 is stopped whatever else is set', () {
      expect(_t(isOpen: 1, isActive: 1).status, RtorrentStatus.stopped);
    });

    test('started but closed is paused', () {
      expect(_t(state: 1).status, RtorrentStatus.paused);
    });

    test('open and active but incomplete is downloading', () {
      expect(
        _t(state: 1, isOpen: 1, isActive: 1).status,
        RtorrentStatus.downloading,
      );
    });

    test('open and active and complete is seeding', () {
      expect(
        _t(state: 1, isOpen: 1, isActive: 1, complete: 1).status,
        RtorrentStatus.seeding,
      );
    });

    test('open but inactive is queued either way', () {
      expect(_t(state: 1, isOpen: 1).status, RtorrentStatus.queued);
      expect(
        _t(state: 1, isOpen: 1, complete: 1).status,
        RtorrentStatus.queued,
      );
    });

    test('priority labels cover rTorrent\'s four levels', () {
      expect(_t(priority: 0).priorityLabel, 'Off');
      expect(_t(priority: 1).priorityLabel, 'Low');
      expect(_t().priorityLabel, 'Normal');
      expect(_t(priority: 3).priorityLabel, 'High');
    });
  });

  group('RtorrentGlobal.fromRows', () {
    // system.multicall wraps each result in a one-element array.
    test('unwraps the one-element arrays a multicall returns', () {
      final RtorrentGlobal g = RtorrentGlobal.fromRows(<Object?>[
        <Object?>['0.16.17'],
        <Object?>[1024],
        <Object?>[512],
        <Object?>[0],
        <Object?>[2048],
        <Object?>[50000],
      ]);
      expect(g.version, '0.16.17');
      expect(g.downRate, 1024);
      expect(g.upRate, 512);
      expect(g.downLimit, 0);
      expect(g.upLimit, 2048);
      expect(g.listenPort, 50000);
    });

    test('accepts bare values too', () {
      final RtorrentGlobal g =
          RtorrentGlobal.fromRows(<Object?>['0.9.8', 10, 20]);
      expect(g.version, '0.9.8');
      expect(g.downRate, 10);
      expect(g.upRate, 20);
    });

    test('0 means unlimited, not stopped', () {
      const RtorrentGlobal g = RtorrentGlobal(upLimit: 1024);
      expect(g.downLimited, isFalse);
      expect(g.upLimited, isTrue);
    });
  });

  group('detail rows', () {
    // rTorrent reports per-file progress in chunks, not bytes.
    test('a file s progress comes from its chunks', () {
      final RtorrentFile f = RtorrentFile.fromRow(
        <Object?>['dir/movie.mkv', 5000, 3, 4, 2],
      );
      expect(f.path, 'dir/movie.mkv');
      expect(f.displayName, 'movie.mkv');
      expect(f.sizeBytes, 5000);
      expect(f.progress, 0.75);
      expect(f.priorityLabel, 'High');
    });

    test('a zero-chunk file reports no progress rather than dividing by 0', () {
      expect(RtorrentFile.fromRow(<Object?>['a', 0, 0, 0, 1]).progress, 0);
    });

    test('file priorities are skip / normal / high', () {
      expect(
        RtorrentFile.fromRow(<Object?>['a', 1, 0, 1, 0]).priorityLabel,
        'Skip',
      );
      expect(
        RtorrentFile.fromRow(<Object?>['a', 1, 0, 1, 1]).priorityLabel,
        'Normal',
      );
    });

    test('a tracker keeps its group and enabled flag', () {
      final RtorrentTracker tr = RtorrentTracker.fromRow(
        <Object?>['http://tracker/announce', 2, 1],
      );
      expect(tr.url, 'http://tracker/announce');
      expect(tr.group, 2);
      expect(tr.isEnabled, isTrue);
      expect(
        RtorrentTracker.fromRow(<Object?>['x', 0, 0]).isEnabled,
        isFalse,
      );
    });

    test('a peer s completed_percent becomes a 0-1 fraction', () {
      final RtorrentPeer p = RtorrentPeer.fromRow(
        <Object?>['10.0.0.5', 'qBittorrent 4.6', 100, 200, 40, 1],
      );
      expect(p.address, '10.0.0.5');
      expect(p.client, 'qBittorrent 4.6');
      expect(p.downRate, 100);
      expect(p.upRate, 200);
      expect(p.progress, 0.4);
      expect(p.isEncrypted, isTrue);
    });
  });

  group('filter and sort', () {
    final List<RtorrentTorrent> all = <RtorrentTorrent>[
      _t(name: 'b', state: 1, isOpen: 1, isActive: 1, size: 300, completed: 30),
      _t(name: 'a', label: 'movies'),
      _t(
        name: 'c',
        state: 1,
        isOpen: 1,
        isActive: 1,
        complete: 1,
        label: 'movies',
        ratio: 2000,
      ),
    ];

    test('an empty filter keeps everything', () {
      expect(
        filterRtorrentTorrents(all, const RtorrentFilter()),
        hasLength(3),
      );
    });

    test('filters by status', () {
      final List<RtorrentTorrent> out = filterRtorrentTorrents(
        all,
        const RtorrentFilter(status: RtorrentStatus.seeding),
      );
      expect(out.map((RtorrentTorrent t) => t.name), <String>['c']);
    });

    test('filters by label', () {
      final List<RtorrentTorrent> out = filterRtorrentTorrents(
        all,
        const RtorrentFilter(label: 'movies'),
      );
      expect(out.map((RtorrentTorrent t) => t.name), <String>['a', 'c']);
    });

    test('sorts by name in both directions', () {
      expect(
        sortRtorrentTorrents(all, RtorrentSortField.name, descending: false)
            .map((RtorrentTorrent t) => t.name),
        <String>['a', 'b', 'c'],
      );
      expect(
        sortRtorrentTorrents(all, RtorrentSortField.name, descending: true)
            .map((RtorrentTorrent t) => t.name),
        <String>['c', 'b', 'a'],
      );
    });

    test('sorts by ratio using the per-mille value', () {
      expect(
        sortRtorrentTorrents(all, RtorrentSortField.ratio, descending: true)
            .first
            .name,
        'c',
      );
    });

    test('sorting leaves the input list alone', () {
      final List<String> before =
          all.map((RtorrentTorrent t) => t.name).toList();
      sortRtorrentTorrents(all, RtorrentSortField.size, descending: true);
      expect(all.map((RtorrentTorrent t) => t.name), before);
    });

    // Labels live in d.custom1, so a plain rTorrent has none at all.
    test('labels are collected from the torrents themselves', () {
      expect(rtorrentLabels(all), <String>['movies']);
      expect(rtorrentLabels(<RtorrentTorrent>[_t()]), isEmpty);
    });
  });

  group('formatting', () {
    test('bytes', () {
      expect(rtFmtBytes(0), '0 B');
      expect(rtFmtBytes(512), '512 B');
      expect(rtFmtBytes(1536), '1.5 KB');
      expect(rtFmtBytes(1024 * 1024 * 3), '3.0 MB');
    });

    test('rate', () {
      expect(rtFmtRate(0), '0 B/s');
      expect(rtFmtRate(2048), '2.0 KB/s');
    });

    test('0 is unlimited, not a stopped transfer', () {
      expect(rtFmtLimit(0), 'Unlimited');
      expect(rtFmtLimit(1024 * 1024), '1.0 MB/s');
    });

    test('a rate splits into figure and unit', () {
      expect(rtSplitRate(2048), ('2.0', 'KB/s'));
    });

    // rTorrent publishes no ETA of its own; it is derived, so a stalled or
    // finished torrent simply has none.
    test('eta is derived from what is left and the current rate', () {
      expect(rtFmtEta(_t(size: 1000, completed: 0, down: 10)), '1m 40s');
      expect(rtFmtEta(_t(size: 1000, completed: 0)), '-');
      expect(rtFmtEta(_t(complete: 1, down: 10)), '-');
    });
  });
}
