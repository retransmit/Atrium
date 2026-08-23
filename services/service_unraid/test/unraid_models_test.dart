import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_unraid/service_unraid.dart';

/// Verbatim from a live Unraid 7.x server, with names and sizes obfuscated by
/// the person who ran the query. Kept as raw JSON rather than hand-built maps
/// so these tests fail if the real shape ever stops matching.
const String _arrayResponse = '''
{
  "data": {
    "array": {
      "state": "STARTED",
      "disks": [
        { "name": "disk1", "size": "~3TB", "status": "DISK_OK", "temp": 42 },
        { "name": "disk2", "size": "~2TB", "status": "DISK_OK", "temp": 37 },
        { "name": "disk3", "size": "~3TB", "status": "DISK_OK", "temp": 43 }
      ]
    }
  }
}
''';

const String _containersResponse = '''
{
  "data": {
    "docker": {
      "containers": [
        { "id": "a1b2:0001", "names": ["/container_1"], "state": "RUNNING",
          "status": "Up 18 hours", "autoStart": false },
        { "id": "a1b2:0002", "names": ["/container_2"], "state": "RUNNING",
          "status": "Up 24 hours (healthy)", "autoStart": true },
        { "id": "a1b2:0003", "names": ["/container_3"], "state": "EXITED",
          "status": "Created", "autoStart": false },
        { "id": "a1b2:0006", "names": ["/container_6"], "state": "EXITED",
          "status": "Exited (143) 32 hours ago", "autoStart": false }
      ]
    }
  }
}
''';

Map<String, dynamic> _data(String raw) =>
    (jsonDecode(raw) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

void main() {
  group('UnraidArray', () {
    late UnraidArray array;

    setUp(() {
      array = UnraidArray.fromJson(
        _data(_arrayResponse)['array'] as Map<String, dynamic>,
      );
    });

    test('reads state and every disk', () {
      expect(array.state, 'STARTED');
      expect(array.isStarted, isTrue);
      expect(array.disks, hasLength(3));
      expect(array.disks.first.name, 'disk1');
      expect(array.disks.first.temp, 42);
      expect(array.disks.first.size, '~3TB');
    });

    test('state is shown as a word, not the raw enum', () {
      expect(array.stateLabel, 'Started');
      expect(
        const UnraidArray(state: 'STOPPED').stateLabel,
        'Stopped',
      );
    });

    test('a healthy array reports nothing needing attention', () {
      expect(array.unhealthyDisks, isEmpty);
    });

    test('a failed disk is picked out and named in plain words', () {
      final UnraidArray withFault = UnraidArray.fromJson(<String, dynamic>{
        'state': 'STARTED',
        'disks': <dynamic>[
          <String, dynamic>{'name': 'disk1', 'status': 'DISK_OK'},
          <String, dynamic>{'name': 'disk2', 'status': 'DISK_DSBL'},
        ],
      });
      expect(withFault.unhealthyDisks, hasLength(1));
      expect(withFault.unhealthyDisks.single.name, 'disk2');
      expect(withFault.unhealthyDisks.single.statusLabel, 'Disabled');
    });

    test('an unrecognised status is not treated as healthy', () {
      // The case that matters: a status this app has never seen is exactly
      // when it must not reassure anyone.
      const UnraidDisk unknown = UnraidDisk(name: 'd', status: 'DISK_SOMETHING');
      expect(unknown.isHealthy, isFalse);
      expect(unknown.statusLabel, 'DISK_SOMETHING');
    });

    test('a spun-down disk reports no temperature rather than zero', () {
      final UnraidDisk parked = UnraidDisk.fromJson(<String, dynamic>{
        'name': 'disk9',
        'status': 'DISK_OK',
      });
      expect(parked.temp, isNull);
      expect(parked.isHealthy, isTrue);
    });
  });

  group('disk temperature bands', () {
    UnraidDisk at(int? c) =>
        UnraidDisk(name: 'd', status: 'DISK_OK', temp: c);

    test('a spun-down disk has no band rather than a cold one', () {
      expect(at(null).heat, DiskHeat.unknown);
    });

    test('bands follow the thresholds Unraid itself warns on', () {
      // 45 is Unraid's default disk temperature warning, 55 its critical.
      expect(at(29).heat, DiskHeat.cool);
      expect(at(30).heat, DiskHeat.normal);
      expect(at(44).heat, DiskHeat.normal);
      expect(at(45).heat, DiskHeat.warm);
      expect(at(54).heat, DiskHeat.warm);
      expect(at(55).heat, DiskHeat.hot);
    });
  });

  group('parity and data disks', () {
    final UnraidArray array = UnraidArray.fromJson(<String, dynamic>{
      'state': 'STARTED',
      'disks': <dynamic>[
        <String, dynamic>{'name': 'parity', 'status': 'DISK_OK', 'temp': 38},
        <String, dynamic>{'name': 'parity2', 'status': 'DISK_OK', 'temp': 51},
        <String, dynamic>{'name': 'disk1', 'status': 'DISK_OK', 'temp': 42},
        <String, dynamic>{'name': 'disk2', 'status': 'DISK_OK'},
      ],
    });

    test('parity disks are told apart by name, the only signal there is', () {
      expect(
        array.parityDisks.map((UnraidDisk d) => d.name),
        <String>['parity', 'parity2'],
      );
      expect(
        array.dataDisks.map((UnraidDisk d) => d.name),
        <String>['disk1', 'disk2'],
      );
    });

    test('a disk named like data is not mistaken for parity', () {
      const UnraidDisk d = UnraidDisk(name: 'disk1');
      expect(d.isParity, isFalse);
      expect(const UnraidDisk(name: 'parity').isParity, isTrue);
    });

    test('the warmest disk is found across parity and data alike', () {
      expect(array.warmestDisk?.name, 'parity2');
    });

    test('a disk reporting nothing cannot be the warmest', () {
      final UnraidArray idle = UnraidArray.fromJson(<String, dynamic>{
        'state': 'STARTED',
        'disks': <dynamic>[
          <String, dynamic>{'name': 'disk1', 'status': 'DISK_OK'},
        ],
      });
      expect(idle.warmestDisk, isNull);
    });
  });

  group('UnraidContainer', () {
    late List<UnraidContainer> containers;

    setUp(() {
      final Map<String, dynamic> docker =
          _data(_containersResponse)['docker'] as Map<String, dynamic>;
      containers = (docker['containers'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(UnraidContainer.fromJson)
          .toList();
    });

    test('reads every container', () {
      expect(containers, hasLength(4));
    });

    test("drops Docker's leading slash from the name", () {
      expect(containers.first.displayName, 'container_1');
    });

    test('running and exited are distinguished', () {
      expect(containers[0].isRunning, isTrue);
      expect(containers[2].isRunning, isFalse);
    });

    test('autoStart is carried through', () {
      expect(containers[0].autoStart, isFalse);
      expect(containers[1].autoStart, isTrue);
    });

    test('a healthcheck result is read from the status line', () {
      expect(containers[1].isHealthy, isTrue);
      expect(containers[0].isHealthy, isFalse);
    });

    test('an unhealthy container is still RUNNING, so state alone misses it',
        () {
      final UnraidContainer failing = UnraidContainer.fromJson(
        <String, dynamic>{
          'id': 'x',
          'names': <dynamic>['/broken'],
          'state': 'RUNNING',
          'status': 'Up 2 hours (unhealthy)',
        },
      );
      expect(failing.isRunning, isTrue);
      expect(failing.isUnhealthy, isTrue);
      expect(failing.isHealthy, isFalse);
    });

    test('status is passed through untouched, not parsed', () {
      expect(containers[3].status, 'Exited (143) 32 hours ago');
    });

    test('a container with no names falls back to its id', () {
      final UnraidContainer nameless = UnraidContainer.fromJson(
        <String, dynamic>{'id': 'abc123', 'names': <dynamic>[]},
      );
      expect(nameless.displayName, 'abc123');
    });
  });
}
