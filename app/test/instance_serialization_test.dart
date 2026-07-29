import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against a stale generated enum map: json_serializable bakes the
/// ServiceKind values into instance.g.dart at build_runner time, so a newly
/// added kind serializes as null (and toJson throws) until codegen is re-run.
/// Round-tripping every kind fails fast when that happens.
void main() {
  test('every ServiceKind round-trips through Instance json', () {
    for (final ServiceKind kind in ServiceKind.values) {
      final Instance instance = Instance(
        id: 'id-${kind.name}',
        name: 'Test ${kind.displayName}',
        kind: kind,
        localUrl: 'http://localhost:1234',
        externalUrl: '',
        urlMode: UrlMode.auto,
        auth: const InstanceAuth.apiKey(apiKey: 'k'),
      );
      final String encoded = jsonEncode(instance.toJson());
      final Instance decoded =
          Instance.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
      expect(decoded.kind, kind, reason: '${kind.name} did not round-trip');
      expect(decoded.id, instance.id);
    }
  });
}
