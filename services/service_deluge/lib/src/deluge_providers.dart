import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:meta/meta.dart';

import 'deluge_client.dart';
import 'models/deluge_filter_tree.dart';
import 'models/deluge_session_status.dart';
import 'models/deluge_torrent.dart';
import 'models/deluge_torrent_detail.dart';

/// How often the torrent list and session counters refresh while a Deluge
/// screen is visible. Deluge's own Web UI polls at 2s; 3s is the same mobile
/// compromise the other download clients make.
const Duration delugeListPollInterval = Duration(seconds: 3);

/// Detail data (files, trackers, peers) changes far more slowly.
const Duration delugeDetailPollInterval = Duration(seconds: 10);

/// A logged-in [DelugeClient] for an instance.
///
/// Resolves the LAN/WAN base URL via the shared [ConnectionResolver], then
/// builds a cookie-aware client. Deluge cannot reuse `instanceDioProvider`
/// because its auth is a session cookie rather than a static header the
/// interceptor can attach.
///
/// Deliberately NOT autoDispose: the client holds the Web UI session *and* the
/// daemon attachment, both of which cost a round trip to rebuild.
final delugeClientProvider = FutureProvider.family<DelugeClient, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ConnectionResolver resolver = ref.watch(connectionResolverProvider);
  final Uri baseUrl = await resolver.resolve(instance);
  // Deluge has no username. It is stored as a cookieLogin with an empty user.
  final String password = switch (instance.auth) {
    InstanceAuthCookie(:final String password) => password,
    InstanceAuthUserPass(:final String password) => password,
    _ => '',
  };
  final Map<String, String> customHeaders = mergeHeaders(
    ref.watch(globalHeadersProvider),
    instance.customHeaders,
  );
  final DelugeClient client = DelugeClient.create(
    baseUrl: baseUrl,
    password: password,
    allowSelfSigned: instance.allowSelfSignedCerts,
    customHeaders: customHeaders,
  );
  ref.onDispose(client.close);
  return client;
});

/// Which buckets the torrent list is narrowed to.
///
/// `'All'` is Deluge's own name for "no filter" in the filter tree, so it is
/// used as the default rather than an empty string.
@immutable
class DelugeFilter {
  const DelugeFilter({
    this.state = 'All',
    this.label = 'All',
    this.trackerHost = 'All',
  });

  final String state;
  final String label;
  final String trackerHost;

  bool get isActive =>
      state != 'All' || label != 'All' || trackerHost != 'All';

  DelugeFilter copyWith({String? state, String? label, String? trackerHost}) =>
      DelugeFilter(
        state: state ?? this.state,
        label: label ?? this.label,
        trackerHost: trackerHost ?? this.trackerHost,
      );

  @override
  bool operator ==(Object other) =>
      other is DelugeFilter &&
      other.state == state &&
      other.label == label &&
      other.trackerHost == trackerHost;

  @override
  int get hashCode => Object.hash(state, label, trackerHost);
}

/// The active filter, per instance.
final delugeFilterProvider =
    StateProvider.family<DelugeFilter, Instance>((Ref ref, Instance _) {
  return const DelugeFilter();
});

/// What the torrent list is ordered by.
enum DelugeSortField {
  queue,
  name,
  size,
  progress,
  state,
  downSpeed,
  upSpeed,
  ratio,
  added,
}

extension DelugeSortFieldX on DelugeSortField {
  String get displayName => switch (this) {
        DelugeSortField.queue => 'Queue position',
        DelugeSortField.name => 'Name',
        DelugeSortField.size => 'Size',
        DelugeSortField.progress => 'Progress',
        DelugeSortField.state => 'State',
        DelugeSortField.downSpeed => 'Down speed',
        DelugeSortField.upSpeed => 'Up speed',
        DelugeSortField.ratio => 'Ratio',
        DelugeSortField.added => 'Date added',
      };
}

/// Current sort field, per instance.
final delugeSortFieldProvider =
    StateProvider.family<DelugeSortField, Instance>((Ref ref, Instance _) {
  return DelugeSortField.queue;
});

/// Whether the sort runs descending.
final delugeSortDescendingProvider =
    StateProvider.family<bool, Instance>((Ref ref, Instance _) => false);

/// Every torrent on the instance, unfiltered. This is the polling provider and
/// the one other features should watch.
///
/// Kept separate from [delugeTorrentsProvider] on purpose: the dashboard widget
/// and the Activity tab need the whole list, and if they watched the filtered
/// one they would inherit whatever the user last picked on the Deluge screen -
/// filter to Paused there and the Activity feed would go empty.
final delugeRawTorrentsProvider =
    FutureProvider.autoDispose.family<List<DelugeTorrent>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(delugeListPollInterval);
  final DelugeClient client =
      await ref.watch(delugeClientProvider(instance).future);
  return client.getTorrents();
});

/// The torrent list as the Deluge screen shows it: filtered and sorted. Adds no
/// network traffic of its own - it derives from [delugeRawTorrentsProvider].
final delugeTorrentsProvider =
    FutureProvider.autoDispose.family<List<DelugeTorrent>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final List<DelugeTorrent> all =
      await ref.watch(delugeRawTorrentsProvider(instance).future);
  final DelugeFilter filter = ref.watch(delugeFilterProvider(instance));
  final DelugeSortField sort = ref.watch(delugeSortFieldProvider(instance));
  final bool descending = ref.watch(delugeSortDescendingProvider(instance));
  return sortDelugeTorrents(
    filterDelugeTorrents(all, filter),
    sort,
    descending: descending,
  );
});

/// Narrows a torrent list by the active filter. Applied locally rather than
/// through `core.get_torrents_status`'s filter argument so that one poll of the
/// full list feeds the screen, the dashboard and the Activity tab alike.
List<DelugeTorrent> filterDelugeTorrents(
  List<DelugeTorrent> torrents,
  DelugeFilter filter,
) {
  bool matches(String selected, String value) =>
      selected.isEmpty || selected == 'All' || selected == value;
  return torrents
      .where(
        (DelugeTorrent t) =>
            matches(filter.state, t.state) &&
            matches(filter.label, t.label) &&
            matches(filter.trackerHost, t.trackerHost),
      )
      .toList();
}

/// Sorts a torrent list. Pulled out of the provider so it is directly testable.
///
/// Unqueued torrents report `queue == -1`, which would otherwise sort them
/// above position 0; they are pushed to the end instead so a queue sort reads
/// the way Deluge's own UI shows it.
List<DelugeTorrent> sortDelugeTorrents(
  List<DelugeTorrent> torrents,
  DelugeSortField field, {
  required bool descending,
}) {
  final List<DelugeTorrent> out = List<DelugeTorrent>.of(torrents);
  int compare(DelugeTorrent a, DelugeTorrent b) => switch (field) {
        DelugeSortField.queue => _queueRank(a).compareTo(_queueRank(b)),
        DelugeSortField.name =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        DelugeSortField.size => a.totalWanted.compareTo(b.totalWanted),
        DelugeSortField.progress => a.progress.compareTo(b.progress),
        DelugeSortField.state => a.state.compareTo(b.state),
        DelugeSortField.downSpeed => a.downloadRate.compareTo(b.downloadRate),
        DelugeSortField.upSpeed => a.uploadRate.compareTo(b.uploadRate),
        DelugeSortField.ratio => a.ratio.compareTo(b.ratio),
        DelugeSortField.added => a.timeAdded.compareTo(b.timeAdded),
      };
  out.sort(
    descending
        ? (DelugeTorrent a, DelugeTorrent b) => compare(b, a)
        : compare,
  );
  return out;
}

int _queueRank(DelugeTorrent t) =>
    t.queue < 0 ? 1 << 30 : t.queue;

/// Session-wide speeds and peer counts. Polls alongside the list.
final delugeSessionStatusProvider =
    FutureProvider.autoDispose.family<DelugeSessionStatus, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(delugeListPollInterval);
  final DelugeClient client =
      await ref.watch(delugeClientProvider(instance).future);
  return client.getSessionStatus();
});

/// The filter buckets the daemon currently offers. Polls slowly - the counts
/// move, but the set of buckets rarely does.
final delugeFilterTreeProvider =
    FutureProvider.autoDispose.family<DelugeFilterTree, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(delugeDetailPollInterval);
  final DelugeClient client =
      await ref.watch(delugeClientProvider(instance).future);
  return client.getFilterTree();
});

/// Whether the whole session is paused. Polls alongside the list so the
/// pause/resume affordance cannot go stale.
final delugeSessionPausedProvider =
    FutureProvider.autoDispose.family<bool, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(delugeListPollInterval);
  final DelugeClient client =
      await ref.watch(delugeClientProvider(instance).future);
  return client.isSessionPaused();
});

/// Global bandwidth caps, in KiB/s.
final delugeSpeedLimitsProvider =
    FutureProvider.autoDispose.family<DelugeSpeedLimits, Instance>((
  Ref ref,
  Instance instance,
) async {
  final DelugeClient client =
      await ref.watch(delugeClientProvider(instance).future);
  return client.getSpeedLimits();
});

/// Free space at the download path, in bytes.
final delugeFreeSpaceProvider =
    FutureProvider.autoDispose.family<int, Instance>((
  Ref ref,
  Instance instance,
) async {
  final DelugeClient client =
      await ref.watch(delugeClientProvider(instance).future);
  return client.getFreeSpace();
});

/// Identifies one torrent on one instance, for the detail provider's family
/// key. A record gives the structural equality Riverpod needs to dedupe.
typedef DelugeTorrentRef = (Instance instance, String torrentId);

/// Files, trackers and peers for one torrent. Polls slowly while open.
final delugeTorrentDetailProvider = FutureProvider.autoDispose
    .family<DelugeTorrentDetail, DelugeTorrentRef>((
  Ref ref,
  DelugeTorrentRef key,
) async {
  ref.pollEvery(delugeDetailPollInterval);
  final DelugeClient client =
      await ref.watch(delugeClientProvider(key.$1).future);
  return client.getTorrentDetail(key.$2);
});
