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

/// An instance's own headers are set under Settings, not on its form, so the
/// form has to carry them through.
///
/// It did not. The form rebuilt the instance from its own fields alone, so
/// saving it for any reason, a new URL or a new key, deleted the headers a
/// reverse proxy needs, and Test connection ran without them and failed
/// against that proxy while the rest of the app still got through.
void main() {
  const Map<String, String> proxyHeaders = <String, String>{
    'X-Proxy-Secret': 'letmein',
  };
  const Instance proxied = Instance(
    id: 'sonarr',
    name: 'Sonarr',
    kind: ServiceKind.sonarr,
    localUrl: 'http://sonarr.example.test',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.apiKey(apiKey: 'k'),
    customHeaders: proxyHeaders,
  );

  late _Profiles profiles;
  late _RecordingTester connectionTester;

  Future<void> editProxied(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    profiles = _Profiles(proxied);
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
                  InstanceFormScreen(instanceId: proxied.id),
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
          connectionTesterProvider.overrideWith(
            (Ref ref) => connectionTester = _RecordingTester(ref),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('saving an edit keeps the headers set under Settings',
      (WidgetTester tester) async {
    await editProxied(tester);
    await tester.enterText(
      find.ancestor(
        of: find.text('Local URL'),
        matching: find.byType(TextFormField),
      ),
      'http://sonarr.lan.test',
    );

    await tapButton(tester, 'Save changes');

    final Instance saved = profiles.saved.single;
    expect(saved.localUrl, 'http://sonarr.lan.test');
    expect(saved.customHeaders, proxyHeaders);
  });

  testWidgets('Test connection sends them too', (WidgetTester tester) async {
    await editProxied(tester);

    await tapButton(tester, 'Test connection');

    expect(connectionTester.candidates.single.customHeaders, proxyHeaders);
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

class _RecordingTester extends ConnectionTester {
  _RecordingTester(super.ref);

  final List<Instance> candidates = <Instance>[];

  @override
  Future<ConnectionTestResult> test({
    required Instance candidate,
    required UrlMode url,
  }) async {
    candidates.add(candidate);
    return const ConnectionTestResult(ConnectionOutcome.connected, 'Connected');
  }
}
