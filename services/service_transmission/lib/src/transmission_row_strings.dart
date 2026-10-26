import 'models/transmission_torrent.dart';
import 'transmission_format.dart';

/// What a row's progress bar tracks: metadata while a magnet is still fetching
/// it, the recheck while verifying, and the download completion percentage.
double trBarValue(TransmissionTorrent t) {
  if (t.needsMetadata) {
    return t.metadataPercentComplete.clamp(0, 1).toDouble();
  }
  if (t.status == TransmissionStatus.checking) {
    return t.recheckProgress.clamp(0, 1).toDouble();
  }
  return t.percentDone.clamp(0, 1).toDouble();
}

/// The one line a compact row gets, from `TorrentRendererCompact`.
String trCompactLine(TransmissionTorrent t) {
  if (t.hasError) return t.errorString;
  if (t.status.isDownloading) {
    final bool down = t.downloadRate > 0;
    final bool up = t.uploadRate > 0;
    if (!down && !up) return 'Idle';
    return <String>[
      if (t.hasEta) trTimeInterval(t.eta),
      if (down) '↓ ${trFmtRate(t.downloadRate)}',
      if (up) '↑ ${trFmtRate(t.uploadRate)}',
    ].join(' ');
  }
  if (t.status.isSeeding) {
    return 'Ratio: ${trRatioString(t.uploadRatio)} - '
        '↑ ${trFmtRate(t.uploadRate)}';
  }
  return t.stateString;
}
