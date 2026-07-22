import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/speedtest_tracker_models.dart';
import 'speedtest_tracker_api.dart';

typedef SpeedtestHistoryQuery = ({
  Instance instance,
  int page,
  int pageSize,
});

final speedtestTrackerApiProvider =
    FutureProvider.autoDispose.family<SpeedtestTrackerApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  return SpeedtestTrackerApi(dio);
});

final speedtestOverviewProvider =
    FutureProvider.autoDispose.family<SpeedtestOverview, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SpeedtestTrackerApi api =
      await ref.watch(speedtestTrackerApiProvider(instance).future);
  final List<SpeedtestResultsPage> pages = await Future.wait(
    <Future<SpeedtestResultsPage>>[
      api.listResults(pageSize: 1),
      api.listResults(
        pageSize: 30,
        status: SpeedtestResultStatus.completed,
      ),
    ],
  );
  return SpeedtestOverview(
    latestAny: pages.first.results.isEmpty ? null : pages.first.results.first,
    completedResults: pages.last.results,
  );
});

final speedtestHistoryProvider = FutureProvider.autoDispose
    .family<SpeedtestResultsPage, SpeedtestHistoryQuery>((
  Ref ref,
  SpeedtestHistoryQuery query,
) async {
  final SpeedtestTrackerApi api =
      await ref.watch(speedtestTrackerApiProvider(query.instance).future);
  return api.listResults(
    page: query.page,
    pageSize: query.pageSize,
    status: SpeedtestResultStatus.completed,
  );
});

final speedtestRunPollIntervalProvider =
    Provider<Duration>((Ref ref) => const Duration(seconds: 3));

final speedtestRunMaxPollsProvider = Provider<int>((Ref ref) => 100);

final speedtestRunReconcileMaxPollsProvider = Provider<int>((Ref ref) => 10);

final speedtestRunClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

enum SpeedtestRunPhase {
  idle,
  checking,
  submitting,
  reconciling,
  queued,
  running,
  completed,
  failed,
  timedOut,
  indeterminate,
  permissionDenied,
  unsupported,
}

class SpeedtestRunState {
  const SpeedtestRunState({
    this.phase = SpeedtestRunPhase.idle,
    this.result,
    this.message,
  });

  final SpeedtestRunPhase phase;
  final SpeedtestResult? result;
  final String? message;

  bool get isBusy => switch (phase) {
        SpeedtestRunPhase.checking ||
        SpeedtestRunPhase.submitting ||
        SpeedtestRunPhase.reconciling ||
        SpeedtestRunPhase.queued ||
        SpeedtestRunPhase.running =>
          true,
        _ => false,
      };

  bool get isDisabledForSession =>
      phase == SpeedtestRunPhase.permissionDenied ||
      phase == SpeedtestRunPhase.unsupported;
}

class _SessionRestriction {
  const _SessionRestriction({
    required this.instanceSignature,
    required this.phase,
    required this.message,
  });

  final int instanceSignature;
  final SpeedtestRunPhase phase;
  final String message;
}

final NotifierProvider<_SpeedtestRunSessionRestrictions,
        Map<String, _SessionRestriction>> _speedtestRunSessionRestrictions =
    NotifierProvider<_SpeedtestRunSessionRestrictions,
        Map<String, _SessionRestriction>>(
  _SpeedtestRunSessionRestrictions.new,
);

class _SpeedtestRunSessionRestrictions
    extends Notifier<Map<String, _SessionRestriction>> {
  @override
  Map<String, _SessionRestriction> build() =>
      const <String, _SessionRestriction>{};

  _SessionRestriction? forInstance(Instance instance) {
    final _SessionRestriction? restriction = state[instance.id];
    return restriction?.instanceSignature == _instanceSignature(instance)
        ? restriction
        : null;
  }

  void restrict(
    Instance instance,
    SpeedtestRunPhase phase,
    String message,
  ) {
    state = <String, _SessionRestriction>{
      ...state,
      instance.id: _SessionRestriction(
        instanceSignature: _instanceSignature(instance),
        phase: phase,
        message: message,
      ),
    };
  }
}

int _instanceSignature(Instance instance) => Object.hash(
      instance.localUrl,
      instance.externalUrl,
      instance.urlMode,
      instance.auth,
      instance.allowSelfSignedCerts,
      Object.hashAll(
        instance.customHeaders.entries.map(
          (MapEntry<String, String> entry) =>
              Object.hash(entry.key, entry.value),
        ),
      ),
    );

final speedtestRunControllerProvider = NotifierProvider.autoDispose
    .family<SpeedtestRunController, SpeedtestRunState, Instance>(
  SpeedtestRunController.new,
);

class SpeedtestRunController extends Notifier<SpeedtestRunState> {
  SpeedtestRunController(this.instance);

  final Instance instance;
  bool _disposed = false;
  late Completer<void> _disposeSignal;

  @override
  SpeedtestRunState build() {
    _disposed = false;
    _disposeSignal = Completer<void>();
    ref.onDispose(() {
      _disposed = true;
      if (!_disposeSignal.isCompleted) {
        _disposeSignal.complete();
      }
    });
    ref.listen<AsyncValue<SpeedtestTrackerApi>>(
      speedtestTrackerApiProvider(instance),
      (_, __) {},
    );
    final _SessionRestriction? restriction = ref
        .read(_speedtestRunSessionRestrictions.notifier)
        .forInstance(instance);
    return restriction == null
        ? const SpeedtestRunState()
        : SpeedtestRunState(
            phase: restriction.phase,
            message: restriction.message,
          );
  }

  Future<void> run({bool confirmIndeterminateRetry = false}) async {
    if (state.phase == SpeedtestRunPhase.indeterminate &&
        !confirmIndeterminateRetry) {
      return;
    }
    if (state.isBusy || state.isDisabledForSession) {
      return;
    }
    state = const SpeedtestRunState(phase: SpeedtestRunPhase.checking);
    try {
      final SpeedtestTrackerApi api =
          await ref.read(speedtestTrackerApiProvider(instance).future);
      final SpeedtestResultsPage latest = await api.listResults(pageSize: 10);
      if (_disposed) {
        return;
      }
      final Set<int> baselineIds = <int>{
        for (final SpeedtestResult result in latest.results) result.id,
      };
      final SpeedtestResult? active = _firstInProgress(latest.results);
      if (active != null) {
        state = SpeedtestRunState(
          phase: SpeedtestRunPhase.running,
          result: active,
          message:
              'A speed test is already ${active.status.label.toLowerCase()}.',
        );
        await _poll(api, active.id);
        return;
      }

      state = const SpeedtestRunState(phase: SpeedtestRunPhase.submitting);
      final DateTime submittedAt =
          ref.read(speedtestRunClockProvider)().toUtc();
      SpeedtestResult queued;
      try {
        queued = await api.runSpeedtest();
      } on SpeedtestTrackerException catch (error) {
        if (_isAmbiguousSubmission(error)) {
          await _reconcileSubmission(
            api,
            submittedAt: submittedAt,
            baselineIds: baselineIds,
          );
          return;
        }
        rethrow;
      }
      if (_disposed) {
        return;
      }
      if (_applyResult(queued)) {
        await _poll(api, queued.id);
      }
    } on SpeedtestTrackerException catch (error) {
      if (!_disposed) {
        _setError(error);
      }
    } on Object {
      if (!_disposed) {
        state = const SpeedtestRunState(
          phase: SpeedtestRunPhase.failed,
          message: 'The speed test could not be started.',
        );
      }
    }
  }

  Future<void> _reconcileSubmission(
    SpeedtestTrackerApi api, {
    required DateTime submittedAt,
    required Set<int> baselineIds,
  }) async {
    state = const SpeedtestRunState(
      phase: SpeedtestRunPhase.reconciling,
      message: 'The run response was interrupted. Checking whether the speed '
          'test was accepted...',
    );
    final Duration interval = ref.read(speedtestRunPollIntervalProvider);
    final int maxPolls = ref.read(speedtestRunReconcileMaxPollsProvider);
    for (int attempt = 0; attempt < maxPolls; attempt++) {
      if (_disposed) {
        return;
      }
      try {
        final SpeedtestResultsPage latest = await api.listResults(pageSize: 10);
        final SpeedtestResult? adopted = _newResultAfter(
          latest.results,
          submittedAt: submittedAt,
          baselineIds: baselineIds,
        );
        if (adopted != null) {
          if (_applyResult(adopted)) {
            await _poll(api, adopted.id);
          }
          return;
        }
      } on SpeedtestTrackerException catch (error) {
        if (!_isTransient(error)) {
          _setError(error);
          return;
        }
      }
      if (attempt + 1 < maxPolls) {
        if (!await _waitOrDispose(interval)) {
          return;
        }
      }
    }
    if (_disposed) {
      return;
    }
    state = const SpeedtestRunState(
      phase: SpeedtestRunPhase.indeterminate,
      message: 'Atrium could not confirm whether the speed test was accepted. '
          'Running again may create a duplicate and requires confirmation.',
    );
    _refreshResults();
  }

  Future<void> _poll(SpeedtestTrackerApi api, int resultId) async {
    final Duration interval = ref.read(speedtestRunPollIntervalProvider);
    final int maxPolls = ref.read(speedtestRunMaxPollsProvider);
    for (int attempt = 0; attempt < maxPolls; attempt++) {
      if (_disposed) {
        return;
      }
      if (!await _waitOrDispose(interval)) {
        return;
      }
      try {
        final SpeedtestResult result = await api.getResult(resultId);
        if (!_applyResult(result)) {
          return;
        }
      } on SpeedtestTrackerException catch (error) {
        if (_isTransient(error)) {
          continue;
        }
        _setError(error);
        return;
      }
    }
    state = SpeedtestRunState(
      phase: SpeedtestRunPhase.timedOut,
      result: state.result,
      message: 'The test may still be running. Refresh results to check it.',
    );
    _refreshResults();
  }

  void _setError(SpeedtestTrackerException error) {
    if (_disposed) {
      return;
    }
    final SpeedtestRunPhase phase = switch (error.kind) {
      SpeedtestErrorKind.permission => SpeedtestRunPhase.permissionDenied,
      SpeedtestErrorKind.unsupported => SpeedtestRunPhase.unsupported,
      _ => SpeedtestRunPhase.failed,
    };
    state = SpeedtestRunState(
      phase: phase,
      result: state.result,
      message: error.message,
    );
    if (phase == SpeedtestRunPhase.permissionDenied ||
        phase == SpeedtestRunPhase.unsupported) {
      ref.read(_speedtestRunSessionRestrictions.notifier).restrict(
            instance,
            phase,
            error.message,
          );
    }
  }

  bool _applyResult(SpeedtestResult result) {
    if (_disposed) {
      return false;
    }
    if (result.status == SpeedtestResultStatus.completed) {
      state = SpeedtestRunState(
        phase: SpeedtestRunPhase.completed,
        result: result,
        message: 'Speed test completed.',
      );
      _refreshResults();
      return false;
    }
    if (result.status.isFailure ||
        result.status == SpeedtestResultStatus.unknown) {
      state = SpeedtestRunState(
        phase: SpeedtestRunPhase.failed,
        result: result,
        message: result.message ??
            (result.status == SpeedtestResultStatus.unknown
                ? 'Speedtest Tracker returned an unsupported test status.'
                : 'The speed test ${result.status.label.toLowerCase()}.'),
      );
      _refreshResults();
      return false;
    }
    state = SpeedtestRunState(
      phase: result.status == SpeedtestResultStatus.waiting
          ? SpeedtestRunPhase.queued
          : SpeedtestRunPhase.running,
      result: result,
    );
    return true;
  }

  void _refreshResults() {
    if (_disposed) {
      return;
    }
    ref.invalidate(speedtestOverviewProvider(instance));
    ref.invalidate(speedtestHistoryProvider);
  }

  Future<bool> _waitOrDispose(Duration duration) async {
    await Future.any(<Future<void>>[
      Future<void>.delayed(duration),
      _disposeSignal.future,
    ]);
    return !_disposed;
  }
}

SpeedtestResult? _firstInProgress(List<SpeedtestResult> results) {
  for (final SpeedtestResult result in results) {
    if (result.status.isInProgress) {
      return result;
    }
  }
  return null;
}

SpeedtestResult? _newResultAfter(
  List<SpeedtestResult> results, {
  required DateTime submittedAt,
  required Set<int> baselineIds,
}) {
  for (final SpeedtestResult result in results) {
    final DateTime? createdAt = result.createdAt;
    if (!baselineIds.contains(result.id) &&
        createdAt != null &&
        !createdAt.toUtc().isBefore(submittedAt)) {
      return result;
    }
  }
  return null;
}

bool _isTransient(SpeedtestTrackerException error) =>
    error.kind == SpeedtestErrorKind.offline ||
    error.kind == SpeedtestErrorKind.timeout ||
    error.kind == SpeedtestErrorKind.server;

bool _isAmbiguousSubmission(SpeedtestTrackerException error) =>
    _isTransient(error) ||
    (error.kind == SpeedtestErrorKind.other && error.statusCode == null);
