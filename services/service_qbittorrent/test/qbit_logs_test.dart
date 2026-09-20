import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

void main() {
  group('QbitLogEntry', () {
    test('parses json with milliseconds timestamp and computes level', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'id': 10,
        'message': 'qBittorrent v5.0 started',
        'timestamp': 1603884800000,
        'type': 1,
      };

      final QbitLogEntry entry = QbitLogEntry.fromJson(json);
      expect(entry.id, 10);
      expect(entry.message, 'qBittorrent v5.0 started');
      expect(entry.timestamp, 1603884800000);
      expect(entry.type, 1);
      expect(entry.level, QbitLogLevel.normal);
      expect(entry.dateTime.millisecondsSinceEpoch, 1603884800000);
      expect(entry.timeText, isNotEmpty);
      expect(entry.toJson(), json);
    });

    test('handles seconds timestamp and all severity types', () {
      final QbitLogEntry normal = QbitLogEntry.fromJson(const <String, dynamic>{
        'id': 1,
        'message': 'normal msg',
        'timestamp': 1603884800,
        'type': 1,
      });
      final QbitLogEntry info = QbitLogEntry.fromJson(const <String, dynamic>{
        'id': 2,
        'message': 'info msg',
        'timestamp': 1603884800,
        'type': 2,
      });
      final QbitLogEntry warning = QbitLogEntry.fromJson(const <String, dynamic>{
        'id': 3,
        'message': 'warning msg',
        'timestamp': 1603884800,
        'type': 4,
      });
      final QbitLogEntry critical =
          QbitLogEntry.fromJson(const <String, dynamic>{
        'id': 4,
        'message': 'critical msg',
        'timestamp': 1603884800,
        'type': 8,
      });

      expect(normal.level, QbitLogLevel.normal);
      expect(info.level, QbitLogLevel.info);
      expect(warning.level, QbitLogLevel.warning);
      expect(critical.level, QbitLogLevel.critical);
      expect(normal.dateTime.millisecondsSinceEpoch, 1603884800000);
    });
  });

  group('QbittorrentLogsTab', () {
    const Instance instance = Instance(
      id: 'qbit-test',
      name: 'My qBittorrent',
      kind: ServiceKind.qbittorrent,
      localUrl: 'http://localhost:8080',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'k'),
    );

    final List<QbitLogEntry> sampleLogs = <QbitLogEntry>[
      const QbitLogEntry(
        id: 1,
        message: 'System initialized successfully',
        timestamp: 1603884800000,
        type: 1,
      ),
      const QbitLogEntry(
        id: 2,
        message: 'UPnP port mapping failed',
        timestamp: 1603884810000,
        type: 4,
      ),
      const QbitLogEntry(
        id: 3,
        message: 'Fatal error: disk space exhausted',
        timestamp: 1603884820000,
        type: 8,
      ),
    ];

    testWidgets('renders logs with time, level badge, and messages',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            qbitLogsProvider(instance)
                .overrideWith((Ref ref) async => sampleLogs),
          ],
          child: MaterialApp(
            theme: AtriumTheme.light(null),
            home: const QbittorrentLogsTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My qBittorrent Logs'), findsOneWidget);
      expect(find.text('System initialized successfully'), findsOneWidget);
      expect(find.text('UPnP port mapping failed'), findsOneWidget);
      expect(find.text('Fatal error: disk space exhausted'), findsOneWidget);
      expect(find.text('NORMAL'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);
    });

    testWidgets('filters logs by level chip', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            qbitLogsProvider(instance)
                .overrideWith((Ref ref) async => sampleLogs),
          ],
          child: MaterialApp(
            theme: AtriumTheme.light(null),
            home: const QbittorrentLogsTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Warning' chip
      await tester.tap(find.widgetWithText(FilterChip, 'Warning'));
      await tester.pumpAndSettle();

      expect(find.text('UPnP port mapping failed'), findsOneWidget);
      expect(find.text('System initialized successfully'), findsNothing);
      expect(find.text('Fatal error: disk space exhausted'), findsNothing);

      // Tap 'All' chip to reset
      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();

      expect(find.text('System initialized successfully'), findsOneWidget);
      expect(find.text('UPnP port mapping failed'), findsOneWidget);
      expect(find.text('Fatal error: disk space exhausted'), findsOneWidget);
    });

    testWidgets('filters logs by search query', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            qbitLogsProvider(instance)
                .overrideWith((Ref ref) async => sampleLogs),
          ],
          child: MaterialApp(
            theme: AtriumTheme.light(null),
            home: const QbittorrentLogsTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap search icon
      await tester.tap(find.byTooltip('Search logs'));
      await tester.pumpAndSettle();

      // Type search query
      await tester.enterText(find.byType(TextField), 'disk');
      await tester.pumpAndSettle();

      expect(find.text('Fatal error: disk space exhausted'), findsOneWidget);
      expect(find.text('System initialized successfully'), findsNothing);
      expect(find.text('UPnP port mapping failed'), findsNothing);
    });

    testWidgets('shows empty state when no logs match',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            qbitLogsProvider(instance)
                .overrideWith((Ref ref) async => sampleLogs),
          ],
          child: MaterialApp(
            theme: AtriumTheme.light(null),
            home: const QbittorrentLogsTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap search icon
      await tester.tap(find.byTooltip('Search logs'));
      await tester.pumpAndSettle();

      // Type search query that matches nothing
      await tester.enterText(find.byType(TextField), 'nonexistent query');
      await tester.pumpAndSettle();

      expect(find.text('No matching logs'), findsOneWidget);
    });
  });
}
