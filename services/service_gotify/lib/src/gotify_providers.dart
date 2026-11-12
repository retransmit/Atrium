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

/// The application the message list is filtered to, or null for all.
final gotifySelectedAppProvider =
    StateProvider.autoDispose.family<int?, Instance>((Ref ref, Instance _) {
  return null;
});

/// The message list, kept across polls and "load older".
///
/// Not a polled FutureProvider: rebuilding on every tick would throw away the
/// older pages the user has loaded. A timer fetches the newest page instead
/// and merges it; see [GotifyMessageFeed.mergeNewest].
class GotifyMessagesNotifier extends AsyncNotifier<GotifyMessageFeed> {
  GotifyMessagesNotifier(this.instance);

  final Instance instance;

  static const int pageSize = 50;

  bool _syncing = false;

  @override
  Future<GotifyMessageFeed> build() async {
    final int? appId = ref.watch(gotifySelectedAppProvider(instance));
    final Timer timer = Timer.periodic(
      Duration(seconds: instance.pollingIntervalSeconds.clamp(1, 3600)),
      (_) {
        final AppLifecycleState? lifecycle =
            SchedulerBinding.instance.lifecycleState;
        if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
          unawaited(sync());
        }
      },
    );
    ref.onDispose(timer.cancel);

    final GotifyApi api = await ref.watch(gotifyApiProvider(instance).future);
    return GotifyMessageFeed.fromPage(
      await api.getMessages(appId: appId),
    );
  }

  /// Folds the newest page into what is on screen. A failure leaves the list
  /// as it is; the next tick tries again.
  Future<void> sync() async {
    if (_syncing || state.value == null) return;
    _syncing = true;
    try {
      final int? appId = ref.read(gotifySelectedAppProvider(instance));
      final GotifyApi api = await ref.read(gotifyApiProvider(instance).future);
      final GotifyMessagePage page =
          await api.getMessages(appId: appId);
      if (!ref.mounted ||
          ref.read(gotifySelectedAppProvider(instance)) != appId) {
        return;
      }
      final GotifyMessageFeed? current = state.value;
      if (current == null) return;
      state = AsyncData<GotifyMessageFeed>(
        current.mergeNewest(page, pageSize),
      );
    } on Object {
      // Keep what is on screen.
    } finally {
      _syncing = false;
    }
  }

  /// Fetches the next, older page.
  Future<void> loadOlder() async {
    final GotifyMessageFeed? current = state.value;
    if (current == null || !current.hasMore) return;
    final int? appId = ref.read(gotifySelectedAppProvider(instance));
    final GotifyApi api = await ref.read(gotifyApiProvider(instance).future);
    final GotifyMessagePage page = await api.getMessages(
      appId: appId,
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
    }
  }

  /// Deletes every message, or every message of the selected application.
  Future<void> clear() async {
    final int? appId = ref.read(gotifySelectedAppProvider(instance));
    final GotifyApi api = await ref.read(gotifyApiProvider(instance).future);
    if (appId == null) {
      await api.deleteAllMessages();
    } else {
      await api.deleteApplicationMessages(appId);
    }
    if (ref.mounted) {
      state = const AsyncData<GotifyMessageFeed>(GotifyMessageFeed.empty);
    }
  }
}

final gotifyMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<GotifyMessagesNotifier, GotifyMessageFeed, Instance>(
  GotifyMessagesNotifier.new,
  retry: (int _, Object __) => null,
);
