import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SshEndpoint.tryParse', () {
    test('accepts ssh URLs, host:port and bare hosts', () {
      expect(
        SshEndpoint.tryParse('ssh://192.168.1.10:2222'),
        const SshEndpoint('192.168.1.10', 2222),
      );
      expect(
        SshEndpoint.tryParse(' nas.local:2200 '),
        const SshEndpoint('nas.local', 2200),
      );
      expect(SshEndpoint.tryParse('nas.local'), const SshEndpoint('nas.local'));
      expect(
        SshEndpoint.tryParse('ssh://root@host'),
        const SshEndpoint('host'),
      );
      expect(SshEndpoint.tryParse('[::1]:22'), const SshEndpoint('::1'));
    });

    test('rejects empty, non-ssh schemes, paths and bad ports', () {
      expect(SshEndpoint.tryParse(''), isNull);
      expect(SshEndpoint.tryParse('http://host:22'), isNull);
      expect(SshEndpoint.tryParse('host/path'), isNull);
      expect(SshEndpoint.tryParse('host:0'), isNull);
    });
  });

  test('instances saved before container shells load with empty fields', () {
    final Instance instance = Instance.fromJson(<String, dynamic>{
      'id': 'i1',
      'name': 'Sonarr',
      'kind': 'sonarr',
      'localUrl': 'http://192.168.1.10:8989',
      'externalUrl': '',
      'urlMode': 'auto',
      'auth': <String, dynamic>{'runtimeType': 'apiKey', 'apiKey': ''},
    });
    expect(instance.dockerHostId, '');
    expect(instance.dockerContainer, '');
  });

  test('ssh auth round-trips and redacts every secret in toString', () {
    const InstanceAuth auth = InstanceAuth.ssh(
      username: 'admin',
      password: 'pw-secret',
      privateKey: 'key-secret',
      passphrase: 'pass-secret',
    );
    expect(InstanceAuth.fromJson(auth.toJson()), auth);
    final String text = auth.toString();
    expect(text, contains('admin'));
    for (final String secret in <String>[
      'pw-secret',
      'key-secret',
      'pass-secret',
    ]) {
      expect(text, isNot(contains(secret)));
    }
  });
}
