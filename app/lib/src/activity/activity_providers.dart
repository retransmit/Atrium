import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:service_emby/service_emby.dart' as emby;
import 'package:service_jellyfin/service_jellyfin.dart' as jf;
import 'package:service_plex/service_plex.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sabnzbd/service_sabnzbd.dart';
import 'package:service_sonarr/service_sonarr.dart';
import 'package:service_tautulli/service_tautulli.dart';

/// One active playback session, normalized across Plex / Jellyfin / Emby /
/// Tautulli for the cross-service Activity feed (and future dashboard
/// widgets).
class ActivityStream {
  const ActivityStream({
    required this.key,
    required this.instance,
    required this.sourceKind,
    required this.title,
    required this.progress,
    required this.paused,
    this.subtitle,
    this.userName,
    this.userAvatarUrl,
    this.imageUrl,
    this.detailChip,
    this.onOpenBuilder,
  });

  /// Stable identity across polls: `<instanceId>:<sessionId>`.
  final String key;
  final Instance instance;
  final ServiceKind sourceKind;
  final String title;

  /// Episode label / device line.
  final String? subtitle;
  final String? userName;
  final String? userAvatarUrl;

  /// Backdrop preferred, poster fallback.
  final String? imageUrl;

  /// Playback progress, 0-1.
  final double progress;
  final bool paused;

  /// e.g. 'Direct Play' / 'Transcode'.
  final String? detailChip;

  /// Screen to push on tap; null means the tap opens the service screen.
  final Widget Function(BuildContext)? onOpenBuilder;
}

/// One in-flight download, normalized across qBittorrent / SABnzbd / Sonarr /
/// Radarr queues.
class ActivityDownload {
  const ActivityDownload({
    required this.key,
    required this.instance,
    required this.sourceKind,
    required this.title,
    required this.progress,
    required this.status,
    this.speedBps,
    this.upSpeedBps,
    this.eta,
  });

  /// Stable identity across polls: `<instanceId>:<id/hash/nzoId>`.
  final String key;
  final Instance instance;
  final ServiceKind sourceKind;
  final String title;

  /// Completion, 0-1.
  final double progress;
  final int? speedBps;

  /// Upload rate, bytes/s. Non-null only while actively seeding
  /// (qBittorrent); usenet clients never set it.
  final int? upSpeedBps;
  final String? eta;

  /// Short status label ('Downloading', 'Queued', 'Importing', ...).
  final String status;
}

/// A source instance whose feed could not be fetched at all (no cached data).
class ActivitySourceError {
  const ActivitySourceError(this.instance);
  final Instance instance;
}

typedef ActivityStreamsState = ({
  List<ActivityStream> streams,
  List<ActivitySourceError> errors,
  bool anyLoading,
});

typedef ActivityDownloadsState = ({
  List<ActivityDownload> downloads,
  List<ActivitySourceError> errors,
  bool anyLoading,
});

typedef ActivitySummary = ({
  int streamCount,
  int downloadCount,
  int totalDlBps,
  int totalUpBps,
});

/// Active streams across every media-server / Tautulli instance of the
/// active profile. Watching this keeps each source's own poll alive; a
/// source that errors without cached data becomes an error entry instead of
/// blocking the healthy ones.
final activityStreamsProvider =
    Provider.autoDispose<ActivityStreamsState>((Ref ref) {
  final List<Instance> instances = ref.watch(activeInstancesProvider);
  final List<ActivityStream> streams = <ActivityStream>[];
  final List<ActivitySourceError> errors = <ActivitySourceError>[];
  bool anyLoading = false;

  void collect<T>(
    Instance instance,
    AsyncValue<T> value,
    List<ActivityStream> Function(T data) map,
  ) {
    final T? data = value.value;
    if (data != null) {
      streams.addAll(map(data));
    } else if (value.hasError) {
      errors.add(ActivitySourceError(instance));
    } else {
      anyLoading = true;
    }
  }

  for (final Instance instance in instances) {
    switch (instance.kind) {
      case ServiceKind.plex:
        collect(
          instance,
          ref.watch(plexSessionsProvider(instance)),
          (List<PlexSession> sessions) => _plexStreams(ref, instance, sessions),
        );
      case ServiceKind.jellyfin:
        collect(
          instance,
          ref.watch(jf.jellyfinFastSessionsProvider(instance)),
          (List<jf.ActiveSession> sessions) =>
              _jellyfinStreams(instance, sessions),
        );
      case ServiceKind.emby:
        collect(
          instance,
          ref.watch(emby.embyFastSessionsProvider(instance)),
          (List<emby.ActiveSession> sessions) =>
              _embyStreams(instance, sessions),
        );
      case ServiceKind.tautulli:
        collect(
          instance,
          ref.watch(tautulliActivityProvider(instance)),
          (TautulliActivity activity) =>
              _tautulliStreams(ref, instance, activity),
        );
      default:
        break;
    }
  }

  return (streams: streams, errors: errors, anyLoading: anyLoading);
});

/// Active downloads across every download-client / *arr queue of the active
/// profile, with the same per-instance resilience as the streams feed.
final activityDownloadsProvider =
    Provider.autoDispose<ActivityDownloadsState>((Ref ref) {
  final List<Instance> instances = ref.watch(activeInstancesProvider);
  final List<ActivityDownload> downloads = <ActivityDownload>[];
  final List<ActivitySourceError> errors = <ActivitySourceError>[];
  bool anyLoading = false;

  void collect<T>(
    Instance instance,
    AsyncValue<T> value,
    List<ActivityDownload> Function(T data) map,
  ) {
    final T? data = value.value;
    if (data != null) {
      downloads.addAll(map(data));
    } else if (value.hasError) {
      errors.add(ActivitySourceError(instance));
    } else {
      anyLoading = true;
    }
  }

  for (final Instance instance in instances) {
    switch (instance.kind) {
      case ServiceKind.qbittorrent:
        collect(
          instance,
          ref.watch(qbitTorrentsProvider(instance)),
          (List<QbitTorrent> torrents) => _qbitDownloads(instance, torrents),
        );
      case ServiceKind.sabnzbd:
        collect(
          instance,
          ref.watch(sabQueueProvider(instance)),
          (SabQueue queue) => _sabDownloads(instance, queue),
        );
      case ServiceKind.sonarr:
        collect(
          instance,
          ref.watch(sonarrQueueProvider(instance)),
          (List<SonarrQueueItem> items) => _sonarrDownloads(instance, items),
        );
      case ServiceKind.radarr:
        collect(
          instance,
          ref.watch(radarrQueueProvider(instance)),
          (List<RadarrQueueItem> items) => _radarrDownloads(instance, items),
        );
      default:
        break;
    }
  }

  return (downloads: downloads, errors: errors, anyLoading: anyLoading);
});

/// Headline numbers for the Activity summary bar, derived from the two feeds.
/// The byte rate sums qBittorrent download speeds; SABnzbd only reports a
/// display string, so its slots count toward totals but not the rate.
final activitySummaryProvider =
    Provider.autoDispose<ActivitySummary>((Ref ref) {
  final ActivityStreamsState streams = ref.watch(activityStreamsProvider);
  final ActivityDownloadsState downloads = ref.watch(activityDownloadsProvider);
  int totalDlBps = 0;
  int totalUpBps = 0;
  for (final ActivityDownload download in downloads.downloads) {
    totalDlBps += download.speedBps ?? 0;
    totalUpBps += download.upSpeedBps ?? 0;
  }
  return (
    streamCount: streams.streams.length,
    downloadCount: downloads.downloads.length,
    totalDlBps: totalDlBps,
    totalUpBps: totalUpBps,
  );
});

/// Invalidates every per-instance source feeding the Activity feed so a
/// pull-to-refresh forces an immediate refetch. Invalidating the aggregate
/// providers alone would only recompute over the sources' cached values.
void refreshActivity(WidgetRef ref) {
  for (final Instance instance in ref.read(activeInstancesProvider)) {
    switch (instance.kind) {
      case ServiceKind.plex:
        ref.invalidate(plexSessionsProvider(instance));
      case ServiceKind.jellyfin:
        ref.invalidate(jf.jellyfinFastSessionsProvider(instance));
      case ServiceKind.emby:
        ref.invalidate(emby.embyFastSessionsProvider(instance));
      case ServiceKind.tautulli:
        ref.invalidate(tautulliActivityProvider(instance));
      case ServiceKind.qbittorrent:
        ref.invalidate(qbitRawTorrentsProvider(instance));
      case ServiceKind.sabnzbd:
        ref.invalidate(sabQueueProvider(instance));
      case ServiceKind.sonarr:
        ref.invalidate(sonarrQueueProvider(instance));
      case ServiceKind.radarr:
        ref.invalidate(radarrQueueProvider(instance));
      default:
        break;
    }
  }
}

/// '2.5 MB/s' - qBittorrent's shared byte formatter with a rate suffix.
String fmtSpeedBps(num bps) => '${fmtBytes(bps)}/s';

// ---------------------------------------------------------------------------
// Stream mapping

List<ActivityStream> _plexStreams(
  Ref ref,
  Instance instance,
  List<PlexSession> sessions,
) {
  final PlexApi? api = ref.watch(plexApiProvider(instance)).value;
  return <ActivityStream>[
    for (final (int index, PlexSession s) in sessions.indexed)
      ActivityStream(
        key:
            '${instance.id}:${s.sessionId.isEmpty ? 'plex-$index' : s.sessionId}',
        instance: instance,
        sourceKind: instance.kind,
        title: s.grandparentTitle ?? s.title,
        subtitle: _plexSubtitle(s),
        userName: (s.user?.title ?? '').isEmpty ? null : s.user!.title,
        userAvatarUrl: api?.imageUrl(s.user?.thumb),
        imageUrl: api?.imageUrl(s.art ?? s.thumb),
        progress: s.progress,
        paused: s.player?.state == 'paused',
        detailChip: s.decisionLabel,
        onOpenBuilder: (BuildContext _) =>
            PlexSessionDetailScreen(instance: instance, initialSession: s),
      ),
  ];
}

String? _plexSubtitle(PlexSession s) {
  if (s.grandparentTitle != null && s.title.isNotEmpty) {
    return s.title;
  }
  final String player = s.player?.title ?? '';
  return player.isEmpty ? null : player;
}

List<ActivityStream> _jellyfinStreams(
  Instance instance,
  List<jf.ActiveSession> sessions,
) {
  return <ActivityStream>[
    for (final jf.ActiveSession s in sessions)
      ActivityStream(
        key: '${instance.id}:${s.id}',
        instance: instance,
        sourceKind: instance.kind,
        title: s.showTitle,
        subtitle: (s.episodeName ?? '').isNotEmpty
            ? s.episodeName
            : (s.device.isEmpty ? null : s.device),
        userName: s.user.isEmpty ? null : s.user,
        imageUrl: s.backdropUrl ?? s.posterUrl,
        progress: (s.progressPercent / 100).clamp(0.0, 1.0),
        paused: s.status.toLowerCase() == 'paused',
        onOpenBuilder: (BuildContext _) => jf.JellyfinSessionDetailScreen(
          instance: instance,
          initialSession: s,
        ),
      ),
  ];
}

List<ActivityStream> _embyStreams(
  Instance instance,
  List<emby.ActiveSession> sessions,
) {
  return <ActivityStream>[
    for (final emby.ActiveSession s in sessions)
      ActivityStream(
        key: '${instance.id}:${s.id}',
        instance: instance,
        sourceKind: instance.kind,
        title: s.showTitle,
        subtitle: (s.episodeName ?? '').isNotEmpty
            ? s.episodeName
            : (s.device.isEmpty ? null : s.device),
        userName: s.user.isEmpty ? null : s.user,
        imageUrl: s.backdropUrl ?? s.posterUrl,
        progress: (s.progressPercent / 100).clamp(0.0, 1.0),
        paused: s.status.toLowerCase() == 'paused',
        onOpenBuilder: (BuildContext _) => emby.EmbySessionDetailScreen(
          instance: instance,
          initialSession: s,
        ),
      ),
  ];
}

List<ActivityStream> _tautulliStreams(
  Ref ref,
  Instance instance,
  TautulliActivity activity,
) {
  final TautulliApi? api = ref.watch(tautulliApiProvider(instance)).value;
  return <ActivityStream>[
    for (final (int index, TautulliSession s) in activity.sessions.indexed)
      ActivityStream(
        key: '${instance.id}:${_tautulliSessionId(s, index)}',
        instance: instance,
        sourceKind: instance.kind,
        title: s.fullTitle,
        subtitle: s.episodeLabel.isNotEmpty
            ? s.episodeLabel
            : (s.player.isEmpty ? null : s.player),
        userName: s.friendlyName.isEmpty ? null : s.friendlyName,
        userAvatarUrl: api?.imageUrl(s.userThumb, fallback: 'art'),
        imageUrl: api?.imageUrl(s.art, width: 800, fallback: 'art') ??
            api?.imageUrl(s.posterThumb),
        progress: (s.progressPercent / 100).clamp(0.0, 1.0),
        paused: s.state.toLowerCase() == 'paused',
        detailChip: _decisionLabel(s.transcodeDecision),
        // Tautulli exports no session screen; the tap opens the service.
      ),
  ];
}

String _tautulliSessionId(TautulliSession s, int index) {
  if (s.sessionId.isNotEmpty) {
    return s.sessionId;
  }
  return s.sessionKey.isEmpty ? 'tautulli-$index' : s.sessionKey;
}

String? _decisionLabel(String decision) => switch (decision.toLowerCase()) {
      '' => null,
      'direct play' => 'Direct Play',
      'copy' || 'direct stream' => 'Direct Stream',
      'transcode' => 'Transcode',
      _ => decision,
    };

// ---------------------------------------------------------------------------
// Download mapping

List<ActivityDownload> _qbitDownloads(
  Instance instance,
  List<QbitTorrent> torrents,
) {
  return <ActivityDownload>[
    // Active transfers: incomplete torrents plus anything actively moving
    // bytes in either direction. Idle seeds and paused-complete torrents
    // stay out of the feed.
    for (final QbitTorrent t in torrents)
      if (t.progress < 1.0 || t.dlspeed > 0 || t.upspeed > 0)
        ActivityDownload(
          key: '${instance.id}:${t.hash}',
          instance: instance,
          sourceKind: instance.kind,
          title: t.name,
          progress: t.progress.clamp(0.0, 1.0),
          speedBps: t.dlspeed > 0 ? t.dlspeed : null,
          upSpeedBps: t.upspeed > 0 ? t.upspeed : null,
          eta: _fmtEtaSeconds(t.eta),
          status: _qbitStatusLabel(t.state),
        ),
  ];
}

String _qbitStatusLabel(String state) {
  final String s = state.toLowerCase();
  if (s.contains('paused') || s.contains('stopped')) {
    return 'Paused';
  }
  if (s.contains('queued')) {
    return 'Queued';
  }
  if (s.contains('stalled')) {
    return 'Stalled';
  }
  if (s.contains('checking')) {
    return 'Checking';
  }
  if (s.contains('error') || s.contains('missing')) {
    return 'Error';
  }
  if (s.contains('dl') || s == 'downloading') {
    return 'Downloading';
  }
  if (s.contains('up') || s == 'uploading') {
    return 'Seeding';
  }
  return _capitalized(state);
}

/// qBittorrent reports 8640000 seconds when the ETA is unknown.
String? _fmtEtaSeconds(int seconds) {
  if (seconds <= 0 || seconds >= 8640000) {
    return null;
  }
  if (seconds >= 3600) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
  if (seconds >= 60) {
    return '${seconds ~/ 60}m';
  }
  return '${seconds}s';
}

List<ActivityDownload> _sabDownloads(Instance instance, SabQueue queue) {
  return <ActivityDownload>[
    for (final SabSlot slot in queue.slots)
      ActivityDownload(
        key: '${instance.id}:${slot.nzoId}',
        instance: instance,
        sourceKind: instance.kind,
        title: slot.filename,
        progress: ((int.tryParse(slot.percentage) ?? 0) / 100).clamp(0.0, 1.0),
        eta: slot.timeleft.isEmpty ? null : slot.timeleft,
        status: slot.status.isEmpty ? 'Queued' : _capitalized(slot.status),
      ),
  ];
}

List<ActivityDownload> _sonarrDownloads(
  Instance instance,
  List<SonarrQueueItem> items,
) {
  return <ActivityDownload>[
    for (final SonarrQueueItem item in items)
      ActivityDownload(
        key: '${instance.id}:${item.id}',
        instance: instance,
        sourceKind: instance.kind,
        title: (item.title ?? '').isNotEmpty
            ? item.title!
            : (item.series?.title ?? 'Unknown'),
        progress: _sizeProgress(item.size ?? 0, item.sizeleft ?? 0),
        eta: (item.timeleft ?? '').isEmpty ? null : item.timeleft,
        status: _arrStatusLabel(item.status, item.trackedDownloadState),
      ),
  ];
}

List<ActivityDownload> _radarrDownloads(
  Instance instance,
  List<RadarrQueueItem> items,
) {
  return <ActivityDownload>[
    for (final RadarrQueueItem item in items)
      ActivityDownload(
        key: '${instance.id}:${item.id}',
        instance: instance,
        sourceKind: instance.kind,
        title: (item.title ?? '').isEmpty ? 'Unknown' : item.title!,
        progress: _sizeProgress(item.size ?? 0, item.sizeleft ?? 0),
        eta: (item.timeleft ?? '').isEmpty ? null : item.timeleft,
        status: _arrStatusLabel(item.status, item.trackedDownloadState),
      ),
  ];
}

double _sizeProgress(double size, double sizeleft) {
  if (size <= 0) {
    return 0;
  }
  return ((size - sizeleft) / size).clamp(0.0, 1.0);
}

String _arrStatusLabel(String? status, String? trackedState) {
  if ((trackedState ?? '').toLowerCase().contains('import')) {
    return 'Importing';
  }
  return switch ((status ?? '').toLowerCase()) {
    'downloading' => 'Downloading',
    'queued' || 'delay' => 'Queued',
    'paused' => 'Paused',
    // Download client finished; the item is waiting on / being imported.
    'completed' => 'Importing',
    '' => 'Queued',
    _ => _capitalized(status!),
  };
}

String _capitalized(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
