import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String token = 'placeholder-token-must-never-appear';

  test('InstanceAuth toString redacts every credential variant', () {
    const List<InstanceAuth> values = <InstanceAuth>[
      InstanceAuth.apiKey(apiKey: token),
      InstanceAuth.userPass(username: 'user', password: token),
      InstanceAuth.plexToken(token: token),
      InstanceAuth.cookieLogin(username: 'user', password: token),
    ];

    for (final InstanceAuth auth in values) {
      expect(auth.toString(), isNot(contains(token)));
      expect(auth.toString(), contains('***redacted***'));
    }
  });

  test('Instance toString redacts auth, URL user info, and header values', () {
    const Instance instance = Instance(
      id: 'redaction-test',
      name: 'Tracker',
      kind: ServiceKind.speedtestTracker,
      localUrl: 'https://user:$token@tracker.example.test',
      externalUrl: 'https://tracker.example.test',
      urlMode: UrlMode.forceLocal,
      auth: InstanceAuth.apiKey(apiKey: token),
      customHeaders: <String, String>{'X-Private': token},
    );

    final String diagnostic = instance.toString();
    expect(diagnostic, isNot(contains(token)));
    expect(diagnostic, contains('***redacted***'));
    expect(diagnostic, contains('X-Private'));
  });
}
