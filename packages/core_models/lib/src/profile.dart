import 'package:freezed_annotation/freezed_annotation.dart';

import 'instance.dart';
import 'wol_device.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// A named collection of [Instance]s.
///
/// Most users will have exactly one profile ("Default"), but the abstraction
/// is useful for two cases:
///
/// 1. A user who manages multiple stacks (e.g., "Home" and "Friend's
///    place") and wants a single tap to switch the whole set of instances.
/// 2. Sharing - a profile can be exported as JSON (with secrets optionally
///    stripped) and imported by another user.
///
/// The active profile is tracked separately by the profile package; this
/// model is just the shape on disk.
@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String id,
    required String name,
    @Default(<Instance>[]) List<Instance> instances,

    /// HTTP headers sent with every request from every instance in this
    /// profile (an instance's own [Instance.customHeaders] win on key
    /// collision). Typical use: reverse-proxy auth headers.
    @Default(<String, String>{}) Map<String, String> globalHeaders,

    /// Wake-on-LAN targets configured for this profile.
    @Default(<WolDevice>[]) List<WolDevice> wolDevices,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}
