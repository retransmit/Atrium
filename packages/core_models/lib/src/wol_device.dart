import 'package:freezed_annotation/freezed_annotation.dart';

part 'wol_device.freezed.dart';
part 'wol_device.g.dart';

/// A machine that can be woken over the LAN with a Wake-on-LAN magic packet.
///
/// Stored on the [Profile] so the device list travels with profile
/// export/import. The networking layer turns [mac] into the magic packet;
/// [broadcastAddress] and [port] cover the common cases (directed broadcast
/// on 255.255.255.255:9) while staying editable for segmented networks.
@freezed
abstract class WolDevice with _$WolDevice {
  const factory WolDevice({
    /// Stable identifier, generated once at create time.
    required String id,

    /// Display name shown in the device list ("NAS", "Gaming PC").
    required String name,

    /// Hardware address of the target NIC. Stored as entered; the packet
    /// builder accepts `:`/`-`/`.` separators or bare 12-hex.
    required String mac,

    /// Address the magic packet is broadcast to.
    @Default('255.255.255.255') String broadcastAddress,

    /// UDP port the packet is sent on; 9 (discard) is the convention.
    @Default(9) int port,
  }) = _WolDevice;

  factory WolDevice.fromJson(Map<String, dynamic> json) =>
      _$WolDeviceFromJson(json);
}
