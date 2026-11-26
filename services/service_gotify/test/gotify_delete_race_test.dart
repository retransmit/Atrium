import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_gotify/service_gotify.dart';

const Instance _instance = Instance(
  id: 'gotify-1',
  name: 'Home Gotify',
  kind: ServiceKind.gotify,
  localUrl: 'http://gotify.local',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'client-token'),
);

GotifyMessage _m(int id) => GotifyMessage(id: id, appId: 1, message: '$id');

/// A server holding messages 3, 2 and 1. Every fetch after the first waits
/// for [release], so a poll can be caught in flight, and deletes wait for
/// [holdDeletes] when it is set, so a delete can be caught in flight too.
class _HeldApi extends GotifyApi {
  _HeldApi() : super(Dio());

  int fetches = 0;
  final Completer<void> release = Completer<void>();
  final List<int> deleted = <int>[];
  Completer<void>? holdDeletes;

  @override
  Future<GotifyMessagePage> getMessages({
    int? appId,
    int limit = 50,
    int? since,
  }) async {
    if (fetches++ > 0) await release.future;
    return GotifyMessagePage(messages: <GotifyMessage>[_m(3), _m(2), _m(1)]);
  }

  @override
  Future<void> deleteMessage(int id) async {
    await holdDeletes?.future;
    deleted.add(id);
  }

  @override
  Future<void> deleteAllMessages() async => holdDeletes?.future;
}

List<int> _ids(GotifyMessageFeed? feed) =>
    feed!.messages.map((GotifyMessage m) => m.id).toList();

void main() {
  const GotifyFeedKey key = (instance: _instance, appId: null);

  late _HeldApi api;
  late ProviderContainer container;

  setUp(() async {
    api = _HeldApi();
    container = ProviderContainer(
      overrides: [
        gotifyApiProvider(_instance).overrideWith((Ref ref) async => api),
      ],
    );
    container.listen(gotifyMessagesProvider(key), (_, _) {});
    await container.read(gotifyMessagesProvider(key).future);
  });

  tearDown(() => container.dispose());

  test('a poll that began before a delete does not bring the message back',
      () async {
    final GotifyMessagesNotifier feed =
        container.read(gotifyMessagesProvider(key).notifier);

    final Future<void> poll = feed.sync();
    await feed.delete(2);
    api.release.complete();
    await poll;

    expect(api.deleted, <int>[2]);
    expect(_ids(container.read(gotifyMessagesProvider(key)).value), <int>[3, 1]);
  });

  test('a poll that began before clearing does not refill the list', () async {
    final GotifyMessagesNotifier feed =
        container.read(gotifyMessagesProvider(key).notifier);

    final Future<void> poll = feed.sync();
    await feed.clear();
    api.release.complete();
    await poll;

    expect(_ids(container.read(gotifyMessagesProvider(key)).value), isEmpty);
  });

  test('a poll that runs while a delete is in flight does not land',
      () async {
    final GotifyMessagesNotifier feed =
        container.read(gotifyMessagesProvider(key).notifier);
    api.release.complete();
    api.holdDeletes = Completer<void>();

    final Future<void> deleting = feed.delete(2);
    await feed.sync();
    api.holdDeletes!.complete();
    await deleting;

    expect(_ids(container.read(gotifyMessagesProvider(key)).value), <int>[3, 1]);
  });

  test('a poll that runs while a clear is in flight does not land', () async {
    final GotifyMessagesNotifier feed =
        container.read(gotifyMessagesProvider(key).notifier);
    api.release.complete();
    api.holdDeletes = Completer<void>();

    final Future<void> clearing = feed.clear();
    final int fetchesBefore = api.fetches;
    await feed.sync();
    expect(api.fetches, fetchesBefore);
    api.holdDeletes!.complete();
    await clearing;

    expect(_ids(container.read(gotifyMessagesProvider(key)).value), isEmpty);
  });

  test('a poll with no delete during it still lands', () async {
    final GotifyMessagesNotifier feed =
        container.read(gotifyMessagesProvider(key).notifier);
    await feed.delete(2);

    final Future<void> poll = feed.sync();
    api.release.complete();
    await poll;

    // The fake server never forgets 2, so a poll that started after the
    // delete shows it again: the guard only discards polls that overlap.
    expect(_ids(container.read(gotifyMessagesProvider(key)).value),
        <int>[3, 2, 1]);
  });
}
