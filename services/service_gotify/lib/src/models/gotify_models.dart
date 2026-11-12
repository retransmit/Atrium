/// Something answered, but not with Gotify's JSON: another server, a
/// reverse proxy's sign-in page, or a wrong base path.
class GotifyUnexpectedAnswer implements Exception {
  const GotifyUnexpectedAnswer();

  String get message =>
      'Something other than Gotify answered at this address. Check the URL '
      'and any reverse proxy in front of it.';

  @override
  String toString() => message;
}

int? _int(Object? value) => switch (value) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v),
      _ => null,
    };

String? _text(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// An application registered on the server: the sender of messages.
class GotifyApplication {
  const GotifyApplication({
    required this.id,
    required this.name,
    this.description,
    this.defaultPriority = 0,
    this.internal = false,
    this.lastUsed,
  });

  factory GotifyApplication.fromJson(Map<String, dynamic> json) =>
      GotifyApplication(
        id: _int(json['id']) ?? 0,
        name: _text(json['name']) ?? 'Application',
        description: _text(json['description']),
        defaultPriority: _int(json['defaultPriority']) ?? 0,
        internal: json['internal'] == true,
        lastUsed: _date(json['lastUsed']),
      );

  final int id;
  final String name;
  final String? description;
  final int defaultPriority;

  /// Created by a Gotify plugin rather than by a user.
  final bool internal;
  final DateTime? lastUsed;
}

/// How Gotify's own clients group the 0-10 priority scale.
enum GotifyPriority { low, normal, high }

class GotifyMessage {
  const GotifyMessage({
    required this.id,
    required this.appId,
    required this.message,
    this.title,
    this.priority = 0,
    this.date,
  });

  factory GotifyMessage.fromJson(Map<String, dynamic> json) => GotifyMessage(
        id: _int(json['id']) ?? 0,
        appId: _int(json['appid']) ?? 0,
        message: json['message'] is String ? json['message'] as String : '',
        title: _text(json['title']),
        priority: _int(json['priority']) ?? 0,
        date: _date(json['date']),
      );

  final int id;
  final int appId;
  final String message;
  final String? title;
  final int priority;
  final DateTime? date;

  GotifyPriority get level => priority >= 8
      ? GotifyPriority.high
      : priority >= 4
          ? GotifyPriority.normal
          : GotifyPriority.low;
}

/// One page of `GET message` or `GET application/{id}/message`.
class GotifyMessagePage {
  const GotifyMessagePage({required this.messages, this.nextSince});

  /// Reads `{messages: [...], paging: {since, next, ...}}`. Gotify only sets
  /// `paging.next` while older messages remain, and `paging.since` is the
  /// value to pass as `since` to fetch them.
  factory GotifyMessagePage.fromResponse(Object? data) {
    if (data is! Map) throw const GotifyUnexpectedAnswer();
    final Object? list = data['messages'];
    if (list is! List) throw const GotifyUnexpectedAnswer();
    final Object? paging = data['paging'];
    final int? since = paging is Map && paging['next'] != null
        ? _int(paging['since'])
        : null;
    return GotifyMessagePage(
      messages: <GotifyMessage>[
        for (final Object? item in list)
          if (item is Map) GotifyMessage.fromJson(item.cast<String, dynamic>()),
      ],
      nextSince: since != null && since > 0 ? since : null,
    );
  }

  final List<GotifyMessage> messages;

  /// The `since` for the next, older page, or null when there is none.
  final int? nextSince;
}

/// The messages on screen: possibly several pages, newest first.
class GotifyMessageFeed {
  const GotifyMessageFeed({required this.messages, this.nextSince});

  factory GotifyMessageFeed.fromPage(GotifyMessagePage page) =>
      GotifyMessageFeed(messages: page.messages, nextSince: page.nextSince);

  static const GotifyMessageFeed empty =
      GotifyMessageFeed(messages: <GotifyMessage>[]);

  final List<GotifyMessage> messages;
  final int? nextSince;

  bool get hasMore => nextSince != null;

  /// Folds a freshly fetched newest page of [pageSize] into this feed.
  ///
  /// With no more than one page loaded the fresh page simply replaces it, so
  /// messages deleted elsewhere disappear too. With older pages loaded only
  /// newer messages are prepended, keeping what the user scrolled to. If the
  /// whole fresh page is newer and the server has more, messages may be
  /// missing in between, so the feed starts over from the fresh page.
  GotifyMessageFeed mergeNewest(GotifyMessagePage newest, int pageSize) {
    if (messages.length <= pageSize || newest.messages.isEmpty) {
      return GotifyMessageFeed.fromPage(newest);
    }
    final int top = messages.first.id;
    final List<GotifyMessage> fresh = <GotifyMessage>[
      for (final GotifyMessage m in newest.messages)
        if (m.id > top) m,
    ];
    if (fresh.isEmpty) return this;
    if (fresh.length == newest.messages.length && newest.nextSince != null) {
      return GotifyMessageFeed.fromPage(newest);
    }
    return GotifyMessageFeed(
      messages: <GotifyMessage>[...fresh, ...messages],
      nextSince: nextSince,
    );
  }

  /// Appends an older [page], skipping any message already shown.
  GotifyMessageFeed appendOlder(GotifyMessagePage page) {
    final Set<int> seen = <int>{for (final GotifyMessage m in messages) m.id};
    return GotifyMessageFeed(
      messages: <GotifyMessage>[
        ...messages,
        for (final GotifyMessage m in page.messages)
          if (!seen.contains(m.id)) m,
      ],
      nextSince: page.nextSince,
    );
  }

  GotifyMessageFeed without(int id) => GotifyMessageFeed(
        messages: <GotifyMessage>[
          for (final GotifyMessage m in messages)
            if (m.id != id) m,
        ],
        nextSince: nextSince,
      );
}
