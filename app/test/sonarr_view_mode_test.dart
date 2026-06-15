import 'dart:io';
import 'package:core_models/core_models.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:service_sonarr/service_sonarr.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('atrium_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('SonarrViewModeNotifier persists and retrieves view mode correctly per instance', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final instance1 = Instance(
      id: 'test-sonarr-1',
      name: 'Sonarr 1',
      kind: ServiceKind.sonarr,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

    final instance2 = Instance(
      id: 'test-sonarr-2',
      name: 'Sonarr 2',
      kind: ServiceKind.sonarr,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

    // 1. Without Hive box open, it should default to grid
    expect(container.read(sonarrViewModeProvider(instance1)), SonarrViewMode.grid);
    expect(container.read(sonarrViewModeProvider(instance2)), SonarrViewMode.grid);

    // 2. Open the settings box
    final box = await Hive.openBox<String>(AtriumBoxes.settings);

    // Default should still be grid
    expect(container.read(sonarrViewModeProvider(instance1)), SonarrViewMode.grid);
    expect(container.read(sonarrViewModeProvider(instance2)), SonarrViewMode.grid);

    // 3. Change view mode of instance1 to banner
    await container.read(sonarrViewModeProvider(instance1).notifier).setViewMode(SonarrViewMode.banner);

    // State of instance1 should update to banner, but instance2 should stay grid
    expect(container.read(sonarrViewModeProvider(instance1)), SonarrViewMode.banner);
    expect(container.read(sonarrViewModeProvider(instance2)), SonarrViewMode.grid);

    // Value should be written to the Hive box with instance1's id
    expect(box.get('sonarr.viewMode.test-sonarr-1'), 'banner');
    expect(box.get('sonarr.viewMode.test-sonarr-2'), isNull);

    // 4. Re-reading with a fresh ProviderContainer (simulating app restart) should restore state
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);

    expect(container2.read(sonarrViewModeProvider(instance1)), SonarrViewMode.banner);
    expect(container2.read(sonarrViewModeProvider(instance2)), SonarrViewMode.grid);
  });
}
