import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_transmission/service_transmission.dart';

import 'support/fake_transmission.dart';
import 'support/transmission_fixtures.dart';
import 'support/transmission_test_instance.dart';

void main() {
  late FakeTransmission fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeTransmission()
      ..on('torrent-get', <String, Object?>{
        'torrents': <Map<String, dynamic>>[
          torrentJson(hash: 'a', name: 'Alpha'),
          torrentJson(id: 2, hash: 'b', name: 'Beta', status: 6),
        ],
      });
    container = ProviderContainer(
      overrides: <Override>[
        instanceDioProvider(transmissionTestInstance)
            .overrideWith((Ref ref) async => fakeTransmissionDio(fake)),
      ],
    );
    addTearDown(container.dispose);
  });

  test('the list follows the search text and the mode', () async {
    const Instance i = transmissionTestInstance;
    // A listener keeps the autoDispose providers alive between reads, as a
    // screen watching them would.
    container.listen(transmissionTorrentsProvider(i), (_, __) {});
    expect(
      await container.read(transmissionTorrentsProvider(i).future),
      hasLength(2),
    );

    container.read(transmissionSearchProvider(i).notifier).state = 'beta';
    expect(
      (await container.read(transmissionTorrentsProvider(i).future))
          .single
          .name,
      'Beta',
    );

    container.read(transmissionSearchProvider(i).notifier).state = '';
    container.read(transmissionFilterProvider(i).notifier).state =
        const TransmissionFilter(mode: TransmissionFilterMode.downloading);
    expect(
      (await container.read(transmissionTorrentsProvider(i).future))
          .single
          .name,
      'Alpha',
    );
  });

  test('free space asks the daemon once per path', () async {
    fake.onCall(
      'free-space',
      (Map<String, dynamic> args) => <String, Object?>{'size-bytes': 42},
    );
    expect(
      await container.read(
        transmissionFreeSpaceProvider((transmissionTestInstance, '/x')).future,
      ),
      42,
    );
    expect(fake.single('free-space').arguments['path'], '/x');
  });

  test('selection and compact start empty and off', () {
    expect(
      container.read(transmissionSelectionProvider(transmissionTestInstance)),
      isEmpty,
    );
    expect(
      container.read(transmissionCompactProvider(transmissionTestInstance)),
      isFalse,
    );
    expect(container.read(transmissionTabProvider(transmissionTestInstance)), 0);
  });
}
