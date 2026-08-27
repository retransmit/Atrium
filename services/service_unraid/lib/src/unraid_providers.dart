import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'models/unraid_models.dart';
import 'unraid_client.dart';

/// Which tab is showing, per instance.
///
/// Kept per instance so moving between two servers does not drop you on
/// whichever tab you last used on the other one.
final tabIndexProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance instance) => 0);

/// Whether the bottom bar is showing. Hidden while scrolling down so a long
/// disk list is not read through a navigation bar.
final bottomNavVisibleProvider =
    StateProvider.family<bool, Instance>((Ref ref, Instance instance) => true);

/// How often the array and container lists refresh while on screen.
///
/// Slower than the torrent clients on purpose: none of this moves quickly, and
/// every tick is a GraphQL query the server has to resolve.
const Duration unraidPollInterval = Duration(seconds: 15);

/// Client bound to one instance.
///
/// Rides [instanceDioProvider], so the base URL, custom headers, self-signed
/// opt-in and the `x-api-key` header all come from the shared setup.
final unraidClientProvider =
    FutureProvider.autoDispose.family<UnraidClient, Instance>(
  (Ref ref, Instance instance) async =>
      UnraidClient(await ref.watch(instanceDioProvider(instance).future)),
);

/// Array state and disks, polled while watched.
final unraidArrayProvider =
    FutureProvider.autoDispose.family<UnraidArray, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    unraidPollInterval,
    () async {
      final UnraidClient client =
          await ref.watch(unraidClientProvider(instance).future);
      return client.getArray();
    },
  ),
);

/// Docker containers, polled while watched.
final unraidContainersProvider =
    FutureProvider.autoDispose.family<List<UnraidContainer>, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    unraidPollInterval,
    () async {
      final UnraidClient client =
          await ref.watch(unraidClientProvider(instance).future);
      return client.getContainers();
    },
  ),
);

/// Virtual machines, polled while watched.
final unraidVmsProvider =
    FutureProvider.autoDispose.family<UnraidVmList, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    unraidPollInterval,
    () async {
      final UnraidClient client =
          await ref.watch(unraidClientProvider(instance).future);
      return client.getVms();
    },
  ),
);

/// How often CPU and memory are sampled.
///
/// Faster than the array poll on purpose. Load moves second to second, and a
/// graph drawn from fifteen second samples reads as a row of steps rather than
/// a curve. The metrics query is also far cheaper than the array one, which is
/// what makes the tighter cadence affordable.
const Duration unraidMetricsPollInterval = Duration(seconds: 5);

/// How hard the machine is working, sampled while watched.
final unraidMetricsProvider =
    FutureProvider.autoDispose.family<UnraidMetrics, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    unraidMetricsPollInterval,
    () async {
      final UnraidClient client =
          await ref.watch(unraidClientProvider(instance).future);
      return client.getMetrics();
    },
  ),
);

/// How many samples a graph holds. At the poll interval above this is five
/// minutes of history.
const int unraidHistoryPoints = 60;

/// A rolling window of samples, oldest first.
class UnraidMetricsHistory {
  const UnraidMetricsHistory({
    this.cpu = const <double>[],
    this.memory = const <double>[],
    this.rx = const <double>[],
    this.tx = const <double>[],
  });

  /// Percentages, 0 to 100.
  final List<double> cpu;
  final List<double> memory;

  /// Bytes per second.
  final List<double> rx;
  final List<double> tx;

  /// A single sample cannot be drawn as a line, so a graph waits for two.
  bool get hasCurve => cpu.length > 1 || memory.length > 1;
}

/// Accumulates the samples a graph needs.
///
/// The server keeps no history for these, so the only way to draw a line is to
/// remember what has been seen. This disposes with the screen: a window that
/// outlived it would come back with a gap in the middle and no way to show
/// one, which reads as load that never happened.
class UnraidMetricsHistoryNotifier extends Notifier<UnraidMetricsHistory> {
  UnraidMetricsHistoryNotifier(this.instance);

  final Instance instance;

  @override
  UnraidMetricsHistory build() {
    ref.listen(unraidMetricsProvider(instance), (
      AsyncValue<UnraidMetrics>? previous,
      AsyncValue<UnraidMetrics> next,
    ) {
      final UnraidMetrics? m = next.value;
      if (m == null) return;
      state = UnraidMetricsHistory(
        cpu: _push(state.cpu, m.cpu?.percentTotal),
        memory: _push(state.memory, (m.memory?.usedFraction ?? 0) * 100,
            skip: m.memory?.usedFraction == null,),
        rx: _push(state.rx, m.rxBytesPerSec),
        tx: _push(state.tx, m.txBytesPerSec),
      );
    });
    return const UnraidMetricsHistory();
  }

  /// Appends one sample, dropping the oldest once the window is full.
  ///
  /// A missing reading is left out rather than pushed as zero, which would
  /// draw a drop to idle that never happened.
  static List<double> _push(List<double> window, double? value,
      {bool skip = false,}) {
    if (value == null || skip) return window;
    final List<double> next = <double>[...window, value];
    if (next.length > unraidHistoryPoints) next.removeAt(0);
    return next;
  }
}

final unraidMetricsHistoryProvider = NotifierProvider.autoDispose
    .family<UnraidMetricsHistoryNotifier, UnraidMetricsHistory, Instance>(
  UnraidMetricsHistoryNotifier.new,
);
