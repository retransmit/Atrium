import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'plex_account_api.dart';

/// What signing in produced, ready to drop into the instance form.
class PlexSignInResult {
  const PlexSignInResult({
    required this.token,
    this.serverName,
    this.localUrl,
    this.externalUrl,
    this.usesRelay = false,
    this.externalUnverified = false,
  });

  final String token;
  final String? serverName;
  final String? localUrl;
  final String? externalUrl;
  final bool usesRelay;

  /// See [PlexServerUrls.externalUnverified].
  final bool externalUnverified;
}

/// Signs the user in at plex.tv and, if they pick a server, hands back its
/// address alongside the token.
///
/// [apiFactory] and [launch] exist so a test can drive the flow without
/// talking to plex.tv or opening a browser.
Future<PlexSignInResult?> showPlexSignInSheet({
  required BuildContext context,
  required String clientIdentifier,
  PlexAccountApi Function()? apiFactory,
  Future<bool> Function(Uri url)? launch,
  Future<PlexServerUrls> Function(PlexServer server)? probe,
}) {
  return showModalBottomSheet<PlexSignInResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _PlexSignInSheet(
      api: apiFactory?.call() ??
          PlexAccountApi(clientIdentifier: clientIdentifier),
      clientIdentifier: clientIdentifier,
      launch: launch ??
          (Uri url) => launchUrl(url, mode: LaunchMode.externalApplication),
      probe: probe ?? probePlexServerUrls,
    ),
  );
}

enum _Stage { starting, waiting, servers, failed }

class _PlexSignInSheet extends StatefulWidget {
  const _PlexSignInSheet({
    required this.api,
    required this.clientIdentifier,
    required this.launch,
    required this.probe,
  });

  final PlexAccountApi api;
  final String clientIdentifier;
  final Future<bool> Function(Uri url) launch;
  final Future<PlexServerUrls> Function(PlexServer server) probe;

  @override
  State<_PlexSignInSheet> createState() => _PlexSignInSheetState();
}

class _PlexSignInSheetState extends State<_PlexSignInSheet> {
  static const Duration _pollEvery = Duration(seconds: 2);

  _Stage _stage = _Stage.starting;
  PlexPin? _pin;
  String? _token;
  String? _error;
  List<PlexServer> _servers = <PlexServer>[];

  /// The server being probed, so its row can say so.
  String? _checking;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.api.close();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.starting;
      _error = null;
    });
    try {
      final PlexPin pin = await widget.api.createPin();
      if (!mounted) {
        return;
      }
      setState(() {
        _pin = pin;
        _stage = _Stage.waiting;
      });
      await _openBrowser();
      _poll = Timer.periodic(_pollEvery, (Timer _) => unawaited(_check(pin)));
    } on PlexAccountException catch (e) {
      _fail(e.message);
    }
  }

  Future<void> _openBrowser() async {
    final PlexPin? pin = _pin;
    if (pin == null) {
      return;
    }
    try {
      await widget.launch(
        plexAuthUri(
          clientIdentifier: widget.clientIdentifier,
          code: pin.code,
        ),
      );
    } catch (_) {
      // The link can be copied from the sheet, so a browser that will not
      // open is awkward rather than fatal.
    }
  }

  Future<void> _check(PlexPin pin) async {
    if (pin.hasExpired) {
      _poll?.cancel();
      _fail('That code expired. Start again.');
      return;
    }
    try {
      final String? token = await widget.api.pollPin(pin);
      if (token == null || !mounted) {
        return;
      }
      _poll?.cancel();
      setState(() {
        _token = token;
        _stage = _Stage.servers;
      });
      await _loadServers(token);
    } on PlexAccountException {
      // Keep polling: a blip on one request says nothing about the next.
    }
  }

  Future<void> _loadServers(String token) async {
    try {
      final List<PlexServer> servers = await widget.api.getServers(token);
      if (!mounted) {
        return;
      }
      setState(() => _servers = servers);
    } on PlexAccountException catch (e) {
      if (!mounted) {
        return;
      }
      // The token is already in hand, so this is not a dead end: the list
      // just stays empty and the sheet offers to keep the token.
      setState(() => _error = e.message);
    }
  }

  void _fail(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = _Stage.failed;
      _error = message;
    });
  }

  Future<void> _finish(PlexServer? server) async {
    final String? accountToken = _token;
    if (accountToken == null) {
      return;
    }
    if (server == null) {
      Navigator.of(context).pop(PlexSignInResult(token: accountToken));
      return;
    }

    setState(() => _checking = server.clientIdentifier);
    final PlexServerUrls urls = await widget.probe(server);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(
      PlexSignInResult(
        token:
            server.accessToken.isNotEmpty ? server.accessToken : accountToken,
        serverName: server.name,
        localUrl: urls.localUrl,
        externalUrl: urls.externalUrl,
        usesRelay: urls.usesRelay,
        externalUnverified: urls.externalUnverified,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Sign in with Plex',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Insets.lg),
            Flexible(child: SingleChildScrollView(child: _body(theme))),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) => switch (_stage) {
        _Stage.starting => const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        _Stage.waiting => _waiting(theme),
        _Stage.servers => _serverList(theme),
        _Stage.failed => _failed(theme),
      };

  Widget _waiting(ThemeData theme) {
    final ColorScheme cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Finish signing in on the page that opened, then come back here.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: Insets.lg),
        Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: Insets.md),
            Text('Waiting for Plex', style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: Insets.lg),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(_openBrowser()),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open the page again'),
        ),
        const SizedBox(height: Insets.sm),
        TextButton.icon(
          onPressed: _copyLink,
          icon: const Icon(Icons.link_rounded),
          label: const Text('Copy the sign-in link'),
        ),
        Text(
          'Paste it into any browser, on this phone or another device.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// The code is a long one (see [PlexAccountApi.createPin]), so plex.tv/link
  /// is no use as a fallback: it only takes the four character kind. The link
  /// carries the code itself and works anywhere.
  Future<void> _copyLink() async {
    final PlexPin? pin = _pin;
    if (pin == null) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: plexAuthUri(
          clientIdentifier: widget.clientIdentifier,
          code: pin.code,
        ).toString(),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in link copied')),
      );
    }
  }

  Widget _serverList(ThemeData theme) {
    final ColorScheme cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          _servers.isEmpty
              ? 'Signed in. No servers came back from your account.'
              : 'Signed in. Pick a server to fill in its address.',
          style: theme.textTheme.bodyMedium,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
          ),
        ],
        const SizedBox(height: Insets.sm),
        for (final PlexServer server in _servers)
          _ServerTile(
            server: server,
            checking: _checking == server.clientIdentifier,
            onTap: () => unawaited(_finish(server)),
          ),
        const SizedBox(height: Insets.sm),
        TextButton(
          onPressed: _checking != null ? null : () => unawaited(_finish(null)),
          child: const Text('Just use the token'),
        ),
      ],
    );
  }

  Widget _failed(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          _error ?? 'Signing in did not work.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.error),
        ),
        const SizedBox(height: Insets.lg),
        FilledButton(
          onPressed: () => unawaited(_start()),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    required this.checking,
    required this.onTap,
  });

  final PlexServer server;
  final bool checking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // What Plex advertises, which is not the same as what answers: the tap
    // probes before filling anything in.
    final PlexServerUrls urls = resolvePlexServerUrls(server);
    final bool hasRelay =
        server.connections.any((PlexConnection c) => c.relay);
    final List<String> notes = <String>[
      if (urls.localUrl != null) 'local',
      if (urls.externalUrl != null && !urls.usesRelay) 'remote',
      if (hasRelay) 'relay',
      if (!server.owned) 'shared with you',
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.dns_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(server.name),
      subtitle: Text(
        checking
            ? 'Checking which addresses answer'
            : (notes.isEmpty ? 'No usable address' : notes.join(' • ')),
        style: theme.textTheme.bodySmall,
      ),
      trailing: checking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: urls.localUrl == null && urls.externalUrl == null ? null : onTap,
    );
  }
}
