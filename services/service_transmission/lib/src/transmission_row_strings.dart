import 'models/transmission_torrent.dart';
import 'transmission_format.dart';

/// What a row's progress bar tracks, from the web UI's `getProgressInfo`:
/// metadata while a magnet is still fetching it, the recheck while verifying,
/// the download until it is done, and the share ratio toward 1.0 after.
double trBarValue(TransmissionTorrent t) {
  if (t.needsMetadata) {
    return t.metadataPercentComplete.clamp(0, 1).toDouble();
  }
  if (t.status == TransmissionStatus.checking) {
    return t.recheckProgress.clamp(0, 1).toDouble();
  }
  if (t.leftUntilDone > 0) return t.percentDone.clamp(0, 1).toDouble();
  return t.ratio.clamp(0, 1).toDouble();
}

/// The line under the bar, from `renderProgressDetails`.
String trProgressLine(TransmissionTorrent t) {
  if (t.needsMetadata) {
    final String state = t.status.isStopped ? 'needs' : 'retrieving';
    return 'Magnetized transfer - $state metadata '
        '(${trPct(t.metadataPercentComplete)}%)';
  }
  final bool done = t.isDone || t.status.isSeeding;
  final StringBuffer s = StringBuffer();
  if (done) {
    if (t.totalSize == t.sizeWhenDone) {
      s.write(trFmtBytes(t.totalSize));
    } else {
      s.write(
        '${trFmtBytes(t.sizeWhenDone)} of ${trFmtBytes(t.totalSize)} '
        '(${trPct(t.percentDone)}%)',
      );
    }
    s.write(
      ', uploaded ${trFmtBytes(t.uploadedEver)} '
      '(Ratio: ${trRatioString(t.uploadRatio)})',
    );
  } else {
    s.write(
      '${trFmtBytes(t.doneBytes)} of ${trFmtBytes(t.sizeWhenDone)} '
      '(${trPct(t.percentDone)}%)',
    );
  }
  if (!t.status.isStopped && !done) {
    s.write(' - ');
    // 999 hours is the web UI's own line for "not worth showing".
    if (t.eta < 0 || t.eta >= 999 * 3600) {
      s.write('remaining time unknown');
    } else {
      s.write('${trTimeInterval(t.eta)} remaining');
    }
  }
  return s.toString();
}

/// The status line, from `renderPeerDetails`.
String trStatusLine(TransmissionTorrent t) {
  if (t.hasError) return t.errorString;
  if (t.status.isDownloading) {
    final List<String> s = <String>['Downloading from'];
    if (t.peersConnected > 0) {
      s.addAll(<String>[
        '${t.peersSendingToUs}',
        'of',
        trCount(t.peersConnected, 'peer', 'peers'),
      ]);
      if (t.webseedsSendingToUs > 0) s.add('and');
    }
    if (t.webseedsSendingToUs > 0) {
      s.add(trCount(t.webseedsSendingToUs, 'web seed', 'web seeds'));
    }
    s.addAll(<String>[
      '-',
      '↓',
      trFmtRate(t.downloadRate),
      '↑',
      trFmtRate(t.uploadRate),
    ]);
    return s.join(' ');
  }
  if (t.status.isSeeding) {
    return 'Seeding to ${t.peersGettingFromUs} of '
        '${trCount(t.peersConnected, 'peer', 'peers')} - '
        '↑ ${trFmtRate(t.uploadRate)}';
  }
  if (t.status == TransmissionStatus.checking) {
    return 'Verifying local data (${trPct(t.recheckProgress)}% tested)';
  }
  return t.stateString;
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
