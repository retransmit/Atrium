import 'dart:io';

/// Builds the 102-byte Wake-on-LAN magic packet for [mac].
///
/// Accepts the common MAC notations: `AA:BB:CC:DD:EE:FF`,
/// `aa-bb-cc-dd-ee-ff`, `aabb.ccdd.eeff`, or bare 12-hex `aabbccddeeff`
/// (case-insensitive). Anything else throws a [FormatException].
///
/// The packet is 6 bytes of `0xFF` followed by the 6 MAC bytes repeated
/// 16 times.
List<int> buildMagicPacket(String mac) {
  final String hex = mac.replaceAll(RegExp(r'[:.\-]'), '');
  if (!RegExp(r'^[0-9A-Fa-f]{12}$').hasMatch(hex)) {
    throw const FormatException('Invalid MAC address');
  }
  final List<int> macBytes = <int>[
    for (int i = 0; i < 12; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
  return <int>[
    ...List<int>.filled(6, 0xFF),
    for (int i = 0; i < 16; i++) ...macBytes,
  ];
}

/// Sends the Wake-on-LAN magic packet for [mac] to
/// [broadcastAddress]:[port] over UDP.
///
/// WOL is fire-and-forget: there is no acknowledgement, and consumer
/// networks drop broadcast frames often enough that a single datagram is
/// unreliable, so the packet is sent three times with a short gap.
/// Exceptions (invalid MAC, socket errors) propagate to the caller; the UI
/// layer turns them into a snackbar.
Future<void> sendWol({
  required String mac,
  String broadcastAddress = '255.255.255.255',
  int port = 9,
}) async {
  final List<int> packet = buildMagicPacket(mac);
  final RawDatagramSocket socket =
      await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    socket.broadcastEnabled = true;
    final InternetAddress target = InternetAddress(broadcastAddress);
    for (int i = 0; i < 3; i++) {
      socket.send(packet, target, port);
      if (i < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  } finally {
    socket.close();
  }
}
