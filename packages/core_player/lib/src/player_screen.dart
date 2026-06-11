import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'playback_spec.dart';

/// Full-screen video player for one [PlaybackSpec].
///
/// Uses media_kit (libmpv) so it direct-plays the codecs/containers
/// self-hosters keep without relying on the platform decoder. The on-screen
/// transport controls come from media_kit_video's adaptive controls.
///
/// Lifecycle of the reporting callbacks:
/// * [PlaybackSpec.onStarted] fires once the first frame is ready.
/// * [PlaybackSpec.onProgress] fires every ~10s and whenever play/pause
///   toggles.
/// * [PlaybackSpec.onStopped] fires once on close with the final position.
class AtriumPlayerScreen extends StatefulWidget {
  const AtriumPlayerScreen({required this.spec, super.key});

  final PlaybackSpec spec;

  @override
  State<AtriumPlayerScreen> createState() => _AtriumPlayerScreenState();
}

class _AtriumPlayerScreenState extends State<AtriumPlayerScreen>
    with WidgetsBindingObserver {
  // media_kit caps libmpv's demuxer read-ahead at 32 MiB by default, so a
  // paused/closed player stops pulling bytes once that window fills. The
  // lifecycle observer below handles the "app backgrounded" case.
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  Timer? _progressTimer;
  StreamSubscription<bool>? _playingSub;
  bool _startedReported = false;
  bool _stoppedReported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _open();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding the app should stop the stream, not keep pulling bytes
    // behind the user's back. They can resume where they left off.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _player.pause();
    }
  }

  Future<void> _open() async {
    await _player.open(
      Media(
        widget.spec.url,
        // NOTE: our media servers (Jellyfin/Emby/Plex) carry auth as a URL
        // query param, so [PlaybackSpec.headers] is empty in practice. We
        // intentionally don't forward it to Media here - media_kit's
        // httpHeaders parameter trips a cross-package type clash with the
        // `http` package's Map type. Revisit if a server ever needs header
        // auth.
        start: widget.spec.startPosition == Duration.zero
            ? null
            : widget.spec.startPosition,
      ),
    );

    // Fire onStarted once the player reports it's playing.
    _playingSub = _player.stream.playing.listen((bool playing) {
      if (playing && !_startedReported) {
        _startedReported = true;
        widget.spec.onStarted?.call(_player.state.position);
      }
      if (_startedReported) {
        widget.spec.onProgress
            ?.call(_player.state.position, !_player.state.playing);
      }
    });

    // Periodic progress heartbeat.
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_startedReported && !_stoppedReported) {
        widget.spec.onProgress
            ?.call(_player.state.position, !_player.state.playing);
      }
    });
  }

  void _reportStopped() {
    if (_stoppedReported) {
      return;
    }
    _stoppedReported = true;
    widget.spec.onStopped?.call(_player.state.position);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportStopped();
    _progressTimer?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) => _reportStopped(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Video(controller: _controller),
      ),
    );
  }
}
