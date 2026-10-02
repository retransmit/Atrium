import 'dart:convert';
import 'dart:typed_data';

import 'package:atrium/src/screens/service_detail_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Back on Ombi's Discover tab returns to its Requests tab.
///
/// The service shell wraps a module's body in a PopScope of its own that
/// leaves for the dashboard, and two PopScopes on one route both fire. So a
/// module with anything to unwind has to be handed the whole screen, or its
/// first back press throws the user out.
void main() {
  const Instance ombi = Instance(
    id: 'ombi-1',
    name: 'Ombi',
    kind: ServiceKind.ombi,
    localUrl: 'http://ombi.test',
    externalUrl: '',
    urlMode: UrlMode.forceLocal,
    auth: InstanceAuth.apiKey(apiKey: 'k'),
  );

  testWidgets('back on Discover returns to Requests, not to the dashboard',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final GoRouter router = GoRouter(
      initialLocation: AtriumRoutes.servicePath(ombi.kind.name, ombi.id),
      routes: <RouteBase>[
        GoRoute(
          path: AtriumRoutes.dashboard,
          name: AtriumRoutes.dashboardName,
          builder: (BuildContext _, GoRouterState __) =>
              const Scaffold(body: Text('the dashboard')),
        ),
        GoRoute(
          path: AtriumRoutes.service,
          name: AtriumRoutes.serviceName,
          builder: (BuildContext _, GoRouterState state) =>
              ServiceDetailScreen(
            kindName: state.pathParameters['kind']!,
            instanceId: state.pathParameters['instanceId']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object __) => null,
        overrides: <Override>[
          activeProfileProvider.overrideWithValue(
            const Profile(
              id: 'p',
              name: 'Default',
              instances: <Instance>[ombi],
            ),
          ),
          instanceDioProvider(ombi).overrideWith(
            (Ref ref) async => Dio(BaseOptions(baseUrl: 'http://ombi.test/'))
              ..httpClientAdapter = _EmptyOmbi(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.text('Discover'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    // The system back, as Android delivers it.
    await tester.binding.handlePopRoute();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('the dashboard'), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });
}

/// An Ombi with nothing in it: every list is empty and Lidarr is off.
class _EmptyOmbi implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.uri.path;
    final Object body;
    if (path == '/api/v1/Lidarr/enabled') {
      body = false;
    } else if (path.startsWith('/api/v2/Requests/')) {
      body = <String, dynamic>{'collection': <Object>[], 'total': 0};
    } else if (path.startsWith('/api/v2/Search/')) {
      body = <Object>[];
    } else {
      body = <String, dynamic>{};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
