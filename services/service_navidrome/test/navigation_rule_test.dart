import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screens, sheets and search pages have to open on the root navigator.
///
/// Every bottom-nav tab has its own branch navigator, which GoRouter rebuilds
/// declaratively, so a page pushed onto one is not in the route table and the
/// next rebuild sweeps it away: the screen opens, then vanishes. CONTRIBUTING
/// spells out the rule, and this package broke it in eleven places, with four
/// sheets opening on the branch navigator as well.
///
/// This walks the package's own sources so the rule cannot quietly come
/// undone. It reads files rather than widgets because the mistake is in how
/// navigation is called, and one test then covers every screen at once.
void main() {
  final List<File> sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList();

  int lineOf(String source, int offset) =>
      source.substring(0, offset).split('\n').length;

  test('there are sources to check', () {
    expect(sources, isNotEmpty, reason: 'run this from the package directory');
  });

  test('no screen is pushed onto the navigator in scope', () {
    // Matches Navigator.push, Navigator.of(...).push and pushNamed. Popping
    // is left alone: it only ever closes what the same code opened.
    final RegExp rawPush = RegExp(
      r'Navigator\.(?:of\([^)]*\)\.)?push(?:Named)?\s*(?:<[^>]*>)?\s*\(',
    );
    final List<String> offenders = <String>[];
    for (final File file in sources) {
      final String source = file.readAsStringSync();
      for (final Match match in rawPush.allMatches(source)) {
        offenders.add('${file.path}:${lineOf(source, match.start)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'use pushScreen from core_ui instead: ${offenders.join(', ')}',
    );
  });

  test('sheets and search pages open on the root navigator', () {
    final RegExp opener = RegExp(r'show(?:ModalBottomSheet|Search)\s*<');
    final List<String> offenders = <String>[];
    for (final File file in sources) {
      final String source = file.readAsStringSync();
      for (final Match match in opener.allMatches(source)) {
        // Read to the closing bracket of this call, so a flag belonging to
        // some later call cannot stand in for a missing one here.
        int depth = 0;
        int end = match.end;
        for (; end < source.length; end++) {
          if (source[end] == '(') depth++;
          if (source[end] == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        if (!source.substring(match.end, end).contains('useRootNavigator')) {
          offenders.add('${file.path}:${lineOf(source, match.start)}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'pass useRootNavigator: true: ${offenders.join(', ')}',
    );
  });
}
