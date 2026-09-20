import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import 'preferences.dart';

const String plexClientIdentifierKey = 'plex.clientIdentifier';

/// How this install identifies itself to plex.tv.
///
/// It is generated once and kept, for two reasons: plex.tv issues a sign-in
/// PIN against an identifier and answers 404 if the poll sends a different
/// one, and the identifier is what the account's device list shows, so a
/// value shared by every install would put everyone under the same entry.
final Provider<String> plexClientIdentifierProvider = Provider<String>((
  Ref ref,
) {
  final Box<String> box = ref.read(settingsBoxProvider);
  final String? saved = box.get(plexClientIdentifierKey);
  if (saved != null && saved.isNotEmpty) {
    return saved;
  }
  final String generated = generatePlexClientIdentifier();
  box.put(plexClientIdentifierKey, generated);
  return generated;
});

/// 32 hex characters, which is the shape Plex's own clients use.
String generatePlexClientIdentifier([Random? random]) {
  final Random source = random ?? Random.secure();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < 32; i++) {
    out.write(source.nextInt(16).toRadixString(16));
  }
  return out.toString();
}
