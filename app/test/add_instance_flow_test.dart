import 'package:atrium/src/router.dart';
import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:atrium/src/screens/service_grid_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Adding a service is two screens, the grid and then the form, so saving
/// has to leave both. Deleting from the form asks first.
void main() {
  const Instance existing = Instance(
    id: 'aria2-1',
    name: 'Home aria2',
    kind: ServiceKind.aria2,
    localUrl: 'http://192.168.1.10:6800',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.apiKey(apiKey: ''),
  );

  late _Profiles profiles;

  Future<GoRouter> pumpApp(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    profiles = _Profiles(existing);
    final GoRouter router = GoRouter(
      initialLocation: location,
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState __) =>
              const Scaffold(body: Text('home')),
          routes: <RouteBase>[
            GoRoute(
              path: 'add-instance',
              name: 'add-instance',
              builder: (BuildContext _, GoRouterState __) =>
                  const ServiceGridScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'form/:kind',
                  name: 'add-instance-form',
                  builder: addInstanceFormPage,
                ),
              ],
            ),
            GoRoute(
              path: 'edit',
              builder: (BuildContext _, GoRouterState __) =>
                  InstanceFormScreen(instanceId: existing.id),
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
          profileRepositoryProvider.overrideWith((Ref ref) => _Repository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('saving a new service returns past the grid', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, '/add-instance');

    final Finder aria2 = find.byKey(const ValueKey<String>('service_card_aria2'));
    await tester.scrollUntilVisible(
      aria2,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(aria2);
    await tester.pumpAndSettle();
    await tester.tap(aria2);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Home aria2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Local URL'),
      'http://192.168.1.10:6800',
    );
    final Finder save = find.widgetWithText(FilledButton, 'Add service');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(profiles.saved.single.kind, ServiceKind.aria2);
    expect(profiles.saved.single.id, 'new-instance');
    expect(find.byType(InstanceFormScreen), findsNothing);
    expect(find.byType(ServiceGridScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('backing out of the form returns to the grid', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpApp(tester, '/add-instance');

    final Finder aria2 = find.byKey(const ValueKey<String>('service_card_aria2'));
    await tester.scrollUntilVisible(
      aria2,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(aria2);
    await tester.pumpAndSettle();
    await tester.tap(aria2);
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(ServiceGridScreen), findsOneWidget);
    expect(profiles.saved, isEmpty);
  });

  testWidgets('deleting asks first, and Cancel keeps the service', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, '/edit');

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Home aria2?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(profiles.deleted, isEmpty);
    expect(find.byType(InstanceFormScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(profiles.deleted, <String>[existing.id]);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('tapping the service swaps it without leaving the form', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, '/add-instance/form/aria2');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Home server',
    );

    await tester.tap(find.byKey(const Key('service_header')));
    await tester.pumpAndSettle();
    expect(find.text('Change service'), findsOneWidget);

    final Finder radarr =
        find.byKey(const ValueKey<String>('service_option_radarr'));
    await tester.ensureVisible(radarr);
    await tester.pumpAndSettle();
    await tester.tap(radarr);
    await tester.pumpAndSettle();

    expect(find.text('Change service'), findsNothing);
    expect(find.byType(InstanceFormScreen), findsOneWidget);
    expect(find.text('Radarr'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'API key'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'RPC secret (optional)'),
      findsNothing,
    );
    expect(find.text('Home server'), findsOneWidget);
  });

  testWidgets('cancelling the service picker keeps the service', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, '/add-instance/form/aria2');

    await tester.tap(find.byKey(const Key('service_header')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Change service'), findsNothing);
    expect(find.text('aria2'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'RPC secret (optional)'),
      findsOneWidget,
    );
  });

  testWidgets('a service changed while editing is saved as the new one', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, '/edit');

    await tester.tap(find.byKey(const Key('service_header')));
    await tester.pumpAndSettle();
    final Finder transmission =
        find.byKey(const ValueKey<String>('service_option_transmission'));
    await tester.ensureVisible(transmission);
    await tester.pumpAndSettle();
    await tester.tap(transmission);
    await tester.pumpAndSettle();

    final Finder save = find.widgetWithText(FilledButton, 'Save changes');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    final Instance saved = profiles.saved.single;
    expect(saved.id, existing.id);
    expect(saved.kind, ServiceKind.transmission);
    expect(saved.name, 'Home aria2');
    expect(saved.localUrl, existing.localUrl);
  });
}

class _Profiles extends ProfileListController {
  _Profiles(this.instance);

  final Instance instance;
  final List<Instance> saved = <Instance>[];
  final List<String> deleted = <String>[];

  @override
  Future<List<Profile>> build() async => <Profile>[
        Profile(id: 'p', name: 'Default', instances: <Instance>[instance]),
      ];

  // Nothing on these screens watches the profile list, so the form can find
  // no active profile yet and asks for a new one.
  @override
  Future<Profile> createProfile(String name) async =>
      Profile(id: 'p', name: name, instances: const <Instance>[]);

  @override
  Future<void> upsertInstance(String profileId, Instance instance) async {
    saved.add(instance);
  }

  @override
  Future<void> deleteInstance(String profileId, String instanceId) async {
    deleted.add(instanceId);
  }
}

class _Active extends ActiveProfileIdController {
  @override
  String? build() => 'p';

  @override
  Future<void> select(String? id) async => state = id;
}

/// Only the id for a new instance is read from the repository here.
class _Repository implements ProfileRepository {
  @override
  String newInstanceId() => 'new-instance';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
