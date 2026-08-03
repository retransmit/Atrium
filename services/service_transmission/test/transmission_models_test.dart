import 'package:flutter_test/flutter_test.dart';
import 'package:service_transmission/service_transmission.dart';

/// Defaults are values no test passes explicitly, so a test spelling out a
/// field is saying something rather than repeating the default.
TransmissionTorrent _t({
  int id = 99,
  String hash = 'unnamed',
  String name = 'unnamed',
  int statusCode = 6,
  double percentDone = 0.5,
  int sizeWhenDone = 100,
  int leftUntilDone = 50,
  int eta = -1,
  int queuePosition = 9,
  List<String> labels = const <String>[],
  int downloadRate = 0,
  int uploadRate = 0,
  double uploadRatio = 0,
  int addedDate = 0,
  int error = 0,
  String errorString = '',
  bool isStalled = false,
  double recheckProgress = 0,
}) {
  return TransmissionTorrent(
    id: id,
    hashString: hash,
    name: name,
    statusCode: statusCode,
    percentDone: percentDone,
    sizeWhenDone: sizeWhenDone,
    leftUntilDone: leftUntilDone,
    eta: eta,
    queuePosition: queuePosition,
    labels: labels,
    downloadRate: downloadRate,
    uploadRate: uploadRate,
    uploadRatio: uploadRatio,
    addedDate: addedDate,
    error: error,
    errorString: errorString,
    isStalled: isStalled,
    recheckProgress: recheckProgress,
  );
}

void main() {
  group('TransmissionStatus', () {
    test('maps every documented code', () {
      expect(TransmissionStatus.fromCode(0), TransmissionStatus.stopped);
      expect(TransmissionStatus.fromCode(1), TransmissionStatus.checkWait);
      expect(TransmissionStatus.fromCode(2), TransmissionStatus.checking);
      expect(TransmissionStatus.fromCode(3), TransmissionStatus.downloadWait);
      expect(TransmissionStatus.fromCode(4), TransmissionStatus.downloading);
      expect(TransmissionStatus.fromCode(5), TransmissionStatus.seedWait);
      expect(TransmissionStatus.fromCode(6), TransmissionStatus.seeding);
    });

    test('falls back to unknown rather than throwing', () {
      // A future Transmission adding a status must not break the list.
      expect(TransmissionStatus.fromCode(42), TransmissionStatus.unknown);
      expect(TransmissionStatus.fromCode(-7), TransmissionStatus.unknown);
    });

    test('groups queued states', () {
      expect(TransmissionStatus.downloadWait.isQueued, isTrue);
      expect(TransmissionStatus.seedWait.isQueued, isTrue);
      expect(TransmissionStatus.checkWait.isQueued, isTrue);
      expect(TransmissionStatus.downloading.isQueued, isFalse);
    });
  });

  group('TransmissionTorrent', () {
    test('parses a torrent-get entry', () {
      final TransmissionTorrent t =
          TransmissionTorrent.fromJson(const <String, dynamic>{
        'id': 1,
        'hashString': 'b360b86c3034f31fa45e4ec1fab979b9a0d5d251',
        'name': 'probe.bin',
        'status': 0,
        'percentDone': 0.0,
        'totalSize': 1048576,
        'sizeWhenDone': 1048576,
        'leftUntilDone': 1048576,
        'eta': -1,
        'queuePosition': 0,
      });
      expect(t.status, TransmissionStatus.stopped);
      expect(t.percentDone, 0.0);
      expect(t.doneBytes, 0);
      expect(t.hasEta, isFalse);
      expect(t.statusLabel, 'Stopped');
    });

    test('tolerates keys the daemon omitted', () {
      final TransmissionTorrent t =
          TransmissionTorrent.fromJson(const <String, dynamic>{'id': 3});
      expect(t.status, TransmissionStatus.unknown);
      expect(t.hashString, '');
      expect(t.percentDone, 0);
      expect(t.labels, isEmpty);
    });

    test('eta sentinels never read as a duration', () {
      // -1 is "not available" (the helper's default), -2 is "unknown".
      // Neither is 0 seconds.
      expect(_t().hasEta, isFalse);
      expect(_t(eta: -2).hasEta, isFalse);
      expect(_t(eta: 0).hasEta, isFalse);
      expect(_t(eta: 30).hasEta, isTrue);
    });

    test('doneBytes derives from sizeWhenDone and clamps', () {
      // sizeWhenDone is 100 by default.
      expect(_t(leftUntilDone: 40).doneBytes, 60);
      expect(_t(leftUntilDone: 0).doneBytes, 100);
      // A daemon reporting more left than the total must not go negative.
      expect(_t(leftUntilDone: 500).doneBytes, 0);
    });

    test('ratio treats -1 as zero', () {
      // Transmission reports -1 until something has been uploaded.
      expect(_t(uploadRatio: -1).ratio, 0);
      expect(_t(uploadRatio: 1.25).ratio, 1.25);
    });

    test('statusLabel folds in error, verifying and stalled', () {
      expect(
        _t(error: 3, errorString: 'tracker gone').statusLabel,
        'Error',
      );
      expect(
        _t(statusCode: 2, recheckProgress: 0.42).statusLabel,
        'Verifying 42%',
      );
      expect(
        _t(statusCode: 4, isStalled: true).statusLabel,
        'Downloading (idle)',
      );
      // A stopped torrent is not "idle", it is stopped.
      expect(_t(statusCode: 0, isStalled: true).statusLabel, 'Stopped');
    });

    test('hasError needs both a code and a message', () {
      // Defaults are error 0 with an empty message.
      expect(_t().hasError, isFalse);
      // A code with no message is still not something worth showing.
      expect(_t(error: 3).hasError, isFalse);
      expect(_t(error: 3, errorString: 'boom').hasError, isTrue);
    });
  });

  group('TransmissionDetail.fromTorrentJson', () {
    test('zips files with fileStats', () {
      final TransmissionDetail d =
          TransmissionDetail.fromTorrentJson(const <String, dynamic>{
        'pieceCount': 4,
        'pieceSize': 262144,
        'files': <dynamic>[
          <String, dynamic>{
            'name': 'dir/a.mkv',
            'length': 100,
            'bytesCompleted': 100,
          },
          <String, dynamic>{
            'name': 'dir/b.mkv',
            'length': 200,
            'bytesCompleted': 0,
          },
        ],
        'fileStats': <dynamic>[
          <String, dynamic>{'wanted': true, 'priority': 1},
          <String, dynamic>{'wanted': false, 'priority': -1},
        ],
      });
      expect(d.files, hasLength(2));
      expect(d.files[0].displayName, 'a.mkv');
      expect(d.files[0].progress, 1.0);
      expect(d.files[0].wanted, isTrue);
      expect(d.files[0].priorityLabel, 'High');
      expect(d.files[1].progress, 0.0);
      expect(d.files[1].wanted, isFalse);
      expect(d.files[1].priorityLabel, 'Low');
    });

    test('bounds-checks a short or missing fileStats', () {
      final TransmissionDetail d =
          TransmissionDetail.fromTorrentJson(const <String, dynamic>{
        'files': <dynamic>[
          <String, dynamic>{'name': 'a', 'length': 10, 'bytesCompleted': 5},
          <String, dynamic>{'name': 'b', 'length': 10, 'bytesCompleted': 0},
        ],
        'fileStats': <dynamic>[
          <String, dynamic>{'wanted': false, 'priority': 1},
        ],
      });
      expect(d.files, hasLength(2));
      expect(d.files[0].wanted, isFalse);
      // Second file has no stats entry, so it keeps the defaults.
      expect(d.files[1].wanted, isTrue);
      expect(d.files[1].priority, 0);
      expect(d.files[0].progress, 0.5);
    });

    test('reads trackerStats and peers, and copes with neither', () {
      final TransmissionDetail d =
          TransmissionDetail.fromTorrentJson(const <String, dynamic>{
        'trackerStats': <dynamic>[
          <String, dynamic>{
            'host': 'tracker.example',
            'announce': 'udp://tracker.example/announce',
            'tier': 0,
            'lastAnnounceSucceeded': false,
            'seederCount': -1,
            'leecherCount': -1,
          },
        ],
      });
      expect(d.trackers, hasLength(1));
      expect(d.trackers.first.seederCount, -1);
      expect(d.peers, isEmpty);
      expect(d.files, isEmpty);
    });

    test('file progress guards a zero length', () {
      final TransmissionDetail d =
          TransmissionDetail.fromTorrentJson(const <String, dynamic>{
        'files': <dynamic>[
          <String, dynamic>{'name': 'empty', 'length': 0, 'bytesCompleted': 0},
        ],
      });
      expect(d.files.single.progress, 0);
    });
  });

  group('filterTransmissionTorrents', () {
    final List<TransmissionTorrent> torrents = <TransmissionTorrent>[
      _t(hash: 'a', statusCode: 4, labels: const <String>['linux']),
      // statusCode 6 (seeding) is the helper default.
      _t(hash: 'b'),
      _t(hash: 'c', statusCode: 0, labels: const <String>['linux', 'iso']),
    ];

    test('the default filter keeps everything', () {
      expect(
        filterTransmissionTorrents(torrents, const TransmissionFilter()),
        hasLength(3),
      );
    });

    test('narrows by status', () {
      final List<TransmissionTorrent> out = filterTransmissionTorrents(
        torrents,
        const TransmissionFilter(status: TransmissionStatus.seeding),
      );
      expect(out.single.hashString, 'b');
    });

    test('narrows by label', () {
      final List<TransmissionTorrent> out = filterTransmissionTorrents(
        torrents,
        const TransmissionFilter(label: 'linux'),
      );
      expect(
        out.map((TransmissionTorrent t) => t.hashString),
        <String>['a', 'c'],
      );
    });

    test('clearStatus drops the status without touching the label', () {
      const TransmissionFilter f = TransmissionFilter(
        status: TransmissionStatus.seeding,
        label: 'linux',
      );
      final TransmissionFilter cleared = f.copyWith(clearStatus: true);
      expect(cleared.status, isNull);
      expect(cleared.label, 'linux');
    });
  });

  group('sortTransmissionTorrents', () {
    test('pushes unqueued torrents to the end of a queue sort', () {
      final List<TransmissionTorrent> out = sortTransmissionTorrents(
        <TransmissionTorrent>[
          _t(hash: 'unqueued', queuePosition: -1),
          _t(hash: 'second', queuePosition: 1),
          _t(hash: 'first', queuePosition: 0),
        ],
        TransmissionSortField.queue,
        descending: false,
      );
      expect(
        out.map((TransmissionTorrent t) => t.hashString),
        <String>['first', 'second', 'unqueued'],
      );
    });

    test('sorts by size and reverses when descending', () {
      final List<TransmissionTorrent> input = <TransmissionTorrent>[
        _t(hash: 'mid', sizeWhenDone: 20),
        _t(hash: 'big', sizeWhenDone: 30),
        _t(hash: 'small', sizeWhenDone: 10),
      ];
      expect(
        sortTransmissionTorrents(
          input,
          TransmissionSortField.size,
          descending: false,
        ).map((TransmissionTorrent t) => t.hashString),
        <String>['small', 'mid', 'big'],
      );
      expect(
        sortTransmissionTorrents(
          input,
          TransmissionSortField.size,
          descending: true,
        ).map((TransmissionTorrent t) => t.hashString),
        <String>['big', 'mid', 'small'],
      );
    });

    test('does not mutate the input list', () {
      final List<TransmissionTorrent> input = <TransmissionTorrent>[
        _t(hash: 'b', sizeWhenDone: 20),
        _t(hash: 'a', sizeWhenDone: 10),
      ];
      sortTransmissionTorrents(
        input,
        TransmissionSortField.size,
        descending: false,
      );
      expect(input.first.hashString, 'b');
    });
  });

  group('transmissionLabels', () {
    test('collects a sorted, de-duplicated set', () {
      final List<String> labels = transmissionLabels(<TransmissionTorrent>[
        _t(labels: const <String>['iso', 'linux']),
        _t(labels: const <String>['linux']),
        _t(),
      ]);
      expect(labels, <String>['iso', 'linux']);
    });
  });

  group('formatters', () {
    test('bytes and rates', () {
      expect(trFmtBytes(0), '0 B');
      expect(trFmtBytes(2048), '2.0 KB');
      expect(trFmtRate(0), '0 B/s');
      expect(trFmtRate(1024 * 1024 * 2), '2.0 MB/s');
    });

    test('eta renders sentinels as a dash', () {
      expect(trFmtEta(-1), '-');
      expect(trFmtEta(-2), '-');
      expect(trFmtEta(0), '-');
      expect(trFmtEta(45), '45s');
      expect(trFmtEta(90), '1m 30s');
      expect(trFmtEta(3600), '1h');
      expect(trFmtEta(90000), '1d 1h');
    });

    test('a limit needs its enabled flag to mean anything', () {
      // The value stays put while the limit is off, so a value alone would
      // report a cap that is not actually in force.
      expect(trFmtLimit(kbps: 100, enabled: false), 'Unlimited');
      expect(trFmtLimit(kbps: 100, enabled: true), '100 KB/s');
      expect(trFmtLimit(kbps: 2048, enabled: true), '2 MB/s');
      expect(trFmtLimit(kbps: 0, enabled: true), 'Stopped');
    });

    test('peer counts show -1 as unknown', () {
      expect(trFmtPeerCount(-1), '?');
      expect(trFmtPeerCount(0), '0');
      expect(trFmtPeerCount(12), '12');
    });
  });
}
