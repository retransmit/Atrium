import 'package:atrium/src/screens/changelog/release_notes.dart';
import 'package:atrium/src/update_check/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release notes are newest first and well formed', () {
    expect(releaseNotes.first.version, '1.1.0');
    for (final ReleaseNote note in releaseNotes) {
      expect(note.date, isNotEmpty);
      expect(note.groups, isNotEmpty);
      for (final ChangeGroup group in note.groups) {
        expect(group.items, isNotEmpty);
      }
    }
  });

  test('the running app version has an entry so Installed can match', () {
    expect(
      releaseNotes.any((ReleaseNote n) => n.version == appVersion),
      isTrue,
    );
  });
}
