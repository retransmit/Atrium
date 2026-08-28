import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_unraid/service_unraid.dart';

/// Captured verbatim from a live Unraid 7.3 server running one parity disk,
/// three XFS data disks and no cache pool.
///
/// An earlier version of this fixture was hand-obfuscated, and replacing the
/// real byte counts with strings like `~3TB` is what taught the models that
/// `size` was a human phrase. It is a count of kilobytes. Kept as raw JSON so
/// these tests fail if the served shape ever moves again.
const String _arrayResponse = '''
{
  "data": {
    "array": {
      "state": "STARTED",
      "capacity": {
        "kilobytes": { "free": "8487752", "used": "4195725", "total": "12683477" }
      },
      "parityCheckStatus": {
        "status": "COMPLETED", "progress": 0, "errors": null, "running": null,
        "paused": null, "correcting": null, "date": "2026-08-26T05:08:22.000Z",
        "duration": 38, "speed": "0"
      },
      "parities": [
        {"idx": 0, "name": "parity", "device": "sdb", "type": "PARITY",
         "size": 6291424, "status": "DISK_OK", "temp": 31, "fsType": null,
         "isSpinning": true, "warning": null, "critical": null, "numErrors": 0,
         "fsSize": null, "fsFree": null, "fsUsed": null}
      ],
      "disks": [
        {"idx": 1, "name": "disk1", "device": "sdc", "type": "DATA",
         "size": 5242848, "status": "DISK_OK", "temp": 31, "fsType": "xfs",
         "isSpinning": true, "warning": null, "critical": null, "numErrors": 0,
         "fsSize": 5301567, "fsFree": 1315099, "fsUsed": 3986469},
        {"idx": 2, "name": "disk2", "device": "sdd", "type": "DATA",
         "size": 4194272, "status": "DISK_OK", "temp": 31, "fsType": "xfs",
         "isSpinning": true, "warning": null, "critical": null, "numErrors": 0,
         "fsSize": 4227826, "fsFree": 4112912, "fsUsed": 114913},
        {"idx": 3, "name": "disk3", "device": "sde", "type": "DATA",
         "size": 3145696, "status": "DISK_OK", "temp": 31, "fsType": "xfs",
         "isSpinning": true, "warning": null, "critical": null, "numErrors": 0,
         "fsSize": 3154084, "fsFree": 3059741, "fsUsed": 94343}
      ],
      "caches": []
    }
  }
}
''';

/// Also captured live, covering the three states a container can report and
/// both sides of the template split: `sonarr` has one, the rest are orphaned.
const String _containersResponse = '''
{
  "data": {
    "docker": {
      "containers": [
        {"id": "srv:c1", "names": ["/old-backup"], "image": "alpine:latest",
         "state": "EXITED", "status": "Exited (0) 29 minutes ago",
         "autoStart": false, "isOrphaned": true, "isUpdateAvailable": null,
         "iconUrl": null, "webUiUrl": null, "ports": []},
        {"id": "srv:c2", "names": ["/paused-svc"], "image": "nginx:alpine",
         "state": "PAUSED", "status": "Up 29 minutes (Paused)",
         "autoStart": false, "isOrphaned": true, "isUpdateAvailable": null,
         "iconUrl": null, "webUiUrl": null,
         "ports": [{"privatePort": 80, "publicPort": null, "type": "TCP"}]},
        {"id": "srv:c3", "names": ["/sonarr"], "image": "nginx:alpine",
         "state": "RUNNING", "status": "Up 53 seconds", "autoStart": true,
         "isOrphaned": false, "isUpdateAvailable": null,
         "iconUrl": "https://example.invalid/sonarr.png",
         "webUiUrl": "http://10.0.2.15:8989/",
         "ports": [{"privatePort": 80, "publicPort": 8989, "type": "TCP"}]}
      ]
    }
  }
}
''';

Map<String, dynamic> _data(String raw) =>
    (jsonDecode(raw) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

UnraidArray _liveArray() => UnraidArray.fromJson(
      _data(_arrayResponse)['array'] as Map<String, dynamic>,
    );

void main() {
  group('UnraidArray', () {
    late UnraidArray array;

    setUp(() => array = _liveArray());

    test('reads state and every disk list', () {
      expect(array.state, 'STARTED');
      expect(array.isStarted, isTrue);
      expect(array.parities, hasLength(1));
      expect(array.disks, hasLength(3));
      expect(array.caches, isEmpty);
      expect(array.allDisks, hasLength(4));
    });

    test('parity is not folded into the data disks', () {
      // The bug this whole rewrite came from: the server never puts parity in
      // `disks`, so a screen reading only that list loses it without a word.
      expect(
        array.disks.map((UnraidDisk d) => d.name),
        <String>['disk1', 'disk2', 'disk3'],
      );
      expect(array.parities.single.name, 'parity');
      expect(array.disks.any((UnraidDisk d) => d.isParity), isFalse);
    });

    test('state is shown as a word, not the raw enum', () {
      expect(array.stateLabel, 'Started');
      expect(const UnraidArray(state: 'STOPPED').stateLabel, 'Stopped');
      expect(
        const UnraidArray(state: 'TOO_MANY_MISSING_DISKS').stateLabel,
        'Too many missing disks',
      );
    });

    test('capacity arrives as strings and still reads as numbers', () {
      // Unlike the sizes on the disks, these are declared String in the
      // schema, so parsing them is not optional.
      expect(array.totalKb, 12683477);
      expect(array.usedKb, 4195725);
      expect(array.freeKb, 8487752);
      expect(array.usageLabel, '4.0 GB of 12.1 GB');
      expect(array.usedFraction, closeTo(0.33, 0.01));
    });

    test('an array reporting no total has no fill rather than an empty one',
        () {
      // A freshly formatted array reports zero, and dividing by it would draw
      // a bar saying there is room when nothing is known.
      const UnraidArray blank =
          UnraidArray(state: 'STARTED', totalKb: 0, usedKb: 0);
      expect(blank.usedFraction, isNull);
      expect(blank.usageLabel, isNull);
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

    test('a fault on parity or cache counts too, not just on a data disk', () {
      final UnraidArray withFault = UnraidArray.fromJson(<String, dynamic>{
        'state': 'STARTED',
        'parities': <dynamic>[
          <String, dynamic>{'name': 'parity', 'status': 'DISK_DSBL'},
        ],
        'disks': <dynamic>[
          <String, dynamic>{'name': 'disk1', 'status': 'DISK_OK'},
        ],
        'caches': <dynamic>[
          <String, dynamic>{'name': 'cache', 'status': 'DISK_WRONG'},
        ],
      });
      expect(
        withFault.unhealthyDisks.map((UnraidDisk d) => d.name),
        <String>['parity', 'cache'],
      );
    });

    test('an unrecognised status is not treated as healthy', () {
      // The case that matters: a status this app has never seen is exactly
      // when it must not reassure anyone.
      const UnraidDisk unknown = UnraidDisk(name: 'd', status: 'DISK_SOMETHING');
      expect(unknown.isHealthy, isFalse);
      expect(unknown.statusLabel, 'DISK_SOMETHING');
    });

    test('every status the schema declares has words of its own', () {
      const List<String> declared = <String>[
        'DISK_NP',
        'DISK_OK',
        'DISK_NP_MISSING',
        'DISK_INVALID',
        'DISK_WRONG',
        'DISK_DSBL',
        'DISK_NP_DSBL',
        'DISK_DSBL_NEW',
        'DISK_NEW',
      ];
      for (final String status in declared) {
        expect(
          UnraidDisk(name: 'd', status: status).statusLabel,
          isNot(status),
          reason: '$status still shows as the raw enum',
        );
      }
    });

    test('a spun-down disk reports no temperature rather than zero', () {
      final UnraidDisk parked = UnraidDisk.fromJson(<String, dynamic>{
        'name': 'disk9',
        'status': 'DISK_OK',
      });
      expect(parked.temp, isNull);
      expect(parked.isHealthy, isTrue);
    });

    test('the warmest disk is found across parity, data and cache alike', () {
      final UnraidArray mixed = UnraidArray.fromJson(<String, dynamic>{
        'state': 'STARTED',
        'parities': <dynamic>[
          <String, dynamic>{'name': 'parity', 'temp': 51},
        ],
        'disks': <dynamic>[
          <String, dynamic>{'name': 'disk1', 'temp': 42},
        ],
        'caches': <dynamic>[
          <String, dynamic>{'name': 'cache', 'temp': 47},
        ],
      });
      expect(mixed.warmestDisk?.name, 'parity');
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

  group('disk size and usage', () {
    late UnraidArray array;

    setUp(() => array = _liveArray());

    test('size is a count of kilobytes, not a phrase', () {
      final UnraidDisk disk1 = array.disks.first;
      expect(disk1.sizeKb, 5242848);
      expect(disk1.sizeLabel, '5.0 GB');
      expect(array.parities.single.sizeLabel, '6.0 GB');
    });

    test('a BigInt is read whether it comes as a number or a string', () {
      // The scalar is serialised as a number while it fits one exactly and as
      // a string once it does not, so a disk big enough to matter is the one
      // that arrives in the other form.
      final UnraidDisk asNumber =
          UnraidDisk.fromJson(<String, dynamic>{'name': 'a', 'size': 20000000000});
      final UnraidDisk asString = UnraidDisk.fromJson(
        <String, dynamic>{'name': 'b', 'size': '20000000000'},
      );
      expect(asNumber.sizeKb, 20000000000);
      expect(asString.sizeKb, 20000000000);
      expect(asString.sizeLabel, asNumber.sizeLabel);
      expect(asString.sizeLabel, '18.6 TB');
    });

    test('a size the server did not send renders as nothing, not as zero', () {
      const UnraidDisk unsized = UnraidDisk(name: 'd');
      expect(unsized.sizeKb, isNull);
      expect(unsized.sizeLabel, '');
    });

    test('filesystem usage is read off the disk', () {
      final UnraidDisk disk1 = array.disks.first;
      expect(disk1.fsType, 'xfs');
      expect(disk1.usedFraction, closeTo(0.75, 0.01));
      expect(disk1.usageLabel, '3.8 GB of 5.1 GB');
    });

    test('a parity disk has no filesystem and so no bar to draw', () {
      // Drawing an empty bar for parity would read as free space it does not
      // have: it holds no filesystem at all.
      final UnraidDisk parity = array.parities.single;
      expect(parity.fsType, isNull);
      expect(parity.usedFraction, isNull);
      expect(parity.usageLabel, isNull);
    });

    test('an unformatted disk reports no usage either', () {
      final UnraidDisk blank = UnraidDisk.fromJson(<String, dynamic>{
        'name': 'disk4',
        'size': 4194272,
        'fsSize': 0,
        'fsUsed': 0,
      });
      expect(blank.usedFraction, isNull);
      expect(blank.sizeLabel, '4.0 GB');
    });
  });

  group('disk temperature bands', () {
    UnraidDisk at(int? c) => UnraidDisk(name: 'd', status: 'DISK_OK', temp: c);

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

    test('a disk with its own thresholds is judged by those', () {
      // Unraid lets a disk override the server defaults, and a disk this app
      // calls warm should be the same one the server would email about.
      const UnraidDisk cool = UnraidDisk(
        name: 'ssd',
        temp: 50,
        warning: 60,
        critical: 70,
      );
      expect(cool.heat, DiskHeat.normal);
      const UnraidDisk fussy = UnraidDisk(
        name: 'old',
        temp: 40,
        warning: 35,
        critical: 45,
      );
      expect(fussy.heat, DiskHeat.warm);
    });
  });

  group('UnraidParityCheck', () {
    late UnraidParityCheck check;

    setUp(() => check = _liveArray().parityCheck!);

    test('reads the last check off the array', () {
      expect(check.status, 'COMPLETED');
      expect(check.statusLabel, 'Completed');
      expect(check.duration, 38);
      expect(check.date?.year, 2026);
    });

    test('a null running flag does not make a finished check look live', () {
      // A live server leaves running, paused and correcting null unless a
      // check is in progress, so none of them can stand in for the status.
      expect(check.running, isNull);
      expect(check.isRunning, isFalse);
      expect(check.isPaused, isFalse);
    });

    test('a running check is recognised from the status alone', () {
      final UnraidParityCheck live = UnraidParityCheck.fromJson(
        <String, dynamic>{'status': 'RUNNING', 'progress': 42},
      );
      expect(live.isRunning, isTrue);
      expect(live.progress, 42);
    });

    test('errors are only reported when there actually are some', () {
      expect(check.foundErrors, isFalse);
      final UnraidParityCheck bad = UnraidParityCheck.fromJson(
        <String, dynamic>{'status': 'COMPLETED', 'errors': 3},
      );
      expect(bad.foundErrors, isTrue);
    });

    test('a check that never ran says so rather than reading as clean', () {
      final UnraidParityCheck never = UnraidParityCheck.fromJson(
        <String, dynamic>{'status': 'NEVER_RUN'},
      );
      expect(never.statusLabel, 'Never run');
      expect(never.foundErrors, isFalse);
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
      expect(containers, hasLength(3));
    });

    test("drops Docker's leading slash from the name", () {
      expect(containers.first.displayName, 'old-backup');
    });

    test('paused is its own state, neither running nor plainly stopped', () {
      // Folding paused into either would misreport what resuming it does.
      final UnraidContainer paused = containers[1];
      expect(paused.isPaused, isTrue);
      expect(paused.isRunning, isFalse);
      expect(paused.isStopped, isTrue);
    });

    test('running and exited are distinguished', () {
      expect(containers[2].isRunning, isTrue);
      expect(containers[0].isRunning, isFalse);
      expect(containers[0].isPaused, isFalse);
    });

    test('autoStart is carried through', () {
      expect(containers[0].autoStart, isFalse);
      expect(containers[2].autoStart, isTrue);
    });

    test('a container with a template keeps its icon and web link', () {
      final UnraidContainer sonarr = containers[2];
      expect(sonarr.isOrphaned, isFalse);
      expect(sonarr.iconUrl, isNotNull);
      expect(sonarr.webUiUrl, 'http://10.0.2.15:8989/');
    });

    test('an orphaned container has neither, which is not an error', () {
      // Anything created outside the web UI has no template, so this is the
      // normal case rather than something to warn about.
      final UnraidContainer orphan = containers[0];
      expect(orphan.isOrphaned, isTrue);
      expect(orphan.iconUrl, isNull);
    });

    test('only published ports are listed', () {
      // A port the container exposes but does not publish cannot be reached
      // from outside the host, so offering it would send someone nowhere.
      expect(containers[2].publishedPortsLabel, '8989');
      expect(containers[1].ports, hasLength(1));
      expect(containers[1].publishedPortsLabel, isNull);
      expect(containers[0].publishedPortsLabel, isNull);
    });

    test('a healthcheck result is read from the status line', () {
      final UnraidContainer healthy = UnraidContainer.fromJson(
        <String, dynamic>{
          'id': 'x',
          'names': <dynamic>['/ok'],
          'state': 'RUNNING',
          'status': 'Up 24 hours (healthy)',
        },
      );
      expect(healthy.isHealthy, isTrue);
      expect(containers[2].isHealthy, isFalse);
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
      expect(containers[0].status, 'Exited (0) 29 minutes ago');
    });

    test('the id keeps both halves, which is what a mutation takes', () {
      // Unraid identifies a container by server id and container id together;
      // sending the bare Docker id back is refused.
      expect(containers.first.id, 'srv:c1');
    });

    test('an image is split into name and tag', () {
      final UnraidContainer c = UnraidContainer.fromJson(<String, dynamic>{
        'id': 'x',
        'names': <dynamic>['/sonarr'],
        'image': 'lscr.io/linuxserver/sonarr:latest',
      });
      expect(c.imageName, 'lscr.io/linuxserver/sonarr');
      expect(c.imageTag, 'latest');
    });

    test('a registry port is not mistaken for a tag', () {
      // `host:5000/img` has a colon that is nothing to do with the tag, so
      // splitting on the last colon alone would cut the registry in half.
      final UnraidContainer c = UnraidContainer.fromJson(<String, dynamic>{
        'id': 'x',
        'names': <dynamic>['/thing'],
        'image': 'registry.local:5000/team/thing',
      });
      expect(c.imageName, 'registry.local:5000/team/thing');
      expect(c.imageTag, isNull);
    });

    test('created is read as seconds, not milliseconds', () {
      // Off by a factor of a thousand puts the container in 1970.
      final UnraidContainer c = UnraidContainer.fromJson(<String, dynamic>{
        'id': 'x',
        'names': <dynamic>['/a'],
        'created': 1787721305,
      });
      expect(c.createdAt?.year, 2026);
    });

    test('only published ports become mappings', () {
      final UnraidContainer c = UnraidContainer.fromJson(<String, dynamic>{
        'id': 'x',
        'names': <dynamic>['/a'],
        'ports': <dynamic>[
          <String, dynamic>{
            'privatePort': 80,
            'publicPort': 8989,
            'type': 'TCP',
          },
          // Exposed but not published: nothing outside can reach it.
          <String, dynamic>{'privatePort': 6767, 'type': 'TCP'},
          <String, dynamic>{
            'privatePort': 53,
            'publicPort': 5353,
            'type': 'UDP',
          },
        ],
      });
      expect(c.portMappings, <String>['8989 -> 80', '5353 -> 53 udp']);
    });

    test('a container with no names falls back to its id', () {
      final UnraidContainer nameless = UnraidContainer.fromJson(
        <String, dynamic>{'id': 'abc123', 'names': <dynamic>[]},
      );
      expect(nameless.displayName, 'abc123');
    });
  });

  group('UnraidMetrics', () {
    /// Captured live. The numbers matter to each other: `used` counts cache,
    /// `available` does not, and `total - available` equals `active`.
    const String raw = '''
{
  "cpu": {
    "percentTotal": 1.22975988158272,
    "cpus": [
      {"percentTotal": 1.235, "percentUser": 0.641, "percentSystem": 0.593,
       "percentIdle": 98.764},
      {"percentTotal": 1.234, "percentUser": 0.612, "percentSystem": 0.622,
       "percentIdle": 98.765}
    ]
  },
  "memory": {
    "total": 4113248256, "used": 3367780352, "free": 745467904,
    "available": 3124817920, "buffcache": 2854338560,
    "percentTotal": 24.03040795211365,
    "swapTotal": 0, "swapUsed": 0, "percentSwapTotal": 0
  },
  "network": [
    {"name": "lo", "operstate": "up", "rxSec": 900000, "txSec": 900000},
    {"name": "br0", "operstate": "up", "rxSec": 1024, "txSec": 2048},
    {"name": "eth0", "operstate": "up", "rxSec": 512, "txSec": 256},
    {"name": "docker0", "operstate": "up", "rxSec": 700000, "txSec": 700000},
    {"name": "veth1a2b", "operstate": "up", "rxSec": 800000, "txSec": 800000},
    {"name": "eth1", "operstate": "down", "rxSec": 999, "txSec": 999}
  ]
}
''';

    late UnraidMetrics metrics;

    setUp(() {
      metrics = UnraidMetrics.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    });

    test('cpu load and per-core figures are read', () {
      expect(metrics.cpu?.percentTotal, closeTo(1.23, 0.01));
      expect(metrics.cpu?.coreCount, 2);
      expect(metrics.cpu?.cores.first.percentIdle, closeTo(98.76, 0.01));
    });

    test('the busiest core is reported, which the average hides', () {
      // One core pinned while the rest idle is a single-threaded job holding
      // everything up, and the average alone reads as a quiet machine.
      const UnraidCpu lopsided = UnraidCpu(
        percentTotal: 25,
        cores: <UnraidCpuCore>[
          UnraidCpuCore(percentTotal: 99),
          UnraidCpuCore(percentTotal: 1),
          UnraidCpuCore(percentTotal: 0),
          UnraidCpuCore(percentTotal: 0),
        ],
      );
      expect(lopsided.busiestCorePercent, 99);
      expect(lopsided.percentTotal, 25);
    });

    test('a cpu reporting no cores has no peak rather than zero', () {
      expect(const UnraidCpu(percentTotal: 5).busiestCorePercent, isNull);
    });

    test('memory in use excludes cache, which Linux hands straight back', () {
      // This is the whole point. Reading `used` puts a machine at 82% when it
      // is at 24%, and 82% is the number that makes someone go buy RAM.
      final UnraidMemory mem = metrics.memory!;
      expect(mem.usedBytes, 3367780352);
      expect(mem.inUseBytes, 4113248256 - 3124817920);
      expect(mem.inUseBytes, 988430336);
      expect(mem.usedBytes! / mem.totalBytes! * 100, closeTo(81.88, 0.01));
      expect(mem.usedFraction! * 100, closeTo(24.03, 0.01));
    });

    test('the bar and the number beside it come from the same figure', () {
      final UnraidMemory mem = metrics.memory!;
      expect(mem.usedFraction! * 100, closeTo(mem.percentUsed!, 0.001));
      expect(mem.usageLabel, '943 MB of 3.8 GB');
    });

    test('memory falls back to computing the percentage itself', () {
      // An older server might not send percentTotal; the bar still has to fill.
      final UnraidMemory mem = UnraidMemory.fromJson(<String, dynamic>{
        'total': 1000,
        'available': 250,
      });
      expect(mem.percentUsed, isNull);
      expect(mem.usedFraction, closeTo(0.75, 0.001));
    });

    test('a machine with no swap has no swap bar to draw', () {
      expect(metrics.memory?.hasSwap, isFalse);
      expect(metrics.memory?.swapFraction, isNull);
    });

    test('swap is reported when there is some', () {
      final UnraidMemory mem = UnraidMemory.fromJson(<String, dynamic>{
        'swapTotal': 2048,
        'swapUsed': 512,
        'percentSwapTotal': 25,
      });
      expect(mem.hasSwap, isTrue);
      expect(mem.swapFraction, closeTo(0.25, 0.001));
    });

    test('loopback and container bridges are kept out of the totals', () {
      // They carry traffic that never leaves the machine. Counting them puts
      // the throughput figure orders of magnitude out.
      expect(
        metrics.physicalInterfaces.map((UnraidNetworkInterface n) => n.name),
        <String>['br0', 'eth0'],
      );
      expect(metrics.rxBytesPerSec, 1024 + 512);
      expect(metrics.txBytesPerSec, 2048 + 256);
    });

    test('an interface that is down carries nothing, whatever it reports', () {
      final UnraidNetworkInterface down = metrics.network
          .firstWhere((UnraidNetworkInterface n) => n.name == 'eth1');
      expect(down.isUp, isFalse);
      expect(metrics.physicalInterfaces.contains(down), isFalse);
    });

    test('a server that sends no metrics parses to nothing, not to zero', () {
      final UnraidMetrics empty =
          UnraidMetrics.fromJson(<String, dynamic>{});
      expect(empty.cpu, isNull);
      expect(empty.memory, isNull);
      expect(empty.network, isEmpty);
      expect(empty.physicalInterfaces, isEmpty);
    });
  });

  group('UnraidSystemInfo', () {
    /// Captured live. `os.uptime` is a boot timestamp, not a span, and the
    /// baseboard fields come back as empty strings on a virtual machine.
    const String raw = '''
{
  "time": "2026-08-27T19:12:57.084Z",
  "os": {
    "distro": "Unraid OS", "release": "7.3 x86_64",
    "kernel": "6.18.38-Unraid", "hostname": "Tower",
    "uptime": "2026-08-27T19:01:03.024Z", "uefi": true
  },
  "cpu": {
    "manufacturer": "AMD", "brand": "Ryzen 7 6800H with Radeon Graphics",
    "cores": 4, "threads": 4, "processors": 1
  },
  "baseboard": {
    "manufacturer": "", "model": "", "memMax": 4294967296, "memSlots": 1
  },
  "system": {
    "manufacturer": "QEMU", "model": "Standard PC (Q35 + ICH9, 2009)",
    "virtual": true
  },
  "versions": { "core": { "unraid": "7.3.2" } }
}
''';

    late UnraidSystemInfo info;

    setUp(() {
      info = UnraidSystemInfo.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    });

    test('uptime is worked out, because the field carries a boot time', () {
      // Reading os.uptime straight would put a date on screen where a
      // duration belongs.
      expect(info.bootTime, isNotNull);
      expect(info.uptime, const Duration(minutes: 11, seconds: 54, milliseconds: 60));
      expect(info.uptimeLabel, '11 minutes');
    });

    test('it measures against the server clock, not the phone\'s', () {
      // A device running fast would otherwise invent uptime out of nothing.
      expect(info.serverTime, isNotNull);
      final UnraidSystemInfo noClock = UnraidSystemInfo.fromJson(
        <String, dynamic>{
          'os': <String, dynamic>{'uptime': '2026-08-27T19:01:03.024Z'},
        },
      );
      expect(noClock.uptime, isNull);
      expect(noClock.uptimeLabel, '');
    });

    test('a clock that disagrees gives no uptime rather than a silly one', () {
      final UnraidSystemInfo skewed = UnraidSystemInfo.fromJson(
        <String, dynamic>{
          'time': '2026-08-27T19:00:00.000Z',
          'os': <String, dynamic>{'uptime': '2026-08-27T19:01:03.024Z'},
        },
      );
      expect(skewed.uptime, isNull);
    });

    test('a blank board reads as absent, not as an empty row', () {
      // The server sends "" rather than null here, which a ?? would keep.
      expect(info.boardManufacturer, isNull);
      expect(info.boardModel, isNull);
      expect(info.boardLabel, isNull);
    });

    test('a real board is joined into one line', () {
      final UnraidSystemInfo bare = UnraidSystemInfo.fromJson(
        <String, dynamic>{
          'baseboard': <String, dynamic>{
            'manufacturer': 'ASUSTeK COMPUTER INC.',
            'model': 'PRIME X570-P',
          },
        },
      );
      expect(bare.boardLabel, 'ASUSTeK COMPUTER INC. PRIME X570-P');
    });

    test('processor and core counts read as words', () {
      expect(info.cpuLabel, 'Ryzen 7 6800H with Radeon Graphics');
      // Threads equal to cores says nothing extra, so it is left off.
      expect(info.coreLabel, '4 cores');
      expect(
        UnraidSystemInfo.fromJson(<String, dynamic>{
          'cpu': <String, dynamic>{'cores': 8, 'threads': 16},
        }).coreLabel,
        '8 cores, 16 threads',
      );
    });

    test('memory capacity describes headroom, which is what is reported', () {
      // memMax is the most the board takes, not the amount fitted.
      expect(info.memoryCapacityLabel, 'up to 4.0 GB across 1 slot');
    });

    test('the version prefers Unraid\'s own number', () {
      expect(info.osLabel, 'Unraid 7.3.2');
      expect(
        UnraidSystemInfo.fromJson(<String, dynamic>{
          'os': <String, dynamic>{'distro': 'Unraid OS', 'release': '7.2'},
        }).osLabel,
        'Unraid OS 7.2',
      );
    });

    test('a virtualised server says so', () {
      expect(info.isVirtual, isTrue);
    });

    test('an empty response parses to nothing rather than throwing', () {
      final UnraidSystemInfo empty =
          UnraidSystemInfo.fromJson(<String, dynamic>{});
      expect(empty.cpuLabel, isNull);
      expect(empty.uptime, isNull);
      expect(empty.boardLabel, isNull);
      expect(empty.memoryCapacityLabel, isNull);
    });
  });

  group('unraidFmtUptime', () {
    test('reads the way a server uptime is usually quoted', () {
      expect(unraidFmtUptime(null), '');
      expect(unraidFmtUptime(const Duration(seconds: 20)), 'just now');
      expect(unraidFmtUptime(const Duration(minutes: 1)), '1 minute');
      expect(unraidFmtUptime(const Duration(minutes: 41)), '41 minutes');
      expect(unraidFmtUptime(const Duration(hours: 3)), '3h');
      expect(unraidFmtUptime(const Duration(hours: 3, minutes: 12)), '3h 12m');
      expect(unraidFmtUptime(const Duration(days: 1)), '1 day');
      expect(unraidFmtUptime(const Duration(days: 9)), '9 days');
      // Minutes stop mattering once it has been up for days.
      expect(unraidFmtUptime(const Duration(days: 9, hours: 4, minutes: 30)),
          '9d 4h',);
    });
  });

  group('unraidFmtBytes', () {
    test('memory is scaled from bytes, not kilobytes', () {
      // The array reports kilobytes and the metrics endpoint reports bytes.
      // Running one through the other is a silent 1024x error.
      expect(unraidFmtBytes(0), '0 B');
      expect(unraidFmtBytes(988430336), '943 MB');
      expect(unraidFmtBytes(4113248256), '3.8 GB');
      expect(unraidFmtKb(4113248256), '3.8 TB');
    });

    test('nothing to show renders as nothing', () {
      expect(unraidFmtBytes(null), '');
    });
  });

  group('unraidFmtKb', () {
    test('scales kilobytes up the way the server prints them', () {
      expect(unraidFmtKb(0), '0 KB');
      expect(unraidFmtKb(512), '512 KB');
      expect(unraidFmtKb(2048), '2.0 MB');
      expect(unraidFmtKb(5242848), '5.0 GB');
      expect(unraidFmtKb(12683477), '12.1 GB');
    });

    test('nothing to show renders as nothing, not as zero', () {
      expect(unraidFmtKb(null), '');
    });
  });
}
