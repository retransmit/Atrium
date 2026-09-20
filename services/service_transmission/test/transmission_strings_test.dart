import 'package:flutter_test/flutter_test.dart';
import 'package:service_transmission/service_transmission.dart';

import 'support/transmission_fixtures.dart';

void main() {
  TransmissionTorrent t(Map<String, dynamic> overrides) =>
      TransmissionTorrent.fromJson(
        <String, dynamic>{...torrentJson(), ...overrides},
      );

  group('formatters', () {
    test('time intervals read like the web UI, two units at most', () {
      expect(trTimeInterval(5), '5 seconds');
      expect(trTimeInterval(1), '1 second');
      expect(trTimeInterval(90), '1 minute, 30 seconds');
      expect(trTimeInterval(3600), '1 hour');
      expect(trTimeInterval(3660), '1 hour, 1 minute');
      expect(trTimeInterval(90000), '1 day, 1 hour');
      expect(trTimeInterval(172800), '2 days');
    });

    test('timestamps are local, to the minute', () {
      final DateTime local = DateTime(2026, 9, 20, 14, 5);
      expect(
        trTimestamp(local.millisecondsSinceEpoch ~/ 1000),
        '2026-09-20 14:05',
      );
    });

    test('ratios: None below zero, fewer decimals as they grow', () {
      expect(trRatioString(-1), 'None');
      expect(trRatioString(0.256), '0.26');
      expect(trRatioString(12.34), '12.3');
      expect(trRatioString(123.4), '123');
    });

    test('percent and counts', () {
      expect(trPct(0.25), '25.0');
      expect(trPct(1), '100');
      expect(trCount(1, 'peer', 'peers'), '1 peer');
      expect(trCount(3, 'peer', 'peers'), '3 peers');
    });

    test('day bitmask', () {
      expect(trDaySummary(trEveryDay), 'Every day');
      expect(trDaySummary(trWeekdays), 'Weekdays');
      expect(trDaySummary(trWeekends), 'Weekends');
      expect(trDaySummary(1 | 4), 'Sun, Tue');
      expect(trDaySummary(0), 'Never');
      expect(trToggleDay(trEveryDay, 1), 126);
      expect(trToggleDay(0, 64), 64);
    });
  });

  group('row strings', () {
    test('a magnet still fetching metadata says so and drives the bar', () {
      final TransmissionTorrent m = t(<String, dynamic>{
        'metadataPercentComplete': 0.4,
        'status': 4,
      });
      expect(
        trProgressLine(m),
        'Magnetized transfer - retrieving metadata (40.0%)',
      );
      expect(trBarValue(m), 0.4);
      expect(
        trProgressLine(
          t(<String, dynamic>{'metadataPercentComplete': 0.4, 'status': 0}),
        ),
        'Magnetized transfer - needs metadata (40.0%)',
      );
    });

    test('a downloading torrent shows done of size and the remaining time',
        () {
      expect(
        trProgressLine(t(<String, dynamic>{})),
        '${trFmtBytes(1000000000)} of ${trFmtBytes(4000000000)} (25.0%) - '
        '15 minutes remaining',
      );
      expect(
        trProgressLine(t(<String, dynamic>{'eta': -1})),
        endsWith(' - remaining time unknown'),
      );
    });

    test('a finished torrent shows its size and what it uploaded', () {
      final TransmissionTorrent done = t(<String, dynamic>{
        'status': 6,
        'leftUntilDone': 0,
        'percentDone': 1.0,
        'uploadRatio': 1.5,
      });
      expect(
        trProgressLine(done),
        '${trFmtBytes(4000000000)}, uploaded ${trFmtBytes(200000000)} '
        '(Ratio: 1.50)',
      );
    });

    test('status lines follow the web UI', () {
      expect(
        trStatusLine(t(<String, dynamic>{})),
        'Downloading from 8 of 12 peers - ↓ ${trFmtRate(1024000)} '
        '↑ ${trFmtRate(51200)}',
      );
      expect(
        trStatusLine(t(<String, dynamic>{'webseedsSendingToUs': 1})),
        startsWith('Downloading from 8 of 12 peers and 1 web seed'),
      );
      expect(
        trStatusLine(t(<String, dynamic>{'status': 6})),
        'Seeding to 3 of 12 peers - ↑ ${trFmtRate(51200)}',
      );
      expect(
        trStatusLine(t(<String, dynamic>{'status': 2, 'recheckProgress': 0.5})),
        'Verifying local data (50.0% tested)',
      );
      expect(trStatusLine(t(<String, dynamic>{'status': 0})), 'Paused');
      expect(
        trStatusLine(
          t(<String, dynamic>{'error': 2, 'errorString': 'Tracker gone'}),
        ),
        'Tracker gone',
      );
    });

    test('compact lines', () {
      expect(
        trCompactLine(t(<String, dynamic>{'rateDownload': 0, 'rateUpload': 0})),
        'Idle',
      );
      expect(
        trCompactLine(t(<String, dynamic>{'status': 6})),
        'Ratio: 0.20 - ↑ ${trFmtRate(51200)}',
      );
    });
  });

  group('info strings', () {
    final TransmissionTorrent tor = t(<String, dynamic>{});
    final TransmissionDetail d =
        TransmissionDetail.fromTorrentJson(detailJson());

    test('have, availability, uploaded, downloaded', () {
      expect(
        trHaveLine(tor, d),
        '${trFmtBytes(900000000)} of ${trFmtBytes(4000000000)} (25.0%), '
        '${trFmtBytes(100000000)} Unverified',
      );
      expect(trAvailability(tor, d), '100%');
      expect(
        trUploadedLine(tor, d),
        '${trFmtBytes(200000000)} (Ratio: 0.05)',
      );
      expect(
        trDownloadedLine(d),
        '${trFmtBytes(1050000000)} (+${trFmtBytes(50000000)} discarded '
        'after failed checksum)',
      );
    });

    test('running time, remaining, last activity', () {
      expect(trRunningTime(tor, d, now: 1758303000 + 3600), '1 hour');
      expect(
        trRunningTime(
          t(<String, dynamic>{'status': 0}),
          d,
          now: 1758303000 + 3600,
        ),
        'Paused',
      );
      expect(trRemaining(tor), '15 minutes');
      expect(trRemaining(t(<String, dynamic>{'eta': -2})), 'Unknown');
      expect(trLastActivity(tor, now: 1758303602), 'Active now');
      expect(trLastActivity(tor, now: 1758303600 + 120), '2 minutes ago');
      expect(
        trLastActivity(t(<String, dynamic>{'activityDate': 0}), now: 1),
        'None',
      );
    });

    test('size, privacy, origin', () {
      expect(
        trSizeLine(tor, d),
        '${trFmtBytes(4000000000)} (1000 pieces @ ${trFmtBytes(4000000)})',
      );
      expect(trPrivacy(d), 'Public torrent');
      expect(
        trPrivacy(d.copyWith(isPrivate: true)),
        'Private to this tracker -- DHT and PEX disabled',
      );
      expect(
        trOrigin(d),
        'Created by mktorrent 1.1 on ${trTimestamp(1758200000)}',
      );
      expect(trOrigin(d.copyWith(dateCreated: 0)), 'Created by mktorrent 1.1');
      expect(trOrigin(d.copyWith(creator: '', dateCreated: 0)), 'Unknown');
    });

    test('tracker state, last announce and last scrape', () {
      final TransmissionTracker tr = d.trackers.single;
      expect(
        trAnnounceState(tr, now: 1758304800 - 600),
        'Next announce in 10 minutes',
      );
      expect(
        trAnnounceState(tr.copyWith(announceState: 3), now: 0),
        'Announce in progress',
      );
      expect(
        trAnnounceState(tr.copyWith(announceState: 2), now: 0),
        'Announce is queued',
      );
      expect(
        trAnnounceState(tr.copyWith(announceState: 0, isBackup: true), now: 0),
        'Tracker will be used as a backup',
      );
      expect(
        trLastAnnounce(tr),
        ('Last announce', '${trTimestamp(1758303000)} (got 40 peers)'),
      );
      expect(
        trLastAnnounce(
          tr.copyWith(
            lastAnnounceSucceeded: false,
            lastAnnounceResult: 'Timed out',
          ),
        ),
        ('Announce error', 'Timed out - ${trTimestamp(1758303000)}'),
      );
      expect(
        trLastAnnounce(tr.copyWith(hasAnnounced: false)),
        ('Last announce', 'N/A'),
      );
      expect(trLastScrape(tr), ('Last scrape', trTimestamp(1758302000)));
    });
  });
}
