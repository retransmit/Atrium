import 'package:atrium/src/screens/profiles_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Profiles can be renamed in place. Before this the name given at creation
/// was final, so the profile the app makes on first run stayed "Default".
void main() {
  late _Profiles profiles;

  Future<void> open(WidgetTester tester, List<Profile> list) async {
    profiles = _Profiles(list);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          profileListProvider.overrideWith(() => profiles),
          activeProfileIdProvider.overrideWith(_Active.new),
        ],
        child: const MaterialApp(home: ProfilesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, {int index = 0}) async {
    await tester.tap(find.byTooltip('Profile actions').at(index));
    await tester.pumpAndSettle();
  }

  Future<void> rename(WidgetTester tester, String to) async {
    await openMenu(tester);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Rename profile'), findsOneWidget);
    await tester.enterText(find.byType(TextField), to);
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
  }

  testWidgets('a profile can be renamed from its menu',
      (WidgetTester tester) async {
    await open(tester, <Profile>[Profile(id: 'p', name: 'Default')]);
    expect(find.text('Default'), findsOneWidget);

    await rename(tester, '  Home  ');

    expect(profiles.saved.single.id, 'p');
    expect(profiles.saved.single.name, 'Home');
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Default'), findsNothing);
  });

  testWidgets('an empty or unchanged name saves nothing',
      (WidgetTester tester) async {
    await open(tester, <Profile>[Profile(id: 'p', name: 'Default')]);

    await rename(tester, '   ');
    await rename(tester, 'Default');

    expect(profiles.saved, isEmpty);
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('the last profile cannot be deleted',
      (WidgetTester tester) async {
    await open(tester, <Profile>[Profile(id: 'p', name: 'Default')]);
    await openMenu(tester);

    expect(_deleteItem(tester).enabled, isFalse);
  });

  testWidgets('a spare profile can be deleted', (WidgetTester tester) async {
    await open(tester, <Profile>[
      Profile(id: 'p', name: 'Default'),
      Profile(id: 'q', name: 'Away'),
    ]);
    await openMenu(tester, index: 1);
    expect(_deleteItem(tester).enabled, isTrue);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(profiles.deleted, <String>['q']);
    expect(find.text('Away'), findsNothing);
  });
}

PopupMenuItem<dynamic> _deleteItem(WidgetTester tester) => tester.widget(
      find.ancestor(
        of: find.text('Delete'),
        matching: find.byWidgetPredicate((Widget w) => w is PopupMenuItem),
      ),
    );

class _Profiles extends ProfileListController {
  _Profiles(this.list);

  List<Profile> list;
  final List<Profile> saved = <Profile>[];
  final List<String> deleted = <String>[];

  @override
  Future<List<Profile>> build() async => list;

  @override
  Future<void> updateProfile(Profile profile) async {
    saved.add(profile);
    list = <Profile>[
      for (final Profile p in list) p.id == profile.id ? profile : p,
    ];
    state = AsyncData<List<Profile>>(list);
  }

  @override
  Future<void> deleteProfile(String id) async {
    deleted.add(id);
    list = <Profile>[
      for (final Profile p in list)
        if (p.id != id) p,
    ];
    state = AsyncData<List<Profile>>(list);
  }
}

class _Active extends ActiveProfileIdController {
  @override
  String? build() => 'p';

  @override
  Future<void> select(String? id) async => state = id;
}
