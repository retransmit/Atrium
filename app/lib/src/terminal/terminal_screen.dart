import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';

import 'docker_shell.dart';
import 'ssh_connector.dart';
import 'terminal_hub.dart';

/// Asks whether to trust an SSH host key, warning loudly when it changed.
Future<bool> confirmHostKey(BuildContext context, HostKeyPrompt prompt) async {
  final ThemeData theme = Theme.of(context);
  final bool? trusted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => AlertDialog(
      icon: Icon(
        prompt.changed ? Icons.gpp_bad_outlined : Icons.key_outlined,
        color: prompt.changed ? theme.colorScheme.error : null,
      ),
      title: Text(prompt.changed ? 'Host key changed' : 'Trust this host?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              prompt.changed
                  ? 'The key presented by ${prompt.endpoint} does not match '
                      'the one saved earlier. This can mean the server was '
                      'reinstalled - or that someone is intercepting the '
                      'connection.'
                  : 'First connection to ${prompt.endpoint}. Check the '
                      'fingerprint matches the server before trusting it.',
            ),
            const SizedBox(height: Insets.md),
            if (prompt.changed) ...<Widget>[
              Text('Saved', style: theme.textTheme.labelMedium),
              SelectableText(
                prompt.previous!,
                style: const TextStyle(fontFamily: 'JetBrainsMono Nerd Font'),
              ),
              const SizedBox(height: Insets.sm),
              Text('Presented', style: theme.textTheme.labelMedium),
            ],
            SelectableText(
              prompt.entry,
              style: const TextStyle(fontFamily: 'JetBrainsMono Nerd Font'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: prompt.changed
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(prompt.changed ? 'Trust new key' : 'Trust'),
        ),
      ],
    ),
  );
  return trusted ?? false;
}

/// Opens (or focuses) [service]'s container shell on its Docker host's
/// shared connection and navigates to that host's terminal.
///
/// [beforeNavigate] runs after the router is captured, for callers that
/// must close a drawer or sheet first.
void openServiceShell(
  BuildContext context,
  WidgetRef ref,
  Instance service, {
  VoidCallback? beforeNavigate,
}) {
  final GoRouter router = GoRouter.of(context);
  final Instance? host =
      dockerHostFor(service, ref.read(activeInstancesProvider));
  if (host == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add a Docker Host service first to open shells.'),
      ),
    );
    return;
  }
  ref.read(terminalHubProvider).session(host.id).openServiceTab(service);
  beforeNavigate?.call();
  router.go(AtriumRoutes.servicePath(host.kind.name, host.id));
}

/// The Docker host's terminal: a tab per shell, all multiplexed over one SSH
/// connection that outlives this screen.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({required this.host, required this.drawer, super.key});

  final Instance host;
  final Widget drawer;

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double _fontSize = 13;
  late final AppLifecycleListener _lifecycle;

  HostSession get _session =>
      ref.read(terminalHubProvider).session(widget.host.id);

  @override
  void initState() {
    super.initState();
    // After the hub's own lifecycle handling, which may just have closed the
    // connection for being in the background too long.
    _lifecycle = AppLifecycleListener(
      onResume: () => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _session.suspended) {
          _connect();
        }
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _session.shouldAutoConnect) {
        _connect();
      }
    });
  }

  @override
  void didUpdateWidget(TerminalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An edited address or login replaces the session (see
    // TerminalHub.syncHosts); bring the fresh one up like on first open.
    if (oldWidget.host != widget.host) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _session.shouldAutoConnect) {
          _connect();
        }
      });
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _connect() {
    final HostSession session = _session;
    if (session.tabs.isEmpty) {
      session.openHostTab(widget.host);
    } else {
      session.reviveActive();
    }
    unawaited(
      session.connect(
        widget.host,
        (HostKeyPrompt p) =>
            mounted ? confirmHostKey(context, p) : Future<bool>.value(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final HostSession session =
        ref.watch(terminalHubProvider).session(widget.host.id);
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        final ScaffoldState? scaffold = _scaffoldKey.currentState;
        if (scaffold?.isDrawerOpen ?? false) {
          scaffold!.closeDrawer();
          return;
        }
        context.goNamed(AtriumRoutes.dashboardName);
      },
      child: ListenableBuilder(
        listenable: session,
        builder: (BuildContext context, Widget? _) => Scaffold(
          key: _scaffoldKey,
          drawerEdgeDragWidth: 24,
          drawer: widget.drawer,
          appBar: AppBar(
            leading: Builder(
              builder: (BuildContext context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(widget.host.name, overflow: TextOverflow.ellipsis),
                Text(
                  _statusLabel(session),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Open shell',
                icon: const Icon(Icons.add),
                onPressed: () => _showOpenMenu(session),
              ),
              PopupMenuButton<String>(
                onSelected: (String v) => _onMenu(v, session),
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'paste',
                    child: Text('Paste'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'copy',
                    child: Text('Copy selection'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'bigger',
                    child: Text('Larger text'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'smaller',
                    child: Text('Smaller text'),
                  ),
                  const PopupMenuDivider(),
                  if (session.status == SshStatus.connected)
                    const PopupMenuItem<String>(
                      value: 'disconnect',
                      child: Text('Disconnect'),
                    )
                  else
                    const PopupMenuItem<String>(
                      value: 'connect',
                      child: Text('Connect'),
                    ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                if (session.status != SshStatus.connected)
                  _StatusBanner(session: session, onRetry: _connect),
                if (session.tabs.isNotEmpty) _TabStrip(session: session),
                Expanded(child: _body(session)),
                _ExtraKeys(session: session),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(HostSession session) {
    final TerminalTab? tab = session.activeTab;
    if (tab == null) {
      return EmptyView(
        icon: Icons.terminal_rounded,
        title: 'No shells open',
        message: 'Open a shell on the host or inside a service container.',
        action: FilledButton.icon(
          onPressed: () => _showOpenMenu(session),
          icon: const Icon(Icons.add),
          label: const Text('Open shell'),
        ),
      );
    }
    final bool loading = !tab.isRunning &&
        (session.status == SshStatus.connecting || tab.isStarting);
    return Stack(
      children: <Widget>[
        Positioned.fill(child: _terminalView(tab)),
        if (loading)
          Center(
            child: _LoadingCard(
              text: session.status == SshStatus.connecting
                  ? (session.stage ?? 'Connecting...')
                  : tab.container == null
                      ? 'Opening shell...'
                      : 'Opening a shell in ${tab.container}...',
            ),
          ),
      ],
    );
  }

  Widget _terminalView(TerminalTab tab) {
    return TerminalView(
      tab.terminal,
      key: ValueKey<String>(tab.id),
      controller: tab.controller,
      autofocus: true,
      theme: TerminalThemes.defaultTheme,
      textStyle: TerminalStyle(
        fontSize: _fontSize,
        fontFamily: 'JetBrainsMono Nerd Font',
      ),
      padding: const EdgeInsets.all(Insets.xs),
      keyboardType: TextInputType.visiblePassword,
      deleteDetection: true,
    );
  }

  String _statusLabel(HostSession s) => switch (s.status) {
        SshStatus.connected => 'Connected to ${s.endpoint}',
        SshStatus.connecting => s.stage ?? 'Connecting...',
        SshStatus.failed => 'Connection failed',
        SshStatus.disconnected => 'Disconnected',
      };

  Future<void> _showOpenMenu(HostSession session) async {
    final List<Instance> services = ref
        .read(activeInstancesProvider)
        .where(
          (Instance i) =>
              i.kind != ServiceKind.dockerHost &&
              dockerHostFor(i, ref.read(activeInstancesProvider))?.id ==
                  widget.host.id,
        )
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.terminal_rounded),
                title: const Text('Host shell'),
                subtitle: Text(widget.host.name),
                onTap: () {
                  Navigator.pop(sheetContext);
                  session.openHostTab(widget.host);
                },
              ),
              if (services.isNotEmpty) const Divider(),
              for (final Instance s in services)
                ListTile(
                  leading: Icon(
                    ServiceVisuals.icon(s.kind),
                    color: ServiceVisuals.accent(s.kind),
                  ),
                  title: Text(s.name),
                  subtitle: Text(
                    s.dockerContainer.isEmpty
                        ? 'No container set - edit the service to pick one'
                        : 'docker exec ${s.dockerContainer}',
                  ),
                  enabled: s.dockerContainer.trim().isNotEmpty,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    session.openServiceTab(s);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(String value, HostSession session) async {
    final TerminalTab? tab = session.activeTab;
    switch (value) {
      case 'paste':
        final ClipboardData? data = await Clipboard.getData('text/plain');
        final String? text = data?.text;
        if (tab != null && text != null && text.isNotEmpty) {
          tab.terminal.paste(text);
        }
      case 'copy':
        final BufferRange? range = tab?.controller.selection;
        if (tab != null && range != null) {
          await Clipboard.setData(
            ClipboardData(text: tab.terminal.buffer.getText(range)),
          );
          tab.controller.clearSelection();
        }
      case 'bigger':
        setState(() => _fontSize = (_fontSize + 1).clamp(8, 28));
      case 'smaller':
        setState(() => _fontSize = (_fontSize - 1).clamp(8, 28));
      case 'disconnect':
        session.disconnect();
      case 'connect':
        _connect();
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.session, required this.onRetry});

  final HostSession session;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    if (session.status == SshStatus.connecting) {
      return const LinearProgressIndicator(minHeight: 3);
    }
    final bool failed = session.status == SshStatus.failed;
    return Material(
      color: failed ? cs.errorContainer : cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              failed ? Icons.error_outline : Icons.link_off,
              size: 18,
              color: failed ? cs.onErrorContainer : cs.onSurfaceVariant,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                session.error ?? 'Not connected.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: failed ? cs.onErrorContainer : null,
                    ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(failed ? 'Retry' : 'Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: Insets.md),
            Flexible(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.session});

  final HostSession session;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.xs,
        ),
        itemCount: session.tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: Insets.xs),
        itemBuilder: (BuildContext context, int i) {
          final TerminalTab tab = session.tabs[i];
          return InputChip(
            avatar: tab.isStarting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    tab.isHost
                        ? Icons.dns_outlined
                        : Icons.inventory_2_outlined,
                    size: 16,
                  ),
            label: Text(tab.title),
            selected: i == session.activeIndex,
            showCheckmark: false,
            onPressed: () => session.select(i),
            onDeleted: () => session.closeTab(tab),
            deleteButtonTooltipMessage: 'Close',
          );
        },
      ),
    );
  }
}

/// Termux-style row of keys a phone keyboard lacks. Ctrl / Alt are one-shot
/// modifiers applied to the next key, from this row or the soft keyboard.
class _ExtraKeys extends StatelessWidget {
  const _ExtraKeys({required this.session});

  final HostSession session;

  void _key(TerminalKey key) {
    final TerminalTab? tab = session.activeTab;
    if (tab == null) return;
    final ({bool ctrl, bool alt}) mods = session.takeModifiers();
    tab.terminal.keyInput(key, ctrl: mods.ctrl, alt: mods.alt);
  }

  void _text(String text) => session.activeTab?.terminal.textInput(text);

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<Widget> keys = <Widget>[
      _KeyButton(label: 'ESC', onTap: () => _key(TerminalKey.escape)),
      _KeyButton(label: 'TAB', onTap: () => _key(TerminalKey.tab)),
      _KeyButton(
        label: 'CTRL',
        active: session.ctrl,
        onTap: session.toggleCtrl,
      ),
      _KeyButton(label: 'ALT', active: session.alt, onTap: session.toggleAlt),
      _KeyButton(label: '←', onTap: () => _key(TerminalKey.arrowLeft)),
      _KeyButton(label: '↓', onTap: () => _key(TerminalKey.arrowDown)),
      _KeyButton(label: '↑', onTap: () => _key(TerminalKey.arrowUp)),
      _KeyButton(label: '→', onTap: () => _key(TerminalKey.arrowRight)),
      _KeyButton(label: 'HOME', onTap: () => _key(TerminalKey.home)),
      _KeyButton(label: 'END', onTap: () => _key(TerminalKey.end)),
      _KeyButton(label: 'PGUP', onTap: () => _key(TerminalKey.pageUp)),
      _KeyButton(label: 'PGDN', onTap: () => _key(TerminalKey.pageDown)),
      for (final String c in const <String>['-', '/', '|', '~', '_'])
        _KeyButton(label: c, onTap: () => _text(c)),
    ];
    return Material(
      color: cs.surfaceContainer,
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
          children: keys,
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Material(
        color: active ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono Nerd Font',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: active ? cs.onPrimary : cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
