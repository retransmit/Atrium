import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:core_storage/core_storage.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

/// Persists [Profile]s and their [Instance]s, splitting secret material out
/// of the plaintext store.
///
/// Storage split:
///
/// * **Hive** (`profilesBox`) holds one JSON entry per profile, keyed by
///   `profile.id`. Each instance inside is written with its auth secrets
///   **redacted** - the auth discriminator and any non-secret field
///   (username) survive, but api keys / passwords / tokens are blanked.
/// * **Secure storage** (Android Keystore) holds the full auth JSON per
///   instance, keyed `instance:<id>:auth`.
///
/// On load the two are recombined. If the secret is missing (e.g., the user
/// restored a backup that excluded secure storage), the instance still loads
/// with blank credentials and the UI can prompt for re-entry rather than
/// crashing.
class ProfileRepository {
  ProfileRepository({
    required Box<String> profilesBox,
    required Box<String> settingsBox,
    required AtriumSecureStorage secrets,
    Uuid? uuid,
  })  : _profiles = profilesBox,
        _settings = settingsBox,
        _secrets = secrets,
        _uuid = uuid ?? const Uuid();

  final Box<String> _profiles;
  final Box<String> _settings;
  final AtriumSecureStorage _secrets;
  final Uuid _uuid;

  static const String _activeProfileKey = 'activeProfileId';

  /// All profiles, with secrets rehydrated. Order is insertion order.
  Future<List<Profile>> getProfiles() async {
    final List<Profile> result = <Profile>[];
    for (final String raw in _profiles.values) {
      final Profile redacted =
          Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      result.add(await _rehydrate(redacted));
    }
    return result;
  }

  /// A single profile by id, or null.
  Future<Profile?> getProfile(String id) async {
    final String? raw = _profiles.get(id);
    if (raw == null) {
      return null;
    }
    return _rehydrate(
      Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>),
    );
  }

  /// Creates a new, empty profile and returns it.
  Future<Profile> createProfile(String name) async {
    final Profile profile = Profile(id: _uuid.v4(), name: name);
    await saveProfile(profile);
    return profile;
  }

  /// Writes [profile] in full: redacted JSON to Hive, secrets to the keystore.
  Future<void> saveProfile(Profile profile) async {
    for (final Instance instance in profile.instances) {
      await _writeSecret(instance);
    }
    final Profile redacted = profile.copyWith(
      instances: profile.instances.map(_redactInstance).toList(),
    );
    await _profiles.put(profile.id, jsonEncode(redacted.toJson()));
  }

  /// Deletes a profile and every secret belonging to its instances.
  Future<void> deleteProfile(String id) async {
    final Profile? profile = await getProfile(id);
    if (profile != null) {
      for (final Instance instance in profile.instances) {
        await _secrets.delete(_authKey(instance.id));
      }
    }
    await _profiles.delete(id);
    if (getActiveProfileId() == id) {
      await setActiveProfileId(_profiles.keys.cast<String>().firstOrNull);
    }
  }

  /// Adds or replaces an instance within a profile (matched by instance id).
  Future<void> upsertInstance(String profileId, Instance instance) async {
    final Profile? profile = await getProfile(profileId);
    if (profile == null) {
      throw StateError('No profile with id $profileId');
    }
    final List<Instance> next = List<Instance>.of(profile.instances);
    final int idx = next.indexWhere((Instance i) => i.id == instance.id);
    if (idx >= 0) {
      next[idx] = instance;
    } else {
      next.add(instance);
    }
    await saveProfile(profile.copyWith(instances: next));
  }

  /// Removes an instance and its secret from a profile.
  Future<void> deleteInstance(String profileId, String instanceId) async {
    final Profile? profile = await getProfile(profileId);
    if (profile == null) {
      return;
    }
    await _secrets.delete(_authKey(instanceId));
    final List<Instance> next =
        profile.instances.where((Instance i) => i.id != instanceId).toList();
    await saveProfile(profile.copyWith(instances: next));
  }

  /// Mints a fresh instance id. Callers building a new [Instance] use this so
  /// the id is stable from creation (it keys the secret store).
  String newInstanceId() => _uuid.v4();

  String? getActiveProfileId() => _settings.get(_activeProfileKey);

  Future<void> setActiveProfileId(String? id) async {
    if (id == null) {
      await _settings.delete(_activeProfileKey);
    } else {
      await _settings.put(_activeProfileKey, id);
    }
  }

  /// Serializes a profile to shareable JSON.
  ///
  /// When [includeSecrets] is false (the default), auth material is redacted
  /// so the export is safe to post in a forum or commit to a dotfiles repo.
  String exportProfile(Profile profile, {bool includeSecrets = false}) {
    final Profile out = includeSecrets
        ? profile
        : profile.copyWith(
            instances: profile.instances.map(_redactInstance).toList(),
          );
    return const JsonEncoder.withIndent('  ').convert(out.toJson());
  }

  /// Imports a profile from [json]. Fresh ids are minted for the profile and
  /// every instance so an import never collides with existing entries, and
  /// secrets (if present in the JSON) land in the keystore.
  Future<Profile> importProfile(String json) async {
    final Profile incoming =
        Profile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    final Profile reIded = incoming.copyWith(
      id: _uuid.v4(),
      instances: incoming.instances
          .map((Instance i) => i.copyWith(id: _uuid.v4()))
          .toList(),
    );
    await saveProfile(reIded);
    return reIded;
  }

  String _authKey(String instanceId) => 'instance:$instanceId:auth';

  Future<void> _writeSecret(Instance instance) async {
    await _secrets.write(
      _authKey(instance.id),
      jsonEncode(instance.auth.toJson()),
    );
  }

  Future<Profile> _rehydrate(Profile redacted) async {
    final List<Instance> instances = <Instance>[];
    for (final Instance instance in redacted.instances) {
      final String? secretJson = await _secrets.read(_authKey(instance.id));
      if (secretJson == null) {
        instances.add(instance);
        continue;
      }
      final InstanceAuth auth = InstanceAuth.fromJson(
        jsonDecode(secretJson) as Map<String, dynamic>,
      );
      instances.add(instance.copyWith(auth: auth));
    }
    return redacted.copyWith(instances: instances);
  }

  Instance _redactInstance(Instance instance) =>
      instance.copyWith(auth: _redactAuth(instance.auth));

  /// Blanks secret fields while keeping the discriminator (and username,
  /// which is not itself a secret) so the Hive copy never holds credentials.
  InstanceAuth _redactAuth(InstanceAuth auth) => switch (auth) {
        InstanceAuthApiKey() => const InstanceAuth.apiKey(apiKey: ''),
        InstanceAuthUserPass(:final String username) =>
          InstanceAuth.userPass(username: username, password: ''),
        InstanceAuthPlex() => const InstanceAuth.plexToken(token: ''),
        InstanceAuthCookie(:final String username) =>
          InstanceAuth.cookieLogin(username: username, password: ''),
      };
}
