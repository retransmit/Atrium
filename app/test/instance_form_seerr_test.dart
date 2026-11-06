import 'package:atrium/src/connection_test/connection_test_result.dart';
import 'package:atrium/src/connection_test/connection_tester.dart';
import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The Seerr part of the instance form: an API key, or a sign-in as a Seerr
/// account or a Jellyfin or Emby one, each saved as its own auth.
void main() {
  Instance seerr(InstanceAuth auth) => Instance(
        id: 'seerr',
        name: 'Seerr',
        kind: ServiceKind.seerr,
        localUrl: 'http://seerr.example.test',
        externalUrl: '',
        urlMode: UrlMode.auto,
        auth: auth,
      );

  late _Profiles profiles;

  Future<void> edit(WidgetTester tester, Instance instance) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    profiles = _Profiles(instance);
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
                  InstanceFormScreen(instanceId: instance.id),
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
          connectionTesterProvider.overrideWith(_Tester.new),
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

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('an API key instance shows the key, and saves as one',
      (WidgetTester tester) async {
    await edit(tester, seerr(const InstanceAuth.apiKey(apiKey: 'k')));

    expect(field('API key'), findsOneWidget);
    expect(field('Email'), findsNothing);

    await tap(tester, 'Save changes');
    expect(profiles.saved.single.auth, const InstanceAuth.apiKey(apiKey: 'k'));
  });

  testWidgets('signing in as a Seerr account asks for an email and password',
      (WidgetTester tester) async {
    await edit(tester, seerr(const InstanceAuth.apiKey(apiKey: 'k')));

    await tap(tester, 'Sign in');
    expect(field('API key'), findsNothing);
    expect(field('Email'), findsOneWidget);
    expect(field('Password'), findsOneWidget);

    await tester.enterText(field('Email'), 'kid@example.com');
    await tester.enterText(field('Password'), 'pw');
    await tap(tester, 'Save changes');

    expect(
      profiles.saved.single.auth,
      const InstanceAuth.cookieLogin(
        username: 'kid@example.com',
        password: 'pw',
      ),
    );
  });

  testWidgets('a Jellyfin or Emby account asks for a username, password '
      'optional', (WidgetTester tester) async {
    await edit(tester, seerr(const InstanceAuth.apiKey(apiKey: 'k')));

    await tap(tester, 'Sign in');
    await tap(tester, 'Jellyfin or Emby');
    expect(field('Username'), findsOneWidget);
    expect(field('Password (Optional)'), findsOneWidget);

    await tester.enterText(field('Username'), 'kid');
    await tap(tester, 'Save changes');

    expect(
      profiles.saved.single.auth,
      const InstanceAuth.userPass(username: 'kid', password: ''),
    );
  });

  testWidgets('a signed-in instance opens on its sign-in',
      (WidgetTester tester) async {
    await edit(
      tester,
      seerr(const InstanceAuth.userPass(username: 'kid', password: 'pw')),
    );

    expect(field('API key'), findsNothing);
    expect(find.text('kid'), findsOneWidget);
    expect(field('Password (Optional)'), findsOneWidget);
  });
}

class _Profiles extends ProfileListController {
  _Profiles(this.instance);

  final Instance instance;
  final List<Instance> saved = <Instance>[];

  @override
  Future<List<Profile>> build() async => <Profile>[
        Profile(id: 'p', name: 'Default', instances: <Instance>[instance]),
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

class _Tester extends ConnectionTester {
  _Tester(super.ref);

  @override
  Future<ConnectionTestResult> test({
    required Instance candidate,
    required UrlMode url,
  }) async =>
      const ConnectionTestResult(ConnectionOutcome.connected, 'Connected');
}
