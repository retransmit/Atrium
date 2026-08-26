import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_unraid/service_unraid.dart';

/// Renders [UnraidHome] against fixed data.
///
/// The model tests prove the right values come out of a response. These prove
/// they reach the screen, which is where the parity bug actually bit: the
/// models had a parity disk all along and the screen filtered a list that
/// could never contain one, so the section silently rendered nothing.
Instance _instance() => const Instance(
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

Future<void> _pump(
  WidgetTester tester, {
  required UnraidArray array,
  List<UnraidContainer> containers = const <UnraidContainer>[],
  UnraidMetrics metrics = const UnraidMetrics(),
}) async {
  // A ListView only builds what fits, and the default 800x600 test surface
  // leaves the Docker section below the fold where nothing can find it. Tall
  // enough here that every section is laid out at once.
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final Instance instance = _instance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        unraidArrayProvider(instance).overrideWith((Ref ref) async => array),
        unraidContainersProvider(instance)
            .overrideWith((Ref ref) async => containers),
        // Left un-overridden this reaches for a real client, which needs a
        // connection resolver only the app's own bootstrap installs.
        unraidMetricsProvider(instance)
            .overrideWith((Ref ref) async => metrics),
      ],
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: UnraidHome(instance: instance),
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
  testWidgets('the parity section renders the parity disk', (
    WidgetTester tester,
  ) async {
    // The regression in full: parity never appears in the data list, so a
    // screen reading only that one showed no parity at all and reported the
    // array as unprotected.
    await _pump(
      tester,
      array: _array(
        parities: const <UnraidDisk>[
          // Cooler than disk1 on purpose: the warmest disk is named in the
          // stat box too, and this keeps the count below unambiguous.
          UnraidDisk(
            name: 'parity',
            type: 'PARITY',
            sizeKb: 6291424,
            status: 'DISK_OK',
            temp: 28,
          ),
        ],
      ),
    );

    expect(find.text('Parity'), findsOneWidget);
    expect(find.text('parity'), findsOneWidget);
    expect(find.text('Single parity'), findsOneWidget);
    expect(find.text('No parity protection'), findsNothing);
  });

  testWidgets('an array with no parity says so', (WidgetTester tester) async {
    await _pump(tester, array: _array());

    expect(find.text('No parity protection'), findsOneWidget);
    // An empty heading reads as something having gone missing.
    expect(find.text('Parity'), findsNothing);
    expect(find.text('Cache'), findsNothing);
  });

  testWidgets('sizes render as capacities, not raw kilobyte counts', (
    WidgetTester tester,
  ) async {
    await _pump(tester, array: _array());

    expect(find.text('5.0 GB'), findsOneWidget);
    expect(find.text('5242848'), findsNothing);
    // The disk's own filesystem usage, and the array total above it.
    expect(find.text('3.8 GB of 5.1 GB'), findsOneWidget);
    expect(find.text('4.0 GB of 12.1 GB'), findsOneWidget);
  });

  testWidgets('a cache pool gets its own section', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(
        caches: const <UnraidDisk>[
          // As above: kept cooler than disk1 so the name appears only in the
          // cache row and not also as the warmest disk.
          UnraidDisk(
            name: 'cache',
            type: 'CACHE',
            sizeKb: 1048576,
            status: 'DISK_OK',
            temp: 25,
          ),
        ],
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
      array: _array(
        parities: const <UnraidDisk>[
          UnraidDisk(name: 'parity', type: 'PARITY', status: 'DISK_DSBL'),
        ],
      ),
    );

    expect(find.text('parity disabled'), findsOneWidget);
  });

  testWidgets('a running parity check shows its progress', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(
        check: const UnraidParityCheck(status: 'RUNNING', progress: 63),
      ),
    );

    expect(find.text('Parity check running, 63%'), findsOneWidget);
  });

  testWidgets('a check that found errors says how many', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(
        check: const UnraidParityCheck(status: 'COMPLETED', errors: 2),
      ),
    );

    expect(find.text('Last parity check found 2 errors'), findsOneWidget);
  });

  testWidgets('parity that has never been checked is called out', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(check: const UnraidParityCheck(status: 'NEVER_RUN')),
    );

    expect(find.text('Parity has never been checked'), findsOneWidget);
  });

  testWidgets('containers render with their published ports', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(),
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
    );

    expect(find.text('sonarr'), findsOneWidget);
    expect(find.text('Up 24 hours  -  8989'), findsOneWidget);
  });

  testWidgets('a running container offers to stop it', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(),
      containers: const <UnraidContainer>[
        UnraidContainer(
          id: 'srv:c1',
          names: <String>['/sonarr'],
          state: 'RUNNING',
          status: 'Up 24 hours',
        ),
      ],
    );

    expect(find.widgetWithIcon(IconButton, Icons.stop_rounded), findsOneWidget);
  });

  testWidgets('a stopped container offers to start it', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(),
      containers: const <UnraidContainer>[
        UnraidContainer(
          id: 'srv:c1',
          names: <String>['/old'],
          state: 'EXITED',
          status: 'Exited (0) 2 days ago',
        ),
      ],
    );

    expect(
      find.widgetWithIcon(IconButton, Icons.play_arrow_rounded),
      findsOneWidget,
    );
  });

  testWidgets('a paused container is offered a resume, not a stop', (
    WidgetTester tester,
  ) async {
    // Stopping a paused container throws away the state pausing it was meant
    // to keep, so resume is the action that belongs on the row.
    await _pump(
      tester,
      array: _array(),
      containers: const <UnraidContainer>[
        UnraidContainer(
          id: 'srv:c1',
          names: <String>['/bazarr'],
          state: 'PAUSED',
          status: 'Up 6 days (Paused)',
        ),
      ],
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
      array: _array(),
      containers: const <UnraidContainer>[
        UnraidContainer(
          id: 'srv:c1',
          names: <String>['/sonarr'],
          state: 'RUNNING',
          status: 'Up 24 hours',
          webUiUrl: 'http://10.0.2.15:8989/',
        ),
      ],
    );

    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    expect(find.byType(InkWell), findsWidgets);
  });

  testWidgets('a container without one is left inert, not tapping to nothing',
      (WidgetTester tester) async {
    await _pump(
      tester,
      array: _array(),
      containers: const <UnraidContainer>[
        UnraidContainer(
          id: 'srv:c1',
          names: <String>['/orphan'],
          state: 'RUNNING',
          status: 'Up 24 hours',
          isOrphaned: true,
        ),
      ],
    );

    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
  });

  testWidgets('cpu and memory load render with the core count', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(),
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

  testWidgets('a graph says it is still collecting until it has a curve', (
    WidgetTester tester,
  ) async {
    // Nothing is kept between visits, so the first sample has no line to
    // draw. An empty box there reads as broken.
    await _pump(
      tester,
      array: _array(),
      metrics: const UnraidMetrics(cpu: UnraidCpu(percentTotal: 5)),
    );

    expect(find.text('Collecting...'), findsWidgets);
  });

  testWidgets('the network card is left out when there is no real interface', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(),
      metrics: const UnraidMetrics(
        cpu: UnraidCpu(percentTotal: 5),
        network: <UnraidNetworkInterface>[
          UnraidNetworkInterface(name: 'lo', operstate: 'up'),
          UnraidNetworkInterface(name: 'docker0', operstate: 'up'),
        ],
      ),
    );

    expect(find.text('NETWORK'), findsNothing);
  });

  testWidgets('a real interface brings the network card with it', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      array: _array(),
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
    );

    expect(find.text('NETWORK'), findsOneWidget);
    expect(find.text('1.0 KB/s'), findsOneWidget);
    expect(find.text('2.0 KB/s'), findsOneWidget);
  });

  testWidgets('a server that cannot serve metrics gets one quiet line', (
    WidgetTester tester,
  ) async {
    // An Unraid too old to know the metrics query refuses it outright. That
    // is not worth an error card, and nesting one header inside another Row
    // to make the line fit is how this last laid out with an unbounded
    // Spacer and crashed.
    final Instance instance = _instance();
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          unraidArrayProvider(instance)
              .overrideWith((Ref ref) async => _array()),
          unraidContainersProvider(instance)
              .overrideWith((Ref ref) async => const <UnraidContainer>[]),
          unraidMetricsProvider(instance).overrideWith(
            (Ref ref) async => throw Exception('no such field'),
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: UnraidHome(instance: instance),
        ),
      ),
    );
    for (int i = 0; i < 3; i++) {
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    expect(find.text('Unavailable'), findsOneWidget);
    // The rest of the screen must survive it.
    expect(find.text('Array Started'), findsOneWidget);
  });

  testWidgets('a server with no containers says so rather than looking broken',
      (WidgetTester tester) async {
    await _pump(tester, array: _array());

    expect(find.text('No containers'), findsOneWidget);
  });
}
