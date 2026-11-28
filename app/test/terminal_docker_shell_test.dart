import 'package:atrium/src/terminal/docker_shell.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

Instance _instance(String id, ServiceKind kind, {String hostId = ''}) =>
    Instance(
      id: id,
      name: id,
      kind: kind,
      localUrl: 'ssh://10.0.0.2',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: ''),
      dockerHostId: hostId,
    );

void main() {
  test('container names are quoted so the host shell cannot split them', () {
    expect(shellQuote("it's"), r"'it'\''s'");
    final String cmd = dockerExecShellCommand("a'b; rm -rf /");
    expect(cmd, startsWith('sh -lc '));
    // The hostile name never appears unquoted at the top level.
    expect(cmd, isNot(contains(" a'b; rm")));
    expect(cmd, contains('docker exec -it'));
  });

  test('parseDockerPs reads name, image and status per line', () {
    expect(
      parseDockerPs(
        'sonarr\tlscr.io/linuxserver/sonarr:latest\tUp 2 days\n'
        '\n'
        'qbit\tlinuxserver/qbittorrent\n',
      ),
      const <DockerContainer>[
        DockerContainer(
          name: 'sonarr',
          image: 'lscr.io/linuxserver/sonarr:latest',
          status: 'Up 2 days',
        ),
        DockerContainer(name: 'qbit', image: 'linuxserver/qbittorrent'),
      ],
    );
  });

  test('containers that look like the service rank first', () {
    const List<DockerContainer> all = <DockerContainer>[
      DockerContainer(name: 'aaa', image: 'postgres'),
      DockerContainer(name: 'torrent', image: 'linuxserver/qbittorrent'),
      DockerContainer(name: 'speedtest', image: 'speedtest-tracker'),
    ];
    expect(
      rankContainersFor(ServiceKind.qbittorrent, all).first.name,
      'torrent',
    );
    expect(
      rankContainersFor(ServiceKind.speedtestTracker, all).first.name,
      'speedtest',
    );
  });

  test('dockerHostFor prefers the named host, else the first one', () {
    final List<Instance> instances = <Instance>[
      _instance('sonarr', ServiceKind.sonarr),
      _instance('h1', ServiceKind.dockerHost),
      _instance('h2', ServiceKind.dockerHost),
    ];
    expect(dockerHostFor(instances.first, instances)?.id, 'h1');
    expect(
      dockerHostFor(_instance('s', ServiceKind.sonarr, hostId: 'h2'), instances)
          ?.id,
      'h2',
    );
    expect(
      dockerHostFor(instances.first, <Instance>[instances.first]),
      isNull,
    );
  });

  test('on-screen Ctrl and Alt encode like a hardware keyboard', () {
    expect(applyModifiers('c', ctrl: true), '\x03');
    expect(applyModifiers('C', ctrl: true), '\x03');
    expect(applyModifiers('[', ctrl: true), '\x1b');
    expect(applyModifiers('b', alt: true), '\x1bb');
    expect(applyModifiers('x'), 'x');
    // Multi-char input (paste, escape sequences) is left alone by Ctrl.
    expect(applyModifiers('ls', ctrl: true), 'ls');
  });
}
