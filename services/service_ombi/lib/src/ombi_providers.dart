import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'generated/generated.dart';
import 'models/ombi_models.dart';
import 'services/ombi_client.dart';

/// An [OmbiClient] over the instance's shared Dio.
final ombiClientProvider = FutureProvider.family<OmbiClient, Instance>((
  Ref ref,
  Instance instance,
) async {
  final Dio dio = await ref.watch(instanceDioProvider(instance).future);
  return OmbiClient.fromDio(dio);
});

final ombiCountsProvider = FutureProvider.family<OmbiCounts, Instance>((
  Ref ref,
  Instance instance,
) async {
  final OmbiClient client =
      await ref.watch(ombiClientProvider(instance).future);
  return client.requestService.counts();
});

/// Whether Ombi takes music requests. A failure reads as no rather than
/// taking the screen down over a segment that is optional anyway.
final ombiMusicEnabledProvider = FutureProvider.family<bool, Instance>((
  Ref ref,
  Instance instance,
) async {
  final OmbiClient client =
      await ref.watch(ombiClientProvider(instance).future);
  try {
    return await client.requestService.musicEnabled();
  } on OmbiException {
    return false;
  }
});

/// The newest movie and TV requests, for the dashboard.
final ombiRecentRequestsProvider =
    FutureProvider.family<List<OmbiRequest>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final OmbiClient client =
      await ref.watch(ombiClientProvider(instance).future);
  return client.requestService.recent();
});

typedef OmbiListKey = ({
  Instance instance,
  OmbiMediaKind kind,
  OmbiRequestFilter filter,
});

/// What the requests list has loaded so far.
class OmbiRequestListState {
  const OmbiRequestListState({
    required this.items,
    required this.total,
    this.loadingMore = false,
  });

  final List<OmbiRequest> items;
  final int total;
  final bool loadingMore;

  bool get hasMore => items.length < total;
}

/// One kind and filter of requests, a page at a time.
final ombiRequestListProvider = AsyncNotifierProvider.family<OmbiRequestList,
    OmbiRequestListState, OmbiListKey>(OmbiRequestList.new);

class OmbiRequestList extends AsyncNotifier<OmbiRequestListState> {
  OmbiRequestList(this.key);

  final OmbiListKey key;
  int _page = 0;

  @override
  Future<OmbiRequestListState> build() async {
    _page = 0;
    final OmbiClient client =
        await ref.watch(ombiClientProvider(key.instance).future);
    final OmbiRequestPage page =
        await client.requestService.list(key.kind, key.filter);
    return OmbiRequestListState(items: page.items, total: page.total);
  }

  /// Appends the next page. Does nothing while one is loading or when there
  /// is nothing left; a failed page leaves the list as it was, and the next
  /// scroll tries again.
  Future<void> loadMore() async {
    final OmbiRequestListState? current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) {
      return;
    }
    state = AsyncData<OmbiRequestListState>(
      OmbiRequestListState(
        items: current.items,
        total: current.total,
        loadingMore: true,
      ),
    );
    try {
      final OmbiClient client =
          await ref.read(ombiClientProvider(key.instance).future);
      final OmbiRequestPage next = await client.requestService
          .list(key.kind, key.filter, page: _page + 1);
      _page++;
      state = AsyncData<OmbiRequestListState>(
        OmbiRequestListState(
          items: <OmbiRequest>[...current.items, ...next.items],
          total: next.total,
        ),
      );
    } on OmbiException {
      state = AsyncData<OmbiRequestListState>(
        OmbiRequestListState(items: current.items, total: current.total),
      );
    }
  }
}

/// How search and title lookups retry.
///
/// Both depend on Ombi reaching TheMovieDB, which on some networks fails
/// often enough that a quick retry saves a tap. But Riverpod's default keeps
/// going for about half a minute, all of it behind a spinner, before the
/// error and its Retry button appear. Two quick tries, then the truth. A
/// refused key will not change its mind, so it is not retried at all.
Duration? _tmdbBackedRetry(int retryCount, Object error) {
  final int? status = error is OmbiException ? error.statusCode : null;
  if (retryCount >= 2 || status == 401 || status == 403) {
    return null;
  }
  return const Duration(milliseconds: 500);
}

typedef OmbiSearchKey = ({Instance instance, String query});

final ombiSearchProvider =
    FutureProvider.autoDispose.family<List<OmbiSearchHit>, OmbiSearchKey>(
  (
    Ref ref,
    OmbiSearchKey key,
  ) async {
    // Every keystroke is a new query. Wait a moment, and let the ones already
    // superseded be disposed before they cost Ombi a TMDB round trip.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!ref.mounted) {
      return const <OmbiSearchHit>[];
    }
    final OmbiClient client =
        await ref.watch(ombiClientProvider(key.instance).future);
    return client.searchService.search(key.query);
  },
  retry: _tmdbBackedRetry,
);

typedef OmbiDiscoverKey = ({Instance instance, OmbiDiscoverRow row});

/// One Discover row. Kept for the session rather than disposed with the tab,
/// so flicking between Requests and Discover does not refetch every list
/// through a TMDB connection that may be slow. Pull to refresh reloads it.
final ombiDiscoverProvider =
    FutureProvider.family<List<OmbiSearchHit>, OmbiDiscoverKey>(
  (Ref ref, OmbiDiscoverKey key) async {
    final OmbiClient client =
        await ref.watch(ombiClientProvider(key.instance).future);
    return client.searchService.discover(key.row);
  },
  retry: _tmdbBackedRetry,
);

typedef OmbiTitleKey = ({Instance instance, OmbiMediaKind kind, int tmdbId});

final ombiTitleStateProvider =
    FutureProvider.autoDispose.family<OmbiTitleState, OmbiTitleKey>(
  (
    Ref ref,
    OmbiTitleKey key,
  ) async {
    final OmbiClient client =
        await ref.watch(ombiClientProvider(key.instance).future);
    return client.searchService.titleState(key.kind, key.tmdbId);
  },
  retry: _tmdbBackedRetry,
);

/// Runs [action] against the instance's Ombi, then refreshes everything that
/// shows its requests.
Future<void> runOmbiAction(
  WidgetRef ref,
  Instance instance,
  Future<void> Function(OmbiClient client) action,
) async {
  final OmbiClient client = await ref.read(ombiClientProvider(instance).future);
  await action(client);
  ref
    ..invalidate(ombiCountsProvider(instance))
    ..invalidate(ombiRecentRequestsProvider(instance))
    ..invalidate(ombiRequestListProvider);
}
