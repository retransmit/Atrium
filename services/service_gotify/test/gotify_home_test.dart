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

const List<GotifyApplication> _apps = <GotifyApplication>[
  GotifyApplication(id: 1, name: 'Backups'),
  GotifyApplication(id: 2, name: 'Watchtower'),
];

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

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        gotifyApplicationsProvider(_instance).overrideWith((Ref ref) async => _apps),
        _feed(
          null,
          const GotifyMessageFeed(
            messages: <GotifyMessage>[
              GotifyMessage(
                id: 3,
                appId: 2,
                title: 'Updated nginx',
                message: 'nginx:1.27 is running',
              ),
              GotifyMessage(
                id: 2,
                appId: 1,
                title: 'Backup failed',
                message: 'Disk full',
                priority: 8,
              ),
            ],
            nextSince: 2,
          ),
        ),
        _feed(
          1,
          const GotifyMessageFeed(
            messages: <GotifyMessage>[
              GotifyMessage(
                id: 2,
                appId: 1,
                title: 'Backup failed',
                message: 'Disk full',
                priority: 8,
              ),
            ],
          ),
        ),
      ],
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: const Scaffold(body: GotifyHome(instance: _instance)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every application\'s messages with their sender',
      (WidgetTester tester) async {
    await _pump(tester);

    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Backups'), findsOneWidget);
    expect(find.text('Updated nginx'), findsOneWidget);
    expect(find.text('Backup failed'), findsOneWidget);
    // Once on its chip, once under its message.
    expect(find.text('Watchtower'), findsNWidgets(2));
    expect(find.text('Backups'), findsNWidgets(2));
    expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
    // More is on the server.
    expect(find.text('Load older'), findsOneWidget);
  });

  testWidgets('picking an application shows only its messages',
      (WidgetTester tester) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Backups'));
    await tester.pumpAndSettle();

    expect(find.text('Backup failed'), findsOneWidget);
    expect(find.text('Updated nginx'), findsNothing);
    expect(find.text('Load older'), findsNothing);
  });
}
