import 'dart:async';

import 'package:atrium/src/router.dart';
import 'package:atrium/src/share_intake/atrium_link.dart';
import 'package:atrium/src/share_intake/share_intake.dart';
import 'package:atrium/src/share_intake/torrent_share.dart';
import 'package:atrium/src/share_intake/torrent_share_listener.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands the listener whatever the test pushes, instead of a platform channel.
class _FakeIntake extends ShareIntake {
  final StreamController<TorrentShare> pushed =
      StreamController<TorrentShare>.broadcast();

  @override
  Stream<TorrentShare> get shares => pushed.stream;

  @override
  Future<TorrentShare?> initialShare() async => null;
}

class _Profiles extends ProfileListController {
  @override
  Future<List<Profile>> build() async => <Profile>[];
}

class _BrokenProfiles extends ProfileListController {
  @override
  Future<List<Profile>> build() async => throw StateError('disk');
}

Future<_FakeIntake> _mount(
  WidgetTester tester, {
  bool profilesBreak = false,
}) async {
  final _FakeIntake intake = _FakeIntake();
  addTearDown(intake.pushed.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        shareIntakeProvider.overrideWithValue(intake),
        profileListProvider.overrideWith(
          profilesBreak ? _BrokenProfiles.new : _Profiles.new,
        ),
        activeInstancesProvider.overrideWithValue(const <Instance>[]),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        builder: (BuildContext context, Widget? child) =>
            TorrentShareListener(child: child!),
        home: const Scaffold(body: Text('home')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return intake;
}

Future<void> _push(
  WidgetTester tester,
  _FakeIntake intake,
  TorrentShare share,
) async {
  intake.pushed.add(share);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a link that finds nothing to open says so as a link',
      (WidgetTester tester) async {
    final _FakeIntake intake = await _mount(tester);
    await _push(
      tester,
      intake,
      const AtriumLink(service: ServiceKind.sonarr),
    );
    expect(find.text('Could not open that link'), findsOneWidget);
    expect(find.text('Nothing added'), findsNothing);
    expect(find.text('No Sonarr is set up in Atrium yet.'), findsOneWidget);
  });

  testWidgets('a link that cannot be read says so as a link',
      (WidgetTester tester) async {
    final _FakeIntake intake = await _mount(tester);
    await _push(tester, intake, parseAtriumLink('atrium://nope'));
    expect(find.text('Could not open that link'), findsOneWidget);
    expect(find.text('Nothing added'), findsNothing);
  });

  testWidgets('a torrent that cannot be read still says nothing was added',
      (WidgetTester tester) async {
    final _FakeIntake intake = await _mount(tester);
    await _push(
      tester,
      intake,
      const TorrentShareProblem('That file is not a torrent.'),
    );
    expect(find.text('Nothing added'), findsOneWidget);
  });

  testWidgets('a link when profiles cannot be read does not talk of torrents',
      (WidgetTester tester) async {
    final _FakeIntake intake = await _mount(tester, profilesBreak: true);
    await _push(
      tester,
      intake,
      const AtriumLink(service: ServiceKind.sonarr),
    );
    expect(find.text('Could not open that link'), findsOneWidget);
    expect(
      find.text(
        'Atrium could not read your saved profiles, so it could not open '
        'that link.',
      ),
      findsOneWidget,
    );
  });
}
