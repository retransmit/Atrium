import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

QbitTorrent _torrent({
  required String hash,
  String name = 'torrent',
  int priority = 0,
  int size = 1000,
  int addedOn = 100,
}) {
  return QbitTorrent(
    hash: hash,
    name: name,
    state: 'downloading',
    priority: priority,
    size: size,
    addedOn: addedOn,
  );
}

void main() {
  group('QbitSortField', () {
    test('displayName for queue is "Queue Position"', () {
      expect(QbitSortField.queue.displayName, 'Queue Position');
    });
  });

  group('qbitQueueRank', () {
    test('ranks positive priorities by their value', () {
      expect(qbitQueueRank(_torrent(hash: 'a', priority: 1)), 1);
      expect(qbitQueueRank(_torrent(hash: 'b', priority: 5)), 5);
    });

    test('pushes unqueued priority (<= 0) to max int rank', () {
      expect(qbitQueueRank(_torrent(hash: 'c')), 1 << 30);
      expect(qbitQueueRank(_torrent(hash: 'd', priority: -1)), 1 << 30);
    });
  });

  group('sortQbitTorrents', () {
    test('pushes unqueued torrents (priority <= 0) to the end of a queue sort',
        () {
      final List<QbitTorrent> torrents = <QbitTorrent>[
        _torrent(hash: 'unqueued_0', name: 'Z'),
        _torrent(hash: 'third', name: 'T', priority: 3),
        _torrent(hash: 'first', name: 'F', priority: 1),
        _torrent(hash: 'unqueued_neg', name: 'A', priority: -1),
        _torrent(hash: 'second', name: 'S', priority: 2),
      ];

      final List<QbitTorrent> sorted = sortQbitTorrents(
        torrents,
        const QbitSortConfig(field: QbitSortField.queue, ascending: true),
      );

      expect(
        sorted.map((QbitTorrent t) => t.hash),
        <String>['first', 'second', 'third', 'unqueued_neg', 'unqueued_0'],
      );
    });

    test('reverses queue sort when descending', () {
      final List<QbitTorrent> torrents = <QbitTorrent>[
        _torrent(hash: 'first', priority: 1),
        _torrent(hash: 'second', priority: 2),
        _torrent(hash: 'third', priority: 3),
      ];

      final List<QbitTorrent> sorted = sortQbitTorrents(
        torrents,
        const QbitSortConfig(field: QbitSortField.queue, ascending: false),
      );

      expect(
        sorted.map((QbitTorrent t) => t.hash),
        <String>['third', 'second', 'first'],
      );
    });

    test('sorts by size and reverses when descending', () {
      final List<QbitTorrent> torrents = <QbitTorrent>[
        _torrent(hash: 'mid', size: 200),
        _torrent(hash: 'big', size: 300),
        _torrent(hash: 'small', size: 100),
      ];

      expect(
        sortQbitTorrents(
          torrents,
          const QbitSortConfig(field: QbitSortField.size, ascending: true),
        ).map((QbitTorrent t) => t.hash),
        <String>['small', 'mid', 'big'],
      );

      expect(
        sortQbitTorrents(
          torrents,
          const QbitSortConfig(field: QbitSortField.size, ascending: false),
        ).map((QbitTorrent t) => t.hash),
        <String>['big', 'mid', 'small'],
      );
    });

    test('falls back to case-insensitive name comparison on equal values', () {
      final List<QbitTorrent> torrents = <QbitTorrent>[
        _torrent(hash: 'b', name: 'Beta', priority: 1),
        _torrent(hash: 'a', name: 'alpha', priority: 1),
      ];

      final List<QbitTorrent> sorted = sortQbitTorrents(
        torrents,
        const QbitSortConfig(field: QbitSortField.queue, ascending: true),
      );

      expect(
        sorted.map((QbitTorrent t) => t.hash),
        <String>['a', 'b'],
      );
    });

    test('does not mutate the input list', () {
      final List<QbitTorrent> torrents = <QbitTorrent>[
        _torrent(hash: 'b', size: 200),
        _torrent(hash: 'a', size: 100),
      ];

      sortQbitTorrents(
        torrents,
        const QbitSortConfig(field: QbitSortField.size, ascending: true),
      );

      expect(torrents.first.hash, 'b');
    });
  });
}
