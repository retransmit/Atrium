import 'dart:async';
import 'dart:io';

import 'package:atrium/src/launcher_shortcuts/launcher_shortcuts.dart';
import 'package:atrium/src/launcher_shortcuts/launcher_shortcuts_publisher.dart';
import 'package:atrium/src/preferences.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// Profiles that arrive when [_profiles] completes, as they do at launch
/// once secure storage has been read.
class _SlowProfiles extends ProfileListController {
  _SlowProfiles(this._profiles);
  final Future<List<Profile>> _profiles;

  @override
  Future<List<Profile>> build() => _profiles;
}

class _FixedActiveId extends ActiveProfileIdController {
  @override
  String? build() => 'p1';
}

class _NoChoice extends LauncherShortcutChoiceController {
  _NoChoice(super.profileId);

  @override
  List<String>? build() => null;
}

const MethodChannel _channel = MethodChannel('app.atrium/launcher');

Instance _i(String id, {String? name, ServiceKind kind = ServiceKind.sonarr}) =>
    Instance(
      id: id,
      name: name ?? id,
      kind: kind,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  void mockChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
      calls.add(call);
      return true;
    });
  }

  List<Object?> shortcutsOf(MethodCall call) =>
      (call.arguments as Map<Object?, Object?>)['shortcuts']! as List<Object?>;

  setUp(() {
    calls = <MethodCall>[];
    mockChannel();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('sends id, name, link and icon in order', () async {
    final Instance sonarr = _i('s1', name: 'Sonarr 4K');
    final Instance adguard =
        _i('a1', name: 'DNS', kind: ServiceKind.adguardHome);
    await LauncherShortcutsPublisher().publish(<Instance>[sonarr, adguard]);

    expect(calls.single.method, 'setShortcuts');
    expect(shortcutsOf(calls.single), <Object?>[
      <String, String>{
        'id': 's1',
        'name': 'Sonarr 4K',
        'link': shortcutLink(sonarr),
        'icon': 'assets/service_icons/sonarr.png',
      },
      <String, String>{
        'id': 'a1',
        'name': 'DNS',
        'link': shortcutLink(adguard),
        'icon': 'assets/service_icons/adguardHome.png',
      },
    ]);
  });

  test('does not resend an unchanged list', () async {
    final LauncherShortcutsPublisher publisher = LauncherShortcutsPublisher();
    await publisher.publish(<Instance>[_i('a')]);
    await publisher.publish(<Instance>[_i('a')]);
    expect(calls, hasLength(1));
  });

  test('a rename is sent again', () async {
    final LauncherShortcutsPublisher publisher = LauncherShortcutsPublisher();
    await publisher.publish(<Instance>[_i('a', name: 'Old')]);
    await publisher.publish(<Instance>[_i('a', name: 'New')]);
    expect(calls, hasLength(2));
  });

  test('an empty list clears', () async {
    final LauncherShortcutsPublisher publisher = LauncherShortcutsPublisher();
    await publisher.publish(<Instance>[_i('a')]);
    await publisher.publish(const <Instance>[]);
    expect(calls, hasLength(2));
    expect(shortcutsOf(calls.last), isEmpty);
  });

  test('no handler does not throw', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await LauncherShortcutsPublisher().publish(<Instance>[_i('a')]);
  });

  test('a failed send is tried again next time', () async {
    int attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (MethodCall call) async {
      attempts++;
      if (attempts == 1) {
        throw PlatformException(code: 'busy');
      }
      return true;
    });
    final LauncherShortcutsPublisher publisher = LauncherShortcutsPublisher();
    await publisher.publish(<Instance>[_i('a')]);
    await publisher.publish(<Instance>[_i('a')]);
    expect(attempts, 2);
  });

  test('nothing is sent until profiles have loaded', () async {
    final Completer<List<Profile>> loading = Completer<List<Profile>>();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        profileListProvider.overrideWith(() => _SlowProfiles(loading.future)),
        activeProfileIdProvider.overrideWith(_FixedActiveId.new),
        launcherShortcutChoiceProvider('p1')
            .overrideWith(() => _NoChoice('p1')),
      ],
    );
    addTearDown(container.dispose);

    container.listen(launcherShortcutsSyncProvider, (_, __) {});
    await pumpEventQueue();
    expect(calls, isEmpty);

    loading.complete(<Profile>[
      Profile(id: 'p1', name: 'Home', instances: <Instance>[_i('a')]),
    ]);
    await pumpEventQueue();
    expect(calls, hasLength(1));
    expect(shortcutsOf(calls.single), hasLength(1));
  });

  test('a failed profile load leaves the shortcuts alone', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        profileListProvider.overrideWith(
          () => _SlowProfiles(Future<List<Profile>>.error(StateError('no'))),
        ),
        activeProfileIdProvider.overrideWith(_FixedActiveId.new),
      ],
    );
    addTearDown(container.dispose);

    container.listen(launcherShortcutsSyncProvider, (_, __) {});
    await pumpEventQueue();
    expect(calls, isEmpty);
  });

  group('kept in step with the active profile', () {
    late Directory tempDir;
    late Box<String> box;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('atrium_shortcut_sync');
      Hive.init(tempDir.path);
      box = await Hive.openBox<String>('settings');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('settings');
      tempDir.deleteSync(recursive: true);
    });

    test("switching profile publishes that profile's list", () async {
      final Profile p1 = Profile(
        id: 'p1',
        name: 'Home',
        instances: <Instance>[_i('a1'), _i('a2')],
      );
      final Profile p2 = Profile(
        id: 'p2',
        name: 'Work',
        instances: <Instance>[for (int n = 1; n <= 5; n++) _i('b$n')],
      );
      await box.put('launcherShortcuts.p1', '["a1"]');
      final StateProvider<Profile> active = StateProvider<Profile>((_) => p1);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          settingsBoxProvider.overrideWithValue(box),
          profileListProvider.overrideWith(
            () => _SlowProfiles(Future<List<Profile>>.value(<Profile>[p1, p2])),
          ),
          activeProfileProvider.overrideWith((Ref ref) => ref.watch(active)),
        ],
      );
      addTearDown(container.dispose);

      container.listen(launcherShortcutsSyncProvider, (_, __) {});
      await pumpEventQueue();
      expect(
        shortcutsOf(calls.last).map((Object? s) => (s! as Map)['id']),
        <String>['a1'],
      );

      container.read(active.notifier).state = p2;
      await pumpEventQueue();
      expect(
        shortcutsOf(calls.last).map((Object? s) => (s! as Map)['id']),
        <String>['b1', 'b2', 'b3', 'b4'],
      );
    });
  });
}
