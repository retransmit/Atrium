import 'dart:io';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue #234: the add sheets remember the last choices per instance.
void main() {
  group('with Hive open', () {
    late Directory tempDir;
    late Box<String> box;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('add_choices_test');
      Hive.init(tempDir.path);
      box = await Hive.openBox<String>(AtriumBoxes.settings);
    });

    tearDown(() async {
      await box.clear();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('what is written reads back', () {
      AddChoices.write('radarr', 'a', <String, Object?>{
        'qualityProfileId': 4,
        'searchForMovie': true,
      });
      expect(AddChoices.read('radarr', 'a'), <String, Object?>{
        'qualityProfileId': 4,
        'searchForMovie': true,
      });
    });

    test('entries are per instance and per service', () {
      AddChoices.write('radarr', 'a', <String, Object?>{'qualityProfileId': 4});
      expect(AddChoices.read('radarr', 'b'), isNull);
      expect(AddChoices.read('sonarr', 'a'), isNull);
    });

    test('unreadable entries read as nothing', () async {
      for (final String raw in <String>['not json', '[1,2]', '"text"']) {
        await box.put('radarr.addChoices.a', raw);
        expect(AddChoices.read('radarr', 'a'), isNull, reason: raw);
      }
    });
  });

  test('without Hive open it reads nothing and writes nothing', () {
    expect(AddChoices.read('radarr', 'a'), isNull);
    AddChoices.write('radarr', 'a', <String, Object?>{'x': 1});
    expect(AddChoices.read('radarr', 'a'), isNull);
  });
}
