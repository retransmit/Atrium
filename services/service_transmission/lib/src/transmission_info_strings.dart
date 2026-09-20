import 'models/transmission_detail.dart';
import 'models/transmission_torrent.dart';
import 'transmission_format.dart';

// The Info tab's strings, each worded as the web UI's inspector words it.

String trHaveLine(TransmissionTorrent t, TransmissionDetail d) {
  if (t.leftUntilDone < 1 && d.haveUnchecked == 0) {
    return '${trFmtBytes(d.haveValid)} (100%)';
  }
  final double fraction = t.sizeWhenDone == 0
      ? 1
      : (t.sizeWhenDone - t.leftUntilDone) / t.sizeWhenDone;
  final String base =
      '${trFmtBytes(d.haveValid)} of ${trFmtBytes(t.sizeWhenDone)} '
      '(${trPct(fraction)}%)';
  return d.haveUnchecked > 0
      ? '$base, ${trFmtBytes(d.haveUnchecked)} Unverified'
      : base;
}

String trAvailability(TransmissionTorrent t, TransmissionDetail d) {
  if (t.sizeWhenDone == 0) return 'None';
  final int available = d.haveValid + d.haveUnchecked + d.desiredAvailable;
  return '${trPct(available / t.sizeWhenDone)}%';
}

String trUploadedLine(TransmissionTorrent t, TransmissionDetail d) {
  final int denominator = t.sizeWhenDone > 0 ? t.sizeWhenDone : d.haveValid;
  final double ratio = denominator == 0 ? -1 : t.uploadedEver / denominator;
  return '${trFmtBytes(t.uploadedEver)} (Ratio: ${trRatioString(ratio)})';
}

String trDownloadedLine(TransmissionDetail d) => d.corruptEver > 0
    ? '${trFmtBytes(d.downloadedEver)} (+${trFmtBytes(d.corruptEver)} '
        'discarded after failed checksum)'
    : trFmtBytes(d.downloadedEver);

String trRunningTime(
  TransmissionTorrent t,
  TransmissionDetail d, {
  required int now,
}) {
  if (t.status.isStopped || d.startDate <= 0) return t.stateString;
  return trTimeInterval(now - d.startDate);
}

String trRemaining(TransmissionTorrent t) =>
    t.eta < 0 ? 'Unknown' : trTimeInterval(t.eta);

String trLastActivity(TransmissionTorrent t, {required int now}) {
  if (t.activityDate <= 0 || t.activityDate > now) return 'None';
  final int idle = now - t.activityDate;
  return idle < 5 ? 'Active now' : '${trTimeInterval(idle)} ago';
}

String trSizeLine(TransmissionTorrent t, TransmissionDetail d) =>
    '${trFmtBytes(t.totalSize)} (${d.pieceCount} pieces @ '
    '${trFmtBytes(d.pieceSize)})';

String trPrivacy(TransmissionDetail d) => d.isPrivate
    ? 'Private to this tracker -- DHT and PEX disabled'
    : 'Public torrent';

String trOrigin(TransmissionDetail d) {
  final bool hasCreator = d.creator.isNotEmpty;
  final bool hasDate = d.dateCreated > 0;
  if (!hasCreator && !hasDate) return 'Unknown';
  if (!hasDate) return 'Created by ${d.creator}';
  if (!hasCreator) return 'Created on ${trTimestamp(d.dateCreated)}';
  return 'Created by ${d.creator} on ${trTimestamp(d.dateCreated)}';
}

/// From the inspector's `getAnnounceState`: 0 inactive, 1 waiting, 2 queued,
/// 3 active.
String trAnnounceState(TransmissionTracker tr, {required int now}) =>
    switch (tr.announceState) {
      3 => 'Announce in progress',
      1 => 'Next announce in '
          '${trTimeInterval((tr.nextAnnounceTime - now).clamp(0, 1 << 31))}',
      2 => 'Announce is queued',
      0 => tr.isBackup
          ? 'Tracker will be used as a backup'
          : 'Announce not scheduled',
      _ => 'Unknown announce state: ${tr.announceState}',
    };

/// A label and its value, since a failed announce changes the label too.
(String, String) trLastAnnounce(TransmissionTracker tr) {
  if (!tr.hasAnnounced) return ('Last announce', 'N/A');
  final String when = trTimestamp(tr.lastAnnounceTime);
  if (tr.lastAnnounceSucceeded) {
    return (
      'Last announce',
      '$when (got ${trCount(tr.lastAnnouncePeerCount, 'peer', 'peers')})',
    );
  }
  final String why =
      tr.lastAnnounceResult.isEmpty ? '' : '${tr.lastAnnounceResult} - ';
  return ('Announce error', '$why$when');
}

(String, String) trLastScrape(TransmissionTracker tr) {
  if (!tr.hasScraped) return ('Last scrape', 'N/A');
  final String when = trTimestamp(tr.lastScrapeTime);
  if (tr.lastScrapeSucceeded) return ('Last scrape', when);
  final String why =
      tr.lastScrapeResult.isEmpty ? '' : '${tr.lastScrapeResult} - ';
  return ('Scrape error', '$why$when');
}
