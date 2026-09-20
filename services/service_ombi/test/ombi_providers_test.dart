import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

import 'support/fake_ombi.dart';
import 'support/ombi_fixtures.dart';
import 'support/ombi_test_instance.dart';

void main() {
  late FakeOmbi fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeOmbi();
    container = ProviderContainer(
      retry: (int _, Object __) => null,
      overrides: <Override>[
        instanceDioProvider(ombiTestInstance)
            .overrideWith((Ref ref) async => fakeOmbiDio(fake)),
      ],
    );
    addTearDown(container.dispose);
  });

  test('counts come through the instance Dio', () async {
    fake.on('GET', '/api/v1/Request/count', countsJson);

    final OmbiCounts counts =
        await container.read(ombiCountsProvider(ombiTestInstance).future);

    expect(counts.total, 8);
  });

  test('music reads as off when Ombi will not say', () async {
    // No route configured: the fake answers 404.
    expect(
      await container.read(ombiMusicEnabledProvider(ombiTestInstance).future),
      isFalse,
    );
  });

  test('the list loads a page and appends the next one', () async {
    fake
      ..on(
        'GET',
        '/api/v2/Requests/movie/pending/25/0/requestedDate/desc',
        pageJson(<Map<String, dynamic>>[movieRequestJson(id: 1)], total: 2),
      )
      ..on(
        'GET',
        '/api/v2/Requests/movie/pending/25/25/requestedDate/desc',
        pageJson(<Map<String, dynamic>>[movieRequestJson(id: 2)], total: 2),
      );
    const OmbiListKey key = (
      instance: ombiTestInstance,
      kind: OmbiMediaKind.movie,
      filter: OmbiRequestFilter.pending,
    );

    final OmbiRequestListState first =
        await container.read(ombiRequestListProvider(key).future);
    expect(first.items.map((OmbiRequest r) => r.id), <int>[1]);
    expect(first.hasMore, isTrue);

    await container.read(ombiRequestListProvider(key).notifier).loadMore();

    final OmbiRequestListState second =
        container.read(ombiRequestListProvider(key)).value!;
    expect(second.items.map((OmbiRequest r) => r.id), <int>[1, 2]);
    expect(second.hasMore, isFalse);
  });

  test('a page that fails to load keeps what is already there', () async {
    fake.on(
      'GET',
      '/api/v2/Requests/movie/pending/25/0/requestedDate/desc',
      pageJson(<Map<String, dynamic>>[movieRequestJson(id: 1)], total: 2),
    );
    const OmbiListKey key = (
      instance: ombiTestInstance,
      kind: OmbiMediaKind.movie,
      filter: OmbiRequestFilter.pending,
    );
    await container.read(ombiRequestListProvider(key).future);

    // The second page has no route, so it 404s.
    await container.read(ombiRequestListProvider(key).notifier).loadMore();

    final OmbiRequestListState state =
        container.read(ombiRequestListProvider(key)).value!;
    expect(state.items.map((OmbiRequest r) => r.id), <int>[1]);
    expect(state.loadingMore, isFalse);
  });
}
