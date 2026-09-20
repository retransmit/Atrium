import 'package:flutter_test/flutter_test.dart';
import 'package:service_transmission/service_transmission.dart';

import 'support/fake_transmission.dart';
import 'support/transmission_fixtures.dart';

void main() {
  late FakeTransmission fake;
  late TransmissionApi api;

  setUp(() {
    fake = FakeTransmission();
    api = TransmissionApi(fakeTransmissionDio(fake));
  });

  test('the first call is refused, retried with the session id, then kept',
      () async {
    fake.on('session-stats', statsJson());

    await api.getSessionStats();
    await api.getSessionStats();

    expect(fake.rejections, 1);
    expect(fake.to('session-stats'), hasLength(2));
  });

  test('a result other than success is an error with its text', () async {
    fake.fail('torrent-verify', 'No such torrent');

    await expectLater(
      api.verify(<String>['aaaa']),
      throwsA(
        predicate<Object>(
          (Object e) => e.toString().contains('No such torrent'),
        ),
      ),
    );
  });

  test('start all and stop all send no ids', () async {
    await api.startAll();
    await api.stopAll();

    expect(fake.single('torrent-start').arguments.containsKey('ids'), isFalse);
    expect(fake.single('torrent-stop').arguments.containsKey('ids'), isFalse);
  });

  test('set location moves the data, as the web UI does', () async {
    await api.setLocation(<String>['aaaa', 'bbbb'], '/data/movies');

    expect(fake.single('torrent-set-location').arguments, <String, dynamic>{
      'ids': <String>['aaaa', 'bbbb'],
      'location': '/data/movies',
      'move': true,
    });
  });

  test('rename addresses one torrent by its current name', () async {
    await api.rename('aaaa', oldName: 'old', newName: 'new');

    expect(fake.single('torrent-rename-path').arguments, <String, dynamic>{
      'ids': <String>['aaaa'],
      'path': 'old',
      'name': 'new',
    });
  });

  test('labels and file priorities go through torrent-set', () async {
    await api.setLabels(<String>['aaaa'], <String>['linux', 'iso']);
    await api.setFilePriority('aaaa', <int>[0, 2], TransmissionPriority.high);

    final List<RpcCall> sets = fake.to('torrent-set');
    expect(sets[0].arguments, <String, dynamic>{
      'ids': <String>['aaaa'],
      'labels': <String>['linux', 'iso'],
    });
    expect(sets[1].arguments, <String, dynamic>{
      'ids': <String>['aaaa'],
      'priority-high': <int>[0, 2],
    });
  });

  test('the magnet link is fetched on demand', () async {
    fake.on('torrent-get', <String, Object?>{
      'torrents': <Map<String, Object?>>[
        <String, Object?>{'magnetLink': 'magnet:?xt=urn:btih:aaaa'},
      ],
    });

    expect(await api.getMagnetLink('aaaa'), 'magnet:?xt=urn:btih:aaaa');
    expect(
      fake.single('torrent-get').arguments['fields'],
      <String>['magnetLink'],
    );
  });

  test('free space is null when the daemon cannot stat the path', () async {
    fake.onCall(
      'free-space',
      (Map<String, dynamic> args) => <String, Object?>{
        'path': args['path'],
        'size-bytes': 123456789,
      },
    );
    expect(await api.freeSpace('/downloads'), 123456789);

    fake.fail('free-space', 'No such file or directory');
    expect(await api.freeSpace('/nowhere'), isNull);
  });

  test('port test, blocklist update and session writes', () async {
    fake.on('port-test', <String, Object?>{'port-is-open': true});
    fake.on('blocklist-update', <String, Object?>{'blocklist-size': 4242});

    expect(await api.portTest(ipProtocol: 'ipv6'), isTrue);
    expect(fake.single('port-test').arguments, <String, dynamic>{
      'ipProtocol': 'ipv6',
    });
    expect(await api.updateBlocklist(), 4242);

    await api.setSession(<String, Object?>{'peer-port': 6881});
    expect(fake.single('session-set').arguments, <String, dynamic>{
      'peer-port': 6881,
    });
  });
}
