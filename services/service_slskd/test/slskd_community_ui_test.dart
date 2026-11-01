import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_slskd/service_slskd.dart';
import 'package:service_slskd/src/browse/slskd_user_bio_sheet.dart';
import 'package:service_slskd/src/community/slskd_chat_composer.dart';
import 'package:service_slskd/src/community/slskd_room_members_sheet.dart';

final String? _fontDir = () {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    return null;
  }
  return '$flutterRoot/bin/cache/artifacts/material_fonts';
}();

final String screenshotDir = Platform.environment['SLSKD_SHOTS_DIR'] ??
    'build/screenshots/service_slskd';

const Instance testInstance = Instance(
  id: 'test-slskd-community',
  name: 'Soulseek Daemon',
  kind: ServiceKind.slskd,
  localUrl: 'http://127.0.0.1:5030/',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthApiKey(apiKey: 'secret-key'),
);

Future<void> _loadFonts() async {
  if (_fontDir == null) {
    return;
  }
  final Directory dir = Directory(_fontDir!);
  if (!dir.existsSync()) {
    return;
  }

  File? findFontFile(String filename) {
    final File direct = File('$_fontDir/$filename');
    if (direct.existsSync()) {
      return direct;
    }
    final String lower = filename.toLowerCase();
    try {
      for (final FileSystemEntity entity in dir.listSync()) {
        if (entity is File &&
            entity.path.split(RegExp(r'[/\\]')).last.toLowerCase() == lower) {
          return entity;
        }
      }
    } catch (_) {}
    return null;
  }

  final FontLoader roboto = FontLoader('Roboto');
  for (final String font in <String>[
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final File? f = findFontFile(font);
    if (f != null && f.existsSync()) {
      roboto.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
  }
  await roboto.load();

  final File? icons = findFontFile('MaterialIcons-Regular.otf');
  if (icons != null && icons.existsSync()) {
    final FontLoader materialIcons = FontLoader('MaterialIcons');
    materialIcons.addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await materialIcons.load();
  }
}

Future<void> capture(
  WidgetTester tester,
  GlobalKey key,
  String fileName,
) async {
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final Uint8List? pngBytes = await tester.runAsync<Uint8List?>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  });
  final Directory dir = Directory(screenshotDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final File outFile = File('$screenshotDir/$fileName');
  outFile.writeAsBytesSync(pngBytes!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  final mockJoinedRooms = <String>['electronic', 'audiophile'];

  final mockAvailableRooms = <SlskdRoomInfo>[
    const SlskdRoomInfo(name: 'electronic', userCount: 142),
    const SlskdRoomInfo(name: 'audiophile', userCount: 88),
    const SlskdRoomInfo(name: 'ambient', userCount: 64),
    const SlskdRoomInfo(name: 'jazz', userCount: 39),
    const SlskdRoomInfo(name: 'rock', userCount: 95),
  ];

  final mockRoomUsers = <SlskdUserPresence>[
    const SlskdUserPresence(username: 'SynthWave99', status: 2, fileCount: 4200, averageSpeed: 1048576),
    const SlskdUserPresence(username: 'TechnoHead', status: 2, fileCount: 1850, averageSpeed: 524288),
    const SlskdUserPresence(username: 'GrooveMaster', status: 1, fileCount: 920, averageSpeed: 262144),
    const SlskdUserPresence(username: 'AudioPhile99', status: 2, fileCount: 8500, averageSpeed: 2097152),
  ];

  final mockRoomMessages = <SlskdRoomMessage>[
    SlskdRoomMessage(
      timestamp: DateTime(2026, 10, 24, 18, 45),
      username: 'SynthWave99',
      message: 'Anyone got the 24-bit Discovery master?',
      roomName: 'electronic',
    ),
    SlskdRoomMessage(
      timestamp: DateTime(2026, 10, 24, 18, 46),
      username: 'TechnoHead',
      message: 'Check my shares, folder 02!',
      roomName: 'electronic',
    ),
    SlskdRoomMessage(
      timestamp: DateTime(2026, 10, 24, 18, 47),
      username: 'System',
      message: 'AmbientLover joined the room.',
      roomName: 'electronic',
    ),
    SlskdRoomMessage(
      timestamp: DateTime(2026, 10, 24, 18, 48),
      username: 'You',
      message: 'Thanks! Enqueuing track 03 now.',
      roomName: 'electronic',
      self: true,
    ),
  ];

  final mockConversations = <SlskdConversation>[
    SlskdConversation(
      username: 'AudioPhile99',
      unAcknowledgedMessageCount: 1,
      messages: <SlskdPrivateMessage>[
        SlskdPrivateMessage(
          id: 1,
          username: 'AudioPhile99',
          timestamp: DateTime(2026, 10, 24, 19, 10),
          direction: MessageDirection.inbound,
          message: 'Hey, let me know if you need more FLAC vinyl rips!',
        ),
      ],
    ),
    SlskdConversation(
      username: 'SynthWave99',
      messages: <SlskdPrivateMessage>[
        SlskdPrivateMessage(
          id: 2,
          username: 'SynthWave99',
          timestamp: DateTime(2026, 10, 24, 17, 30),
          direction: MessageDirection.inbound,
          message: 'Thanks for sharing the Daft Punk albums!',
        ),
      ],
    ),
  ];

  final mockDmMessages = <SlskdPrivateMessage>[
    SlskdPrivateMessage(
      id: 1,
      username: 'AudioPhile99',
      timestamp: DateTime(2026, 10, 24, 19, 10),
      direction: MessageDirection.inbound,
      message: 'Hey, let me know if you need more FLAC vinyl rips!',
    ),
    SlskdPrivateMessage(
      id: 2,
      username: 'AudioPhile99',
      timestamp: DateTime(2026, 10, 24, 19, 12),
      direction: MessageDirection.outbound,
      message: 'Yes please! Looking for Random Access Memories 24-bit.',
    ),
  ];

  group('SlskdCommunityTab Widget & Screenshot Tests', () {
    testWidgets('renders Two Tabs, Contextual FABs, SearchBars, Discover Sheet, and Active Chat subviews',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GlobalKey repaintKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdActiveTabProvider(testInstance).overrideWith((ref) => 3),
            slskdJoinedRoomNamesProvider(testInstance).overrideWith((ref) => mockJoinedRooms),
            slskdAvailableRoomsProvider(testInstance).overrideWith((ref) => mockAvailableRooms),
            slskdRoomMessagesProvider((testInstance, 'electronic')).overrideWith(
              (ref) => mockRoomMessages,
            ),
            slskdRoomUsersProvider((testInstance, 'electronic')).overrideWith(
              (ref) => mockRoomUsers,
            ),
            slskdConversationsProvider(testInstance).overrideWith(
              (ref) => mockConversations,
            ),
            slskdConversationMessagesProvider((testInstance, 'AudioPhile99')).overrideWith(
              (ref) => mockDmMessages,
            ),
            // Async like the real request, so the profile button only has the
            // bio if something keeps this provider alive while it loads.
            slskdUserInfoProvider((testInstance, 'AudioPhile99')).overrideWith(
              (ref) async => const SlskdUserInfo(description: 'Sharing 24-bit FLAC vinyl rips.'),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFF0D9488),
              brightness: Brightness.dark,
              fontFamily: 'Roboto',
            ),
            builder: (BuildContext context, Widget? child) {
              return RepaintBoundary(
                key: repaintKey,
                child: child!,
              );
            },
            home: const SlskdHome(instance: testInstance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // -----------------------------------------------------------------------
      // 1. Direct Messages Tab (Tab 0)
      // -----------------------------------------------------------------------
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byType(SearchBar)),
        findsOneWidget,
      );
      expect(find.text('Direct Messages (2)'), findsOneWidget);
      expect(find.text('Chat Rooms (2)'), findsOneWidget);
      expect(find.text('AudioPhile99'), findsOneWidget);
      expect(find.text('SynthWave99'), findsOneWidget);
      expect(find.text('Hey, let me know if you need more FLAC vinyl rips!'), findsOneWidget);
      expect(find.byKey(const ValueKey('new_dm_fab')), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_community_dms.png');
      await capture(tester, repaintKey, 'slskd_community_inbox.png');

      // -----------------------------------------------------------------------
      // 2. Direct Messages Search Filtering
      // -----------------------------------------------------------------------
      final dmSearchFinder = find.widgetWithText(SearchBar, 'Search direct messages...');
      expect(dmSearchFinder, findsOneWidget);

      await tester.enterText(
        find.descendant(of: dmSearchFinder, matching: find.byType(TextField)),
        'AudioPhile',
      );
      await tester.pumpAndSettle();

      expect(find.text('AudioPhile99'), findsOneWidget);
      expect(find.text('SynthWave99'), findsNothing);

      await capture(tester, repaintKey, 'slskd_community_search.png');

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(find.text('SynthWave99'), findsOneWidget);

      // -----------------------------------------------------------------------
      // 3. Switch to Chat Rooms Tab (Tab 1)
      // -----------------------------------------------------------------------
      await tester.tap(find.text('Chat Rooms (2)'));
      await tester.pumpAndSettle();

      expect(find.text('electronic'), findsOneWidget);
      expect(find.text('audiophile'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover_rooms_fab')), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_community_rooms.png');

      // -----------------------------------------------------------------------
      // 4. Open "Discover Chat Rooms" Sheet via Contextual FAB
      // -----------------------------------------------------------------------
      await tester.tap(find.byKey(const ValueKey('discover_rooms_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Discover Chat Rooms'), findsOneWidget);
      expect(find.text('ambient'), findsOneWidget);
      expect(find.text('jazz'), findsOneWidget);
      expect(find.text('rock'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_community_discover_sheet.png');

      // Close the discover sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // -----------------------------------------------------------------------
      // 5. Enter Active Room View ("electronic")
      // -----------------------------------------------------------------------
      await tester.tap(find.text('electronic'));
      await tester.pumpAndSettle();

      expect(find.text('Anyone got the 24-bit Discovery master?'), findsOneWidget);
      expect(find.text('Check my shares, folder 02!'), findsOneWidget);
      expect(find.text('AmbientLover joined the room.'), findsOneWidget);
      expect(find.text('Thanks! Enqueuing track 03 now.'), findsOneWidget);
      expect(find.text('Message electronic...'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_community_active_room.png');

      // -----------------------------------------------------------------------
      // 6. Open Room Members Sheet
      // -----------------------------------------------------------------------
      await tester.tap(find.byIcon(Icons.people_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('electronic Members (4)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SlskdRoomMembersSheet),
          matching: find.text('SynthWave99'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SlskdRoomMembersSheet),
          matching: find.text('TechnoHead'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SlskdRoomMembersSheet),
          matching: find.text('GrooveMaster'),
        ),
        findsOneWidget,
      );

      await capture(tester, repaintKey, 'slskd_community_members_sheet.png');

      // Close Members Sheet via Navigator pop
      Navigator.of(tester.element(find.byType(SlskdRoomMembersSheet))).pop();
      await tester.pumpAndSettle();

      // Open room options popup menu and test Set Room Ticker dialog
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Set Room Ticker'), findsOneWidget);
      await tester.tap(find.text('Set Room Ticker'));
      await tester.pumpAndSettle();

      expect(find.text('Set Ticker for #electronic'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Welcome to electronic room! No spam please.');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Navigate back to Community root tab view
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // -----------------------------------------------------------------------
      // 7. Active 1-on-1 Direct Message View
      // -----------------------------------------------------------------------
      // Switch back to Direct Messages Tab
      await tester.tap(find.text('Direct Messages (2)'));
      await tester.pumpAndSettle();

      // Tap conversation with "AudioPhile99"
      await tester.tap(find.text('AudioPhile99'));
      await tester.pumpAndSettle();

      expect(find.text('Hey, let me know if you need more FLAC vinyl rips!'), findsOneWidget);
      expect(find.text('Yes please! Looking for Random Access Memories 24-bit.'), findsOneWidget);
      expect(find.text('Message AudioPhile99...'), findsOneWidget);

      await capture(tester, repaintKey, 'slskd_community_active_dm.png');

      // The profile button shows the peer's bio, not an empty placeholder.
      await tester.tap(find.byTooltip('User profile bio'));
      await tester.pumpAndSettle();
      expect(find.text('Sharing 24-bit FLAC vinyl rips.'), findsOneWidget);
      Navigator.of(tester.element(find.byType(SlskdUserBioSheet))).pop();
      await tester.pumpAndSettle();

      // -----------------------------------------------------------------------
      // 8. Inter-Tab Peer Handoff ("Browse Shares" shortcut)
      // -----------------------------------------------------------------------
      await tester.tap(find.byIcon(Icons.folder_shared_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Peer Library Explorer'), findsNothing);
      expect(find.text('AudioPhile99'), findsWidgets);
    });

    testWidgets('new message dialog closes cleanly and opens the chat', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdActiveTabProvider(testInstance).overrideWith((ref) => 3),
            slskdJoinedRoomNamesProvider(testInstance).overrideWith((ref) => mockJoinedRooms),
            slskdAvailableRoomsProvider(testInstance).overrideWith((ref) => mockAvailableRooms),
            slskdConversationsProvider(testInstance).overrideWith((ref) => mockConversations),
            slskdConversationMessagesProvider((testInstance, 'NewPeer')).overrideWith(
              (ref) => const <SlskdPrivateMessage>[],
            ),
          ],
          child: const MaterialApp(home: SlskdHome(instance: testInstance)),
        ),
      );
      await tester.pumpAndSettle();

      // Cancelling disposes nothing the closing dialog still draws.
      await tester.tap(find.byTooltip('New direct message'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'NewPeer');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('New Direct Message'), findsNothing);

      await tester.tap(find.byTooltip('New direct message'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'NewPeer');
      await tester.tap(find.text('Start Chat'));
      await tester.pumpAndSettle();
      expect(find.text('Message NewPeer...'), findsOneWidget);
    });

    testWidgets('says the lists failed to load rather than that they are empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdActiveTabProvider(testInstance).overrideWith((ref) => 3),
            slskdConversationsProvider(testInstance).overrideWith(
              (ref) async => throw Exception('slskd is unreachable'),
            ),
            slskdJoinedRoomNamesProvider(testInstance).overrideWith(
              (ref) async => throw Exception('slskd is unreachable'),
            ),
            slskdAvailableRoomsProvider(testInstance).overrideWith(
              (ref) async => throw Exception('slskd is unreachable'),
            ),
          ],
          child: const MaterialApp(home: SlskdHome(instance: testInstance)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load direct messages'), findsOneWidget);
      expect(find.text('No direct messages yet.'), findsNothing);

      await tester.tap(find.text('Chat Rooms (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load your rooms'), findsOneWidget);
      expect(find.text('No chat rooms joined yet.'), findsNothing);

      await tester.tap(find.byTooltip('Discover public rooms'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load rooms'), findsOneWidget);
      expect(find.text('No public rooms found.'), findsNothing);
    });

    testWidgets('composer keeps the message when sending fails', (WidgetTester tester) async {
      bool succeed = false;
      final List<String> sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlskdChatComposer(
              onSend: (String text) async {
                sent.add(text);
                return succeed;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'hello there');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(sent, <String>['hello there']);
      expect(find.text('hello there'), findsOneWidget);

      succeed = true;
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(sent, <String>['hello there', 'hello there']);
      expect(find.text('hello there'), findsNothing);
    });

    testWidgets('composer keeps a draft typed while a send is in flight', (WidgetTester tester) async {
      final Completer<bool> pending = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlskdChatComposer(onSend: (String text) => pending.future),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'first message');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      // The next message, typed before the first one has gone out.
      await tester.enterText(find.byType(TextField), 'second message');
      pending.complete(true);
      await tester.pumpAndSettle();

      expect(find.text('second message'), findsOneWidget);
    });

    testWidgets('chats open on the newest message', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      // slskd lists messages oldest first; 60 is far more than one screen.
      final List<SlskdPrivateMessage> longThread = <SlskdPrivateMessage>[
        for (int i = 0; i < 60; i++)
          SlskdPrivateMessage(
            id: i,
            username: 'AudioPhile99',
            timestamp: DateTime(2026, 10, 24, 19).add(Duration(minutes: i)),
            direction: i.isEven ? MessageDirection.inbound : MessageDirection.outbound,
            message: 'dm number $i',
          ),
      ];
      final List<SlskdRoomMessage> longRoom = <SlskdRoomMessage>[
        for (int i = 0; i < 60; i++)
          SlskdRoomMessage(
            timestamp: DateTime(2026, 10, 24, 18).add(Duration(minutes: i)),
            username: 'SynthWave99',
            message: 'room line $i',
            roomName: 'electronic',
          ),
      ];

      Future<void> open({String? convo, String? room}) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              slskdActiveTabProvider(testInstance).overrideWith((ref) => 3),
              slskdActiveConversationUsernameProvider(testInstance).overrideWith((ref) => convo),
              slskdActiveRoomNameProvider(testInstance).overrideWith((ref) => room),
              slskdJoinedRoomNamesProvider(testInstance).overrideWith((ref) => mockJoinedRooms),
              slskdAvailableRoomsProvider(testInstance).overrideWith((ref) => mockAvailableRooms),
              slskdConversationsProvider(testInstance).overrideWith((ref) => mockConversations),
              slskdConversationMessagesProvider((testInstance, 'AudioPhile99')).overrideWith(
                (ref) => longThread,
              ),
              slskdRoomMessagesProvider((testInstance, 'electronic')).overrideWith(
                (ref) => longRoom,
              ),
              slskdRoomUsersProvider((testInstance, 'electronic')).overrideWith(
                (ref) => mockRoomUsers,
              ),
            ],
            child: const MaterialApp(home: SlskdHome(instance: testInstance)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open(convo: 'AudioPhile99');
      expect(find.text('dm number 59'), findsOneWidget);
      expect(find.text('dm number 0'), findsNothing);

      await open(room: 'electronic');
      expect(find.text('room line 59'), findsOneWidget);
      expect(find.text('room line 0'), findsNothing);
    });

    testWidgets('browsing a peer from a chat starts at their root folder', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slskdActiveTabProvider(testInstance).overrideWith((ref) => 3),
            slskdActiveConversationUsernameProvider(testInstance).overrideWith(
              (ref) => 'AudioPhile99',
            ),
            // Browse is still inside another peer's folder.
            slskdBrowseUsernameProvider(testInstance).overrideWith((ref) => 'OtherPeer'),
            slskdBrowsePathSegmentsProvider(testInstance).overrideWith(
              (ref) => const <String>['Music', 'Rock'],
            ),
            slskdUserDirectoriesProvider((testInstance, 'OtherPeer')).overrideWith(
              (ref) => const <SlskdDirectory>[],
            ),
            slskdConversationsProvider(testInstance).overrideWith((ref) => mockConversations),
            slskdConversationMessagesProvider((testInstance, 'AudioPhile99')).overrideWith(
              (ref) => mockDmMessages,
            ),
            slskdUserDirectoriesProvider((testInstance, 'AudioPhile99')).overrideWith(
              (ref) => const <SlskdDirectory>[],
            ),
          ],
          child: const MaterialApp(home: SlskdHome(instance: testInstance)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Browse AudioPhile99 shares'));
      await tester.pump();

      final ProviderContainer container =
          ProviderScope.containerOf(tester.element(find.byType(SlskdHome)));
      expect(container.read(slskdBrowsePathSegmentsProvider(testInstance)), isEmpty);
      expect(container.read(slskdBrowseUsernameProvider(testInstance)), 'AudioPhile99');
    });
  });
}
