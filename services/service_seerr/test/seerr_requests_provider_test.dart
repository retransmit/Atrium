import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

/// A Seerr whose full list of requests takes [delay] to read, signed in as a
/// user with [permissions].
class _SlowSeerr extends SeerrApi {
  _SlowSeerr(this.delay, {this.permissions = SeerrPermission.admin})
      : super(Dio());

  final Duration delay;
  final int permissions;
  int reads = 0;

  /// The `ownOnly` of every read.
  final List<bool> ownOnly = <bool>[];

  @override
  Future<SeerrUser> me() async => SeerrUser(id: 7, permissions: permissions);

  @override
  Future<List<SeerrRequest>> getAllRequests({
    String sort = 'added',
    String? filter,
    bool ownOnly = false,
  }) async {
    reads++;
    this.ownOnly.add(ownOnly);
    await Future<void>.delayed(delay);
    return const <SeerrRequest>[];
  }
}

const Instance _instance = Instance(
  id: 'test-seerr',
  name: 'Test Seerr',
  kind: ServiceKind.seerr,
  localUrl: 'http://seerr.test',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

void main() {
  testWidgets(
    'a read slower than the refresh interval finishes before the next starts',
    (WidgetTester tester) async {
      final _SlowSeerr api = _SlowSeerr(const Duration(seconds: 15));
      final ProviderContainer container = ProviderContainer(
        overrides: [
          seerrApiProvider.overrideWith((Ref ref, Instance i) async => api),
        ],
      );
      final ProviderSubscription<AsyncValue<List<SeerrRequest>>> sub =
          container.listen(seerrRequestsProvider(_instance), (_, __) {});

      await tester.pump(const Duration(seconds: 14));
      expect(api.reads, 1);

      await tester.pump(const Duration(seconds: 2));
      expect(sub.read(), isA<AsyncData<List<SeerrRequest>>>());
      expect(api.reads, 1);

      await tester.pump(const Duration(seconds: 10));
      expect(api.reads, 2);

      sub.close();
      container.dispose();
      await tester.pump(const Duration(seconds: 15));
    },
  );

  for (final (String who, int permissions, bool ownOnly) in <(String, int, bool)>[
    ('a user who sees only their own requests', SeerrPermission.request, true),
    ('a user who may view all requests', SeerrPermission.requestView, false),
    ('a request manager', SeerrPermission.manageRequests, false),
  ]) {
    testWidgets('$who reads ${ownOnly ? 'only theirs' : 'every request'}',
        (WidgetTester tester) async {
      final _SlowSeerr api = _SlowSeerr(
        Duration.zero,
        permissions: permissions,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          seerrApiProvider.overrideWith((Ref ref, Instance i) async => api),
        ],
      );
      final ProviderSubscription<AsyncValue<List<SeerrRequest>>> sub =
          container.listen(seerrRequestsProvider(_instance), (_, __) {});
      await tester.pump();
      await tester.pump();

      expect(api.ownOnly, <bool>[ownOnly]);

      sub.close();
      container.dispose();
      await tester.pump(const Duration(seconds: 15));
    });
  }
}
