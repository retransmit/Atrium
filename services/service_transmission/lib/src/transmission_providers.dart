import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:meta/meta.dart';

import 'models/transmission_detail.dart';
import 'models/transmission_session.dart';
import 'models/transmission_torrent.dart';
import 'transmission_api.dart';

/// How often the torrent list and session counters refresh while a Transmission
/// screen is visible.
const Duration transmissionListPollInterval = Duration(seconds: 3);

/// Session settings and per-torrent detail move far more slowly.
const Duration transmissionSlowPollInterval = Duration(seconds: 10);

/// A [TransmissionApi] for an instance, over the shared `instanceDioProvider`.
///
/// Unlike the cookie-based clients, Transmission needs no Dio of its own: its
/// only auth is HTTP Basic, which the shared [AuthInterceptor] attaches (and
/// omits entirely when no credentials are configured). The CSRF token lives in
/// the client instance, which is why this is NOT autoDispose - throwing the
/// client away would mean re-learning the token on the next screen visit.
final transmissionApiProvider =
    FutureProvider.family<TransmissionApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final Dio dio = await ref.watch(instanceDioProvider(instance).future);
  return TransmissionApi(dio);
});

/// The web UI's filter modes, in its order, with its definitions.
enum TransmissionFilterMode {
  all('All'),
  active('Active'),
  downloading('Downloading'),
  seeding('Seeding'),
  paused('Paused'),
  finished('Finished'),
  error('Error'),
  private('Private'),
  public('Public');

  const TransmissionFilterMode(this.label);

  final String label;

  bool matches(TransmissionTorrent t) => switch (this) {
        TransmissionFilterMode.all => true,
        // Moving bytes with anyone, or busy verifying.
        TransmissionFilterMode.active => t.peersGettingFromUs > 0 ||
            t.peersSendingToUs > 0 ||
            t.webseedsSendingToUs > 0 ||
            t.status == TransmissionStatus.checking,
        TransmissionFilterMode.downloading =>
          t.status == TransmissionStatus.downloading ||
              t.status == TransmissionStatus.downloadWait,
        TransmissionFilterMode.seeding =>
          t.status == TransmissionStatus.seeding ||
              t.status == TransmissionStatus.seedWait,
        TransmissionFilterMode.paused => t.status.isStopped,
        TransmissionFilterMode.finished => t.isFinished,
        TransmissionFilterMode.error => t.error != 0,
        TransmissionFilterMode.private => t.isPrivate,
        TransmissionFilterMode.public => !t.isPrivate,
      };
}

/// Which torrents the list is narrowed to. Everything combines with AND.
@immutable
class TransmissionFilter {
  const TransmissionFilter({
    this.mode = TransmissionFilterMode.all,
    this.tracker = '',
    this.label = '',
  });

  final TransmissionFilterMode mode;

  /// A tracker host from [transmissionTrackers]; empty means any.
  final String tracker;

  /// Empty means every label.
  final String label;

  bool get isActive =>
      mode != TransmissionFilterMode.all ||
      tracker.isNotEmpty ||
      label.isNotEmpty;

  TransmissionFilter copyWith({
    TransmissionFilterMode? mode,
    String? tracker,
    String? label,
  }) =>
      TransmissionFilter(
        mode: mode ?? this.mode,
        tracker: tracker ?? this.tracker,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      other is TransmissionFilter &&
      other.mode == mode &&
      other.tracker == tracker &&
      other.label == label;

  @override
  int get hashCode => Object.hash(mode, tracker, label);
}

final transmissionFilterProvider =
    StateProvider.family<TransmissionFilter, Instance>((Ref ref, Instance _) {
  return const TransmissionFilter();
});

/// What the torrent list is ordered by.
enum TransmissionSortField {
  queue,
  name,
  size,
  progress,
  status,
  downSpeed,
  upSpeed,
  ratio,
  added,
  activity,
}

extension TransmissionSortFieldX on TransmissionSortField {
  String get displayName => switch (this) {
        TransmissionSortField.queue => 'Queue position',
        TransmissionSortField.name => 'Name',
        TransmissionSortField.size => 'Size',
        TransmissionSortField.progress => 'Progress',
        TransmissionSortField.status => 'Status',
        TransmissionSortField.downSpeed => 'Down speed',
        TransmissionSortField.upSpeed => 'Up speed',
        TransmissionSortField.ratio => 'Ratio',
        TransmissionSortField.added => 'Date added',
        TransmissionSortField.activity => 'Last activity',
      };
}

final transmissionSortFieldProvider =
    StateProvider.family<TransmissionSortField, Instance>((
  Ref ref,
  Instance _,
) {
  return TransmissionSortField.queue;
});

final transmissionSortDescendingProvider =
    StateProvider.family<bool, Instance>((Ref ref, Instance _) => false);

/// Which of the home's tabs is showing: 0 Torrents, 1 Settings.
final transmissionTabProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance _) => 0);

/// The search box's text. Matches names and labels.
final transmissionSearchProvider =
    StateProvider.family<String, Instance>((Ref ref, Instance _) => '');

/// Compact rows, the web UI's toggle. Kept for the session like the sort.
final transmissionCompactProvider =
    StateProvider.family<bool, Instance>((Ref ref, Instance _) => false);

/// Hashes of the rows the user long-pressed into a selection. Non-empty is
/// selection mode. autoDispose so leaving the screen clears it.
final transmissionSelectionProvider =
    StateProvider.autoDispose.family<Set<String>, Instance>(
  (Ref ref, Instance _) => <String>{},
);

/// Free bytes at a folder on the daemon's host, or null when it cannot tell.
final transmissionFreeSpaceProvider =
    FutureProvider.autoDispose.family<int?, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final TransmissionApi api =
      await ref.watch(transmissionApiProvider(key.$1).future);
  return api.freeSpace(key.$2);
});

/// Every torrent on the instance, unfiltered. This is the polling provider and
/// the one other features should watch.
///
/// Kept separate from [transmissionTorrentsProvider] so the dashboard widget and
/// the Activity feed see the whole list instead of inheriting whatever filter
/// the user last chose on the Transmission screen.
final transmissionRawTorrentsProvider =
    FutureProvider.autoDispose.family<List<TransmissionTorrent>, Instance>((
  Ref ref,
  Instance instance,
) => ref.polled(transmissionListPollInterval, () async {
    final TransmissionApi api =
        await ref.watch(transmissionApiProvider(instance).future);
    return api.getTorrents();
    },
  ),
);

/// The list as the Transmission screen shows it: filtered and sorted. Derives
/// from [transmissionRawTorrentsProvider] and adds no traffic of its own.
final transmissionTorrentsProvider =
    FutureProvider.autoDispose.family<List<TransmissionTorrent>, Instance>((
  Ref ref,
  Instance instance,
) async {
  // Every synchronous dependency is watched before the await: a Ref must not
  // be used after an async gap once the provider has been disposed, which
  // happens whenever the list refreshes with nobody listening yet.
  final TransmissionFilter filter =
      ref.watch(transmissionFilterProvider(instance));
  final TransmissionSortField sort =
      ref.watch(transmissionSortFieldProvider(instance));
  final bool descending =
      ref.watch(transmissionSortDescendingProvider(instance));
  final String search = ref.watch(transmissionSearchProvider(instance));
  final List<TransmissionTorrent> all =
      await ref.watch(transmissionRawTorrentsProvider(instance).future);
  return sortTransmissionTorrents(
    filterTransmissionTorrents(all, filter, search: search),
    sort,
    descending: descending,
  );
});

/// Narrows a torrent list by mode, tracker, label and search text, the way
/// the web UI's `Torrent.test()` combines its filters.
List<TransmissionTorrent> filterTransmissionTorrents(
  List<TransmissionTorrent> torrents,
  TransmissionFilter filter, {
  String search = '',
}) {
  final String needle = search.trim().toLowerCase();
  return torrents
      .where(
        (TransmissionTorrent t) =>
            filter.mode.matches(t) &&
            (filter.tracker.isEmpty ||
                t.trackerHosts.contains(filter.tracker)) &&
            (filter.label.isEmpty || t.labels.contains(filter.label)) &&
            (needle.isEmpty ||
                t.name.toLowerCase().contains(needle) ||
                t.labels.any((String l) => l.toLowerCase().contains(needle))),
      )
      .toList();
}

/// Sorts a torrent list. Pulled out of the provider so it is directly testable.
///
/// Unqueued torrents report a negative [TransmissionTorrent.queuePosition], so
/// they are pushed to the end of a queue sort rather than ranking above
/// position 0.
List<TransmissionTorrent> sortTransmissionTorrents(
  List<TransmissionTorrent> torrents,
  TransmissionSortField field, {
  required bool descending,
}) {
  final List<TransmissionTorrent> out = List<TransmissionTorrent>.of(torrents);
  int compare(TransmissionTorrent a, TransmissionTorrent b) => switch (field) {
        TransmissionSortField.queue =>
          _queueRank(a).compareTo(_queueRank(b)),
        TransmissionSortField.name =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        TransmissionSortField.size =>
          a.sizeWhenDone.compareTo(b.sizeWhenDone),
        TransmissionSortField.progress =>
          a.percentDone.compareTo(b.percentDone),
        TransmissionSortField.status =>
          a.statusCode.compareTo(b.statusCode),
        TransmissionSortField.downSpeed =>
          a.downloadRate.compareTo(b.downloadRate),
        TransmissionSortField.upSpeed =>
          a.uploadRate.compareTo(b.uploadRate),
        TransmissionSortField.ratio => a.ratio.compareTo(b.ratio),
        TransmissionSortField.added => a.addedDate.compareTo(b.addedDate),
        // Most recent first is the natural order, as the web UI has it; the
        // direction toggle inverts it like any other field.
        TransmissionSortField.activity =>
          b.activityDate.compareTo(a.activityDate),
      };
  out.sort(
    descending
        ? (TransmissionTorrent a, TransmissionTorrent b) => compare(b, a)
        : compare,
  );
  return out;
}

int _queueRank(TransmissionTorrent t) =>
    t.queuePosition < 0 ? 1 << 30 : t.queuePosition;

/// The labels currently in use, for the filter row. Transmission has no
/// filter-tree call, so this is derived from the list itself - which also means
/// a label with no torrents simply is not offered.
List<String> transmissionLabels(List<TransmissionTorrent> torrents) {
  final Set<String> labels = <String>{};
  for (final TransmissionTorrent t in torrents) {
    labels.addAll(t.labels);
  }
  final List<String> out = labels.toList()..sort();
  return out;
}

/// The tracker hosts in use, for the filter row, derived like the labels.
List<String> transmissionTrackers(List<TransmissionTorrent> torrents) {
  final Set<String> hosts = <String>{};
  for (final TransmissionTorrent t in torrents) {
    hosts.addAll(t.trackerHosts);
  }
  final List<String> out = hosts.toList()..sort();
  return out;
}

/// Session settings: bandwidth limits, turtle mode, download dir, free space.
final transmissionSessionProvider =
    FutureProvider.autoDispose.family<TransmissionSession, Instance>((
  Ref ref,
  Instance instance,
) => ref.polled(transmissionSlowPollInterval, () async {
    final TransmissionApi api =
        await ref.watch(transmissionApiProvider(instance).future);
    return api.getSession();
    },
  ),
);

/// Live session speeds and counts.
final transmissionSessionStatsProvider =
    FutureProvider.autoDispose.family<TransmissionSessionStats, Instance>((
  Ref ref,
  Instance instance,
) => ref.polled(transmissionListPollInterval, () async {
    final TransmissionApi api =
        await ref.watch(transmissionApiProvider(instance).future);
    return api.getSessionStats();
    },
  ),
);

/// Identifies one torrent on one instance, keyed by **infohash** rather than
/// the numeric id, which Transmission reassigns when the daemon restarts.
typedef TransmissionTorrentRef = (Instance instance, String hashString);

/// Files, peers and trackers for one torrent.
final transmissionDetailProvider = FutureProvider.autoDispose
    .family<TransmissionDetail, TransmissionTorrentRef>((
  Ref ref,
  TransmissionTorrentRef key,
) => ref.polled(transmissionSlowPollInterval, () async {
    final TransmissionApi api =
        await ref.watch(transmissionApiProvider(key.$1).future);
    return api.getDetail(key.$2);
    },
  ),
);
