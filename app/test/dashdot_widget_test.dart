import 'package:atrium/src/dashboard/widgets/dashdot_widget.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_dashdot/service_dashdot.dart';

Instance makeInstance() => const Instance(
      id: 'test-dashdot',
      name: 'My Dashdot',
      kind: ServiceKind.dashdot,
      localUrl: 'http://localhost:3001',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'k'),
    );

class _FakeCpuNotifier extends CpuHistoryNotifier {
  _FakeCpuNotifier(super.instance, this._initial);
  final CpuHistoryState _initial;

  @override
  CpuHistoryState build() => _initial;
}

class _FakeRamNotifier extends RamHistoryNotifier {
  _FakeRamNotifier(super.instance, this._initial);
  final MetricHistory _initial;

  @override
  MetricHistory build() => _initial;
}

class _FakeStorageNotifier extends StorageHistoryNotifier {
  _FakeStorageNotifier(super.instance, this._initial);
  final MetricHistory _initial;

  @override
  MetricHistory build() => _initial;
}

class _FakeNetworkNotifier extends NetworkHistoryNotifier {
  _FakeNetworkNotifier(super.instance, this._initial);
  final NetworkHistory _initial;

  @override
  NetworkHistory build() => _initial;
}

void main() {
  testWidgets('DashboardDashdotWidget renders idle row when empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: const Scaffold(
            body: DashboardDashdotWidget(instances: <Instance>[]),
          ),
        ),
      ),
    );
    expect(find.text('Dashdot'), findsOneWidget);
    expect(find.text('No Dashdot instances configured'), findsOneWidget);
  });

  testWidgets(
      'DashboardDashdotWidget renders circular monitor and vitals pills',
      (WidgetTester tester) async {
    final Instance instance = makeInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashdotCpuHistoryProvider(instance).overrideWith(
            () => _FakeCpuNotifier(
              instance,
              CpuHistoryState(
                MetricHistory(<double>[25.0]),
                <MetricHistory>[
                  MetricHistory(<double>[], temps: <double>[48.0]),
                ],
              ),
            ),
          ),
          dashdotRamHistoryProvider(instance).overrideWith(
            () => _FakeRamNotifier(instance, MetricHistory(<double>[8.0])),
          ),
          dashdotStorageHistoryProvider(instance).overrideWith(
            () => _FakeStorageNotifier(
              instance,
              MetricHistory(<double>[250.0]),
            ),
          ),
          dashdotNetworkHistoryProvider(instance).overrideWith(
            () => _FakeNetworkNotifier(
              instance,
              NetworkHistory(
                <double>[5242880.0], // 5 MB/s
                <double>[1048576.0], // 1 MB/s
              ),
            ),
          ),
          dashdotInfoProvider(instance).overrideWith(
            (Ref ref) async => const DashdotInfo(
              os: DashdotOsInfo(uptime: 90000), // 1d 1h
              ram: DashdotRamInfo(totalCapacity: 16),
              storage: <DashdotStorageInfo>[
                DashdotStorageInfo(capacity: 500),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: Scaffold(
            body: DashboardDashdotWidget(instances: <Instance>[instance]),
          ),
        ),
      ),
    );

    // Settle async providers and animations
    await tester.pumpAndSettle();

    expect(find.text('Dashdot'), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('RAM'), findsOneWidget);
    expect(find.text('Disk'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget); // CPU
    expect(find.text('50%'), findsNWidgets(2)); // RAM 8/16 & Disk 250/500

    // Vitals pills
    expect(find.text('Down'), findsOneWidget);
    expect(find.text('5.0 MB/s'), findsOneWidget);
    expect(find.text('Up'), findsOneWidget);
    expect(find.text('1.0 MB/s'), findsOneWidget);
    expect(find.text('Temp'), findsOneWidget);
    expect(find.text('48°'), findsOneWidget);
    expect(find.text('Uptime'), findsOneWidget);
    expect(find.text('1d 1h'), findsOneWidget);
  });
}
