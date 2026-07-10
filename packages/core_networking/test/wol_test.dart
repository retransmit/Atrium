import 'package:core_networking/core_networking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<int> macBytes = <int>[0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF];

  test('magic packet is 102 bytes: 6 x 0xFF then the MAC 16 times', () {
    final List<int> packet = buildMagicPacket('AA:BB:CC:DD:EE:FF');

    expect(packet, hasLength(102));
    expect(packet.sublist(0, 6), List<int>.filled(6, 0xFF));
    expect(packet.sublist(6, 12), macBytes);
    for (int rep = 0; rep < 16; rep++) {
      expect(
        packet.sublist(6 + rep * 6, 12 + rep * 6),
        macBytes,
        reason: 'repetition $rep of the MAC bytes',
      );
    }
  });

  test('all supported MAC notations parse to the same packet', () {
    final List<int> reference = buildMagicPacket('AA:BB:CC:DD:EE:FF');

    expect(buildMagicPacket('aa-bb-cc-dd-ee-ff'), reference);
    expect(buildMagicPacket('aabb.ccdd.eeff'), reference);
    expect(buildMagicPacket('aabbccddeeff'), reference);
  });

  test('invalid MACs throw FormatException', () {
    expect(() => buildMagicPacket('nope'), throwsFormatException);
    // 11 hex digits.
    expect(() => buildMagicPacket('aabbccddeef'), throwsFormatException);
    // 13 hex digits.
    expect(() => buildMagicPacket('aabbccddeeff0'), throwsFormatException);
    // Non-hex characters at the right length.
    expect(() => buildMagicPacket('gg:hh:ii:jj:kk:ll'), throwsFormatException);
    expect(() => buildMagicPacket(''), throwsFormatException);
  });

  test('mergeHeaders lets instance keys win over global keys', () {
    final Map<String, String> merged = mergeHeaders(
      <String, String>{'X-Auth': 'global', 'X-Only-Global': '1'},
      <String, String>{'X-Auth': 'instance', 'X-Only-Instance': '2'},
    );

    expect(merged, <String, String>{
      'X-Auth': 'instance',
      'X-Only-Global': '1',
      'X-Only-Instance': '2',
    });
  });
}
