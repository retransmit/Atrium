import 'package:flutter_test/flutter_test.dart';
import 'package:service_transmission/service_transmission.dart';

import 'support/transmission_fixtures.dart';

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
  bool isFinished = false,
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
    isFinished: isFinished,
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
      expect(t.statusLabel, 'Paused');
    });

    test('parses the list fields the filters need', () {
      final TransmissionTorrent t = TransmissionTorrent.fromJson(
        <String, dynamic>{
          'id': 1,
          'hashString': 'aaaa',
          'isPrivate': true,
          'activityDate': 1758303600,
          'metadataPercentComplete': 0.4,
          'webseedsSendingToUs': 2,
          'trackers': <Map<String, dynamic>>[
            <String, dynamic>{
              'announce': 'udp://tracker.example.org:1337/announce',
              'sitename': '',
              'tier': 0,
            },
            <String, dynamic>{
              'announce': 'http://bttracker.debian.org:6969/announce',
              'sitename': 'debian',
              'tier': 1,
            },
          ],
        },
      );

      expect(t.isPrivate, isTrue);
      expect(t.activityDate, 1758303600);
      expect(t.needsMetadata, isTrue);
      expect(t.webseedsSendingToUs, 2);
      // sitename when the daemon gives one, else the announce URL's host.
      expect(t.trackerHosts, <String>{'tracker.example.org', 'debian'});
    });

    test('a daemon that omits metadataPercentComplete is not retrieving',
        () {
      expect(
        TransmissionTorrent.fromJson(<String, dynamic>{'id': 1}).needsMetadata,
        isFalse,
      );
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
      // A stopped torrent is not "idle", it is paused, in the web UI's words.
      expect(_t(statusCode: 0, isStalled: true).statusLabel, 'Paused');
    });

    test('state strings are the web UI words, with Seeding complete', () {
      expect(_t(statusCode: 0).stateString, 'Paused');
      expect(
        _t(statusCode: 0, isFinished: true).stateString,
        'Seeding complete',
      );
      expect(_t(statusCode: 1).stateString, 'Queued for verification');
      expect(_t(statusCode: 2).stateString, 'Verifying local data');
      expect(_t(statusCode: 3).stateString, 'Queued for download');
      expect(_t(statusCode: 5).stateString, 'Queued for seeding');
      // Seeding is the helper's default status.
      expect(_t().stateString, 'Seeding');
      expect(_t(statusCode: 42).stateString, 'Unknown');
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

  group('TransmissionSession', () {
    test('parses every settings key and the version gates', () {
      final TransmissionSession s = TransmissionSession.fromJson(
        <String, dynamic>{
          'rpc-version': 19,
          'start-added-torrents': true,
          'seedRatioLimited': true,
          'seedRatioLimit': 1.5,
          'idle-seeding-limit-enabled': true,
          'idle-seeding-limit': 45,
          'incomplete-dir-enabled': true,
          'incomplete-dir': '/downloads/incomplete',
          'rename-partial-files': false,
          'download-queue-enabled': true,
          'download-queue-size': 3,
          'default-trackers': 'udp://a\n\nudp://b',
          'alt-speed-time-enabled': true,
          'alt-speed-time-begin': 540,
          'alt-speed-time-end': 1020,
          'alt-speed-time-day': 62,
          'peer-limit-per-torrent': 50,
          'peer-limit-global': 200,
          'encryption': 'required',
          'pex-enabled': false,
          'dht-enabled': true,
          'lpd-enabled': true,
          'blocklist-enabled': true,
          'blocklist-url': 'http://example.com/list',
          'blocklist-size': 12,
          'peer-port': 6881,
          'peer-port-random-on-start': true,
          'port-forwarding-enabled': false,
          'utp-enabled': false,
        },
      );

      expect(s.startAddedTorrents, isTrue);
      expect(s.seedRatioLimit, 1.5);
      expect(s.idleSeedingLimit, 45);
      expect(s.incompleteDir, '/downloads/incomplete');
      expect(s.renamePartialFiles, isFalse);
      expect(s.downloadQueueSize, 3);
      expect(s.defaultTrackers, 'udp://a\n\nudp://b');
      expect(s.altSpeedTimeBegin, 540);
      expect(s.altSpeedTimeDay, 62);
      expect(s.peerLimitGlobal, 200);
      expect(s.encryption, 'required');
      expect(s.pexEnabled, isFalse);
      expect(s.blocklistSize, 12);
      expect(s.peerPort, 6881);
      expect(s.peerPortRandomOnStart, isTrue);
      expect(s.utpEnabled, isFalse);
      expect(s.supportsLabels, isTrue);
      expect(s.supportsDefaultTrackers, isTrue);
      expect(s.supportsPortTestPerProtocol, isTrue);
    });

    test('an older daemon hides what it cannot do', () {
      final TransmissionSession s =
          TransmissionSession.fromJson(<String, dynamic>{'rpc-version': 16});
      expect(s.supportsLabels, isTrue);
      expect(s.supportsDefaultTrackers, isFalse);
      expect(s.supportsPortTestPerProtocol, isFalse);
    });

    test('statistics carry both blocks', () {
      final TransmissionSessionStats s =
          TransmissionSessionStats.fromJson(statsJson());
      expect(s.currentStats.secondsActive, 3600);
      expect(s.cumulativeStats.sessionCount, 57);
      expect(s.cumulativeStats.uploadedBytes, 391807173959);
    });
  });

  group('TransmissionDetail inspector fields', () {
    test('reads the inspector fields, peer flags, tracker times and web seeds',
        () {
      final TransmissionDetail d =
          TransmissionDetail.fromTorrentJson(detailJson());

      expect(d.haveValid, 900000000);
      expect(d.haveUnchecked, 100000000);
      expect(d.desiredAvailable, 3000000000);
      expect(d.downloadedEver, 1050000000);
      expect(d.corruptEver, 50000000);
      expect(d.startDate, 1758303000);
      expect(d.magnetLink, startsWith('magnet:?xt=urn:btih:aaaa'));
      expect(d.webseeds, <String>['https://cdimage.debian.org/']);
      expect(d.peers.single.port, 51413);
      expect(d.peers.single.flagStr, 'DEI');
      final TransmissionTracker tr = d.trackers.single;
      expect(tr.sitename, 'debian');
      expect(tr.announceState, 1);
      expect(tr.hasAnnounced, isTrue);
      expect(tr.lastAnnouncePeerCount, 40);
      expect(tr.nextAnnounceTime, 1758304800);
      expect(tr.lastScrapeTime, 1758302000);
      expect(tr.downloadCount, 5000);
      expect(tr.isBackup, isFalse);
    });
  });

  group('TransmissionFilterMode', () {
    test('uses the web UI definitions', () {
      final TransmissionTorrent active =
          _t(statusCode: 0).copyWith(peersSendingToUs: 1);
      final TransmissionTorrent quiet = _t();
      expect(TransmissionFilterMode.active.matches(active), isTrue);
      expect(TransmissionFilterMode.active.matches(_t(statusCode: 2)), isTrue);
      expect(TransmissionFilterMode.active.matches(quiet), isFalse);

      expect(
        TransmissionFilterMode.downloading.matches(_t(statusCode: 3)),
        isTrue,
      );
      expect(
        TransmissionFilterMode.downloading.matches(_t(statusCode: 4)),
        isTrue,
      );
      expect(TransmissionFilterMode.downloading.matches(_t()), isFalse);
      expect(TransmissionFilterMode.seeding.matches(_t(statusCode: 5)), isTrue);
      expect(TransmissionFilterMode.seeding.matches(_t()), isTrue);
      expect(TransmissionFilterMode.paused.matches(_t(statusCode: 0)), isTrue);
      expect(TransmissionFilterMode.paused.matches(_t(statusCode: 4)), isFalse);
      expect(
        TransmissionFilterMode.finished.matches(_t(isFinished: true)),
        isTrue,
      );
      expect(TransmissionFilterMode.finished.matches(_t()), isFalse);
      expect(TransmissionFilterMode.error.matches(_t(error: 2)), isTrue);
      expect(TransmissionFilterMode.error.matches(_t()), isFalse);
      final TransmissionTorrent private = _t().copyWith(isPrivate: true);
      expect(TransmissionFilterMode.private.matches(private), isTrue);
      expect(TransmissionFilterMode.public.matches(private), isFalse);
      expect(TransmissionFilterMode.public.matches(_t()), isTrue);
      expect(TransmissionFilterMode.all.matches(private), isTrue);
    });
  });

  group('filterTransmissionTorrents', () {
    final List<TransmissionTorrent> torrents = <TransmissionTorrent>[
      _t(hash: 'a', name: 'Alpha', statusCode: 4, labels: const <String>['linux'])
          .copyWith(
        trackers: const <TransmissionTrackerRef>[
          TransmissionTrackerRef(announce: 'http://t1.example.org/announce'),
        ],
      ),
      // statusCode 6 (seeding) is the helper default.
      _t(hash: 'b', name: 'Beta'),
      _t(
        hash: 'c',
        name: 'Gamma',
        statusCode: 0,
        labels: const <String>['linux', 'iso'],
      ),
    ];

    test('the default filter keeps everything', () {
      expect(
        filterTransmissionTorrents(torrents, const TransmissionFilter()),
        hasLength(3),
      );
    });

    test('narrows by mode', () {
      final List<TransmissionTorrent> out = filterTransmissionTorrents(
        torrents,
        const TransmissionFilter(mode: TransmissionFilterMode.seeding),
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

    test('narrows by tracker host', () {
      final List<TransmissionTorrent> out = filterTransmissionTorrents(
        torrents,
        const TransmissionFilter(tracker: 't1.example.org'),
      );
      expect(out.single.hashString, 'a');
    });

    test('search matches the name or a label, case-insensitively', () {
      expect(
        filterTransmissionTorrents(
          torrents,
          const TransmissionFilter(),
          search: 'ALPHA',
        ).single.hashString,
        'a',
      );
      expect(
        filterTransmissionTorrents(
          torrents,
          const TransmissionFilter(),
          search: 'iso',
        ).single.hashString,
        'c',
      );
    });

    test('copyWith changes one thing at a time', () {
      const TransmissionFilter f = TransmissionFilter(
        mode: TransmissionFilterMode.seeding,
        label: 'linux',
      );
      final TransmissionFilter cleared =
          f.copyWith(mode: TransmissionFilterMode.all);
      expect(cleared.mode, TransmissionFilterMode.all);
      expect(cleared.label, 'linux');
      expect(cleared.isActive, isTrue);
    });
  });

  group('transmissionTrackers', () {
    test('collects a sorted, de-duplicated set of hosts', () {
      const TransmissionTrackerRef debian = TransmissionTrackerRef(
        announce: 'http://x/announce',
        sitename: 'debian',
      );
      final List<TransmissionTorrent> torrents = <TransmissionTorrent>[
        _t(hash: 'a').copyWith(trackers: const <TransmissionTrackerRef>[debian]),
        _t(hash: 'b').copyWith(
          trackers: const <TransmissionTrackerRef>[
            debian,
            TransmissionTrackerRef(announce: 'udp://tracker.example.org:1337'),
          ],
        ),
      ];
      expect(
        transmissionTrackers(torrents),
        <String>['debian', 'tracker.example.org'],
      );
    });
  });

  group('sortTransmissionTorrents', () {
    test('last activity puts the most recent first before the toggle', () {
      final List<TransmissionTorrent> out = sortTransmissionTorrents(
        <TransmissionTorrent>[
          _t(hash: 'old').copyWith(activityDate: 100),
          _t(hash: 'new').copyWith(activityDate: 200),
        ],
        TransmissionSortField.activity,
        descending: false,
      );
      expect(out.first.hashString, 'new');
    });

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
