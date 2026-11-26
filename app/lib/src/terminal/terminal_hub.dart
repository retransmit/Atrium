import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../preferences.dart';
import 'docker_shell.dart';
import 'ssh_connector.dart';
import 'ssh_host_status.dart';

enum SshStatus { disconnected, connecting, connected, failed }

/// One terminal tab: the host's own shell, or a shell inside a service's
/// container. Every tab is a channel on its host's single SSH connection.
class TerminalTab {
  TerminalTab._({
    required this.id,
    required this.title,
    required this.container,
  }) : terminal = Terminal(maxLines: 5000);

  /// Id of the host shell tab; service tabs use the service instance id.
  static const String hostTabId = '__host__';

  final String id;
  String title;

  /// The container the tab execs into; null for the host shell.
  String? container;

  final Terminal terminal;

  /// Selection state for copy, kept per tab so it matches the buffer.
  final TerminalController controller = TerminalController();

  SSHSession? _session;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;

  /// A channel is being opened. Guards against starting the tab twice while
  /// `execute` / `shell` is still in flight.
  bool _starting = false;

  /// The remote process ended on its own (`exit`, Ctrl+D). Such a tab is not
  /// restarted behind the user's back - only by Enter or by opening it again.
  bool finished = false;

  bool get isHost => id == hostTabId;
  bool get isRunning => _session != null;
  bool get isStarting => _starting;

  /// Running, starting, or waiting to be started on the next connect.
  bool get _wantsShell => isRunning || _starting || !finished;

  void _detach() {
    _stdout?.cancel();
    _stderr?.cancel();
    _stdout = null;
    _stderr = null;
    _session = null;
  }
}

/// The shared SSH connection to one Docker host and the tabs on it.
///
/// Lives for the app session (owned by [TerminalHub]), so leaving the
/// terminal screen keeps shells and scrollback alive, Termux-style. The
/// connection itself is only held while some shell needs it: once the last
/// one exits or is closed, it is closed too.
class HostSession extends ChangeNotifier {
  HostSession(this.hostId, this._knownHosts);

  final String hostId;
  final KnownHostsStore _knownHosts;

  SSHClient? _client;
  Future<void>? _connecting;
  bool _disposed = false;

  /// Last host / prompter used, so opening a tab or pressing Enter on a
  /// finished one can reconnect without the screen's help.
  Instance? _host;
  HostKeyPrompter? _onHostKey;

  /// The user chose Disconnect; don't reconnect just because the screen
  /// was opened again.
  bool _manuallyDisconnected = false;

  /// Closed by the app going to the background; the screen reconnects on
  /// resume.
  bool suspended = false;

  /// One-off uses of the connection outside any tab (`docker ps`).
  int _busy = 0;

  SshStatus status = SshStatus.disconnected;

  /// Why the session is not connected (error or explanation), for the banner.
  String? error;

  /// What the connection attempt is doing right now, for the loading UI.
  String? stage;

  /// Called with the outcome of every real login (not unreachable hosts -
  /// reachability is the health probe's business).
  void Function(SshLoginRecord login)? onLogin;

  /// The last Docker problem seen on this host (`docker ps` failing, or
  /// `docker exec` not found / not allowed). Kept apart from the connection
  /// status: the server itself is fine.
  String? dockerIssue;
  SshEndpoint? endpoint;

  final List<TerminalTab> tabs = <TerminalTab>[];
  int _active = 0;

  /// One-shot on-screen modifiers, cleared after the next key.
  bool ctrl = false;
  bool alt = false;

  TerminalTab? get activeTab =>
      tabs.isEmpty ? null : tabs[_active.clamp(0, tabs.length - 1)];

  int get activeIndex => tabs.isEmpty ? 0 : _active.clamp(0, tabs.length - 1);

  /// Whether opening the terminal screen should connect by itself.
  bool get shouldAutoConnect =>
      status != SshStatus.connected &&
      status != SshStatus.failed &&
      !_manuallyDisconnected &&
      (tabs.isEmpty || tabs.any((TerminalTab t) => t._wantsShell));

  void select(int index) {
    if (index >= 0 && index < tabs.length && index != _active) {
      _active = index;
      _notify();
    }
  }

  void toggleCtrl() {
    ctrl = !ctrl;
    _notify();
  }

  void toggleAlt() {
    alt = !alt;
    _notify();
  }

  /// Returns and clears the pending modifiers, for keys the screen encodes
  /// itself (arrows, Esc, ...).
  ({bool ctrl, bool alt}) takeModifiers() {
    final ({bool ctrl, bool alt}) mods = (ctrl: ctrl, alt: alt);
    if (ctrl || alt) {
      ctrl = false;
      alt = false;
      _notify();
    }
    return mods;
  }

  /// Connects (once; concurrent callers share the attempt) and starts every
  /// tab that wants a shell and is not already running or starting.
  Future<void> connect(Instance host, HostKeyPrompter onHostKey) {
    _host = host;
    _onHostKey = onHostKey;
    _manuallyDisconnected = false;
    if (status == SshStatus.connected) {
      return _startPending();
    }
    return _connecting ??= _connect(host, onHostKey).whenComplete(() {
      _connecting = null;
    });
  }

  Future<void> _connect(Instance host, HostKeyPrompter onHostKey) async {
    status = SshStatus.connecting;
    error = null;
    suspended = false;
    stage = 'Connecting...';
    _notify();
    try {
      final ({SSHClient client, SshEndpoint endpoint}) result = await connectSsh(
        host,
        knownHosts: _knownHosts,
        onHostKey: onHostKey,
        onProgress: (String s) {
          stage = s;
          _notify();
        },
      );
      if (_disposed) {
        result.client.close();
        return;
      }
      _client = result.client;
      endpoint = result.endpoint;
      status = SshStatus.connected;
      onLogin?.call(
        SshLoginRecord(ok: true, at: DateTime.now(), username: _username(host)),
      );
      stage = null;
      final SSHClient client = result.client;
      unawaited(
        client.done.then((_) {}, onError: (Object _) {}).whenComplete(
          () => _onClosed(client),
        ),
      );
      _notify();
      await _startPending();
    } on Object catch (e) {
      status = SshStatus.failed;
      stage = null;
      error = e.toString();
      if (e is SshConnectException && e.authFailed) {
        onLogin?.call(
          SshLoginRecord(
            ok: false,
            at: DateTime.now(),
            username: _username(host),
            message: e.message,
          ),
        );
      }
      _notify();
    }
  }

  static String _username(Instance host) => switch (host.auth) {
        InstanceAuthSsh(:final String username) => username.trim(),
        _ => '',
      };

  void _onClosed(SSHClient client) {
    if (!identical(client, _client)) {
      return;
    }
    _client = null;
    if (status == SshStatus.connected) {
      status = SshStatus.disconnected;
      error = 'Connection lost.';
    }
    for (final TerminalTab tab in tabs) {
      if (tab.isRunning) {
        tab._detach();
        tab.terminal.write('\r\n\x1b[31m[Connection lost]\x1b[0m\r\n');
      }
    }
    _notify();
  }

  /// Closes the connection at the user's request; tabs and scrollback stay.
  void disconnect() {
    _manuallyDisconnected = true;
    _close(null);
  }

  /// Closes the connection because the app went to the background; the
  /// screen reconnects on resume and running tabs start again.
  void suspend(String reason) {
    if (_client == null) return;
    for (final TerminalTab tab in tabs) {
      if (tab.isRunning) {
        tab.terminal.write('\r\n\x1b[33m[$reason]\x1b[0m\r\n');
      }
    }
    _close(reason);
    suspended = true;
    _notify();
  }

  void _close(String? reason) {
    final SSHClient? client = _client;
    _client = null;
    status = SshStatus.disconnected;
    error = reason;
    stage = null;
    for (final TerminalTab tab in tabs) {
      tab._session?.close();
      tab._detach();
    }
    client?.close();
    _notify();
  }

  /// Closes the connection once nothing uses it any more: every tab has
  /// exited or been closed, and no `docker ps` is in flight.
  void _closeIfIdle() {
    if (_client == null || _busy > 0) return;
    if (tabs.any((TerminalTab t) => t.isRunning || t.isStarting)) return;
    _close(
      tabs.isEmpty
          ? 'No shells open, so the SSH connection was closed.'
          : 'All shells exited, so the SSH connection was closed.',
    );
  }

  /// Focuses the host shell, creating or restarting it.
  TerminalTab openHostTab(Instance host) =>
      _open(TerminalTab.hostTabId, host.name, null);

  /// Focuses [service]'s container shell, reusing its tab when it exists.
  TerminalTab openServiceTab(Instance service) =>
      _open(service.id, service.name, service.dockerContainer.trim());

  TerminalTab _open(String id, String title, String? container) {
    TerminalTab? tab = tabs.firstWhereOrNull((TerminalTab t) => t.id == id);
    if (tab == null) {
      tab = _newTab(id, title, container);
      tabs.add(tab);
    } else {
      tab.title = title;
      if (tab.container != container && tab.isRunning) {
        // The service now points at another container; reopen there.
        tab._session?.close();
        tab._detach();
      }
      tab.container = container;
    }
    tab.finished = false;
    _active = tabs.indexOf(tab);
    _notify();
    _ensureStarted(tab);
    return tab;
  }

  /// Starts [tab] now if connected, otherwise reconnects (when the screen
  /// has connected before) and lets the connect start it.
  void _ensureStarted(TerminalTab tab) {
    if (status == SshStatus.connected) {
      unawaited(_start(tab));
    } else if (status != SshStatus.connecting &&
        _host != null &&
        _onHostKey != null) {
      unawaited(connect(_host!, _onHostKey!));
    }
  }

  /// Marks the active tab as wanted again (after `exit`), for the Connect
  /// button.
  void reviveActive() {
    activeTab?.finished = false;
  }

  void closeTab(TerminalTab tab) {
    tab._session?.close();
    tab._detach();
    final int index = tabs.indexOf(tab);
    tabs.remove(tab);
    if (_active >= index && _active > 0) {
      _active--;
    }
    _notify();
    _closeIfIdle();
  }

  /// Connects if needed and lists the host's running containers, keeping
  /// the connection busy throughout so it is not closed as idle mid-way.
  Future<List<DockerContainer>> fetchContainers(
    Instance host,
    HostKeyPrompter onHostKey,
  ) async {
    _busy++;
    try {
      await connect(host, onHostKey);
      if (status != SshStatus.connected) {
        throw StateError(error ?? 'Could not connect to ${host.name}');
      }
      return await listContainers();
    } finally {
      _busy--;
      _closeIfIdle();
    }
  }

  /// Runs `docker ps` on the host over the shared connection.
  Future<List<DockerContainer>> listContainers() async {
    final SSHClient? client = _client;
    if (client == null) {
      throw StateError('Not connected');
    }
    _busy++;
    try {
      final SSHRunResult result = await client.runWithResult(dockerPsCommand);
      final String out = utf8.decode(result.stdout, allowMalformed: true);
      if (result.exitCode != null && result.exitCode != 0) {
        final String err = utf8.decode(result.stderr, allowMalformed: true);
        final String reason =
            (err.trim().isEmpty ? out : err).trim().split('\n').first;
        _setDockerIssue(dockerIssueFor(result.exitCode!, reason));
        throw StateError(reason);
      }
      _setDockerIssue(null);
      return parseDockerPs(out);
    } finally {
      _busy--;
      _closeIfIdle();
    }
  }

  TerminalTab _newTab(String id, String title, String? container) {
    final TerminalTab tab =
        TerminalTab._(id: id, title: title, container: container);
    tab.terminal.onOutput = (String data) {
      if (!tab.isRunning) {
        // Termux-style: Enter on a finished tab starts it again.
        if (!tab.isStarting && data.contains('\r')) {
          tab.finished = false;
          _ensureStarted(tab);
        }
        return;
      }
      final ({bool ctrl, bool alt}) mods = takeModifiers();
      final String out = applyModifiers(data, ctrl: mods.ctrl, alt: mods.alt);
      tab._session?.write(utf8.encode(out));
    };
    tab.terminal.onResize = (int w, int h, int pw, int ph) {
      tab._session?.resizeTerminal(w, h, pw, ph);
    };
    return tab;
  }

  Future<void> _startPending() async {
    for (final TerminalTab tab in List<TerminalTab>.of(tabs)) {
      if (!tab.finished) {
        await _start(tab);
      }
    }
    _closeIfIdle();
  }

  Future<void> _start(TerminalTab tab) async {
    final SSHClient? client = _client;
    if (client == null || tab.isRunning || tab.isStarting) {
      return;
    }
    final Terminal term = tab.terminal;
    final String? container = tab.container;
    if (container != null && container.isEmpty) {
      term.write(
        '\r\n\x1b[33m[No container set for ${tab.title}. Edit the service '
        'to pick one.]\x1b[0m\r\n',
      );
      tab.finished = true;
      _closeIfIdle();
      return;
    }
    tab._starting = true;
    _notify();
    final SSHPtyConfig pty = SSHPtyConfig(
      width: term.viewWidth,
      height: term.viewHeight,
    );
    final SSHSession session;
    try {
      if (container == null) {
        session = await client.shell(pty: pty);
      } else {
        term.write('\x1b[2m[docker exec into $container]\x1b[0m\r\n');
        session = await client.execute(
          dockerExecShellCommand(container),
          pty: pty,
        );
      }
    } on Object catch (e) {
      tab._starting = false;
      if (identical(client, _client)) {
        term.write('\r\n\x1b[31m[Could not open a shell: $e]\x1b[0m\r\n');
        tab.finished = true;
      }
      _notify();
      _closeIfIdle();
      return;
    }
    tab._starting = false;
    if (!tabs.contains(tab) || _disposed || !identical(client, _client)) {
      session.close();
      _notify();
      return;
    }
    tab._session = session;
    final DateTime startedAt = DateTime.now();
    const Utf8Decoder decoder = Utf8Decoder(allowMalformed: true);
    tab._stdout = session.stdout.cast<List<int>>().transform(decoder).listen(
          term.write,
        );
    tab._stderr = session.stderr.cast<List<int>>().transform(decoder).listen(
          term.write,
        );
    unawaited(
      session.done.then((_) {}, onError: (Object _) {}).whenComplete(() {
        if (!identical(tab._session, session)) {
          return;
        }
        tab._detach();
        if (identical(client, _client)) {
          // The remote process ended by itself (exit / Ctrl+D).
          tab.finished = true;
          final int? code = session.exitCode;
          // `docker exec` that dies at once with 126/127 never got a shell:
          // docker is missing or not allowed. Later, the same codes are just
          // the user's last command inside the container.
          if (tab.container != null &&
              code != null &&
              DateTime.now().difference(startedAt) <
                  const Duration(seconds: 3)) {
            if (code == 126 || code == 127) {
              _setDockerIssue(dockerIssueFor(code, ''));
            }
          } else if (tab.container != null) {
            _setDockerIssue(null);
          }
          term.write(
            '\r\n\x1b[2m[Process completed${code == null ? '' : ' ($code)'}'
            ' - press Enter to restart]\x1b[0m\r\n',
          );
        }
        _notify();
        _closeIfIdle();
      }),
    );
    _notify();
  }

  void _setDockerIssue(String? issue) {
    if (dockerIssue != issue) {
      dockerIssue = issue;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _close(null);
    super.dispose();
  }
}

/// Owns one [HostSession] per Docker host for the app's lifetime, and closes
/// their connections when the app is closed or left in the background.
class TerminalHub {
  TerminalHub(this._knownHosts, {DateTime Function()? now, this.onLogin})
      : _now = now ?? DateTime.now;

  /// Receives every host's login outcomes (see [HostSession.onLogin]).
  final void Function(String hostId, SshLoginRecord login)? onLogin;

  /// How long the app may sit in the background before SSH connections are
  /// closed. Long enough to switch apps to copy something, short enough not
  /// to leave sessions open on the server indefinitely.
  static const Duration backgroundGrace = Duration(minutes: 5);

  final KnownHostsStore _knownHosts;
  final DateTime Function() _now;
  final Map<String, HostSession> _sessions = <String, HostSession>{};
  final Map<String, Object> _hostConnections = <String, Object>{};

  Timer? _backgroundTimer;
  DateTime? _backgroundedAt;

  KnownHostsStore get knownHosts => _knownHosts;

  HostSession session(String hostId) => _sessions.putIfAbsent(
        hostId,
        () => HostSession(hostId, _knownHosts)
          ..onLogin = (SshLoginRecord login) => onLogin?.call(hostId, login),
      );

  /// Closes sessions whose host left the active profile, or whose address
  /// or login was edited - their connection was made with the old details.
  /// A rename keeps the session.
  void syncHosts(Iterable<Instance> hosts) {
    final Map<String, Object> next = <String, Object>{
      for (final Instance h in hosts)
        if (h.kind == ServiceKind.dockerHost)
          h.id: (h.localUrl, h.externalUrl, h.urlMode, h.auth),
    };
    final List<String> stale = _sessions.keys
        .where(
          (String id) =>
              !next.containsKey(id) ||
              (_hostConnections.containsKey(id) &&
                  _hostConnections[id] != next[id]),
        )
        .toList();
    for (final String id in stale) {
      _sessions.remove(id)?.dispose();
    }
    _hostConnections
      ..clear()
      ..addAll(next);
  }

  void handleLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _backgroundTimer?.cancel();
        _backgroundTimer = null;
        // The timer cannot fire while Android has the process frozen, so
        // check the wall clock as well.
        final DateTime? since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null && _now().difference(since) >= backgroundGrace) {
          _suspendAll();
        }
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _backgroundedAt ??= _now();
        _backgroundTimer ??= Timer(backgroundGrace, _suspendAll);
      case AppLifecycleState.detached:
        _backgroundTimer?.cancel();
        _backgroundTimer = null;
        for (final HostSession s in _sessions.values) {
          s.suspend('App closed');
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _suspendAll() {
    _backgroundTimer = null;
    for (final HostSession s in _sessions.values) {
      s.suspend(
        'Disconnected after ${backgroundGrace.inMinutes} minutes in the '
        'background',
      );
    }
  }

  void dispose() {
    _backgroundTimer?.cancel();
    for (final HostSession s in _sessions.values) {
      s.dispose();
    }
    _sessions.clear();
  }
}

final Provider<TerminalHub> terminalHubProvider = Provider<TerminalHub>((
  Ref ref,
) {
  final TerminalHub hub = TerminalHub(
    KnownHostsStore(ref.watch(settingsBoxProvider)),
    onLogin: (String hostId, SshLoginRecord login) =>
        ref.read(sshLoginRecordsProvider.notifier).record(hostId, login),
  );
  final AppLifecycleListener lifecycle =
      AppLifecycleListener(onStateChange: hub.handleLifecycle);
  hub.syncHosts(ref.read(activeInstancesProvider));
  ref.listen<List<Instance>>(
    activeInstancesProvider,
    (_, List<Instance> next) => hub.syncHosts(next),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    hub.dispose();
  });
  return hub;
});
