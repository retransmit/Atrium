import 'package:flutter_test/flutter_test.dart';
import 'package:service_plex/service_plex.dart';

void main() {
  test('plexCommandParams builds the Companion routing params', () {
    final Map<String, dynamic> p = plexCommandParams(
      machineIdentifier: 'abc123',
      clientIdentifier: 'atrium-dev',
      commandId: 5,
    );
    expect(p['X-Plex-Target-Client-Identifier'], 'abc123');
    expect(p['X-Plex-Client-Identifier'], 'atrium-dev');
    expect(p['commandID'], 5);
    expect(p.containsKey('offset'), isFalse);
  });

  test('seek adds the offset', () {
    final Map<String, dynamic> p = plexCommandParams(
      machineIdentifier: 'm',
      clientIdentifier: 'c',
      commandId: 1,
      offsetMs: 42000,
    );
    expect(p['offset'], 42000);
  });
}
