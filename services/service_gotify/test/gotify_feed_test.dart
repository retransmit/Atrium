import 'package:flutter_test/flutter_test.dart';
import 'package:service_gotify/service_gotify.dart';

GotifyMessage _m(int id) => GotifyMessage(id: id, appId: 1, message: '$id');

List<int> _ids(GotifyMessageFeed feed) =>
    feed.messages.map((GotifyMessage m) => m.id).toList();

void main() {
  group('mergeNewest', () {
    test('with one page loaded, the fresh page replaces it', () {
      final GotifyMessageFeed feed = GotifyMessageFeed(
        messages: <GotifyMessage>[_m(5), _m(4), _m(3)],
        nextSince: 3,
      );
      final GotifyMessageFeed merged = feed.mergeNewest(
        GotifyMessagePage(messages: <GotifyMessage>[_m(6), _m(5), _m(3)]),
        3,
      );
      // 4 was deleted elsewhere and is gone; there is no next page any more.
      expect(_ids(merged), <int>[6, 5, 3]);
      expect(merged.hasMore, isFalse);
    });

    test('with older pages loaded, only newer messages are prepended', () {
      final GotifyMessageFeed feed = GotifyMessageFeed(
        messages: <GotifyMessage>[_m(5), _m(4), _m(3), _m(2)],
        nextSince: 2,
      );
      final GotifyMessageFeed merged = feed.mergeNewest(
        GotifyMessagePage(
          messages: <GotifyMessage>[_m(6), _m(5)],
          nextSince: 5,
        ),
        2,
      );
      expect(_ids(merged), <int>[6, 5, 4, 3, 2]);
      expect(merged.nextSince, 2);
    });

    test('a whole fresh page with more behind it starts over', () {
      final GotifyMessageFeed feed = GotifyMessageFeed(
        messages: <GotifyMessage>[_m(3), _m(2), _m(1)],
      );
      final GotifyMessageFeed merged = feed.mergeNewest(
        GotifyMessagePage(
          messages: <GotifyMessage>[_m(9), _m(8)],
          nextSince: 8,
        ),
        2,
      );
      expect(_ids(merged), <int>[9, 8]);
      expect(merged.nextSince, 8);
    });
  });

  test('appendOlder skips messages already shown', () {
    final GotifyMessageFeed feed = GotifyMessageFeed(
      messages: <GotifyMessage>[_m(5), _m(4)],
      nextSince: 4,
    );
    final GotifyMessageFeed next = feed.appendOlder(
      GotifyMessagePage(messages: <GotifyMessage>[_m(4), _m(3)]),
    );
    expect(_ids(next), <int>[5, 4, 3]);
    expect(next.hasMore, isFalse);
  });

  test('without drops one message', () {
    final GotifyMessageFeed feed =
        GotifyMessageFeed(messages: <GotifyMessage>[_m(2), _m(1)]);
    expect(_ids(feed.without(2)), <int>[1]);
  });

  test('relative time', () {
    final DateTime now = DateTime(2026, 11, 8, 12);
    expect(gotifyRelativeTime(now, now), 'just now');
    expect(
      gotifyRelativeTime(now.subtract(const Duration(minutes: 5)), now),
      '5m ago',
    );
    expect(
      gotifyRelativeTime(now.subtract(const Duration(hours: 3)), now),
      '3h ago',
    );
    expect(gotifyRelativeTime(DateTime(2026, 11, 1, 14, 5), now), 'Nov 1 14:05');
  });
}
