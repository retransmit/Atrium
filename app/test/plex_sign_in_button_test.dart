import 'package:atrium/src/plex_client_identifier.dart';
import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plex is the one service whose credential cannot be read off a settings
/// page: you either dig the token out of a request against the server, or you
/// sign in at plex.tv. The form now offers the second way, so somebody who
/// cannot reach their server can still add it.
void main() {
  Future<void> openForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: InstanceFormScreen())),
    );
  }

  Future<void> pickPlex(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownMenu<ServiceKind>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Plex - Media server'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plex - Media server'));
    await tester.pumpAndSettle();
  }

  testWidgets('Plex offers to sign in beside the token field',
      (WidgetTester tester) async {
    await openForm(tester);
    await pickPlex(tester);

    expect(find.text('Sign in with Plex'), findsOneWidget);
    // Typing a token by hand still works for anyone who already has one.
    expect(find.text('Plex token (X-Plex-Token)'), findsOneWidget);
  });

  testWidgets('no other service pretends to have a Plex account',
      (WidgetTester tester) async {
    // The form opens on Sonarr.
    await openForm(tester);

    expect(find.text('Sign in with Plex'), findsNothing);
  });

  test('the client identifier is 32 hex characters', () {
    final String id = generatePlexClientIdentifier();

    expect(id, hasLength(32));
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
    expect(id, isNot(generatePlexClientIdentifier()));
  });
}
