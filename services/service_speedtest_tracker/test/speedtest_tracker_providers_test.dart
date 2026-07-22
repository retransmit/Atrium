import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';

void main() {
  const Instance instance = Instance(
    id: 'speedtest-test',
    name: 'Test tracker',
    kind: ServiceKind.speedtestTracker,
    localUrl: 'https://tracker.example.test',
    externalUrl: '',
    urlMode: UrlMode.forceLocal,
    auth: InstanceAuth.apiKey(apiKey: 'placeholder-token'),
  );
  final DateTime submittedAt = DateTime.utc(2026, 7, 21, 12);

  test('adopts an already-running result without a second submission',
      () async {
    final _FakeApi api = _FakeApi(
      listPages: <SpeedtestResultsPage>[
        _page(<SpeedtestResult>[_result(1, SpeedtestResultStatus.running)]),
      ],
      polled: <SpeedtestResult>[
        _result(1, SpeedtestResultStatus.completed),
      ],
    );
    final ProviderContainer container = _container(instance, api);
    final ProviderSubscription<SpeedtestRunState> subscription =
        _listen(container, instance);
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    await container
        .read(speedtestRunControllerProvider(instance).notifier)
        .run();

    expect(api.runCalls, 0);
    expect(
      container.read(speedtestRunControllerProvider(instance)).phase,
      SpeedtestRunPhase.completed,
    );
  });

  test('queues once, polls, and completes', () async {
    final _FakeApi api = _FakeApi(
      listPages: <SpeedtestResultsPage>[_page(const <SpeedtestResult>[])],
      queued: _result(2, SpeedtestResultStatus.waiting),
      polled: <SpeedtestResult>[
        _result(2, SpeedtestResultStatus.running),
        _result(2, SpeedtestResultStatus.completed),
      ],
    );
    final ProviderContainer container = _container(instance, api);
    final ProviderSubscription<SpeedtestRunState> subscription =
        _listen(container, instance);
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    await container
        .read(speedtestRunControllerProvider(instance).notifier)
        .run();

    expect(api.runCalls, 1);
    expect(api.pollCalls, 2);
    expect(
      container.read(speedtestRunControllerProvider(instance)).phase,
      SpeedtestRunPhase.completed,
    );
  });

  test('403 persists unchanged but clears after credential or URL edits',
      () async {
    final Instance edited = instance.copyWith(
      auth: const InstanceAuth.apiKey(apiKey: 'edited-placeholder-token'),
    );
    final Instance urlEdited = instance.copyWith(
      localUrl: 'https://edited-tracker.example.test',
    );
    final _FakeApi editedApi = _FakeApi(
      listPages: <SpeedtestResultsPage>[_page(const <SpeedtestResult>[])],
    );
    final _FakeApi urlEditedApi = _FakeApi(
      listPages: <SpeedtestResultsPage>[_page(const <SpeedtestResult>[])],
    );
    final _FakeApi deniedApi = _FakeApi(
      listPages: <SpeedtestResultsPage>[_page(const <SpeedtestResult>[])],
      runErrors: <SpeedtestTrackerException>[
        const SpeedtestTrackerException(
          SpeedtestErrorKind.permission,
          'The API token lacks the speedtests:run ability.',
        ),
      ],
    );
    final ProviderContainer container = _container(
      instance,
      deniedApi,
      additionalApis: <Instance, _FakeApi>{
        edited: editedApi,
        urlEdited: urlEditedApi,
      },
      clock: () => submittedAt,
    );
    ProviderSubscription<SpeedtestRunState> subscription =
        _listen(container, instance);

    await container
        .read(speedtestRunControllerProvider(instance).notifier)
        .run();
    expect(
      container.read(speedtestRunControllerProvider(instance)).phase,
      SpeedtestRunPhase.permissionDenied,
    );

    subscription.close();
    await container.pump();
    subscription = _listen(container, instance);
    expect(
      container.read(speedtestRunControllerProvider(instance)).phase,
      SpeedtestRunPhase.permissionDenied,
    );

    final ProviderSubscription<SpeedtestRunState> editedSubscription =
        _listen(container, edited);
    expect(
      container.read(speedtestRunControllerProvider(edited)).phase,
      SpeedtestRunPhase.idle,
    );
    final ProviderSubscription<SpeedtestRunState> urlEditedSubscription =
        _listen(container, urlEdited);
    expect(
      container.read(speedtestRunControllerProvider(urlEdited)).phase,
      SpeedtestRunPhase.idle,
    );

    subscription.close();
    editedSubscription.close();
    urlEditedSubscription.close();
    container.dispose();
  });

  test('ambiguous accepted submissions adopt the newly visible result',
      () async {
    for (final SpeedtestTrackerException error in <SpeedtestTrackerException>[
      const SpeedtestTrackerException(
        SpeedtestErrorKind.timeout,
        'Timed out.',
      ),
      const SpeedtestTrackerException(
        SpeedtestErrorKind.offline,
        'Connection reset.',
      ),
      const SpeedtestTrackerException(
        SpeedtestErrorKind.server,
        'Late server response.',
        statusCode: 503,
      ),
      const SpeedtestTrackerException(
        SpeedtestErrorKind.other,
        'Unknown network response.',
      ),
    ]) {
      final SpeedtestResult adopted = _result(
        8,
        SpeedtestResultStatus.waiting,
        createdAt: submittedAt.add(const Duration(seconds: 1)),
      );
      final _FakeApi api = _FakeApi(
        listPages: <SpeedtestResultsPage>[
          _page(const <SpeedtestResult>[]),
          _page(<SpeedtestResult>[adopted]),
        ],
        runErrors: <SpeedtestTrackerException>[error],
        polled: <SpeedtestResult>[
          _result(8, SpeedtestResultStatus.completed),
        ],
      );
      final ProviderContainer container = _container(
        instance,
        api,
        clock: () => submittedAt,
      );
      final ProviderSubscription<SpeedtestRunState> subscription =
          _listen(container, instance);

      await container
          .read(speedtestRunControllerProvider(instance).notifier)
          .run();

      expect(api.runCalls, 1, reason: error.kind.name);
      expect(api.pollCalls, 1, reason: error.kind.name);
      expect(
        container.read(speedtestRunControllerProvider(instance)).phase,
        SpeedtestRunPhase.completed,
        reason: error.kind.name,
      );
      subscription.close();
      container.dispose();
    }
  });

  test('does not submit twice while reconciliation is in progress', () async {
    final Completer<SpeedtestResultsPage> reconciliation =
        Completer<SpeedtestResultsPage>();
    final SpeedtestResult adopted = _result(
      9,
      SpeedtestResultStatus.completed,
      createdAt: submittedAt.add(const Duration(seconds: 1)),
    );
    final _FakeApi api = _FakeApi(
      listPages: <SpeedtestResultsPage>[_page(const <SpeedtestResult>[])],
      runErrors: <SpeedtestTrackerException>[
        const SpeedtestTrackerException(
          SpeedtestErrorKind.timeout,
          'Timed out.',
        ),
      ],
      pendingList: reconciliation,
    );
    final ProviderContainer container = _container(
      instance,
      api,
      clock: () => submittedAt,
    );
    final ProviderSubscription<SpeedtestRunState> subscription =
        _listen(container, instance);
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    final SpeedtestRunController controller =
        container.read(speedtestRunControllerProvider(instance).notifier);
    final Future<void> firstRun = controller.run();
    await _waitForPhase(container, instance, SpeedtestRunPhase.reconciling);

    await controller.run();
    expect(api.runCalls, 1);

    reconciliation.complete(_page(<SpeedtestResult>[adopted]));
    await firstRun;
    expect(api.runCalls, 1);
    expect(
      container.read(speedtestRunControllerProvider(instance)).phase,
      SpeedtestRunPhase.completed,
    );
  });

  test('indeterminate outcome requires explicit confirmation before retry',
      () async {
    final _FakeApi api = _FakeApi(
      listPages: <SpeedtestResultsPage>[
        _page(const <SpeedtestResult>[]),
        _page(const <SpeedtestResult>[]),
        _page(const <SpeedtestResult>[]),
      ],
      runErrors: <SpeedtestTrackerException>[
        const SpeedtestTrackerException(
          SpeedtestErrorKind.timeout,
          'Timed out.',
        ),
      ],
      queued: _result(12, SpeedtestResultStatus.completed),
    );
    final ProviderContainer container = _container(
      instance,
      api,
      reconcileMaxPolls: 1,
      clock: () => submittedAt,
    );
    final ProviderSubscription<SpeedtestRunState> subscription =
        _listen(container, instance);
    addTearDown(subscription.close);
    addTearDown(container.dispose);
    final SpeedtestRunController controller =
        container.read(speedtestRunControllerProvider(instance).notifier);

    await controller.run();
    expect(
      container.read(speedtestRunControllerProvider(instance)).phase,
      SpeedtestRunPhase.indeterminate,
    );
    expect(api.runCalls, 1);

    await controller.run();
    expect(api.runCalls, 1);

    await controller.run(confirmIndeterminateRetry: true);
    expect(api.runCalls, 2);
    expect(
      container.read(speedtestRunControllerProvider(instance)).phase,
      SpeedtestRunPhase.completed,
    );
  });

  test('failed and skipped result reasons are retained', () async {
    for (final SpeedtestResultStatus terminal in <SpeedtestResultStatus>[
      SpeedtestResultStatus.failed,
      SpeedtestResultStatus.skipped,
    ]) {
      final _FakeApi api = _FakeApi(
        listPages: <SpeedtestResultsPage>[_page(const <SpeedtestResult>[])],
        queued: _result(4, SpeedtestResultStatus.waiting),
        polled: <SpeedtestResult>[
          _result(4, terminal, message: 'Upstream failure reason'),
        ],
      );
      final ProviderContainer container = _container(instance, api);
      final ProviderSubscription<SpeedtestRunState> subscription =
          _listen(container, instance);

      await container
          .read(speedtestRunControllerProvider(instance).notifier)
          .run();

      final SpeedtestRunState state =
          container.read(speedtestRunControllerProvider(instance));
      expect(state.phase, SpeedtestRunPhase.failed);
      expect(state.message, 'Upstream failure reason');
      subscription.close();
      container.dispose();
    }
  });

  test('disposing the controller stops a pending polling delay', () async {
    final _FakeApi api = _FakeApi(
      listPages: <SpeedtestResultsPage>[_page(const <SpeedtestResult>[])],
      queued: _result(20, SpeedtestResultStatus.waiting),
      polled: <SpeedtestResult>[
        _result(20, SpeedtestResultStatus.completed),
      ],
    );
    final ProviderContainer container = _container(
      instance,
      api,
      pollInterval: const Duration(hours: 1),
    );
    final ProviderSubscription<SpeedtestRunState> subscription =
        _listen(container, instance);
    final Future<void> run =
        container.read(speedtestRunControllerProvider(instance).notifier).run();
    await _waitForPhase(container, instance, SpeedtestRunPhase.queued);

    subscription.close();
    await container.pump();
    await run.timeout(const Duration(seconds: 1));

    expect(api.pollCalls, 0);
    container.dispose();
  });
}

ProviderContainer _container(
  Instance instance,
  _FakeApi api, {
  int maxPolls = 5,
  int reconcileMaxPolls = 2,
  Duration pollInterval = Duration.zero,
  DateTime Function()? clock,
  Map<Instance, _FakeApi> additionalApis = const <Instance, _FakeApi>{},
}) =>
    ProviderContainer(
      overrides: <Override>[
        speedtestTrackerApiProvider(instance).overrideWith(
          (Ref ref) async => api,
        ),
        for (final MapEntry<Instance, _FakeApi> entry in additionalApis.entries)
          speedtestTrackerApiProvider(entry.key).overrideWith(
            (Ref ref) async => entry.value,
          ),
        speedtestRunPollIntervalProvider.overrideWithValue(pollInterval),
        speedtestRunMaxPollsProvider.overrideWithValue(maxPolls),
        speedtestRunReconcileMaxPollsProvider.overrideWithValue(
          reconcileMaxPolls,
        ),
        speedtestRunClockProvider.overrideWithValue(
          clock ?? DateTime.now,
        ),
      ],
    );

ProviderSubscription<SpeedtestRunState> _listen(
  ProviderContainer container,
  Instance instance,
) =>
    container.listen<SpeedtestRunState>(
      speedtestRunControllerProvider(instance),
      (_, __) {},
      fireImmediately: true,
    );

Future<void> _waitForPhase(
  ProviderContainer container,
  Instance instance,
  SpeedtestRunPhase phase,
) async {
  for (int attempt = 0; attempt < 100; attempt++) {
    if (container.read(speedtestRunControllerProvider(instance)).phase ==
        phase) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Run controller did not reach ${phase.name}.');
}

SpeedtestResult _result(
  int id,
  SpeedtestResultStatus status, {
  DateTime? createdAt,
  String? message,
}) =>
    SpeedtestResult(
      id: id,
      status: status,
      createdAt: createdAt,
      message: message,
    );

SpeedtestResultsPage _page(List<SpeedtestResult> results) =>
    SpeedtestResultsPage(results: results, page: 1, hasMore: false);

class _FakeApi extends SpeedtestTrackerApi {
  _FakeApi({
    required this.listPages,
    this.queued,
    this.polled = const <SpeedtestResult>[],
    this.runErrors = const <SpeedtestTrackerException>[],
    this.pendingList,
  }) : super(Dio());

  final List<SpeedtestResultsPage> listPages;
  final SpeedtestResult? queued;
  final List<SpeedtestResult> polled;
  final List<SpeedtestTrackerException> runErrors;
  final Completer<SpeedtestResultsPage>? pendingList;
  int listCalls = 0;
  int runCalls = 0;
  int pollCalls = 0;

  @override
  Future<SpeedtestResultsPage> listResults({
    int page = 1,
    int pageSize = 25,
    SpeedtestResultStatus? status,
  }) async {
    final int index = listCalls++;
    if (index >= listPages.length && pendingList != null) {
      return pendingList!.future;
    }
    return listPages[index.clamp(0, listPages.length - 1)];
  }

  @override
  Future<SpeedtestResult> runSpeedtest() async {
    final int index = runCalls++;
    if (index < runErrors.length) {
      throw runErrors[index];
    }
    return queued!;
  }

  @override
  Future<SpeedtestResult> getResult(int id) async {
    final int index = pollCalls++;
    return polled[index.clamp(0, polled.length - 1)];
  }
}
