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

/// Which torrents the list is narrowed to.
@immutable
class TransmissionFilter {
  const TransmissionFilter({this.status, this.label = ''});

  /// Null means every status.
  final TransmissionStatus? status;

  /// Empty means every label.
  final String label;

  bool get isActive => status != null || label.isNotEmpty;

  TransmissionFilter copyWith({
    TransmissionStatus? status,
    bool clearStatus = false,
    String? label,
  }) =>
      TransmissionFilter(
        status: clearStatus ? null : (status ?? this.status),
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      other is TransmissionFilter &&
      other.status == status &&
      other.label == label;

  @override
  int get hashCode => Object.hash(status, label);
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
) async {
  ref.pollEvery(transmissionListPollInterval);
  final TransmissionApi api =
      await ref.watch(transmissionApiProvider(instance).future);
  return api.getTorrents();
});

/// The list as the Transmission screen shows it: filtered and sorted. Derives
/// from [transmissionRawTorrentsProvider] and adds no traffic of its own.
final transmissionTorrentsProvider =
    FutureProvider.autoDispose.family<List<TransmissionTorrent>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final List<TransmissionTorrent> all =
      await ref.watch(transmissionRawTorrentsProvider(instance).future);
  final TransmissionFilter filter =
      ref.watch(transmissionFilterProvider(instance));
  final TransmissionSortField sort =
      ref.watch(transmissionSortFieldProvider(instance));
  final bool descending =
      ref.watch(transmissionSortDescendingProvider(instance));
  return sortTransmissionTorrents(
    filterTransmissionTorrents(all, filter),
    sort,
    descending: descending,
  );
});

/// Narrows a torrent list by status and label.
List<TransmissionTorrent> filterTransmissionTorrents(
  List<TransmissionTorrent> torrents,
  TransmissionFilter filter,
) {
  return torrents
      .where(
        (TransmissionTorrent t) =>
            (filter.status == null || t.status == filter.status) &&
            (filter.label.isEmpty || t.labels.contains(filter.label)),
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

/// Session settings: bandwidth limits, turtle mode, download dir, free space.
final transmissionSessionProvider =
    FutureProvider.autoDispose.family<TransmissionSession, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(transmissionSlowPollInterval);
  final TransmissionApi api =
      await ref.watch(transmissionApiProvider(instance).future);
  return api.getSession();
});

/// Live session speeds and counts.
final transmissionSessionStatsProvider =
    FutureProvider.autoDispose.family<TransmissionSessionStats, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(transmissionListPollInterval);
  final TransmissionApi api =
      await ref.watch(transmissionApiProvider(instance).future);
  return api.getSessionStats();
});

/// Identifies one torrent on one instance, keyed by **infohash** rather than
/// the numeric id, which Transmission reassigns when the daemon restarts.
typedef TransmissionTorrentRef = (Instance instance, String hashString);

/// Files, peers and trackers for one torrent.
final transmissionDetailProvider = FutureProvider.autoDispose
    .family<TransmissionDetail, TransmissionTorrentRef>((
  Ref ref,
  TransmissionTorrentRef key,
) async {
  ref.pollEvery(transmissionSlowPollInterval);
  final TransmissionApi api =
      await ref.watch(transmissionApiProvider(key.$1).future);
  return api.getDetail(key.$2);
});
