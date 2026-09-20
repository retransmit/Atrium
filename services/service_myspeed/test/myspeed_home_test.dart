import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_myspeed/service_myspeed.dart';

class _FakeHistoryNotifier extends MySpeedHistoryNotifier {
  _FakeHistoryNotifier(super.instance, this.tests);

  final List<MySpeedTest> tests;

  @override
  Future<List<MySpeedTest>> build() async => tests;

  @override
  Future<void> fetchDiff() async {}

  @override
  Future<void> reload() async {}
}

void main() {
  const Instance instance = Instance(
    id: 'test-myspeed',
    name: 'MySpeed Test',
    kind: ServiceKind.myspeed,
    localUrl: 'http://localhost:5216',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.apiKey(apiKey: ''),
  );

  final List<MySpeedTest> sampleTests = <MySpeedTest>[
    MySpeedTest(
      id: '1',
      download: 320.5,
      upload: 45.2,
      ping: 12.0,
      createdAt: DateTime.now(),
      server: 'Local ISP',
    ),
  ];

  const MySpeedConfig sampleConfig = MySpeedConfig(
    entries: <String, dynamic>{
      'cron': '0 * * * *',
      'provider': 'ookla',
      'server_name': 'myspeed-node',
    },
    cron: '0 * * * *',
    provider: 'ookla',
  );

  const MySpeedStorage sampleStorage = MySpeedStorage(
    size: 1048576,
    testCount: 42,
  );

  List<Override> overridesForTab({
    bool isRunning = false,
    int activeTab = 0,
  }) {
    return <Override>[
      myspeedActiveTabBarIndexProvider(instance).overrideWith((ref) => activeTab),
      myspeedStatusProvider(instance).overrideWith(
        (ref) async => MySpeedStatus(isRunning: isRunning),
      ),
      myspeed24HourTestsProvider(instance).overrideWith(
        (ref) async => sampleTests,
      ),
      myspeedHistoryProvider(instance).overrideWith(
        () => _FakeHistoryNotifier(instance, sampleTests),
      ),
      myspeedConfigProvider(instance).overrideWith(
        (ref) async => sampleConfig,
      ),
      myspeedStorageProvider(instance).overrideWith(
        (ref) async => sampleStorage,
      ),
    ];
  }

  testWidgets('MySpeedHome renders bottom NavigationBar with 3 destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesForTab(),
        child: const MaterialApp(
          home: MySpeedHome(instance: instance),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Config'), findsOneWidget);
  });

  testWidgets('Tab 0 renders status, run action without flash icon, latest result, and 24h results',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesForTab(),
        child: const MaterialApp(
          home: MySpeedHome(instance: instance),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Execution status'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('Run test'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);
    expect(find.byIcon(Icons.bolt), findsNothing);
    expect(find.text('Most recent result'), findsOneWidget);
    expect(find.text('#1'), findsAtLeastNWidgets(1));

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Recent results'), findsOneWidget);
    expect(find.text('1 test'), findsOneWidget);
    expect(find.text('320.5'), findsAtLeastNWidgets(1)); // from dedicated metric box
  });

  testWidgets('Tab 1 renders 24-hour summary and test card',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesForTab(activeTab: 1),
        child: const MaterialApp(
          home: MySpeedHome(instance: instance),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Historical summary'), findsOneWidget);
    expect(find.text('1 test'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('320.5'), findsNWidgets(2)); // summary + card
  });

  testWidgets('Tab 2 renders config overview, storage info, and properties',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesForTab(activeTab: 2),
        child: const MaterialApp(
          home: MySpeedHome(instance: instance),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Configuration overview'), findsOneWidget);
    expect(find.text('Storage and retention'), findsOneWidget);
    expect(find.text('1.0 MB'), findsOneWidget); // detail row
    expect(find.text('42'), findsOneWidget);
    expect(find.text('0 * * * *'), findsNWidgets(2));
    expect(find.text('ookla'), findsNWidgets(2));
    expect(find.text('server_name'), findsOneWidget);
  });
}
