import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

/// The filter button has to reach the Scaffold that actually owns the drawer.
///
/// Issue #142: the home screen nests a Scaffold inside another. The outer one
/// carries the end drawer; the inner one carries the app bar the button lives
/// in. `Scaffold.of` finds the nearest, so the button asked the inner Scaffold
/// to open a drawer it does not have, and `openEndDrawer` returns quietly
/// rather than throwing. Nothing happened and nothing was logged, while the
/// right-edge swipe kept working because that gesture belongs to the outer
/// Scaffold.
void main() {
  testWidgets('the filter button opens the drawer the outer Scaffold owns',
      (WidgetTester tester) async {
    final GlobalKey<ScaffoldState> outer = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: Scaffold(
            key: outer,
            endDrawer: const Drawer(child: Text('filters')),
            // The nesting the real screen has: the bar the button sits in
            // belongs to an inner Scaffold with no drawer of its own.
            body: Builder(
              builder: (BuildContext context) => Scaffold(
                appBar: AppBar(
                  actions: <Widget>[
                    QbittorrentAppBarActions(
                      instance: _instance,
                      onFilter: () => Scaffold.of(context).openEndDrawer(),
                    ),
                  ],
                ),
                body: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );

    expect(outer.currentState!.isEndDrawerOpen, isFalse);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(
      outer.currentState!.isEndDrawerOpen,
      isTrue,
      reason: 'the button reached the inner Scaffold, which has no end drawer',
    );
  });

  testWidgets('without a handler it still falls back to the nearest Scaffold',
      (WidgetTester tester) async {
    // The action bar is used in more than one place; where the surrounding
    // Scaffold does own the drawer, no handler needs passing.
    final GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: Scaffold(
            key: key,
            endDrawer: const Drawer(child: Text('filters')),
            appBar: AppBar(
              actions: const <Widget>[
                QbittorrentAppBarActions(instance: _instance),
              ],
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(key.currentState!.isEndDrawerOpen, isTrue);
  });

  testWidgets('the home screen hands the button the right Scaffold',
      (WidgetTester tester) async {
    // The two tests above prove the button honours a handler when given one.
    // This proves the home screen actually gives it one, which is the half
    // that was missing and where the bug lived.
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          qbitRawTorrentsProvider(_instance)
              .overrideWith((Ref ref) async => const <QbitTorrent>[]),
          qbitTransferProvider(_instance)
              .overrideWith((Ref ref) async => const QbitTransferInfo()),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: const QbittorrentHome(instance: _instance),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final QbittorrentAppBarActions actions =
        tester.widget<QbittorrentAppBarActions>(
      find.byType(QbittorrentAppBarActions),
    );
    expect(
      actions.onFilter,
      isNotNull,
      reason: 'left to Scaffold.of the button reaches the inner Scaffold, '
          'which owns no end drawer, and the tap does nothing',
    );
  });
}

const Instance _instance = Instance(
  id: 'test-qbit',
  name: 'Test qBittorrent',
  kind: ServiceKind.qbittorrent,
  localUrl: 'http://localhost',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);
