import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'gotify_api.dart';
import 'models/gotify_models.dart';

final gotifyApiProvider =
    FutureProvider.autoDispose.family<GotifyApi, Instance>(
  (Ref ref, Instance instance) async {
    final Dio dio = await ref.watch(instanceDioProvider(instance).future);
    return GotifyApi(dio);
  },
  retry: (int _, Object __) => null,
);

final gotifyApplicationsProvider =
    FutureProvider.autoDispose.family<List<GotifyApplication>, Instance>(
  (Ref ref, Instance instance) async {
    final GotifyApi api = await ref.watch(gotifyApiProvider(instance).future);
    return api.getApplications();
  },
  retry: (int _, Object __) => null,
);

/// The application the screen's message list is filtered to, or null for all.
final gotifySelectedAppProvider =
    StateProvider.autoDispose.family<int?, Instance>((Ref ref, Instance _) {
  return null;
});

/// Which messages a feed holds: every application's when [appId] is null,
/// otherwise that one application's.
///
/// Part of the key rather than read from [gotifySelectedAppProvider], so the
/// dashboard's unfiltered feed never picks up a filter chosen on the screen.
typedef GotifyFeedKey = ({Instance instance, int? appId});

/// The message list, kept across polls and "load older".
///
/// Not a polled FutureProvider: rebuilding on every tick would throw away the
/// older pages the user has loaded. A timer fetches the newest page instead
/// and merges it; see [GotifyMessageFeed.mergeNewest].
class GotifyMessagesNotifier extends AsyncNotifier<GotifyMessageFeed> {
  GotifyMessagesNotifier(this.key);

  final GotifyFeedKey key;

  Instance get instance => key.instance;

  static const int pageSize = 50;

  /// Failed polls in a row cap out at skipping 31 ticks between tries.
  static const int _maxBackoffShift = 5;

  bool _syncing = false;
  int _failures = 0;
  int _ticksToSkip = 0;

  /// Counts deletes and clears, before and after each reaches the server. A
  /// poll that overlapped one fetched the list as it was, so its page would
  /// put deleted messages back; it is dropped and the next tick fetches again.
  int _edits = 0;

  @override
  Future<GotifyMessageFeed> build() async {
    final Timer timer = Timer.periodic(
      Duration(seconds: instance.pollingIntervalSeconds.clamp(1, 3600)),
      (_) => _tick(),
    );
    ref.onDispose(timer.cancel);

    final GotifyApi api = await ref.watch(gotifyApiProvider(instance).future);
    return GotifyMessageFeed.fromPage(
      await api.getMessages(appId: key.appId),
    );
  }

  void _tick() {
    if (_ticksToSkip > 0) {
      _ticksToSkip--;
      return;
    }
    final AppLifecycleState? lifecycle =
        SchedulerBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      unawaited(sync());
    }
  }

  /// Folds the newest page into what is on screen. A failure leaves the list
  /// as it is and backs off: a wrong token or a server that is down is tried
  /// again after 1, 3, 7, ... skipped ticks rather than on every one.
  Future<void> sync() async {
    if (_syncing || state.value == null) return;
    _syncing = true;
    final int edits = _edits;
    try {
      final GotifyApi api = await ref.read(gotifyApiProvider(instance).future);
      final GotifyMessagePage page =
          await api.getMessages(appId: key.appId);
      _failures = 0;
      _ticksToSkip = 0;
      if (!ref.mounted || edits != _edits) return;
      final GotifyMessageFeed? current = state.value;
      if (current == null) return;
      state = AsyncData<GotifyMessageFeed>(
        current.mergeNewest(page, pageSize),
      );
    } on Object {
      if (_failures < _maxBackoffShift) _failures++;
      _ticksToSkip = (1 << _failures) - 1;
    } finally {
      _syncing = false;
    }
  }

  /// Fetches the next, older page.
  Future<void> loadOlder() async {
    final GotifyMessageFeed? current = state.value;
    if (current == null || !current.hasMore) return;
    final GotifyApi api = await ref.read(gotifyApiProvider(instance).future);
    final GotifyMessagePage page = await api.getMessages(
      appId: key.appId,
      since: current.nextSince,
    );
    if (!ref.mounted) return;
    state = AsyncData<GotifyMessageFeed>(
      (state.value ?? current).appendOlder(page),
    );
  }

  /// Removes the message at once (a dismissed tile must leave the tree), then
  /// asks the server. A refusal reloads the list and rethrows.
  Future<void> delete(int id) async {
    _edits++;
    final GotifyMessageFeed? current = state.value;
    if (current != null) {
      state = AsyncData<GotifyMessageFeed>(current.without(id));
    }
    try {
      final GotifyApi api = await ref.read(gotifyApiProvider(instance).future);
      await api.deleteMessage(id);
    } on Object {
      if (ref.mounted) ref.invalidateSelf();
      rethrow;
    } finally {
      _edits++;
    }
  }

  /// Deletes every message, or every message of this feed's application.
  Future<void> clear() async {
    _edits++;
    final int? appId = key.appId;
    try {
      final GotifyApi api = await ref.read(gotifyApiProvider(instance).future);
      if (appId == null) {
        await api.deleteAllMessages();
      } else {
        await api.deleteApplicationMessages(appId);
      }
    } finally {
      _edits++;
    }
    if (ref.mounted) {
      state = const AsyncData<GotifyMessageFeed>(GotifyMessageFeed.empty);
    }
  }
}

final gotifyMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<GotifyMessagesNotifier, GotifyMessageFeed, GotifyFeedKey>(
  GotifyMessagesNotifier.new,
  retry: (int _, Object __) => null,
);
