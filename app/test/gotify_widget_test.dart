import 'package:atrium/src/dashboard/widgets/gotify_widget.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

/// Serves a fixed feed instead of polling a server.
class _FixedFeed extends GotifyMessagesNotifier {
  _FixedFeed(super.key, this.feed);

  final GotifyMessageFeed feed;

  @override
  Future<GotifyMessageFeed> build() async => feed;
}

Override _feed(int? appId, GotifyMessageFeed feed) {
  final GotifyFeedKey key = (instance: _instance, appId: appId);
  return gotifyMessagesProvider(key).overrideWith(() => _FixedFeed(key, feed));
}

const GotifyMessageFeed _everything = GotifyMessageFeed(
  messages: <GotifyMessage>[
    GotifyMessage(id: 3, appId: 2, title: 'Updated nginx', message: 'ok'),
    GotifyMessage(id: 2, appId: 1, message: 'Disk full', priority: 8),
    GotifyMessage(id: 1, appId: 1, message: 'Backup done'),
  ],
  nextSince: 1,
);

const GotifyMessageFeed _backupsOnly = GotifyMessageFeed(
  messages: <GotifyMessage>[
    GotifyMessage(id: 2, appId: 1, message: 'Disk full', priority: 8),
  ],
);

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: const Scaffold(
          body: DashboardGotifyWidget(instances: <Instance>[_instance]),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows the message counts and the newest message',
      (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[_feed(null, _everything)],
    );
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(find.text('Gotify'), findsOneWidget);
    // Only part of the server's messages is loaded.
    expect(find.text('3+ messages'), findsOneWidget);
    expect(find.text('1+ high priority'), findsOneWidget);
    expect(find.text('Updated nginx'), findsOneWidget);
  });

  testWidgets('ignores an application picked on the Gotify screen',
      (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        _feed(null, _everything),
        _feed(1, _backupsOnly),
      ],
    );
    addTearDown(container.dispose);
    // The screen is still open with Backups picked.
    container.listen(gotifySelectedAppProvider(_instance), (_, __) {});
    container.read(gotifySelectedAppProvider(_instance).notifier).state = 1;

    await _pump(tester, container);

    expect(find.text('3+ messages'), findsOneWidget);
    expect(find.text('Updated nginx'), findsOneWidget);
    expect(find.text('Disk full'), findsNothing);
  });

  testWidgets('says so when there are no messages',
      (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[_feed(null, GotifyMessageFeed.empty)],
    );
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(find.text('No messages'), findsOneWidget);
  });
}
