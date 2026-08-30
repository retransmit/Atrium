@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_unraid/service_unraid.dart';

/// Drives [UnraidClient] against a real Unraid server.
///
/// The fixture tests prove the models can read a response that was captured
/// once. This proves they can read the one the server is serving now, which is
/// where the last round of breakage came from: the fixture had been
/// hand-obfuscated, so it agreed with models that a live server did not.
///
/// Not part of the normal suite. Needs UNRAID_URL and UNRAID_KEY, and reads
/// only, so running it cannot disturb a real server.
void main() {
  final String url = Platform.environment['UNRAID_URL'] ?? '';
  final String key = Platform.environment['UNRAID_KEY'] ?? '';

  if (url.isEmpty || key.isEmpty) {
    test('skipped: no live server configured', () {}, skip: true);
    return;
  }

  late UnraidClient client;

  setUpAll(() {
    client = UnraidClient(
      Dio(
        BaseOptions(
          baseUrl: url,
          headers: <String, String>{'X-Api-Key': key},
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
        ),
      ),
    );
  });

  test('the array parses off a real server', () async {
    final UnraidArray array = await client.getArray();

    // ignore: avoid_print
    print('\n  state: ${array.state}'
        '\n  parity: ${array.parities.length}, data: ${array.disks.length}, '
        'cache: ${array.caches.length}'
        '\n  usage: ${array.usageLabel}');

    expect(array.state, isNotEmpty);
    expect(array.disks, isNotEmpty, reason: 'no data disks came back');

    for (final UnraidDisk d in array.allDisks) {
      expect(d.name, isNotEmpty, reason: 'a disk arrived with no name');
      // The defect that started this: a size read as a string parsed to null
      // and rendered as nothing at all.
      expect(
        d.sizeKb,
        isNotNull,
        reason: '${d.name} lost its size, so it would render blank',
      );
      expect(
        d.sizeLabel,
        isNot(equals('${d.sizeKb}')),
        reason: '${d.name} would show a raw kilobyte count',
      );
      // ignore: avoid_print
      print('  ${d.name.padRight(8)} ${d.type} ${d.sizeLabel.padLeft(9)} '
          '${d.statusLabel} ${d.usageLabel ?? ''}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)),);

  test('parity comes back in its own list, not mixed into the data disks',
      () async {
    final UnraidArray array = await client.getArray();

    // A server with no parity disk cannot prove anything either way, so say
    // so rather than passing quietly.
    if (array.parities.isEmpty) {
      // ignore: avoid_print
      print('  server has no parity disk; nothing to check');
      return;
    }
    expect(
      array.disks.where((UnraidDisk d) => d.isParity),
      isEmpty,
      reason: 'a parity disk turned up in the data list',
    );
    for (final UnraidDisk p in array.parities) {
      expect(p.isParity, isTrue, reason: '${p.name} is not typed as parity');
      expect(
        p.usedFraction,
        isNull,
        reason: 'parity has no filesystem, so it must not draw a usage bar',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)),);

  test('metrics parse, and memory is not read as full when it is not',
      () async {
    final UnraidMetrics m = await client.getMetrics();

    final UnraidCpu? cpu = m.cpu;
    final UnraidMemory? mem = m.memory;
    expect(cpu, isNotNull, reason: 'no cpu metrics came back');
    expect(mem, isNotNull, reason: 'no memory metrics came back');
    expect(cpu!.percentTotal, isNotNull);
    expect(cpu.cores, isNotEmpty, reason: 'no per-core figures');

    // The trap: Linux counts buffers and cache in `used`, so reading that as
    // memory in use reports a machine near full when it is nowhere near.
    final int? naive = mem!.usedBytes;
    final int? real = mem.inUseBytes;
    expect(real, isNotNull);
    expect(
      real,
      lessThanOrEqualTo(naive ?? real!),
      reason: 'committed memory cannot exceed what Linux calls used',
    );

    // Whatever the app draws has to agree with the server's own percentage.
    final double? fraction = mem.usedFraction;
    expect(fraction, isNotNull);
    expect(
      fraction! * 100,
      closeTo(mem.percentUsed ?? -1, 1.0),
      reason: 'the bar would disagree with the number beside it',
    );

    // ignore: avoid_print
    print('\n  cpu ${cpu.percentTotal!.toStringAsFixed(1)}% over '
        '${cpu.coreCount} cores'
        '\n  memory ${(fraction * 100).toStringAsFixed(1)}% '
        '(${mem.usageLabel})'
        '\n  naive used/total would read '
        '${(naive! / mem.totalBytes! * 100).toStringAsFixed(1)}%'
        '\n  swap: ${mem.hasSwap ? mem.swapFraction : 'none'}');
    for (final UnraidNetworkInterface n in m.physicalInterfaces) {
      // ignore: avoid_print
      print('  net ${n.name}: rx ${n.rxBytesPerSec} tx ${n.txBytesPerSec}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)),);

  test('system info parses, and uptime is worked out not read', () async {
    final UnraidSystemInfo info = await client.getSystemInfo();

    // ignore: avoid_print
    print('\n  cpu: ${info.cpuLabel} (${info.coreLabel})'
        '\n  os: ${info.osLabel}, kernel ${info.kernel}'
        '\n  host: ${info.hostname}, virtual: ${info.isVirtual}'
        '\n  board: ${info.boardLabel ?? '(none reported)'}'
        '\n  memory: ${info.memoryCapacityLabel ?? '(not reported)'}'
        '\n  booted: ${info.bootTime}  server clock: ${info.serverTime}'
        '\n  uptime: ${info.uptimeLabel}');

    expect(info.cpuLabel, isNotNull, reason: 'no processor reported');
    expect(info.osLabel, isNotNull);

    // The field is called uptime but carries the moment of boot, so a naive
    // read would print a date where a duration belongs.
    expect(info.bootTime, isNotNull);
    expect(info.serverTime, isNotNull);
    expect(
      info.uptime,
      isNotNull,
      reason: 'uptime could not be derived from boot time and server clock',
    );
    expect(info.uptime!.isNegative, isFalse);
    expect(
      info.uptimeLabel,
      isNot(contains('20')),
      reason: 'a year in the label means the timestamp reached the screen raw',
    );

    // Blank strings are what a virtual machine sends for its board, and they
    // must read as absent rather than as an empty row.
    if (info.boardLabel != null) {
      expect(info.boardLabel!.trim(), isNotEmpty);
    }
  }, timeout: const Timeout(Duration(minutes: 2)),);

  test('a server with virtualisation off reports it rather than failing',
      () async {
    // Unraid ships the VM manager off, so this refusal is the ordinary case
    // for most servers. Raised rather than reported, it would take the tab
    // down for the majority who do not run VMs.
    final UnraidVmList vms = await client.getVms();

    // ignore: avoid_print
    print('\n  VM manager enabled: ${vms.enabled}, ${vms.vms.length} machines');
    for (final UnraidVm v in vms.vms) {
      // ignore: avoid_print
      print('  ${v.displayName}: ${v.stateLabel}');
      expect(v.id, isNotEmpty);
      expect(
        v.stateLabel,
        isNot(equals(v.state)),
        reason: '${v.displayName} shows libvirt\'s own word for its state',
      );
    }
    if (!vms.enabled) {
      expect(vms.vms, isEmpty);
    }
  }, timeout: const Timeout(Duration(minutes: 2)),);

  test('every container parses, whatever state it is in', () async {
    final List<UnraidContainer> containers = await client.getContainers();

    // ignore: avoid_print
    print('\n  ${containers.length} containers');
    for (final UnraidContainer c in containers) {
      expect(c.id, isNotEmpty, reason: 'a container arrived with no id');
      expect(
        c.displayName,
        isNot(startsWith('/')),
        reason: "Docker's leading slash reached the screen",
      );
      // Every state must land somewhere: a state this app has not seen would
      // otherwise read as stopped and offer the wrong button.
      expect(
        c.isRunning || c.isPaused || c.state == 'EXITED',
        isTrue,
        reason: '${c.displayName} reports an unhandled state: ${c.state}',
      );
      // ignore: avoid_print
      print('  ${c.displayName.padRight(14)} ${c.state} '
          '${c.publishedPortsLabel ?? ''}'
          '${c.isOrphaned ? ' (no template)' : ''}');
    }
  }, timeout: const Timeout(Duration(minutes: 2)),);
}
