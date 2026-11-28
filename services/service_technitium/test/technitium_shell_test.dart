import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_technitium/service_technitium.dart';

import 'support/technitium_test_instance.dart';

void main() {
  testWidgets('TechnitiumShell renders tabs and switches destinations',
      (WidgetTester tester) async {
    final TechnitiumStatus status = TechnitiumStatus(
      version: '13.0.0',
      isBlockingEnabled: true,
      readAt: DateTime.now(),
    );
    const TechnitiumStats stats = TechnitiumStats(
      totalQueries: 1250,
      blockedQueries: 250,
      cachedQueries: 400,
      clientsCount: 3,
      topClients: <TechnitiumTopItem>[
        TechnitiumTopItem(name: '192.168.1.100', hits: 500),
      ],
      topDomains: <TechnitiumTopItem>[
        TechnitiumTopItem(name: 'google.com', hits: 300),
      ],
      topBlockedDomains: <TechnitiumTopItem>[
        TechnitiumTopItem(name: 'ads.example.com', hits: 150),
      ],
    );
    const TechnitiumSettings settings = TechnitiumSettings();
    const TechnitiumQueryLogPage queryLogPage = TechnitiumQueryLogPage(
      entries: <TechnitiumQueryEntry>[
        TechnitiumQueryEntry(
          qname: 'ads.tracker.net',
          qtype: 'A',
          clientIp: '192.168.1.50',
          responseType: 'Blocked',
          rcode: 'NxDomain',
          protocol: 'UDP',
          roundTripTimeMs: 0.8,
          answer: '0.0.0.0',
        ),
      ],
      totalEntries: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          technitiumStatusProvider(technitiumTestInstance)
              .overrideWith((_) async => status),
          technitiumStatsProvider(technitiumTestInstance)
              .overrideWith((_) async => stats),
          technitiumSettingsProvider(technitiumTestInstance)
              .overrideWith((_) async => settings),
          technitiumBlockedZonesProvider(technitiumTestInstance).overrideWith(
            (_) async => const <TechnitiumBlockedZone>[
              TechnitiumBlockedZone(domain: 'blocked.example.com'),
            ],
          ),
          technitiumQueryLogProvider(technitiumTestInstance)
              .overrideWith((_) async => queryLogPage),
        ],
        child: const MaterialApp(
          home: TechnitiumShell(instance: technitiumTestInstance),
        ),
      ),
    );

    // Initial pump
    await tester.pumpAndSettle();

    // Verify Overview Tab rendered
    expect(find.text('Technitium Test'), findsOneWidget);
    expect(find.text('Protection is on'), findsOneWidget);
    expect(find.text('Total Queries'), findsOneWidget);
    expect(find.text('Top Clients'), findsOneWidget);
    expect(find.text('192.168.1.100'), findsOneWidget);
    expect(find.text('Top Blocked Domains'), findsOneWidget);
    expect(find.text('ads.example.com'), findsOneWidget);

    // Switch to Query Log tab
    await tester.tap(find.text('Query log'));
    await tester.pumpAndSettle();
    expect(find.text('ads.tracker.net'), findsOneWidget);
    expect(find.text('Blocked'), findsWidgets);

    // Tap query log row to open detail modal
    await tester.tap(find.text('ads.tracker.net'));
    await tester.pumpAndSettle();
    expect(find.text('192.168.1.50'), findsWidgets);
    expect(find.text('Already Blocked (Re-add)'), findsOneWidget);

    // Close modal
    await tester.tap(find.text('Already Blocked (Re-add)'));
    await tester.pumpAndSettle();

    // Switch to Blocked zones tab
    await tester.tap(find.text('Blocked zones'));
    await tester.pumpAndSettle();
    expect(find.text('blocked.example.com'), findsOneWidget);
    expect(find.text('Add zone'), findsOneWidget);

    // Switch to Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('DNS Cache'), findsOneWidget);
    expect(find.text('Flush DNS cache'), findsOneWidget);
    expect(find.text('Enable Blocking'), findsOneWidget);
  });
}
