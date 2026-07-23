import 'dart:io';

import 'package:atrium/src/update_check/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appVersion matches the pubspec version', () {
    // Flutter tests run with the package root (app/) as the current
    // directory, so this resolves to app/pubspec.yaml.
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
        .firstMatch(pubspec);

    expect(
      match,
      isNotNull,
      reason: 'Could not find a "version: X.Y.Z+N" line in pubspec.yaml.',
    );

    final pubspecVersion = match!.group(1);

    expect(
      appVersion,
      pubspecVersion,
      reason:
          'appVersion ($appVersion) must equal the pubspec version '
          '($pubspecVersion). Bump the appVersion constant in '
          'app/lib/src/update_check/app_version.dart in lockstep with the '
          'pubspec version at release time (see docs/RELEASING.md). It is the '
          'update check baseline and the version shown in Settings, so if they '
          'drift a shipped release reports itself as "update available".',
    );
  });
}
