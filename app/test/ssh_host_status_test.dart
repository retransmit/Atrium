import 'dart:io';

import 'package:atrium/src/preferences.dart';
import 'package:atrium/src/terminal/docker_shell.dart';
import 'package:atrium/src/terminal/ssh_host_status.dart';
import 'package:atrium/src/terminal/terminal_hub.dart';
import 'package:core_models/core_models.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 26, 12);
  SshLoginRecord login({required bool ok, Duration ago = Duration.zero}) =>
      SshLoginRecord(
        ok: ok,
        at: now.subtract(ago),
        username: 'admin',
        message: ok ? null : 'refused',
      );

  group('dockerHostHealth', () {
    test('a refused last login turns an answering server amber', () {
      expect(
        dockerHostHealth(
          probe: Health.ok,
          lastLogin: login(ok: false),
        ),
        Health.warning,
      );
      expect(
        dockerHostHealth(
          probe: Health.ok,
          lastLogin: login(ok: true),
        ),
        Health.ok,
      );
    });

    test('an unreachable server stays red whatever the last login', () {
      expect(
        dockerHostHealth(
          probe: Health.error,
          lastLogin: login(ok: false),
        ),
        Health.error,
      );
    });
  });

  test('describeDockerHost says why, in words', () {
    String say(Health h, {SshLoginRecord? last, SshStatus? s}) =>
        describeDockerHost(
          health: h,
          session: s ?? SshStatus.disconnected,
          endpoint: const SshEndpoint('nas.lan'),
          lastLogin: last,
          now: now,
        );
    expect(
      say(Health.ok, s: SshStatus.connected),
      'Connected now to nas.lan:22',
    );
    expect(say(Health.ok), 'SSH answering - not logged in yet');
    expect(
      say(Health.ok, last: login(ok: true, ago: const Duration(hours: 2))),
      'SSH answering - last login OK 2 h ago',
    );
    expect(
      say(
        Health.warning,
        last: login(ok: false, ago: const Duration(minutes: 5)),
      ),
      'SSH answering - login refused for admin 5 min ago',
    );
    expect(
      say(Health.warning),
      'Something answers on that port, but it is not an SSH server',
    );
    expect(say(Health.error), 'Not reachable');
  });

  test('dockerIssueFor names the usual Docker problems', () {
    expect(dockerIssueFor(127, ''), 'Docker was not found on the host');
    expect(
      dockerIssueFor(
        1,
        'permission denied while trying to connect to the Docker daemon socket',
      ),
      contains('not allowed to use Docker'),
    );
    expect(
      dockerIssueFor(1, 'Cannot connect to the Docker daemon at unix://...'),
      'Docker is installed but its daemon is not running',
    );
  });

  test('login records survive a restart and can be cleared', () async {
    final Directory dir = await Directory.systemTemp.createTemp('records');
    Hive.init(dir.path);
    final Box<String> box = await Hive.openBox<String>('settings');
    addTearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });
    ProviderContainer container() => ProviderContainer(
          overrides: <Override>[settingsBoxProvider.overrideWithValue(box)],
        );

    final ProviderContainer first = container();
    await first
        .read(sshLoginRecordsProvider.notifier)
        .record('h1', login(ok: false));
    first.dispose();

    final ProviderContainer second = container();
    addTearDown(second.dispose);
    final SshLoginRecord? restored = second.read(sshLoginRecordsProvider)['h1'];
    expect(restored?.ok, isFalse);
    expect(restored?.username, 'admin');
    expect(restored?.message, 'refused');

    await second.read(sshLoginRecordsProvider.notifier).clear('h1');
    expect(second.read(sshLoginRecordsProvider), isEmpty);
    expect(box.keys.where((dynamic k) => '$k'.startsWith('sshLastLogin:')),
        isEmpty);
  });
}
