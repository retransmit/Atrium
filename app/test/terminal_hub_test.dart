import 'dart:io';

import 'package:atrium/src/terminal/ssh_connector.dart';
import 'package:atrium/src/terminal/terminal_hub.dart';
import 'package:core_models/core_models.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const Instance _host = Instance(
  id: 'h1',
  name: 'NAS',
  kind: ServiceKind.dockerHost,
  localUrl: 'ssh://10.0.0.2',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.ssh(username: 'admin', password: 'pw'),
);

void main() {
  late TerminalHub hub;

  setUp(() async {
    final Directory dir = await Directory.systemTemp.createTemp('hub');
    Hive.init(dir.path);
    final Box<String> box = await Hive.openBox<String>('settings');
    hub = TerminalHub(KnownHostsStore(box));
    addTearDown(() async {
      hub.dispose();
      await Hive.close();
      await dir.delete(recursive: true);
    });
  });

  test('a renamed host keeps its session', () {
    hub.syncHosts(<Instance>[_host]);
    final HostSession session = hub.session('h1');
    hub.syncHosts(<Instance>[_host.copyWith(name: 'Server')]);
    expect(hub.session('h1'), same(session));
  });

  test('an edited login or address replaces the session', () {
    hub.syncHosts(<Instance>[_host]);
    final HostSession first = hub.session('h1');
    hub.syncHosts(<Instance>[
      _host.copyWith(
        auth: const InstanceAuth.ssh(username: 'admin', password: 'new'),
      ),
    ]);
    final HostSession second = hub.session('h1');
    expect(second, isNot(same(first)));

    hub.syncHosts(<Instance>[_host.copyWith(localUrl: 'ssh://10.0.0.3')]);
    expect(hub.session('h1'), isNot(same(second)));
  });

  test('a host that leaves the profile loses its session', () {
    hub.syncHosts(<Instance>[_host]);
    final HostSession session = hub.session('h1');
    hub.syncHosts(const <Instance>[]);
    expect(hub.session('h1'), isNot(same(session)));
  });
}
