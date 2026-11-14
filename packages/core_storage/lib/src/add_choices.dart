import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import 'hive_setup.dart';

/// The choices last used on a service's add sheet, kept per instance so the
/// next add starts from them (issue #234).
///
/// Stored as one JSON object per service and instance in the settings box.
/// Without the box open, as in widget tests, nothing is read or written.
abstract final class AddChoices {
  static String _keyFor(String service, String instanceId) =>
      '$service.addChoices.$instanceId';

  static Box<String>? get _box => Hive.isBoxOpen(AtriumBoxes.settings)
      ? Hive.box<String>(AtriumBoxes.settings)
      : null;

  /// The stored choices, or null when there are none or they cannot be read.
  static Map<String, Object?>? read(String service, String instanceId) {
    final String? raw = _box?.get(_keyFor(service, instanceId));
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Replaces the stored choices for this service and instance.
  static void write(
    String service,
    String instanceId,
    Map<String, Object?> choices,
  ) {
    _box?.put(_keyFor(service, instanceId), jsonEncode(choices));
  }
}
