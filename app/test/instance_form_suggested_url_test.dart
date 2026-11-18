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

/// When Test connection finds the service at a nearby address, such as
/// rTorrent beneath the ruTorrent page, the form offers to switch to it.
void main() {
  const String typed = 'https://seedbox.test/user/rutorrent';
  const String found =
      'https://seedbox.test/user/rutorrent/plugins/httprpc/action.php';

  const Instance rtorrent = Instance(
    id: 'rtorrent',
    name: 'rTorrent',
    kind: ServiceKind.rtorrent,
    localUrl: typed,
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.userPass(username: '', password: ''),
  );

  late _Profiles profiles;
  late List<String> tested;

  Future<void> edit(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    profiles = _Profiles(rtorrent);
    tested = <String>[];
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
                  InstanceFormScreen(instanceId: rtorrent.id),
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
          connectionTesterProvider
              .overrideWith((Ref ref) => _Tester(ref, tested, found)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('Use this address fills in the address and tests it again',
      (WidgetTester tester) async {
    await edit(tester);

    await tap(tester, 'Test connection');
    expect(find.textContaining('It answers at $found'), findsOneWidget);

    await tap(tester, 'Use this address');
    expect(find.widgetWithText(TextFormField, found), findsOneWidget);
    expect(tested, <String>[typed, found]);
    expect(find.text('Local: Connected'), findsOneWidget);
    expect(find.text('Use this address'), findsNothing);

    await tap(tester, 'Save changes');
    expect(profiles.saved.single.localUrl, found);
  });

  testWidgets('no button without a suggestion', (WidgetTester tester) async {
    await edit(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, typed),
      'http://other.test:8000',
    );

    await tap(tester, 'Test connection');
    expect(find.text('Local: Connected'), findsOneWidget);
    expect(find.text('Use this address'), findsNothing);
  });
}

/// Finds rTorrent at [found] whenever any other address is tested.
class _Tester extends ConnectionTester {
  _Tester(super.ref, this.tested, this.found);

  final List<String> tested;
  final String found;

  @override
  Future<ConnectionTestResult> test({
    required Instance candidate,
    required UrlMode url,
  }) async {
    tested.add(candidate.localUrl);
    if (candidate.localUrl == found ||
        candidate.localUrl == 'http://other.test:8000') {
      return const ConnectionTestResult(ConnectionOutcome.connected, 'Connected');
    }
    return ConnectionTestResult(
      ConnectionOutcome.authFailed,
      'Reachable, but rTorrent is not at this address. It answers at $found',
      suggestedUrl: found,
    );
  }
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
