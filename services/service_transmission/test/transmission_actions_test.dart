import 'package:core_networking/core_networking.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_transmission/service_transmission.dart';

import 'support/fake_transmission.dart';
import 'support/pump.dart';
import 'support/transmission_fixtures.dart';
import 'support/transmission_test_instance.dart';

void main() {
  late FakeTransmission fake;

  setUp(() {
    fake = FakeTransmission()
      ..on('torrent-get', <String, Object?>{'torrents': <Object>[]});
  });

  final List<TransmissionTorrent> targets = <TransmissionTorrent>[
    TransmissionTorrent.fromJson(torrentJson(hash: 'a', name: 'Alpha')),
    TransmissionTorrent.fromJson(torrentJson(hash: 'b', name: 'Beta')),
  ];

  /// A screen with one button per action, so each can be driven in turn.
  Future<void> pumpHarness(WidgetTester tester) async {
    // Tall enough for every action's button to be on screen.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          instanceDioProvider(transmissionTestInstance)
              .overrideWith((Ref ref) async => fakeTransmissionDio(fake)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                  ListView(
                children: <Widget>[
                  for (final TransmissionTorrentAction a
                      in TransmissionTorrentAction.values)
                    TextButton(
                      onPressed: () => performTransmissionAction(
                        context,
                        ref,
                        transmissionTestInstance,
                        a,
                        a == TransmissionTorrentAction.rename ||
                                a == TransmissionTorrentAction.copyMagnet
                            ? targets.sublist(0, 1)
                            : targets,
                      ),
                      child: Text(a.name),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> run(WidgetTester tester, TransmissionTorrentAction a) async {
    await tester.tap(find.text(a.name));
    await settle(tester);
  }

  testWidgets('pause sends every hash in one call', (WidgetTester tester) async {
    await pumpHarness(tester);
    await run(tester, TransmissionTorrentAction.pause);
    expect(fake.single('torrent-stop').arguments['ids'], <String>['a', 'b']);
  });

  testWidgets('set location asks for a path and moves the data',
      (WidgetTester tester) async {
    await pumpHarness(tester);
    await run(tester, TransmissionTorrentAction.setLocation);
    // Prefilled with the first torrent's folder.
    expect(find.widgetWithText(TextField, '/downloads'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '/data/iso');
    await tester.tap(find.text('Apply'));
    await settle(tester);

    expect(fake.single('torrent-set-location').arguments, <String, dynamic>{
      'ids': <String>['a', 'b'],
      'location': '/data/iso',
      'move': true,
    });
  });

  testWidgets('rename sends the old and new names',
      (WidgetTester tester) async {
    await pumpHarness(tester);
    await run(tester, TransmissionTorrentAction.rename);
    await tester.enterText(find.byType(TextField), 'Alpha 2');
    // The dialog's title says Rename too; the button is the filled one.
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await settle(tester);

    expect(fake.single('torrent-rename-path').arguments, <String, dynamic>{
      'ids': <String>['a'],
      'path': 'Alpha',
      'name': 'Alpha 2',
    });
  });

  testWidgets('edit labels writes a trimmed, comma-separated list',
      (WidgetTester tester) async {
    await pumpHarness(tester);
    await run(tester, TransmissionTorrentAction.editLabels);
    await tester.enterText(find.byType(TextField), ' linux, iso ,,');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(fake.single('torrent-set').arguments, <String, dynamic>{
      'ids': <String>['a', 'b'],
      'labels': <String>['linux', 'iso'],
    });
  });

  testWidgets('trash preselects deleting the data and asks first',
      (WidgetTester tester) async {
    await pumpHarness(tester);
    await run(tester, TransmissionTorrentAction.trash);
    final Checkbox box = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(box.value, isTrue);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await settle(tester);

    expect(fake.single('torrent-remove').arguments, <String, dynamic>{
      'ids': <String>['a', 'b'],
      'delete-local-data': true,
    });
  });

  testWidgets('copy magnet fetches the link and copies it',
      (WidgetTester tester) async {
    fake.on('torrent-get', <String, Object?>{
      'torrents': <Map<String, Object?>>[
        <String, Object?>{'magnetLink': 'magnet:?xt=urn:btih:a'},
      ],
    });
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpHarness(tester);
    await run(tester, TransmissionTorrentAction.copyMagnet);

    expect(copied, 'magnet:?xt=urn:btih:a');
    expect(find.text('Magnet link copied'), findsOneWidget);
  });

  testWidgets('a failure lands in a snackbar', (WidgetTester tester) async {
    fake.fail('torrent-verify', 'No such torrent');
    await pumpHarness(tester);
    await run(tester, TransmissionTorrentAction.verify);

    expect(find.textContaining('No such torrent'), findsOneWidget);
  });

  test('the menu hides labels and rename where they do not apply', () {
    List<TransmissionTorrentAction> values(
      List<PopupMenuEntry<TransmissionTorrentAction>> items,
    ) =>
        <TransmissionTorrentAction>[
          for (final PopupMenuEntry<TransmissionTorrentAction> e in items)
            if (e is PopupMenuItem<TransmissionTorrentAction>) e.value!,
        ];
    final List<TransmissionTorrentAction> bulk = values(
      transmissionActionMenuItems(
        anyStopped: true,
        single: false,
        labelsSupported: false,
      ),
    );
    expect(bulk, isNot(contains(TransmissionTorrentAction.rename)));
    expect(bulk, isNot(contains(TransmissionTorrentAction.editLabels)));
    expect(bulk, isNot(contains(TransmissionTorrentAction.copyMagnet)));
    expect(bulk, contains(TransmissionTorrentAction.resumeNow));

    final List<TransmissionTorrentAction> single = values(
      transmissionActionMenuItems(
        anyStopped: false,
        single: true,
        labelsSupported: true,
      ),
    );
    expect(single, contains(TransmissionTorrentAction.rename));
    expect(single, contains(TransmissionTorrentAction.editLabels));
    expect(single, isNot(contains(TransmissionTorrentAction.resumeNow)));
  });
}
