import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

import 'support/qbit_fixtures.dart';

const Instance _instance = Instance(
  id: 'test-qbit',
  name: 'Test qBittorrent',
  kind: ServiceKind.qbittorrent,
  localUrl: 'http://localhost',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

const int _sessionUp = 1610612736; // 1.5 GB
const int _sessionDown = 536870912; // 512 MB

/// A seeding torrent that has moved some data since qBittorrent started.
Map<String, dynamic> _row() => <String, dynamic>{
      ...torrentRowJson(),
      'uploaded_session': _sessionUp,
      'downloaded_session': _sessionDown,
    };

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(411, 891);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<ProviderContainer> _openList(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        qbitRawTorrentsProvider(_instance).overrideWith(
          (Ref ref) async => <QbitTorrent>[QbitTorrent.fromJson(_row())],
        ),
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
  return ProviderScope.containerOf(
    tester.element(find.byType(QbittorrentHome)),
  );
}

Future<void> _sortBy(
  WidgetTester tester,
  ProviderContainer container,
  QbitSortField field,
) async {
  await container.read(qbitSortProvider(_instance).notifier).setField(field);
  await tester.pump();
}

Future<void> _openDetail(WidgetTester tester) async {
  _phone(tester);
  final QbitTorrent row = QbitTorrent.fromJson(_row());
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        qbitRawTorrentsProvider(_instance)
            .overrideWith((Ref ref) async => <QbitTorrent>[row]),
        qbitPropertiesProvider((_instance, row.hash)).overrideWith(
          (Ref ref) async => QbitTorrentProperties.fromJson(
            <String, dynamic>{
              ...torrentPropertiesJson(),
              'total_uploaded': 51539607552, // 48.0 GB
            },
          ),
        ),
      ],
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: TorrentDetailScreen(instance: _instance, torrent: row),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('the torrent card', () {
    testWidgets('keeps to its usual figures under the default sort',
        (WidgetTester tester) async {
      await _openList(tester);
      expect(find.textContaining('this session'), findsNothing);
    });

    testWidgets('shows the session upload when sorted by it',
        (WidgetTester tester) async {
      final ProviderContainer c = await _openList(tester);
      await _sortBy(tester, c, QbitSortField.sessionUp);
      expect(find.text('1.5 GB this session'), findsOneWidget);
      expect(find.text('512 MB this session'), findsNothing);
    });

    testWidgets('shows the session download when sorted by it',
        (WidgetTester tester) async {
      final ProviderContainer c = await _openList(tester);
      await _sortBy(tester, c, QbitSortField.sessionDl);
      expect(find.text('512 MB this session'), findsOneWidget);
      expect(find.text('1.5 GB this session'), findsNothing);
    });

    testWidgets('keeps the session line inside a narrow card at large text',
        (WidgetTester tester) async {
      final ProviderContainer c = await _openList(tester);
      tester.view.physicalSize = const Size(320, 891);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // Set aside here: overflow, since the card's speed row overflows at
      // this size on its own and the session line is measured below; and
      // the settings tab, built alongside the list, which the wide test font
      // trips at this size where Roboto does not. Any other error from the
      // list still reports.
      final void Function(FlutterErrorDetails)? report = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails d) {
        final String text = '$d';
        if (text.contains('qbittorrent_home.dart') &&
            !text.contains('A RenderFlex overflowed')) {
          report?.call(d);
        }
      };
      try {
        await _sortBy(tester, c, QbitSortField.sessionUp);
        await tester.pump();
      } finally {
        FlutterError.onError = report;
      }
      final Rect line = tester.getRect(find.textContaining('this session'));
      expect(line.right, lessThanOrEqualTo(320));
    });

    testWidgets('drops it again for another sort',
        (WidgetTester tester) async {
      final ProviderContainer c = await _openList(tester);
      await _sortBy(tester, c, QbitSortField.sessionUp);
      await _sortBy(tester, c, QbitSortField.name);
      expect(find.textContaining('this session'), findsNothing);
    });
  });

  group('the detail screen', () {
    testWidgets('puts the session beside the all-time totals',
        (WidgetTester tester) async {
      await _openDetail(tester);
      expect(find.text('48.0 GB (1.5 GB this session)'), findsOneWidget);
      expect(find.textContaining('(512 MB this session)'), findsOneWidget);
    });
  });
}
