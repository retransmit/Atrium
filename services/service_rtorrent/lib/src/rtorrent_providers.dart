import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:meta/meta.dart';

import 'models/rtorrent_detail.dart';
import 'models/rtorrent_torrent.dart';
import 'rtorrent_api.dart';

/// How often the torrent list and global counters refresh while an rTorrent
/// screen is visible.
const Duration rtorrentListPollInterval = Duration(seconds: 3);

/// Per-torrent files, trackers and peers move far more slowly.
const Duration rtorrentSlowPollInterval = Duration(seconds: 10);

/// A [RtorrentApi] for an instance, over the shared `instanceDioProvider`.
///
/// rTorrent has no session to keep, so this holds no state - any HTTP Basic
/// credentials are attached by the shared [AuthInterceptor], and omitted
/// entirely when none are configured.
final rtorrentApiProvider = FutureProvider.family<RtorrentApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final Dio dio = await ref.watch(instanceDioProvider(instance).future);
  return RtorrentApi(dio);
});

/// Which torrents the list is narrowed to.
@immutable
class RtorrentFilter {
  const RtorrentFilter({this.status, this.label = ''});

  /// Null means every status.
  final RtorrentStatus? status;

  /// Empty means every label.
  final String label;

  bool get isActive => status != null || label.isNotEmpty;

  RtorrentFilter copyWith({
    RtorrentStatus? status,
    bool clearStatus = false,
    String? label,
  }) =>
      RtorrentFilter(
        status: clearStatus ? null : (status ?? this.status),
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      other is RtorrentFilter && other.status == status && other.label == label;

  @override
  int get hashCode => Object.hash(status, label);
}

final rtorrentFilterProvider =
    StateProvider.family<RtorrentFilter, Instance>((Ref ref, Instance _) {
  return const RtorrentFilter();
});

/// What the torrent list is ordered by.
enum RtorrentSortField {
  name,
  size,
  progress,
  status,
  downSpeed,
  upSpeed,
  ratio,
  priority,
}

extension RtorrentSortFieldX on RtorrentSortField {
  String get displayName => switch (this) {
        RtorrentSortField.name => 'Name',
        RtorrentSortField.size => 'Size',
        RtorrentSortField.progress => 'Progress',
        RtorrentSortField.status => 'Status',
        RtorrentSortField.downSpeed => 'Down speed',
        RtorrentSortField.upSpeed => 'Up speed',
        RtorrentSortField.ratio => 'Ratio',
        RtorrentSortField.priority => 'Priority',
      };
}

final rtorrentSortFieldProvider =
    StateProvider.family<RtorrentSortField, Instance>((
  Ref ref,
  Instance _,
) {
  return RtorrentSortField.name;
});

final rtorrentSortDescendingProvider =
    StateProvider.family<bool, Instance>((Ref ref, Instance _) => false);

/// Every torrent on the instance, unfiltered. This is the polling provider and
/// the one other features should watch.
///
/// Kept separate from [rtorrentTorrentsProvider] so the dashboard widget and the
/// Activity feed see the whole list instead of inheriting whatever filter the
/// user last chose on the rTorrent screen.
final rtorrentRawTorrentsProvider =
    FutureProvider.autoDispose.family<List<RtorrentTorrent>, Instance>(
  (
    Ref ref,
    Instance instance,
  ) =>
      ref.polled(rtorrentListPollInterval, () async {
    final RtorrentApi api =
        await ref.watch(rtorrentApiProvider(instance).future);
    return api.getTorrents();
  }),
);

/// The list as the rTorrent screen shows it: filtered and sorted. Derives from
/// [rtorrentRawTorrentsProvider] and adds no traffic of its own.
final rtorrentTorrentsProvider =
    FutureProvider.autoDispose.family<List<RtorrentTorrent>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final List<RtorrentTorrent> all =
      await ref.watch(rtorrentRawTorrentsProvider(instance).future);
  final RtorrentFilter filter = ref.watch(rtorrentFilterProvider(instance));
  final RtorrentSortField sort = ref.watch(rtorrentSortFieldProvider(instance));
  final bool descending = ref.watch(rtorrentSortDescendingProvider(instance));
  return sortRtorrentTorrents(
    filterRtorrentTorrents(all, filter),
    sort,
    descending: descending,
  );
});

/// Global counters and limits.
final rtorrentGlobalProvider =
    FutureProvider.autoDispose.family<RtorrentGlobal, Instance>(
  (
    Ref ref,
    Instance instance,
  ) =>
      ref.polled(rtorrentListPollInterval, () async {
    final RtorrentApi api =
        await ref.watch(rtorrentApiProvider(instance).future);
    return api.getGlobal();
  }),
);

/// Files, trackers and peers for one torrent, keyed by instance + hash.
@immutable
class RtorrentDetailArgs {
  const RtorrentDetailArgs(this.instance, this.hash);

  final Instance instance;
  final String hash;

  @override
  bool operator ==(Object other) =>
      other is RtorrentDetailArgs &&
      other.instance == instance &&
      other.hash == hash;

  @override
  int get hashCode => Object.hash(instance, hash);
}

final rtorrentDetailProvider =
    FutureProvider.autoDispose.family<RtorrentDetail, RtorrentDetailArgs>(
  (
    Ref ref,
    RtorrentDetailArgs args,
  ) =>
      ref.polled(rtorrentSlowPollInterval, () async {
    final RtorrentApi api =
        await ref.watch(rtorrentApiProvider(args.instance).future);
    return api.getDetail(args.hash);
  }),
);

/// One torrent out of the polled list, so a detail screen keeps updating
/// without a second round trip.
final rtorrentTorrentProvider =
    FutureProvider.autoDispose.family<RtorrentTorrent?, RtorrentDetailArgs>((
  Ref ref,
  RtorrentDetailArgs args,
) async {
  final List<RtorrentTorrent> all =
      await ref.watch(rtorrentRawTorrentsProvider(args.instance).future);
  for (final RtorrentTorrent t in all) {
    if (t.hash == args.hash) return t;
  }
  return null;
});

/// Narrows a torrent list by status and label.
List<RtorrentTorrent> filterRtorrentTorrents(
  List<RtorrentTorrent> torrents,
  RtorrentFilter filter,
) {
  return torrents
      .where(
        (RtorrentTorrent t) =>
            (filter.status == null || t.status == filter.status) &&
            (filter.label.isEmpty || t.label == filter.label),
      )
      .toList();
}

/// Sorts a torrent list. Pulled out of the provider so it is directly testable.
List<RtorrentTorrent> sortRtorrentTorrents(
  List<RtorrentTorrent> torrents,
  RtorrentSortField field, {
  required bool descending,
}) {
  final List<RtorrentTorrent> out = List<RtorrentTorrent>.of(torrents);
  int compare(RtorrentTorrent a, RtorrentTorrent b) => switch (field) {
        RtorrentSortField.name =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        RtorrentSortField.size => a.sizeBytes.compareTo(b.sizeBytes),
        RtorrentSortField.progress => a.progress.compareTo(b.progress),
        RtorrentSortField.status => a.status.index.compareTo(b.status.index),
        RtorrentSortField.downSpeed => a.downRate.compareTo(b.downRate),
        RtorrentSortField.upSpeed => a.upRate.compareTo(b.upRate),
        RtorrentSortField.ratio => a.ratioPerMille.compareTo(b.ratioPerMille),
        RtorrentSortField.priority => a.priority.compareTo(b.priority),
      };
  out.sort(
    descending
        ? (RtorrentTorrent a, RtorrentTorrent b) => compare(b, a)
        : compare,
  );
  return out;
}

/// The labels present on the instance, for the filter sheet.
///
/// rTorrent has no label registry - ruTorrent just writes a string into
/// `d.custom1` - so the set is whatever the torrents themselves carry.
List<String> rtorrentLabels(List<RtorrentTorrent> torrents) {
  final Set<String> out = <String>{};
  for (final RtorrentTorrent t in torrents) {
    if (t.label.isNotEmpty) out.add(t.label);
  }
  final List<String> sorted = out.toList()
    ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return sorted;
}
