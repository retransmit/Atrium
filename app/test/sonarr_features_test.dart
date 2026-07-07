import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_sonarr/service_sonarr.dart';
import 'package:service_sonarr/src/home/settings/parse_title_dialog.dart';

Instance _instance() => Instance(
      id: 'test-sonarr',
      name: 'Test Sonarr',
      kind: ServiceKind.sonarr,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

void main() {
  group('Sonarr Selection Providers', () {
    test('sonarrQueueSelectionProvider holds selection state correctly', () {
      final container = ProviderContainer();
      final instance = _instance();

      // Read initial state
      var selection = container.read(sonarrQueueSelectionProvider(instance));
      expect(selection, isEmpty);

      // Select items
      container.read(sonarrQueueSelectionProvider(instance).notifier).state = {1, 2};
      selection = container.read(sonarrQueueSelectionProvider(instance));
      expect(selection, containsAll([1, 2]));

      // Clear selection
      container.read(sonarrQueueSelectionProvider(instance).notifier).state = {};
      selection = container.read(sonarrQueueSelectionProvider(instance));
      expect(selection, isEmpty);
    });

    test('sonarrBlocklistSelectionProvider holds selection state correctly', () {
      final container = ProviderContainer();
      final instance = _instance();

      // Read initial state
      var selection = container.read(sonarrBlocklistSelectionProvider(instance));
      expect(selection, isEmpty);

      // Select items
      container.read(sonarrBlocklistSelectionProvider(instance).notifier).state = {3, 4};
      selection = container.read(sonarrBlocklistSelectionProvider(instance));
      expect(selection, containsAll([3, 4]));

      // Clear selection
      container.read(sonarrBlocklistSelectionProvider(instance).notifier).state = {};
      selection = container.read(sonarrBlocklistSelectionProvider(instance));
      expect(selection, isEmpty);
    });
  });

  group('SonarrParseTitleDialog UI Widget Tests', () {
    testWidgets('Renders Parse Title Dialog', (WidgetTester tester) async {
      final instance = _instance();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AtriumTheme.light(null),
            home: Scaffold(
              body: SonarrParseTitleDialog(instance: instance),
            ),
          ),
        ),
      );

      // Check title and fields render
      expect(find.text('Parse Release Title'), findsOneWidget);
      expect(find.text('Paste a release name or torrent title below to see how Sonarr parses season, episode, quality, and matching library details.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Parse'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });
  });
}
