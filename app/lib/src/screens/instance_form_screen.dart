import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dartssh2/dartssh2.dart' show SSHClient;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_plex/service_plex.dart';
import 'package:service_seerr/service_seerr.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';

import '../connection_test/connection_test_result.dart';
import '../connection_test/connection_tester.dart';
import '../plex_client_identifier.dart';
import '../service_icon.dart';
import '../terminal/docker_shell.dart';
import '../terminal/ssh_connector.dart';
import '../terminal/ssh_host_status.dart';
import '../terminal/terminal_hub.dart';
import '../terminal/terminal_screen.dart';

const String speedtestConnectionSuccessMessage =
    'Connected with results:read. Run permission cannot be verified until used.';

String speedtestConnectionErrorMessage(SpeedtestTrackerException error) =>
    switch (error.kind) {
      SpeedtestErrorKind.authentication =>
        'The bearer token was rejected or lacks results:read.',
      SpeedtestErrorKind.permission =>
        'The API token does not have the required permission.',
      SpeedtestErrorKind.unsupported =>
        'Authenticated results require Speedtest Tracker 1.1 or newer.',
      SpeedtestErrorKind.offline => 'Could not reach Speedtest Tracker.',
      SpeedtestErrorKind.timeout =>
        'Speedtest Tracker took too long to respond.',
      SpeedtestErrorKind.server => 'Speedtest Tracker returned a server error.',
      SpeedtestErrorKind.malformed =>
        'Speedtest Tracker returned an unsupported response.',
      SpeedtestErrorKind.notFound =>
        'The requested Speedtest Tracker result was not found.',
      SpeedtestErrorKind.other =>
        'Speedtest Tracker returned an unexpected response.',
    };

/// Add / edit an instance. When [instanceId] is null this is an "add" form
/// for [initialKind], the service picked on the grid; otherwise it pre-fills
/// from the existing instance.
///
/// The auth fields shown depend on the selected [ServiceKind]'s auth style:
/// API-key and bearer-token services show one field; user/pass services show
/// two; Plex shows a token field.
class InstanceFormScreen extends ConsumerStatefulWidget {
  const InstanceFormScreen({
    this.instanceId,
    this.initialKind,
    super.key,
  });

  final String? instanceId;
  final ServiceKind? initialKind;

  @override
  ConsumerState<InstanceFormScreen> createState() => _InstanceFormScreenState();
}

class _InstanceFormScreenState extends ConsumerState<InstanceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _localUrl = TextEditingController();
  final TextEditingController _externalUrl = TextEditingController();
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _privateKey = TextEditingController();
  final TextEditingController _passphrase = TextEditingController();
  final TextEditingController _dockerContainer = TextEditingController();

  /// The Docker host this service's container runs on; empty = the first.
  String _dockerHostId = '';
  bool _loadingContainers = false;

  /// qBittorrent 5.2+ supports both username/password and API-key auth; this
  /// tracks which the user picked (qBit only).
  bool _qbitUseApiKey = false;

  /// Seerr takes either its API key, which acts as the owner, or one person's
  /// own account; this tracks which the user picked (Seerr only).
  bool _seerrSignIn = false;

  /// Which kind of account a Seerr sign-in uses.
  SeerrAccountKind _seerrAccount = SeerrAccountKind.local;
  bool _testingConnection = false;
  Map<String, ConnectionTestResult> _connectionResults =
      <String, ConnectionTestResult>{};
  final TextEditingController _pollingInterval =
      TextEditingController(text: '5');

  ServiceKind _kind = ServiceKind.sonarr;
  UrlMode _urlMode = UrlMode.auto;
  bool _allowSelfSigned = false;
  bool _loaded = false;

  /// Not edited here: an instance's own headers live under Settings. Held so
  /// that saving the form, and testing it, carry them rather than drop them.
  Map<String, String> _customHeaders = const <String, String>{};

  bool get _isEdit => widget.instanceId != null;

  bool get _isSsh => _kind == ServiceKind.dockerHost;

  @override
  void initState() {
    super.initState();
    if (widget.initialKind != null) {
      _kind = widget.initialKind!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _localUrl.dispose();
    _externalUrl.dispose();
    _apiKey.dispose();
    _username.dispose();
    _password.dispose();
    _privateKey.dispose();
    _passphrase.dispose();
    _dockerContainer.dispose();
    _pollingInterval.dispose();
    super.dispose();
  }

  void _hydrateFrom(Instance instance) {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _name.text = instance.name;
    _localUrl.text = instance.localUrl;
    _externalUrl.text = instance.externalUrl;
    _kind = instance.kind;
    _urlMode = instance.urlMode;
    _allowSelfSigned = instance.allowSelfSignedCerts;
    _pollingInterval.text = instance.pollingIntervalSeconds.toString();
    _customHeaders = instance.customHeaders;
    _dockerHostId = instance.dockerHostId;
    _dockerContainer.text = instance.dockerContainer;
    switch (instance.auth) {
      case InstanceAuthApiKey(:final String apiKey):
        _apiKey.text = apiKey;
      case InstanceAuthPlex(:final String token):
        _apiKey.text = token;
      case InstanceAuthUserPass(:final String username, :final String password):
        _username.text = username;
        _password.text = password;
      case InstanceAuthCookie(:final String username, :final String password):
        _username.text = username;
        _password.text = password;
      case InstanceAuthSsh(
          :final String username,
          :final String password,
          :final String privateKey,
          :final String passphrase,
        ):
        _username.text = username;
        _password.text = password;
        _privateKey.text = privateKey;
        _passphrase.text = passphrase;
    }
    // A qBittorrent instance saved with key auth reopens on the API-key tab.
    _qbitUseApiKey = instance.kind == ServiceKind.qbittorrent &&
        instance.auth is InstanceAuthApiKey;
    // A Seerr instance saved with an account reopens on the sign-in tab.
    if (instance.kind == ServiceKind.seerr) {
      final SeerrSignIn? signIn = SeerrSignIn.fromAuth(instance.auth);
      _seerrSignIn = signIn != null;
      _seerrAccount = signIn?.kind ?? SeerrAccountKind.local;
    }
  }

  InstanceAuth _buildAuth() {
    if (_kind == ServiceKind.seerr && _seerrSignIn) {
      return SeerrSignIn(
        kind: _seerrAccount,
        username: _username.text.trim(),
        password: _password.text,
      ).toAuth();
    }
    return switch (_kind.authStyle) {
      AuthStyle.apiKey => InstanceAuth.apiKey(apiKey: _apiKey.text.trim()),
      AuthStyle.bearerToken => InstanceAuth.apiKey(apiKey: _apiKey.text.trim()),
      AuthStyle.plexToken => InstanceAuth.plexToken(token: _apiKey.text.trim()),
      AuthStyle.userPass => InstanceAuth.userPass(
          username: _username.text.trim(),
          password: _password.text,
        ),
      AuthStyle.cookieLogin =>
        (_kind == ServiceKind.qbittorrent && _qbitUseApiKey)
            ? InstanceAuth.apiKey(apiKey: _apiKey.text.trim())
            : InstanceAuth.cookieLogin(
                username: _username.text.trim(),
                password: _password.text,
              ),
      AuthStyle.ssh => InstanceAuth.ssh(
          username: _username.text.trim(),
          password: _password.text,
          privateKey: _privateKey.text.trim(),
          passphrase: _passphrase.text,
        ),
      AuthStyle.none => const InstanceAuth.apiKey(apiKey: ''),
    };
  }

  Instance _buildInstance(String id) => Instance(
        id: id,
        name: _name.text.trim(),
        kind: _kind,
        localUrl: _localUrl.text.trim(),
        externalUrl: _externalUrl.text.trim(),
        urlMode: _urlMode,
        auth: _buildAuth(),
        allowSelfSignedCerts: _allowSelfSigned,
        pollingIntervalSeconds: int.tryParse(_pollingInterval.text.trim()) ?? 5,
        customHeaders: _customHeaders,
        dockerHostId: _isSsh ? '' : _dockerHostId,
        dockerContainer: _isSsh ? '' : _dockerContainer.text.trim(),
      );

  void _clearConnectionTest(String _) {
    setState(() {
      _connectionResults = <String, ConnectionTestResult>{};
    });
  }

  /// Swaps the service in place. What is typed so far stays, as it did with
  /// the old dropdown; only a connection result for the old service goes.
  Future<void> _changeService() async {
    final ServiceKind? picked = await showDialog<ServiceKind>(
      context: context,
      builder: (BuildContext context) => _ServiceKindDialog(current: _kind),
    );
    if (picked == null || picked == _kind || !mounted) {
      return;
    }
    setState(() {
      _kind = picked;
      _connectionResults = <String, ConnectionTestResult>{};
    });
  }

  /// Fills the token, and the URLs too when the user picks a server.
  ///
  /// Anything the sheet did not find is left alone rather than blanked: a
  /// server with no remote connection should not wipe an external URL the
  /// user typed themselves.
  Future<void> _signInWithPlex() async {
    final PlexSignInResult? result = await showPlexSignInSheet(
      context: context,
      clientIdentifier: ref.read(plexClientIdentifierProvider),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _apiKey.text = result.token;
      final String? local = result.localUrl;
      if (local != null && local.isNotEmpty) {
        _localUrl.text = local;
      }
      final String? external = result.externalUrl;
      if (external != null && external.isNotEmpty) {
        _externalUrl.text = external;
      }
      final String? serverName = result.serverName;
      if (_name.text.trim().isEmpty &&
          serverName != null &&
          serverName.isNotEmpty) {
        _name.text = serverName;
      }
      _connectionResults = <String, ConnectionTestResult>{};
    });
    final String? note = _plexFillNote(result);
    if (note != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
    }
  }

  /// Says what the sign-in could not work out, so an empty field is never a
  /// mystery.
  static String? _plexFillNote(PlexSignInResult result) {
    final bool noLocal = result.localUrl == null || result.localUrl!.isEmpty;
    final bool noExternal =
        result.externalUrl == null || result.externalUrl!.isEmpty;
    if (noLocal && noExternal) {
      return 'None of the addresses Plex advertises for that server answered, '
          'so both URLs are yours to fill in.';
    }
    if (result.externalUnverified) {
      return 'The external URL is the one Plex advertises. It could not be '
          'checked from this network, since a router will not usually turn a '
          'connection back on itself.';
    }
    if (result.usesRelay) {
      return 'Nothing answered on that server\'s public address, so the '
          'external URL is a Plex Relay one. It works, but Plex caps it at '
          '1 Mbps.';
    }
    if (noLocal) {
      // Almost always a server in a Docker bridge network, which can only
      // advertise its address on that bridge.
      return 'Nothing Plex advertises on the local network answered, so the '
          'local URL is yours to fill in. Servers in Docker usually only '
          'advertise their container address.';
    }
    return null;
  }

  IconData _connectionOutcomeIcon(ConnectionOutcome outcome) =>
      switch (outcome) {
        ConnectionOutcome.connected => Icons.check_circle_outline,
        ConnectionOutcome.authFailed => Icons.warning_amber_outlined,
        ConnectionOutcome.unreachable => Icons.error_outline,
      };

  Color _connectionOutcomeColor(
    BuildContext context,
    ConnectionOutcome outcome,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return switch (outcome) {
      ConnectionOutcome.connected => scheme.primary,
      ConnectionOutcome.authFailed => scheme.tertiary,
      ConnectionOutcome.unreachable => scheme.error,
    };
  }

  bool get _warnAboutExternalHttp {
    if (_kind != ServiceKind.speedtestTracker) {
      return false;
    }
    final Uri? uri = Uri.tryParse(_externalUrl.text.trim());
    return uri != null && uri.scheme.toLowerCase() == 'http';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final ProfileListController controller =
        ref.read(profileListProvider.notifier);
    Profile? profile = ref.read(activeProfileProvider);
    profile ??= await controller.createProfile('Default');
    // After creating, make it active.
    await ref.read(activeProfileIdProvider.notifier).select(profile.id);

    final String id = widget.instanceId ??
        ref.read(profileRepositoryProvider).newInstanceId();
    final Instance instance = _buildInstance(id);
    final Instance? before =
        _isEdit ? ref.read(instanceByIdProvider(widget.instanceId!)) : null;
    if (_isSsh && before != null && !_sameSshLogin(before, instance)) {
      // The last login was made with the old details; forget it so a host
      // that refused a wrong password is not still amber after the fix.
      await ref.read(sshLoginRecordsProvider.notifier).clear(id);
    }
    await controller.upsertInstance(profile.id, instance);
    if (mounted) {
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.goNamed(AtriumRoutes.dashboardName);
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _testingConnection = true;
      _connectionResults = <String, ConnectionTestResult>{};
    });
    final Instance candidate = _buildInstance(
      widget.instanceId ?? 'connection-test',
    );
    final ConnectionTester tester = ref.read(connectionTesterProvider);
    final Future<ConnectionTestResult> Function(UrlMode) testOne = _isSsh
        ? (UrlMode url) => _testSsh(candidate.copyWith(urlMode: url))
        : (UrlMode url) => tester.test(candidate: candidate, url: url);
    final Map<String, ConnectionTestResult> results =
        <String, ConnectionTestResult>{};
    try {
      if (_localUrl.text.trim().isNotEmpty) {
        results['Local'] = await testOne(UrlMode.forceLocal);
      }
      if (_externalUrl.text.trim().isNotEmpty) {
        results['External'] = await testOne(UrlMode.forceExternal);
      }
    } finally {
      if (mounted) {
        // Results belong to the form as it was tested. Anything edited since
        // has already cleared them, and putting them back would offer an old
        // address over the one now typed.
        final bool unchanged = _buildInstance(
              widget.instanceId ?? 'connection-test',
            ) ==
            candidate;
        setState(() {
          _testingConnection = false;
          _connectionResults =
              unchanged ? results : <String, ConnectionTestResult>{};
        });
      }
    }
  }

  /// Puts the address the test found into the field it was testing, and tests
  /// again so the result shows it working.
  void _useSuggestedUrl(String which, String url) {
    (which == 'External' ? _externalUrl : _localUrl).text = url;
    _testConnection();
  }

  Future<void> _delete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete ${_name.text.isEmpty ? "service" : _name.text}?'),
        content: const Text(
          'This will permanently remove this instance and its connection credentials.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final Profile? profile = ref.read(activeProfileProvider);
    if (profile == null || widget.instanceId == null) {
      return;
    }
    await ref
        .read(profileListProvider.notifier)
        .deleteInstance(profile.id, widget.instanceId!);
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      final Instance? existing =
          ref.watch(instanceByIdProvider(widget.instanceId!));
      if (existing != null) {
        _hydrateFrom(existing);
      }
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent = ServiceVisuals.accent(_kind);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit service' : 'Add service'),
        actions: <Widget>[
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: Insets.page,
          children: <Widget>[
            // Service Hero / Header Card
            Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Semantics(
                button: true,
                label: 'Change service',
                child: InkWell(
                  key: const Key('service_header'),
                  onTap: _changeService,
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(Insets.xs),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          child: Center(
                            child: ServiceIcon(kind: _kind, size: 36),
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      _kind.displayName,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_kind.isBeta) ...<Widget>[
                                    const SizedBox(width: Insets.xs),
                                    const BetaBadge(),
                                  ],
                                ],
                              ),
                              const SizedBox(height: Insets.xxs),
                              Text(
                                _kind.tagline,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Icon(Icons.swap_horiz, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),

            // General Information Card
            _FormSectionCard(
              title: 'General',
              icon: Icons.badge_outlined,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Name',
                    hintText: 'e.g. Home ${_kind.displayName}',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (String? v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),

            // Connection Card
            _FormSectionCard(
              title: 'Connection',
              icon: Icons.lan_outlined,
              children: <Widget>[
                TextFormField(
                  controller: _localUrl,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: _isSsh ? 'Local address' : 'Local URL',
                    hintText: _isSsh
                        ? 'ssh://192.168.1.10:22'
                        : _kind.defaultPort == null
                            ? 'http://192.168.1.10'
                            : 'http://192.168.1.10:${_kind.defaultPort}',
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: _clearConnectionTest,
                  validator: _validateUrlsTogether,
                ),
                const SizedBox(height: Insets.md),
                TextFormField(
                  controller: _externalUrl,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: _isSsh ? 'External address' : 'External URL',
                    hintText: _isSsh
                        ? 'ssh://home.example.com:2222'
                        : _kind == ServiceKind.speedtestTracker
                            ? 'https://speedtest.example.com'
                            : 'https://sonarr.example.com',
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: _clearConnectionTest,
                  validator: _validateUrlsTogether,
                ),
                if (_warnAboutExternalHttp) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Container(
                    padding: const EdgeInsets.all(Insets.sm),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: cs.error,
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text(
                            'An external or Tailscale HTTP URL does not protect the '
                            'bearer token with TLS. Use HTTPS when possible.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Insets.md),
                DropdownMenu<UrlMode>(
                  initialSelection: _urlMode,
                  label: const Text('URL selection'),
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: const <DropdownMenuEntry<UrlMode>>[
                    DropdownMenuEntry<UrlMode>(
                      value: UrlMode.auto,
                      label: 'Auto (probe local, fall back to external)',
                    ),
                    DropdownMenuEntry<UrlMode>(
                      value: UrlMode.forceLocal,
                      label: 'Always local',
                    ),
                    DropdownMenuEntry<UrlMode>(
                      value: UrlMode.forceExternal,
                      label: 'Always external',
                    ),
                  ],
                  onSelected: (UrlMode? m) => setState(() {
                    _urlMode = m ?? _urlMode;
                    _connectionResults = <String, ConnectionTestResult>{};
                  }),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),

            // Authentication Card
            _FormSectionCard(
              title: 'Authentication',
              icon: Icons.lock_outline,
              children: _authFields(),
            ),
            const SizedBox(height: Insets.lg),

            if (_containerSection() case final Widget section) ...<Widget>[
              section,
              const SizedBox(height: Insets.lg),
            ],

            // Preferences Card (nothing applies to an SSH host)
            if (!_isSsh) ...<Widget>[
              _FormSectionCard(
                title: 'Preferences',
                icon: Icons.tune_outlined,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow self-signed certificates'),
                    subtitle: const Text(
                      'Skip TLS validation for this instance only.',
                    ),
                    value: _allowSelfSigned,
                    onChanged: (bool v) => setState(() {
                      _allowSelfSigned = v;
                      _connectionResults = <String, ConnectionTestResult>{};
                    }),
                  ),
                  if (_kind == ServiceKind.glances ||
                      _kind == ServiceKind.dashdot ||
                      _kind == ServiceKind.gluetun ||
                      _kind == ServiceKind.qbittorrent ||
                      _kind == ServiceKind.slskd ||
                      _kind == ServiceKind.gotify) ...<Widget>[
                    const SizedBox(height: Insets.md),
                    TextFormField(
                      controller: _pollingInterval,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Polling Interval (seconds)',
                        hintText: '5',
                        suffixText: 'sec',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (String? v) {
                        final int? val = int.tryParse(v?.trim() ?? '');
                        if (val == null || val < 1) {
                          return 'Must be at least 1 second';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Insets.lg),
            ],

            // Connection Test Card
            _FormSectionCard(
              title: 'Diagnostics',
              icon: Icons.cable_outlined,
              subtitle: 'Verify connectivity before saving.',
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: _testingConnection
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: ExpressiveProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_outlined),
                  label: Text(
                    _testingConnection ? 'Testing...' : 'Test connection',
                  ),
                ),
                for (final MapEntry<String, ConnectionTestResult> entry
                    in _connectionResults.entries) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Container(
                    padding: const EdgeInsets.all(Insets.sm),
                    decoration: BoxDecoration(
                      color: _connectionOutcomeColor(context, entry.value.outcome)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(
                        color: _connectionOutcomeColor(context, entry.value.outcome)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          _connectionOutcomeIcon(entry.value.outcome),
                          size: 18,
                          color: _connectionOutcomeColor(
                            context,
                            entry.value.outcome,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${entry.key}: ${entry.value.message}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (entry.value.suggestedUrl
                                  case final String suggested)
                                TextButton(
                                  onPressed: _testingConnection
                                      ? null
                                      : () => _useSuggestedUrl(
                                            entry.key,
                                            suggested,
                                          ),
                                  child: const Text('Use this address'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Insets.xl),

            // Save / Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  _isEdit ? 'Save changes' : 'Add service',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: Insets.xl),
          ],
        ),
      ),
    );
  }

  /// Seerr's API key, or a person's own Seerr, Jellyfin or Emby account so
  /// friends and family get only what their Seerr permissions allow.
  List<Widget> _seerrAuthFields() {
    final bool local = _seerrAccount == SeerrAccountKind.local;
    return <Widget>[
      SegmentedButton<bool>(
        segments: const <ButtonSegment<bool>>[
          ButtonSegment<bool>(
            value: false,
            label: Text('API key'),
            icon: Icon(Icons.key),
          ),
          ButtonSegment<bool>(
            value: true,
            label: Text('Sign in'),
            icon: Icon(Icons.person_outline),
          ),
        ],
        selected: <bool>{_seerrSignIn},
        onSelectionChanged: (Set<bool> s) => setState(() {
          _seerrSignIn = s.first;
          _connectionResults = <String, ConnectionTestResult>{};
        }),
      ),
      const SizedBox(height: Insets.md),
      if (!_seerrSignIn)
        TextFormField(
          controller: _apiKey,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'API key',
            helperText: 'Settings, General in Seerr. Acts as the Seerr owner.',
          ),
          autocorrect: false,
          onChanged: _clearConnectionTest,
          validator: (String? v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        )
      else ...<Widget>[
        SegmentedButton<SeerrAccountKind>(
          segments: const <ButtonSegment<SeerrAccountKind>>[
            ButtonSegment<SeerrAccountKind>(
              value: SeerrAccountKind.local,
              label: Text('Seerr account'),
            ),
            ButtonSegment<SeerrAccountKind>(
              value: SeerrAccountKind.mediaServer,
              label: Text('Jellyfin or Emby'),
            ),
          ],
          selected: <SeerrAccountKind>{_seerrAccount},
          onSelectionChanged: (Set<SeerrAccountKind> s) => setState(() {
            _seerrAccount = s.first;
            _connectionResults = <String, ConnectionTestResult>{};
          }),
        ),
        const SizedBox(height: Insets.md),
        TextFormField(
          controller: _username,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: local ? 'Email' : 'Username',
          ),
          keyboardType:
              local ? TextInputType.emailAddress : TextInputType.text,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          onChanged: _clearConnectionTest,
          validator: (String? v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: Insets.md),
        TextFormField(
          controller: _password,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            // A Jellyfin or Emby account may have no password.
            labelText: local ? 'Password' : 'Password (Optional)',
            helperText:
                'What this account may do follows its permissions in Seerr.',
            helperMaxLines: 2,
          ),
          obscureText: true,
          onChanged: _clearConnectionTest,
          validator: local
              ? (String? v) => (v == null || v.isEmpty) ? 'Required' : null
              : (String? v) => null,
        ),
      ],
    ];
  }

  List<Widget> _authFields() {
    switch (_kind.authStyle) {
      case AuthStyle.apiKey:
        if (_kind == ServiceKind.seerr) {
          return _seerrAuthFields();
        }
        if (_kind == ServiceKind.myspeed) {
          return <Widget>[
            TextFormField(
              controller: _apiKey,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Password (optional)',
                helperText:
                    'Leave empty if password protection is disabled on your MySpeed instance.',
              ),
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: _clearConnectionTest,
              validator: (String? v) => null,
            ),
          ];
        }
        // aria2's credential is its `--rpc-secret`, which the daemon reads
        // from the first parameter of every RPC call rather than from a
        // header - so the field says so. It is optional: a daemon started
        // without a secret answers anyone, and demanding one would lock the
        // user out of a perfectly reachable server.
        if (_kind == ServiceKind.aria2) {
          return <Widget>[
            TextFormField(
              controller: _apiKey,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'RPC secret (optional)',
                helperText: 'aria2\'s --rpc-secret, sent as the first '
                    'parameter of every RPC call. Leave empty if the daemon '
                    'has no secret.',
              ),
              autocorrect: false,
              enableSuggestions: false,
              onChanged: _clearConnectionTest,
              validator: (String? v) => null,
            ),
          ];
        }
        if (_kind == ServiceKind.gotify) {
          return <Widget>[
            TextFormField(
              controller: _apiKey,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Client token',
                helperText: 'Create one under Clients in Gotify. An app '
                    'token can only send messages, not read them.',
                helperMaxLines: 2,
              ),
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: _clearConnectionTest,
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ];
        }
        // Gluetun's control server and slskd can run without auth, through a role with
        // auth = "none" or SLSKD_NO_AUTH=true, and then there is no key to give.
        final bool keyOptional =
            _kind == ServiceKind.gluetun || _kind == ServiceKind.slskd;
        return <Widget>[
          TextFormField(
            controller: _apiKey,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: keyOptional ? 'API key (optional)' : 'API key',
              helperText: keyOptional
                  ? (_kind == ServiceKind.slskd
                      ? 'Leave empty if authentication is disabled in slskd.'
                      : 'Leave empty if the control server has auth turned off.')
                  : null,
            ),
            autocorrect: false,
            onChanged: _clearConnectionTest,
            validator: (String? v) =>
                !keyOptional && (v == null || v.trim().isEmpty)
                    ? 'Required'
                    : null,
          ),
        ];
      case AuthStyle.bearerToken:
        return <Widget>[
          TextFormField(
            controller: _apiKey,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Bearer API token',
              helperText: 'Requires results:read; speedtests:run is optional.',
            ),
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: _clearConnectionTest,
            validator: (String? v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ];
      case AuthStyle.plexToken:
        return <Widget>[
          OutlinedButton.icon(
            onPressed: _signInWithPlex,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign in with Plex'),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _apiKey,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Plex token (X-Plex-Token)',
            ),
            autocorrect: false,
            onChanged: _clearConnectionTest,
            validator: (String? v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ];
      case AuthStyle.userPass:
      case AuthStyle.cookieLogin:
        // Transmission's RPC auth is optional and off in a default install,
        // and an AdGuard Home set up without a user answers anyone, so
        // *neither* field may be required there - demanding credentials would
        // lock users out of a perfectly reachable server.
        final bool authOptional = _kind == ServiceKind.transmission ||
            _kind == ServiceKind.rtorrent ||
            _kind == ServiceKind.adguardHome;
        // Emby/Jellyfin accounts may legitimately have no password; every other
        // username/password service (e.g. qBittorrent) requires one, where an
        // empty submission guarantees a failed login.
        final bool passwordOptional = authOptional ||
            _kind == ServiceKind.emby ||
            _kind == ServiceKind.jellyfin;
        final Widget passwordField = TextFormField(
          controller: _password,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: passwordOptional ? 'Password (Optional)' : 'Password',
          ),
          obscureText: true,
          validator: passwordOptional
              ? (String? v) => null
              : (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
        final List<Widget> userPass = <Widget>[
          TextFormField(
            controller: _username,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: authOptional ? 'Username (Optional)' : 'Username',
            ),
            autocorrect: false,
            textInputAction: TextInputAction.next,
            validator: authOptional
                ? (String? v) => null
                : (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: Insets.md),
          passwordField,
        ];

        // Deluge's Web UI has no username at all - only a password - so a
        // username field here would be a dead input that fails validation.
        if (_kind == ServiceKind.deluge) {
          return <Widget>[passwordField];
        }
        if (_kind != ServiceKind.qbittorrent) {
          return userPass;
        }
        // qBittorrent 5.2+ accepts either username/password or a stateless
        // API key, so offer both.
        return <Widget>[
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: false,
                label: Text('Password'),
                icon: Icon(Icons.password),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('API key'),
                icon: Icon(Icons.key),
              ),
            ],
            selected: <bool>{_qbitUseApiKey},
            onSelectionChanged: (Set<bool> s) =>
                setState(() => _qbitUseApiKey = s.first),
          ),
          const SizedBox(height: Insets.md),
          if (_qbitUseApiKey)
            TextFormField(
              controller: _apiKey,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'API key',
                helperText: 'qBittorrent 5.2+ Web UI setting; '
                    'sent as Authorization: Bearer',
              ),
              autocorrect: false,
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            )
          else
            ...userPass,
        ];
      case AuthStyle.ssh:
        return _sshAuthFields();
      case AuthStyle.none:
        return <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xs),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'No authentication credentials are required for ${_kind.displayName}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }

  List<Widget> _sshAuthFields() {
    const TextStyle mono = TextStyle(fontFamily: 'JetBrainsMono Nerd Font');
    return <Widget>[
      TextFormField(
        controller: _username,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Username',
        ),
        autocorrect: false,
        textInputAction: TextInputAction.next,
        onChanged: _clearConnectionTest,
        validator: (String? v) =>
            (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: Insets.md),
      TextFormField(
        controller: _password,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Password (optional with a key)',
        ),
        obscureText: true,
        onChanged: _clearConnectionTest,
        validator: (String? v) =>
            (v ?? '').isEmpty && _privateKey.text.trim().isEmpty
                ? 'Enter a password or a private key'
                : null,
      ),
      const SizedBox(height: Insets.md),
      TextFormField(
        controller: _privateKey,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: 'Private key (optional)',
          hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
          helperText: 'Paste an OpenSSH / PEM key. Stored in the keystore.',
          alignLabelWithHint: true,
          suffixIcon: IconButton(
            tooltip: 'Load key file',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: _loadKeyFile,
          ),
        ),
        style: mono.copyWith(fontSize: 12),
        minLines: 2,
        maxLines: 5,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.multiline,
        onChanged: _clearConnectionTest,
        validator: (String? v) {
          final String key = (v ?? '').trim();
          if (key.isNotEmpty && !key.contains('PRIVATE KEY')) {
            return 'Not a private key (expected a BEGIN ... PRIVATE KEY block)';
          }
          return null;
        },
      ),
      const SizedBox(height: Insets.md),
      TextFormField(
        controller: _passphrase,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Key passphrase (optional)',
        ),
        obscureText: true,
        onChanged: _clearConnectionTest,
      ),
    ];
  }

  Future<void> _loadKeyFile() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(dialogTitle: 'Private key');
    } on PlatformException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open file picker: ${e.message}')),
      );
      return;
    }
    final PlatformFile? file =
        picked == null || picked.files.isEmpty ? null : picked.files.single;
    if (file == null) {
      return;
    }
    String text;
    try {
      text = utf8.decode(await file.readAsBytes(), allowMalformed: true).trim();
    } on Object {
      text = '';
    }
    if (!text.contains('PRIVATE KEY')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That file is not a private key.')),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _privateKey.text = text;
        _connectionResults = <String, ConnectionTestResult>{};
      });
    }
  }

  /// Logs in over SSH for real, so a wrong password or key shows up here.
  Future<ConnectionTestResult> _testSsh(Instance forced) async {
    try {
      final ({SSHClient client, SshEndpoint endpoint}) result = await connectSsh(
        forced,
        knownHosts: ref.read(terminalHubProvider).knownHosts,
        onHostKey: (HostKeyPrompt p) =>
            mounted ? confirmHostKey(context, p) : Future<bool>.value(false),
      );
      result.client.close();
      _recordTestLogin(forced, null);
      return const ConnectionTestResult(
        ConnectionOutcome.connected,
        'Connected and logged in',
      );
    } on SshConnectException catch (e) {
      if (e.authFailed) {
        _recordTestLogin(forced, e.message);
      }
      return ConnectionTestResult(
        e.authFailed
            ? ConnectionOutcome.authFailed
            : ConnectionOutcome.unreachable,
        e.message,
      );
    }
  }

  /// A test login counts towards the saved host's status only when it used
  /// the saved address and login - not unsaved edits still on the form.
  void _recordTestLogin(Instance tested, String? refusal) {
    final String? id = widget.instanceId;
    final Instance? saved = id == null ? null : ref.read(instanceByIdProvider(id));
    if (id == null || saved == null || !_sameSshLogin(saved, tested)) {
      return;
    }
    final InstanceAuth auth = tested.auth;
    ref.read(sshLoginRecordsProvider.notifier).record(
          id,
          SshLoginRecord(
            ok: refusal == null,
            at: DateTime.now(),
            username: auth is InstanceAuthSsh ? auth.username : '',
            message: refusal,
          ),
        );
  }

  static bool _sameSshLogin(Instance a, Instance b) =>
      a.localUrl == b.localUrl &&
      a.externalUrl == b.externalUrl &&
      a.auth == b.auth;

  List<Instance> get _dockerHosts => ref
      .watch(activeInstancesProvider)
      .where((Instance i) => i.kind == ServiceKind.dockerHost)
      .toList();

  Instance? get _selectedDockerHost {
    final List<Instance> hosts = _dockerHosts;
    for (final Instance h in hosts) {
      if (h.id == _dockerHostId) return h;
    }
    return hosts.isEmpty ? null : hosts.first;
  }

  /// Which container this service runs in, for the in-container shell.
  /// Only shown once the profile has a Docker host.
  Widget? _containerSection() {
    if (_isSsh) {
      return null;
    }
    final List<Instance> hosts = _dockerHosts;
    if (hosts.isEmpty) {
      return null;
    }
    final Instance host = _selectedDockerHost!;
    final Instance? saved = _isEdit
        ? ref.watch(instanceByIdProvider(widget.instanceId!))
        : null;
    return _FormSectionCard(
      title: 'Container shell',
      icon: Icons.terminal_rounded,
      subtitle: 'Open a shell inside this service\'s Docker container, over '
          'the Docker host\'s SSH connection.',
      children: <Widget>[
        if (hosts.length > 1) ...<Widget>[
          DropdownMenu<String>(
            initialSelection: host.id,
            label: const Text('Docker host'),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: <DropdownMenuEntry<String>>[
              for (final Instance h in hosts)
                DropdownMenuEntry<String>(value: h.id, label: h.name),
            ],
            onSelected: (String? id) =>
                setState(() => _dockerHostId = id ?? _dockerHostId),
          ),
          const SizedBox(height: Insets.md),
        ],
        TextFormField(
          controller: _dockerContainer,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Container name',
            hintText: _kind.name.toLowerCase(),
            helperText: 'Leave empty to turn the container shell off.',
            suffixIcon: _loadingContainers
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Pick a running container',
                    icon: const Icon(Icons.manage_search_rounded),
                    onPressed: () => _pickContainer(host),
                  ),
          ),
          autocorrect: false,
          enableSuggestions: false,
        ),
        _DockerIssueNote(hostId: host.id),
        if (saved != null && saved.dockerContainer.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.md),
          OutlinedButton.icon(
            onPressed: () => openServiceShell(context, ref, saved),
            icon: const Icon(Icons.terminal_rounded),
            label: const Text('Open shell'),
          ),
        ],
      ],
    );
  }

  /// Lists the host's running containers over the shared SSH connection,
  /// likely matches for this service first.
  Future<void> _pickContainer(Instance host) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _loadingContainers = true);
    List<DockerContainer> containers;
    try {
      final List<DockerContainer> all =
          await ref.read(terminalHubProvider).session(host.id).fetchContainers(
                host,
                (HostKeyPrompt p) => mounted
                    ? confirmHostKey(context, p)
                    : Future<bool>.value(false),
              );
      containers = rankContainersFor(_kind, all);
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not list containers: $e')),
      );
      return;
    } finally {
      if (mounted) setState(() => _loadingContainers = false);
    }
    if (!mounted) return;
    if (containers.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('No running containers on ${host.name}.')),
      );
      return;
    }
    final DockerContainer? picked = await showModalBottomSheet<DockerContainer>(
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
              for (final DockerContainer c in containers)
                ListTile(
                  leading: Icon(
                    containerMatchesKind(c, _kind)
                        ? Icons.star_rounded
                        : Icons.inventory_2_outlined,
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    c.status.isEmpty ? c.image : '${c.image} - ${c.status}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(sheetContext, c),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _dockerContainer.text = picked.name);
    }
  }

  /// At least one of local / external must be a valid URL, and any entered URL must be valid.
  String? _validateUrlsTogether(String? value) {
    final bool localOk = _isValidUrl(_localUrl.text);
    final bool externalOk = _isValidUrl(_externalUrl.text);
    if (!localOk && !externalOk) {
      return _isSsh
          ? 'Enter at least one SSH address (local or external)'
          : 'Enter at least one valid URL (local or external)';
    }
    if (value != null && value.trim().isNotEmpty && !_isValidUrl(value)) {
      return _isSsh ? 'Enter host, host:port or ssh://host:port' : 'Enter a valid URL';
    }
    return null;
  }

  bool _isValidUrl(String raw) {
    if (raw.trim().isEmpty) {
      return false;
    }
    if (_isSsh) {
      return SshEndpoint.tryParse(raw) != null;
    }
    final Uri? uri = Uri.tryParse(raw.trim());
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}

/// The last Docker problem seen on the host, if any. It lives here rather
/// than on the host's status dot because the server itself is reachable.
class _DockerIssueNote extends ConsumerWidget {
  const _DockerIssueNote({required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HostSession session = ref.watch(terminalHubProvider).session(hostId);
    return ListenableBuilder(
      listenable: session,
      builder: (BuildContext context, Widget? _) {
        final String? issue = session.dockerIssue;
        if (issue == null) {
          return const SizedBox.shrink();
        }
        final ColorScheme cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: Insets.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  issue,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.error),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: Insets.xxs),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: Insets.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// The services by category in a dialog, with the current one ticked and
/// scrolled into view.
class _ServiceKindDialog extends StatefulWidget {
  const _ServiceKindDialog({required this.current});

  final ServiceKind current;

  @override
  State<_ServiceKindDialog> createState() => _ServiceKindDialogState();
}

class _ServiceKindDialogState extends State<_ServiceKindDialog> {
  final GlobalKey _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? current = _currentKey.currentContext;
      if (current != null) {
        Scrollable.ensureVisible(current, alignment: 0.4);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      // Narrower margins than the default leave room for long names at
      // large text sizes.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                Insets.sm,
              ),
              child: Text('Change service', style: theme.textTheme.titleLarge),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            // Every row is built up front so the current one can be scrolled
            // to, however far down it is.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final ServiceRole role in ServiceRole.values)
                      ..._section(context, role),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(Insets.sm),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(BuildContext context, ServiceRole role) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final List<ServiceKind> kinds = ServiceKind.sortedValues
        .where((ServiceKind k) => k.role == role)
        .toList(growable: false);
    if (kinds.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.md,
          Insets.lg,
          Insets.xs,
        ),
        child: Text(
          ServiceVisuals.roleLabel(role),
          style: theme.textTheme.labelLarge?.copyWith(color: cs.primary),
        ),
      ),
      for (final ServiceKind kind in kinds)
        ListTile(
          key: kind == widget.current
              ? _currentKey
              : ValueKey<String>('service_option_${kind.name}'),
          selected: kind == widget.current,
          selectedTileColor: cs.secondaryContainer.withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ServiceVisuals.accent(kind).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            alignment: Alignment.center,
            child: ServiceIcon(kind: kind, size: 24),
          ),
          title: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  kind.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (kind.isBeta) ...<Widget>[
                const SizedBox(width: Insets.sm),
                const BetaBadge(),
              ],
            ],
          ),
          subtitle: Text(
            kind.tagline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: kind == widget.current
              ? Icon(Icons.check, color: cs.primary)
              : null,
          onTap: () => Navigator.of(context).pop(kind),
        ),
    ];
  }
}
