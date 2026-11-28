import 'package:atrium/src/dashboard/widgets/technitium_widget.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_technitium/service_technitium.dart';

class _RecordingActions extends TechnitiumActions {
  _RecordingActions(super.ref, super.instance);

  final List<String> calls = <String>[];

  @override
  Future<void> setProtection({required bool enabled, Duration? pause}) async {
    calls.add('protection enabled=$enabled pause=${pause?.inSeconds}');
  }

  @override
  Future<void> refresh() async => calls.add('refresh');
}

void main() {
  const Instance instance = Instance(
    id: 'technitium-1',
    name: 'DNS Main',
    kind: ServiceKind.technitium,
    localUrl: 'http://192.168.1.100:5380',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.apiKey(apiKey: 'secret-token'),
  );

  final DateTime readAt = DateTime(2026, 11, 22, 14, 0);

  TechnitiumStatus statusWith({
    bool enabled = true,
    DateTime? pausedUntil,
  }) {
    return TechnitiumStatus(
      version: '13.0.0',
      isBlockingEnabled: enabled,
      readAt: readAt,
      pausedUntil: pausedUntil,
    );
  }

  const TechnitiumStats testStats = TechnitiumStats(
    totalQueries: 5000,
    blockedQueries: 1000,
    queriesSeries: <int>[1000, 1500, 2500],
    blockedSeries: <int>[200, 300, 500],
  );

  testWidgets('shows idle text when no instances configured',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DashboardTechnitiumWidget(instances: <Instance>[]),
          ),
        ),
      ),
    );

    expect(find.text('No Technitium DNS instances configured'), findsOneWidget);
  });

  testWidgets('renders protected state, metrics and pause button',
      (WidgetTester tester) async {
    late _RecordingActions actions;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          technitiumStatusProvider(instance).overrideWith(
            (_) async => statusWith(enabled: true),
          ),
          technitiumDashboardStatsProvider(instance).overrideWith(
            (_) async => testStats,
          ),
          technitiumActionsProvider(instance).overrideWith(
            (Ref ref) => actions = _RecordingActions(ref, instance),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DashboardTechnitiumWidget(
              instances: <Instance>[instance],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PROTECTED'), findsOneWidget);
    expect(find.text('Queries'), findsOneWidget);
    expect(find.text('5K'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('1K'), findsOneWidget);
    expect(find.text('20.0%'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    // Tap pause button to open pause menu
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(find.text('1 minute'), findsOneWidget);
    expect(find.text('5 minutes'), findsOneWidget);
    expect(find.text('10 minutes'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
    expect(find.text('Until turned back on'), findsOneWidget);

    // Select 10 minutes
    await tester.tap(find.text('10 minutes'));
    await tester.pumpAndSettle();

    expect(actions.calls, <String>['protection enabled=false pause=600']);
  });

  testWidgets('renders paused state and resume button',
      (WidgetTester tester) async {
    late _RecordingActions actions;

    final DateTime future = readAt.add(const Duration(minutes: 5));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          technitiumStatusProvider(instance).overrideWith(
            (_) async => statusWith(enabled: true, pausedUntil: future),
          ),
          technitiumDashboardStatsProvider(instance).overrideWith(
            (_) async => testStats,
          ),
          technitiumActionsProvider(instance).overrideWith(
            (Ref ref) => actions = _RecordingActions(ref, instance),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DashboardTechnitiumWidget(
              instances: <Instance>[instance],
              now: () => readAt,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('5:00'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    // Tap Resume
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(actions.calls, <String>['protection enabled=true pause=null']);
  });
}
