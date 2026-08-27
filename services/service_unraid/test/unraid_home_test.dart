import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_unraid/service_unraid.dart';

/// Renders the Unraid tabs against fixed data.
///
/// The model tests prove the right values come out of a response. These prove
/// they reach the screen, which is where the parity bug actually bit: the
/// models had a parity disk all along and the screen filtered a list that
/// could never contain one, so the section silently rendered nothing.
///
/// Each tab is pumped on its own rather than through [UnraidHome], because an
/// IndexedStack keeps the tabs you are not looking at offstage where no finder
/// will reach them. [UnraidHome] gets its own tests for the navigation itself.
const Instance _instance = Instance(
  id: 'test-unraid',
  name: 'Tower',
  kind: ServiceKind.unraid,
  localUrl: 'http://localhost',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

UnraidArray _array({
  List<UnraidDisk> parities = const <UnraidDisk>[],
  List<UnraidDisk> caches = const <UnraidDisk>[],
  UnraidParityCheck? check,
}) =>
    UnraidArray(
      state: 'STARTED',
      parities: parities,
      caches: caches,
      parityCheck: check,
      totalKb: 12683477,
      usedKb: 4195725,
      disks: const <UnraidDisk>[
        UnraidDisk(
          name: 'disk1',
          type: 'DATA',
          sizeKb: 5242848,
          status: 'DISK_OK',
          temp: 31,
          fsSizeKb: 5301567,
          fsUsedKb: 3986469,
          fsFreeKb: 1315099,
        ),
      ],
    );

List<Override> _overrides({
  UnraidArray? array,
  List<UnraidContainer> containers = const <UnraidContainer>[],
  UnraidMetrics metrics = const UnraidMetrics(),
  UnraidVmList vms = const UnraidVmList(enabled: false),
  UnraidSystemInfo info = const UnraidSystemInfo(),
}) =>
    <Override>[
      unraidSystemInfoProvider(_instance).overrideWith((Ref ref) async => info),
      unraidArrayProvider(_instance)
          .overrideWith((Ref ref) async => array ?? _array()),
      unraidContainersProvider(_instance)
          .overrideWith((Ref ref) async => containers),
      // Left un-overridden these reach for a real client, which needs a
      // connection resolver only the app's own bootstrap installs.
      unraidMetricsProvider(_instance).overrideWith((Ref ref) async => metrics),
      unraidVmsProvider(_instance).overrideWith((Ref ref) async => vms),
    ];

Future<void> _pump(WidgetTester tester, Widget child, List<Override> o) async {
  // A ListView only builds what fits, and the default 800x600 surface leaves
  // the lower cards below the fold where nothing can find them.
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: o,
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: Scaffold(body: child),
      ),
    ),
  );
  // Overridden FutureProviders settle on the next microtask; pumpAndSettle
  // would hang on the refresh indicator, so pump a fixed number of frames.
  for (int i = 0; i < 3; i++) {
    await tester.pump();
  }
}

void main() {
  group('array tab', () {
    testWidgets('the parity section renders the parity disk', (
      WidgetTester tester,
    ) async {
      // The regression in full: parity never appears in the data list, so a
      // screen reading only that one showed no parity at all and reported the
      // array as unprotected.
      await _pump(
        tester,
        const UnraidArrayTab(instance: _instance),
        _overrides(
          array: _array(
            parities: const <UnraidDisk>[
              // Cooler than disk1 on purpose: the warmest disk is named in
              // the stat box too, which would double the match below.
              UnraidDisk(
                name: 'parity',
                type: 'PARITY',
                sizeKb: 6291424,
                status: 'DISK_OK',
                temp: 28,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Parity'), findsOneWidget);
      expect(find.text('parity'), findsOneWidget);
      expect(find.text('Single parity'), findsOneWidget);
      expect(find.text('No parity protection'), findsNothing);
    });

    testWidgets('an array with no parity says so', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidArrayTab(instance: _instance),
        _overrides(),
      );

      expect(find.text('No parity protection'), findsOneWidget);
      // An empty heading reads as something having gone missing.
      expect(find.text('Parity'), findsNothing);
      expect(find.text('Cache'), findsNothing);
    });

    testWidgets('sizes render as capacities, not raw kilobyte counts', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidArrayTab(instance: _instance),
        _overrides(),
      );

      expect(find.text('5.0 GB'), findsOneWidget);
      expect(find.text('5242848'), findsNothing);
      expect(find.text('3.8 GB of 5.1 GB'), findsOneWidget);
      expect(find.text('4.0 GB of 12.1 GB'), findsOneWidget);
    });

    testWidgets('a cache pool gets its own section', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidArrayTab(instance: _instance),
        _overrides(
          array: _array(
            caches: const <UnraidDisk>[
              UnraidDisk(
                name: 'cache',
                type: 'CACHE',
                sizeKb: 1048576,
                status: 'DISK_OK',
                temp: 25,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Cache'), findsOneWidget);
      expect(find.text('cache'), findsOneWidget);
    });

    testWidgets('a failed disk is named rather than only counted', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidArrayTab(instance: _instance),
        _overrides(
          array: _array(
            parities: const <UnraidDisk>[
              UnraidDisk(name: 'parity', type: 'PARITY', status: 'DISK_DSBL'),
            ],
          ),
        ),
      );

      expect(find.text('parity disabled'), findsOneWidget);
    });

    testWidgets('a running parity check shows its progress', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidArrayTab(instance: _instance),
        _overrides(
          array: _array(
            check: const UnraidParityCheck(status: 'RUNNING', progress: 63),
          ),
        ),
      );

      expect(find.text('Parity check running, 63%'), findsOneWidget);
    });

    testWidgets('a check that found errors says how many', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidArrayTab(instance: _instance),
        _overrides(
          array: _array(
            check: const UnraidParityCheck(status: 'COMPLETED', errors: 2),
          ),
        ),
      );

      expect(find.text('Last parity check found 2 errors'), findsOneWidget);
    });

    testWidgets('parity that has never been checked is called out', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidArrayTab(instance: _instance),
        _overrides(
          array: _array(check: const UnraidParityCheck(status: 'NEVER_RUN')),
        ),
      );

      expect(find.text('Parity has never been checked'), findsOneWidget);
    });
  });

  group('docker tab', () {
    testWidgets('containers render with their published ports', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidDockerTab(instance: _instance),
        _overrides(
          containers: const <UnraidContainer>[
            UnraidContainer(
              id: 'srv:c1',
              names: <String>['/sonarr'],
              state: 'RUNNING',
              status: 'Up 24 hours',
              ports: <UnraidPort>[
                UnraidPort(privatePort: 80, publicPort: 8989, type: 'TCP'),
              ],
            ),
          ],
        ),
      );

      expect(find.text('sonarr'), findsOneWidget);
      expect(find.text('Up 24 hours  -  8989'), findsOneWidget);
    });

    testWidgets('a running container offers to stop it', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidDockerTab(instance: _instance),
        _overrides(
          containers: const <UnraidContainer>[
            UnraidContainer(
              id: 'srv:c1',
              names: <String>['/sonarr'],
              state: 'RUNNING',
              status: 'Up 24 hours',
            ),
          ],
        ),
      );

      expect(
        find.widgetWithIcon(IconButton, Icons.stop_rounded),
        findsOneWidget,
      );
    });

    testWidgets('a stopped container offers to start it', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidDockerTab(instance: _instance),
        _overrides(
          containers: const <UnraidContainer>[
            UnraidContainer(
              id: 'srv:c1',
              names: <String>['/old'],
              state: 'EXITED',
              status: 'Exited (0) 2 days ago',
            ),
          ],
        ),
      );

      expect(
        find.widgetWithIcon(IconButton, Icons.play_arrow_rounded),
        findsOneWidget,
      );
    });

    testWidgets('a paused container is offered a resume, not a stop', (
      WidgetTester tester,
    ) async {
      // Stopping a paused container throws away the state pausing it was
      // meant to keep, so resume is the action that belongs on the row.
      await _pump(
        tester,
        const UnraidDockerTab(instance: _instance),
        _overrides(
          containers: const <UnraidContainer>[
            UnraidContainer(
              id: 'srv:c1',
              names: <String>['/bazarr'],
              state: 'PAUSED',
              status: 'Up 6 days (Paused)',
            ),
          ],
        ),
      );

      final Finder button =
          find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
      expect(button, findsOneWidget);
      expect(tester.widget<IconButton>(button).tooltip, 'Resume');
      expect(find.widgetWithIcon(IconButton, Icons.stop_rounded), findsNothing);
    });

    testWidgets('a container with a web interface says the row opens it', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidDockerTab(instance: _instance),
        _overrides(
          containers: const <UnraidContainer>[
            UnraidContainer(
              id: 'srv:c1',
              names: <String>['/sonarr'],
              state: 'RUNNING',
              status: 'Up 24 hours',
              webUiUrl: 'http://10.0.2.15:8989/',
            ),
          ],
        ),
      );

      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    });

    testWidgets('a container without one is left inert', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidDockerTab(instance: _instance),
        _overrides(
          containers: const <UnraidContainer>[
            UnraidContainer(
              id: 'srv:c1',
              names: <String>['/orphan'],
              state: 'RUNNING',
              status: 'Up 24 hours',
              isOrphaned: true,
            ),
          ],
        ),
      );

      expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
    });

    testWidgets('a server with no containers says so', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidDockerTab(instance: _instance),
        _overrides(),
      );

      expect(find.text('No containers'), findsOneWidget);
    });
  });

  group('system tab', () {
    testWidgets('cpu and memory load render with the core count', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidSystemTab(instance: _instance),
        _overrides(
          metrics: const UnraidMetrics(
            cpu: UnraidCpu(
              percentTotal: 37.4,
              cores: <UnraidCpuCore>[
                UnraidCpuCore(percentTotal: 37),
                UnraidCpuCore(percentTotal: 38),
              ],
            ),
            memory: UnraidMemory(
              totalBytes: 4113248256,
              usedBytes: 3367780352,
              availableBytes: 3124817920,
              percentUsed: 24.03,
            ),
          ),
        ),
      );

      expect(find.text('System'), findsOneWidget);
      expect(find.text('2 cores'), findsOneWidget);
      expect(find.text('37%'), findsOneWidget);
      expect(find.text('busiest core 38%'), findsOneWidget);
      // 24%, not the 82% that reading Linux's `used` would put on screen.
      expect(find.text('24%'), findsOneWidget);
      expect(find.text('82%'), findsNothing);
      expect(find.text('943 MB of 3.8 GB'), findsOneWidget);
    });

    testWidgets('every core gets its own bar', (WidgetTester tester) async {
      // What larvs asked for: an average across a machine hides one core
      // pinned while the rest idle.
      await _pump(
        tester,
        const UnraidSystemTab(instance: _instance),
        _overrides(
          metrics: const UnraidMetrics(
            cpu: UnraidCpu(
              percentTotal: 25,
              cores: <UnraidCpuCore>[
                UnraidCpuCore(percentTotal: 99),
                UnraidCpuCore(percentTotal: 1),
                UnraidCpuCore(percentTotal: 0),
                UnraidCpuCore(percentTotal: 0),
              ],
            ),
          ),
        ),
      );

      expect(find.text('PER CORE'), findsOneWidget);
      // Numbered while there are few enough for the labels to be readable.
      for (final String label in <String>['0', '1', '2', '3']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('busiest core 99%'), findsOneWidget);
    });

    testWidgets('a single core machine gets no bar row', (
      WidgetTester tester,
    ) async {
      // One bar filling the width says nothing the number above it did not.
      await _pump(
        tester,
        const UnraidSystemTab(instance: _instance),
        _overrides(
          metrics: const UnraidMetrics(
            cpu: UnraidCpu(
              percentTotal: 12,
              cores: <UnraidCpuCore>[UnraidCpuCore(percentTotal: 12)],
            ),
          ),
        ),
      );

      expect(find.text('1 core'), findsOneWidget);
      expect(find.text('PER CORE'), findsNothing);
    });

    testWidgets('a graph says it is still collecting until it has a curve', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidSystemTab(instance: _instance),
        _overrides(
          metrics: const UnraidMetrics(cpu: UnraidCpu(percentTotal: 5)),
        ),
      );

      expect(find.text('Collecting...'), findsWidgets);
    });

    testWidgets('the network card is left out with no real interface', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidSystemTab(instance: _instance),
        _overrides(
          metrics: const UnraidMetrics(
            cpu: UnraidCpu(percentTotal: 5),
            network: <UnraidNetworkInterface>[
              UnraidNetworkInterface(name: 'lo', operstate: 'up'),
              UnraidNetworkInterface(name: 'docker0', operstate: 'up'),
            ],
          ),
        ),
      );

      expect(find.text('NETWORK'), findsNothing);
    });

    testWidgets('a real interface brings the network card with it', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidSystemTab(instance: _instance),
        _overrides(
          metrics: const UnraidMetrics(
            cpu: UnraidCpu(percentTotal: 5),
            network: <UnraidNetworkInterface>[
              UnraidNetworkInterface(
                name: 'br0',
                operstate: 'up',
                rxBytesPerSec: 1024,
                txBytesPerSec: 2048,
              ),
            ],
          ),
        ),
      );

      expect(find.text('NETWORK'), findsOneWidget);
      expect(find.text('1.0 KB/s'), findsOneWidget);
      expect(find.text('2.0 KB/s'), findsOneWidget);
    });
  });

  group('system info card', () {
    testWidgets('shows what the machine is, with uptime as a duration', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidSystemTab(instance: _instance),
        _overrides(
          metrics: const UnraidMetrics(cpu: UnraidCpu(percentTotal: 5)),
          info: UnraidSystemInfo(
            serverTime: DateTime.utc(2026, 8, 27, 19, 12),
            bootTime: DateTime.utc(2026, 8, 24, 15, 12),
            kernel: '6.18.38-Unraid',
            hostname: 'Tower',
            cpuBrand: 'Ryzen 7 6800H with Radeon Graphics',
            cores: 8,
            threads: 16,
            boardManufacturer: 'ASUSTeK COMPUTER INC.',
            boardModel: 'PRIME X570-P',
            memMaxBytes: 137438953472,
            memSlots: 4,
            unraidVersion: '7.3.2',
          ),
        ),
      );

      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('Ryzen 7 6800H with Radeon Graphics'), findsOneWidget);
      expect(find.text('8 cores, 16 threads'), findsOneWidget);
      // A duration, not the boot timestamp the field actually carries.
      expect(find.text('3d 4h'), findsOneWidget);
      expect(find.text('Unraid 7.3.2'), findsOneWidget);
      expect(find.text('6.18.38-Unraid'), findsOneWidget);
      expect(find.text('ASUSTeK COMPUTER INC. PRIME X570-P'), findsOneWidget);
      expect(find.text('up to 128 GB across 4 slots'), findsOneWidget);
    });

    testWidgets('a board the server did not report is left out entirely', (
      WidgetTester tester,
    ) async {
      // Every virtual machine sends empty strings here.
      await _pump(
        tester,
        const UnraidSystemTab(instance: _instance),
        _overrides(
          metrics: const UnraidMetrics(cpu: UnraidCpu(percentTotal: 5)),
          info: const UnraidSystemInfo(
            cpuBrand: 'QEMU Virtual CPU',
            unraidVersion: '7.3.2',
            isVirtual: true,
          ),
        ),
      );

      expect(find.text('Board'), findsNothing);
      expect(find.text('Memory'), findsNothing);
      // Worth saying, since it explains a lot of odd readings elsewhere.
      expect(find.text('virtual machine'), findsOneWidget);
    });

    testWidgets('a server that will not serve it hides the card, not the tab', (
      WidgetTester tester,
    ) async {
      const Instance i = _instance;
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            unraidMetricsProvider(i).overrideWith(
              (Ref ref) async =>
                  const UnraidMetrics(cpu: UnraidCpu(percentTotal: 5)),
            ),
            unraidSystemInfoProvider(i).overrideWith(
              (Ref ref) async => throw Exception('no permission'),
            ),
          ],
          child: MaterialApp(
            theme: AtriumTheme.light(null),
            home: const Scaffold(body: UnraidSystemTab(instance: _instance)),
          ),
        ),
      );
      for (int n = 0; n < 3; n++) {
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      expect(find.text('ABOUT'), findsNothing);
      // The load graphs are the point of this tab and must survive.
      expect(find.text('System'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
    });
  });

  group('vms tab', () {
    testWidgets('a server with virtualisation off says so, and is not an error',
        (WidgetTester tester) async {
      // Unraid ships with the VM manager off, so this is the ordinary case
      // for most servers rather than something to report as broken.
      await _pump(
        tester,
        const UnraidVmsTab(instance: _instance),
        _overrides(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Virtual machines are off'), findsOneWidget);
      expect(find.text('No virtual machines'), findsNothing);
    });

    testWidgets('the manager being on with nothing defined is its own state', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidVmsTab(instance: _instance),
        _overrides(vms: const UnraidVmList(enabled: true)),
      );

      expect(find.text('No virtual machines'), findsOneWidget);
      expect(find.text('Virtual machines are off'), findsNothing);
    });

    testWidgets('machines are listed with their state', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidVmsTab(instance: _instance),
        _overrides(
          vms: const UnraidVmList(
            enabled: true,
            vms: <UnraidVm>[
              UnraidVm(id: 'srv:v1', name: 'Windows 11', state: 'RUNNING'),
              UnraidVm(id: 'srv:v2', name: 'Home Assistant', state: 'SHUTOFF'),
              UnraidVm(id: 'srv:v3', name: 'Broken', state: 'CRASHED'),
            ],
          ),
        ),
      );

      expect(find.text('Windows 11'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      // SHUTOFF is libvirt's word, not one to put in front of anyone.
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.text('Crashed'), findsOneWidget);
      expect(find.text('1 of 3 running'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('all four tabs are offered, and the array shows first', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const UnraidHome(instance: _instance),
        _overrides(),
      );

      // Scoped to the bar: "Array" is also the caption on the usage meter.
      final Finder nav = find.byType(NavigationBar);
      for (final String label in <String>['Array', 'System', 'Docker', 'VMs']) {
        expect(
          find.descendant(of: nav, matching: find.text(label)),
          findsOneWidget,
          reason: '$label is missing from the navigation bar',
        );
      }
      expect(find.text('Array Started'), findsOneWidget);
    });

    testWidgets('choosing a tab shows it', (WidgetTester tester) async {
      await _pump(
        tester,
        const UnraidHome(instance: _instance),
        _overrides(),
      );

      await tester.tap(find.text('VMs'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Virtual machines are off'), findsOneWidget);
    });
  });
}
