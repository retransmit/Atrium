import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

/// Copying logs has to fit on the clipboard and say truthfully what it did.
///
/// qBittorrent keeps up to 20,000 log entries. With a live server holding
/// that many, Copy put 1.3 MB on the clipboard, Android refused it with a
/// TransactionTooLargeException, and the app still said "Copied 20000 log
/// entries to clipboard" while nothing had been copied.
void main() {
  const Instance instance = Instance(
    id: 'qbit-test',
    name: 'My qBittorrent',
    kind: ServiceKind.qbittorrent,
    localUrl: 'http://localhost:8080',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.apiKey(apiKey: 'k'),
  );

  // Entries shaped like the ones a busy server fills its log with, each
  // numbered so the order of copied lines can be checked.
  List<QbitLogEntry> logsOf(int count) => <QbitLogEntry>[
        for (int i = 0; i < count; i++)
          QbitLogEntry(
            id: i,
            message: 'WebAPI login success. IP: ::ffff:172.20.0.1 #$i',
            timestamp: 1789662480 + i,
            type: 1,
          ),
      ];

  Future<void> pumpLogs(WidgetTester tester, int count) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          qbitLogsProvider(instance)
              .overrideWith((Ref ref) async => logsOf(count)),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: const QbittorrentLogsTab(instance: instance),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Stands in for the platform clipboard, recording what was copied, or
  // refusing the way Android does when the text is too large.
  void clipboard(WidgetTester tester, {void Function(String)? onCopy}) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method != 'Clipboard.setData') return null;
        if (onCopy == null) {
          throw PlatformException(
            code: 'error',
            message: 'android.os.TransactionTooLargeException',
          );
        }
        onCopy((call.arguments as Map<Object?, Object?>)['text']! as String);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  Future<void> copy(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Copy logs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a log that fits is copied whole, oldest first',
      (WidgetTester tester) async {
    String? copied;
    clipboard(tester, onCopy: (String text) => copied = text);
    await pumpLogs(tester, 3);

    await copy(tester);

    expect(copied!.split('\n'), hasLength(3));
    expect(copied!.split('\n').first, endsWith('#0'));
    expect(copied!.split('\n').last, endsWith('#2'));
    expect(find.text('Copied 3 log entries to clipboard'), findsOneWidget);
  });

  testWidgets('a full log copies the newest entries that fit, and says so',
      (WidgetTester tester) async {
    String? copied;
    clipboard(tester, onCopy: (String text) => copied = text);
    await pumpLogs(tester, 20000);

    await copy(tester);

    expect(copied!.length, lessThanOrEqualTo(100000));
    final List<String> lines = copied!.split('\n');
    expect(lines.length, lessThan(20000));
    // The newest entry is kept, and what came before it runs on unbroken.
    expect(lines.last, endsWith('#19999'));
    expect(lines.first, endsWith('#${20000 - lines.length}'));
    expect(
      find.text(
        'Copied the newest ${lines.length} of 20000 log entries to clipboard',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a refused copy says so instead of claiming it worked',
      (WidgetTester tester) async {
    clipboard(tester);
    await pumpLogs(tester, 3);

    await copy(tester);

    expect(find.textContaining('Copied'), findsNothing);
    expect(find.text('Could not copy to the clipboard'), findsOneWidget);
  });

  testWidgets('tapping one entry reports a refused copy too',
      (WidgetTester tester) async {
    clipboard(tester);
    await pumpLogs(tester, 3);

    await tester.tap(find.textContaining('#2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Log entry copied to clipboard'), findsNothing);
    expect(find.text('Could not copy to the clipboard'), findsOneWidget);
  });
}
