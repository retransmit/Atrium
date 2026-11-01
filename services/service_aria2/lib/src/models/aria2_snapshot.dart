import 'aria2_download.dart';
import 'aria2_global_stat.dart';
import 'aria2_version.dart';

/// Everything one poll of an aria2 daemon returns.
///
/// The daemon has no single "list everything" call, so the module asks for
/// the three lists and the global counters in one batched request
/// (`system.multicall`) and keeps them together here.
class Aria2Snapshot {
  const Aria2Snapshot({
    required this.stat,
    required this.version,
    required this.active,
    required this.waiting,
    required this.stopped,
  });

  final Aria2GlobalStat stat;
  final Aria2Version version;

  /// Downloads running right now.
  final List<Aria2Download> active;

  /// Downloads in the queue, paused ones included.
  final List<Aria2Download> waiting;

  /// Downloads that finished, failed or were removed, oldest first.
  final List<Aria2Download> stopped;

  /// Everything that is not stopped yet.
  List<Aria2Download> get live => <Aria2Download>[...active, ...waiting];

  /// Whether any queued download is paused.
  bool get hasPaused =>
      waiting.any((Aria2Download d) => d.isPaused) ||
      active.any((Aria2Download d) => d.isPaused);

  /// Whether the daemon is doing nothing at all.
  bool get isIdle => active.isEmpty && waiting.isEmpty;
}
