import 'dart:io';

import 'package:atrium/src/launcher_shortcuts/launcher_shortcuts.dart';
import 'package:atrium/src/preferences.dart';
import 'package:atrium/src/share_intake/atrium_link.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

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

List<String> _ids(List<Instance> list) =>
    list.map((Instance i) => i.id).toList();

void main() {
  final List<Instance> six = <Instance>[
    for (final String id in <String>['a', 'b', 'c', 'd', 'e', 'f']) _i(id),
  ];

  group('shortcutInstances', () {
    test('defaults to the first four in sidebar order', () {
      expect(_ids(shortcutInstances(six, null)), <String>['a', 'b', 'c', 'd']);
    });

    test('keeps a stored choice in sidebar order', () {
      expect(_ids(shortcutInstances(six, <String>['e', 'b'])), <String>['b', 'e']);
    });

    test('drops chosen ids that no longer exist', () {
      expect(_ids(shortcutInstances(six, <String>['b', 'gone'])), <String>['b']);
    });

    test('caps a stored choice at four', () {
      expect(
        shortcutInstances(six, <String>['a', 'b', 'c', 'd', 'e']),
        hasLength(maxLauncherShortcuts),
      );
      expect(maxLauncherShortcuts, 4);
    });

    test('an empty choice means none', () {
      expect(shortcutInstances(six, <String>[]), isEmpty);
    });
  });

  group('shortcutLink', () {
    test('links round-trip every service kind', () {
      for (final ServiceKind kind in ServiceKind.values) {
        final Instance instance = _i('x', name: 'My ${kind.name}', kind: kind);
        final Object parsed = parseAtriumLink(shortcutLink(instance));
        expect(parsed, isA<AtriumLink>(), reason: kind.name);
        final AtriumLink link = parsed as AtriumLink;
        expect(link.service, kind);
        expect(link.item, LinkItem.none);
        expect(link.instanceName, instance.name);
      }
    });

    test('links keep awkward names', () {
      for (final String name in <String>['Sonarr 4K', 'A&B=C#1', 'Séries']) {
        final AtriumLink link =
            parseAtriumLink(shortcutLink(_i('x', name: name))) as AtriumLink;
        expect(link.instanceName, name);
      }
    });
  });

  group('stored choice', () {
    late Directory tempDir;
    late Box<String> box;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('atrium_shortcuts');
      Hive.init(tempDir.path);
      box = await Hive.openBox<String>('settings');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('settings');
      tempDir.deleteSync(recursive: true);
    });

    ProviderContainer relaunch() {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[settingsBoxProvider.overrideWithValue(box)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('choice persists per profile', () async {
      await relaunch()
          .read(launcherShortcutChoiceProvider('p1').notifier)
          .setChosen(<String>['x']);

      final ProviderContainer again = relaunch();
      expect(again.read(launcherShortcutChoiceProvider('p1')), <String>['x']);
      expect(again.read(launcherShortcutChoiceProvider('p2')), isNull);
    });

    test('garbage in the box reads as the default', () async {
      await box.put('launcherShortcuts.p1', 'not json');
      expect(relaunch().read(launcherShortcutChoiceProvider('p1')), isNull);
    });

    test('a new choice shows before the save finishes', () async {
      final ProviderContainer container = relaunch();
      final LauncherShortcutChoiceController choice =
          container.read(launcherShortcutChoiceProvider('p1').notifier);

      final Future<void> first = choice.setChosen(<String>['a', 'b']);
      // A second tap, made while the first save is still running, starts
      // from the first tap's choice.
      expect(container.read(launcherShortcutChoiceProvider('p1')),
          <String>['a', 'b']);
      final Future<void> second = choice.setChosen(<String>['b']);
      await Future.wait(<Future<void>>[first, second]);

      expect(relaunch().read(launcherShortcutChoiceProvider('p1')), <String>['b']);
    });

    test('a failed save puts the old choice back', () async {
      await box.put('launcherShortcuts.p1', '["a"]');
      final ProviderContainer container = relaunch();
      expect(container.read(launcherShortcutChoiceProvider('p1')), <String>['a']);
      await box.close();

      await expectLater(
        container
            .read(launcherShortcutChoiceProvider('p1').notifier)
            .setChosen(<String>['b']),
        throwsA(anything),
      );
      expect(container.read(launcherShortcutChoiceProvider('p1')), <String>['a']);

      box = await Hive.openBox<String>('settings');
    });

    test('the active profile picks its own instances', () async {
      await box.put('launcherShortcuts.p1', '["c"]');
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          settingsBoxProvider.overrideWithValue(box),
          activeProfileProvider.overrideWithValue(
            Profile(id: 'p1', name: 'Home', instances: six),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(_ids(container.read(launcherShortcutInstancesProvider)), <String>['c']);
    });

    test('no profile means no shortcuts', () {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          settingsBoxProvider.overrideWithValue(box),
          activeProfileProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(launcherShortcutInstancesProvider), isEmpty);
    });
  });
}
