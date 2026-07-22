import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backward-compatibility guarantees for the profile JSON on disk.
///
/// Old profiles (and old exports) carry none of the header / Wake-on-LAN
/// keys; they must keep deserializing with empty defaults. New profiles must
/// round-trip through the same encode path the repository uses
/// (`jsonEncode(profile.toJson())`).
void main() {
  test('Profile.fromJson without new keys falls back to defaults', () {
    final Profile profile = Profile.fromJson(<String, dynamic>{
      'id': 'p1',
      'name': 'Default',
      'instances': <dynamic>[],
    });

    expect(profile.globalHeaders, const <String, String>{});
    expect(profile.wolDevices, const <WolDevice>[]);
  });

  test('round-trip preserves headers and WOL devices', () {
    const Profile profile = Profile(
      id: 'p1',
      name: 'Default',
      instances: <Instance>[
        Instance(
          id: 'i1',
          name: 'Sonarr',
          kind: ServiceKind.sonarr,
          localUrl: 'http://192.168.1.10:8989',
          externalUrl: '',
          urlMode: UrlMode.auto,
          auth: InstanceAuth.apiKey(apiKey: ''),
          customHeaders: <String, String>{'X-Instance': 'sonarr'},
        ),
      ],
      globalHeaders: <String, String>{'X-Proxy-Auth': 'token'},
      wolDevices: <WolDevice>[
        WolDevice(
          id: 'w1',
          name: 'NAS',
          mac: 'AA:BB:CC:DD:EE:FF',
          broadcastAddress: '192.168.1.255',
          port: 7,
        ),
      ],
    );

    // Same path the repository uses: encode to a JSON string, decode back.
    final String raw = jsonEncode(profile.toJson());
    final Profile decoded =
        Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(
      decoded.globalHeaders,
      const <String, String>{'X-Proxy-Auth': 'token'},
    );
    expect(decoded.wolDevices, hasLength(1));
    expect(decoded.wolDevices.first.name, 'NAS');
    expect(decoded.wolDevices.first.mac, 'AA:BB:CC:DD:EE:FF');
    expect(decoded.wolDevices.first.broadcastAddress, '192.168.1.255');
    expect(decoded.wolDevices.first.port, 7);
    expect(
      decoded.instances.first.customHeaders,
      const <String, String>{'X-Instance': 'sonarr'},
    );
  });

  test('Instance.fromJson without customHeaders falls back to empty', () {
    final Instance instance = Instance.fromJson(<String, dynamic>{
      'id': 'i1',
      'name': 'Sonarr',
      'kind': 'sonarr',
      'localUrl': 'http://192.168.1.10:8989',
      'externalUrl': '',
      'urlMode': 'auto',
      'auth': <String, dynamic>{'apiKey': '', 'runtimeType': 'apiKey'},
    });

    expect(instance.customHeaders, const <String, String>{});
  });

  test('Speedtest Tracker instance round-trips by stable enum name', () {
    const Instance instance = Instance(
      id: 'speedtest-1',
      name: 'Home speed',
      kind: ServiceKind.speedtestTracker,
      localUrl: 'https://speedtest.example.test',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: ''),
    );

    final Map<String, dynamic> json = jsonDecode(
      jsonEncode(instance.toJson()),
    ) as Map<String, dynamic>;
    final Instance decoded = Instance.fromJson(json);

    expect(json['kind'], 'speedtestTracker');
    expect(decoded.kind, ServiceKind.speedtestTracker);
  });

  test('WolDevice.fromJson fills broadcast and port defaults', () {
    final WolDevice device = WolDevice.fromJson(<String, dynamic>{
      'id': 'w1',
      'name': 'NAS',
      'mac': 'AA:BB:CC:DD:EE:FF',
    });

    expect(device.broadcastAddress, '255.255.255.255');
    expect(device.port, 9);
  });
}
