import 'dart:io';

import 'package:atrium/src/preferences.dart';
import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The Docker Host form takes SSH addresses and credentials, and once a
/// profile has one, every other service can name its container.
void main() {
  const Instance dockerHost = Instance(
    id: 'host',
    name: 'NAS',
    kind: ServiceKind.dockerHost,
    localUrl: 'ssh://192.168.1.10',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.ssh(username: 'admin', password: 'pw'),
  );
  const Instance sonarr = Instance(
    id: 'sonarr',
    name: 'Sonarr',
    kind: ServiceKind.sonarr,
    localUrl: 'http://sonarr.example.test',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.apiKey(apiKey: 'k'),
  );

  late _Profiles profiles;
  late Box<String> settings;

  setUpAll(() async {
    final Directory dir = await Directory.systemTemp.createTemp('form');
    Hive.init(dir.path);
    settings = await Hive.openBox<String>('settings');
  });

  tearDownAll(() async {
    await Hive.close();
  });

  Future<void> edit(WidgetTester tester, String instanceId) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    profiles = _Profiles(<Instance>[dockerHost, sonarr]);
    final GoRouter router = GoRouter(
      initialLocation: '/edit',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState __) =>
              const Scaffold(body: Text('home')),
          routes: <RouteBase>[
            GoRoute(
              path: 'edit',
              builder: (BuildContext _, GoRouterState __) =>
                  InstanceFormScreen(instanceId: instanceId),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          profileListProvider.overrideWith(() => profiles),
          activeProfileIdProvider.overrideWith(_Active.new),
          settingsBoxProvider.overrideWithValue(settings),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextFormField),
      );

  Future<void> save(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
  }

  testWidgets('a Docker host takes an SSH address and keeps its SSH login',
      (WidgetTester tester) async {
    await edit(tester, dockerHost.id);
    expect(find.text('Private key (optional)'), findsOneWidget);
    expect(find.text('Container shell'), findsNothing);
    // Nothing in Preferences applies to SSH, so the card is left out.
    expect(find.text('Preferences'), findsNothing);

    await tester.enterText(field('Local address'), 'http://nas.lan');
    await save(tester);
    expect(profiles.saved, isEmpty);
    expect(find.text('Enter at least one SSH address (local or external)'),
      findsWidgets,);

    await tester.enterText(field('Local address'), 'nas.lan:2222');
    await save(tester);
    final Instance saved = profiles.saved.single;
    expect(saved.localUrl, 'nas.lan:2222');
    expect(
      saved.auth,
      const InstanceAuth.ssh(username: 'admin', password: 'pw'),
    );
  });

  testWidgets('a service names the container its shell opens in',
      (WidgetTester tester) async {
    await edit(tester, sonarr.id);
    await tester.scrollUntilVisible(
      find.text('Container name'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(field('Container name'), ' sonarr ');
    await save(tester);
    expect(profiles.saved.single.dockerContainer, 'sonarr');
  });
}

class _Profiles extends ProfileListController {
  _Profiles(this.instances);

  final List<Instance> instances;
  final List<Instance> saved = <Instance>[];

  @override
  Future<List<Profile>> build() async => <Profile>[
        Profile(id: 'p', name: 'Default', instances: instances),
      ];

  @override
  Future<void> upsertInstance(String profileId, Instance instance) async {
    saved.add(instance);
  }
}

class _Active extends ActiveProfileIdController {
  @override
  String? build() => 'p';

  @override
  Future<void> select(String? id) async => state = id;
}
