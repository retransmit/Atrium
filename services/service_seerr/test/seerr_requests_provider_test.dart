import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

/// A Seerr whose full list of requests takes [delay] to read.
class _SlowSeerr extends SeerrApi {
  _SlowSeerr(this.delay) : super(Dio());

  final Duration delay;
  int reads = 0;

  @override
  Future<List<SeerrRequest>> getAllRequests({
    String sort = 'added',
    String? filter,
  }) async {
    reads++;
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
}
