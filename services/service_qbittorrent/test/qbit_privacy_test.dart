import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

import 'support/qbit_fixtures.dart';

/// Whether a torrent is private is only shown where qBittorrent says so.
///
/// It says so in the list from 5.0, and not until a magnet's metadata is in.
/// Before that the rows carry nothing, and a torrent's properties carry
/// `is_private` from 4.5.1. Calling everything else Public would tell someone
/// on 4.x that a private torrent is safe to remove.
void main() {
  group('what a row of the list says', () {
    QbitTorrent row({
      QbitRelease release = QbitRelease.v512,
      bool private = false,
      bool hasMetadata = true,
    }) =>
        QbitTorrent.fromJson(
          torrentRowJson(
            release: release,
            private: private,
            hasMetadata: hasMetadata,
          ),
        );

    test('qBittorrent 5 marks a private torrent and a public one', () {
      expect(row(private: true).private, isTrue);
      expect(row().private, isFalse);
    });

    test('qBittorrent 5 does not say until a magnet has its metadata', () {
      expect(row(private: true, hasMetadata: false).private, isNull);
    });

    test('qBittorrent 4 does not say', () {
      expect(row(release: QbitRelease.v467, private: true).private, isNull);
      expect(row(release: QbitRelease.v439, private: true).private, isNull);
    });
  });

  group("what a torrent's properties say", () {
    bool? isPrivate(
      QbitRelease release, {
      required bool private,
      bool hasMetadata = true,
    }) =>
        qbitIsPrivate(
          QbitTorrentProperties.fromJson(
            torrentPropertiesJson(
              release: release,
              private: private,
              hasMetadata: hasMetadata,
            ),
          ),
        );

    test('qBittorrent 5 answers for a private torrent and a public one', () {
      expect(isPrivate(QbitRelease.v512, private: true), isTrue);
      expect(isPrivate(QbitRelease.v512, private: false), isFalse);
    });

    test('qBittorrent 4.6 answers too, under its older name', () {
      expect(isPrivate(QbitRelease.v467, private: true), isTrue);
      expect(isPrivate(QbitRelease.v467, private: false), isFalse);
    });

    // Both releases report is_private false for a torrent with no metadata,
    // whatever its tracker; 5 marks the real answer as not known yet.
    test('neither answers until a magnet has its metadata', () {
      expect(
        isPrivate(QbitRelease.v512, private: true, hasMetadata: false),
        isNull,
      );
      expect(
        isPrivate(QbitRelease.v467, private: true, hasMetadata: false),
        isNull,
      );
    });

    test('qBittorrent 4.3 does not say', () {
      expect(isPrivate(QbitRelease.v439, private: true), isNull);
    });
  });

  group('the torrent list', () {
    testWidgets('marks a private torrent Private and a public one Public',
        (WidgetTester tester) async {
      await _openList(tester, <Map<String, dynamic>>[
        torrentRowJson(hash: 'a' * 40, name: 'Private one', private: true),
        torrentRowJson(hash: 'b' * 40, name: 'Public one'),
      ]);

      expect(_badgeOf(tester, 'Private one'), 'Private');
      expect(_badgeOf(tester, 'Public one'), 'Public');
    });

    testWidgets('says neither on qBittorrent 4, which does not tell',
        (WidgetTester tester) async {
      await _openList(tester, <Map<String, dynamic>>[
        torrentRowJson(
          release: QbitRelease.v467,
          name: 'Private one',
          private: true,
        ),
      ]);

      expect(find.text('Private one'), findsOneWidget);
      expect(find.text('Public'), findsNothing);
      expect(find.text('Private'), findsNothing);
    });

    testWidgets('says neither while a magnet is fetching its metadata',
        (WidgetTester tester) async {
      await _openList(tester, <Map<String, dynamic>>[
        torrentRowJson(
          name: 'A magnet',
          state: 'metaDL',
          progress: 0,
          private: true,
          hasMetadata: false,
        ),
      ]);

      expect(find.text('Fetching metadata'), findsOneWidget);
      expect(find.text('Public'), findsNothing);
      expect(find.text('Private'), findsNothing);
    });

    // The state pill and the badge share a line with the sizes. Where they
    // do not all fit the sizes move down a line: cut short they would read
    // "754 MB / 7...", which leaves out the number the line is there for.
    testWidgets('keeps the sizes whole on a narrow phone',
        (WidgetTester tester) async {
      await _openList(
        tester,
        <Map<String, dynamic>>[
          torrentRowJson(name: 'Private one', private: true),
        ],
        width: 320,
      );

      expect(tester.takeException(), isNull);
      expect(_badgeOf(tester, 'Private one'), 'Private');
      final Finder sizes = find.text('754 MB / 754 MB');
      expect(sizes, findsOneWidget);
      expect(_isCutShort(tester, sizes), isFalse);
    });
  });

  group("a torrent's own screen", () {
    testWidgets('says Private on qBittorrent 5', (WidgetTester tester) async {
      await _openDetail(tester, QbitRelease.v512, private: true);

      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Public'), findsNothing);
    });

    testWidgets('says Public on qBittorrent 5', (WidgetTester tester) async {
      await _openDetail(tester, QbitRelease.v512, private: false);

      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsNothing);
    });

    // The list cannot say on 4.6, but the properties this screen already
    // loads can.
    testWidgets('says Private on qBittorrent 4.6, from its properties',
        (WidgetTester tester) async {
      await _openDetail(tester, QbitRelease.v467, private: true);

      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Public'), findsNothing);
    });

    testWidgets('says Public on qBittorrent 4.6, from its properties',
        (WidgetTester tester) async {
      await _openDetail(tester, QbitRelease.v467, private: false);

      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsNothing);
    });

    testWidgets('says neither on a qBittorrent too old to tell',
        (WidgetTester tester) async {
      await _openDetail(tester, QbitRelease.v439, private: true);

      expect(find.text('Seeding (idle)'), findsOneWidget);
      expect(find.text('Public'), findsNothing);
      expect(find.text('Private'), findsNothing);
    });

    // Without metadata 4.6 answers `is_private: false` for every torrent.
    testWidgets('says neither while a magnet is fetching its metadata',
        (WidgetTester tester) async {
      for (final QbitRelease release in <QbitRelease>[
        QbitRelease.v467,
        QbitRelease.v512,
      ]) {
        await _openDetail(
          tester,
          release,
          private: true,
          hasMetadata: false,
          state: 'metaDL',
        );

        expect(find.text('Fetching metadata'), findsOneWidget);
        expect(find.text('Public'), findsNothing, reason: '$release');
        expect(find.text('Private'), findsNothing, reason: '$release');
      }
    });

    // Both speeds, the privacy pill and the time left share one line.
    testWidgets('fits a narrow phone while a private torrent downloads',
        (WidgetTester tester) async {
      await _openDetail(
        tester,
        QbitRelease.v512,
        private: true,
        state: 'downloading',
        progress: 0.42,
        dlSpeed: 11744051,
        upSpeed: 1153433,
        eta: 1630,
        width: 320,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('11.2 MB/s'), findsOneWidget);
      expect(find.text('27m 10s'), findsOneWidget);
    });
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

void _phone(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openList(
  WidgetTester tester,
  List<Map<String, dynamic>> rows, {
  double width = 411,
}) async {
  _phone(tester, width);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        qbitRawTorrentsProvider(_instance).overrideWith(
          (Ref ref) async => rows.map(QbitTorrent.fromJson).toList(),
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
}

Future<void> _openDetail(
  WidgetTester tester,
  QbitRelease release, {
  required bool private,
  bool hasMetadata = true,
  String state = 'stalledUP',
  double progress = 1,
  int dlSpeed = 0,
  int upSpeed = 0,
  int eta = 8640000,
  double width = 411,
}) async {
  _phone(tester, width);
  final QbitTorrent row = QbitTorrent.fromJson(
    torrentRowJson(
      release: release,
      private: private,
      hasMetadata: hasMetadata,
      state: state,
      progress: progress,
      dlspeed: dlSpeed,
      upspeed: upSpeed,
      eta: eta,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope each time, for the test that opens the screen twice.
      key: UniqueKey(),
      overrides: <Override>[
        qbitRawTorrentsProvider(_instance)
            .overrideWith((Ref ref) async => <QbitTorrent>[row]),
        qbitPropertiesProvider((_instance, row.hash)).overrideWith(
          (Ref ref) async => QbitTorrentProperties.fromJson(
            torrentPropertiesJson(
              release: release,
              private: private,
              hasMetadata: hasMetadata,
              dlSpeed: dlSpeed,
              upSpeed: upSpeed,
            ),
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

/// The privacy badge on the row of the torrent called [name].
String? _badgeOf(WidgetTester tester, String name) {
  final Finder row = find.ancestor(
    of: find.text(name),
    matching: find.byType(InkWell),
  );
  for (final String word in <String>['Private', 'Public']) {
    if (find
        .descendant(of: row.first, matching: find.text(word))
        .evaluate()
        .isNotEmpty) {
      return word;
    }
  }
  return null;
}

bool _isCutShort(WidgetTester tester, Finder text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(text);
  return paragraph.didExceedMaxLines ||
      paragraph.size.width + 0.5 <
          paragraph.getMaxIntrinsicWidth(double.infinity);
}
