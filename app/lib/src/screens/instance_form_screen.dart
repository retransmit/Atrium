import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';

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

/// Add / edit an instance. When [instanceId] is null this is an "add" form;
/// otherwise it pre-fills from the existing instance.
///
/// The auth fields shown depend on the selected [ServiceKind]'s auth style:
/// API-key and bearer-token services show one field; user/pass services show
/// two; Plex shows a token field.
class InstanceFormScreen extends ConsumerStatefulWidget {
  const InstanceFormScreen({this.instanceId, super.key});

  final String? instanceId;

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

  /// qBittorrent 5.2+ supports both username/password and API-key auth; this
  /// tracks which the user picked (qBit only).
  bool _qbitUseApiKey = false;
  bool _testingConnection = false;
  bool _connectionTestFailed = false;
  String? _connectionTestMessage;
  final TextEditingController _pollingInterval =
      TextEditingController(text: '5');

  ServiceKind _kind = ServiceKind.sonarr;
  UrlMode _urlMode = UrlMode.auto;
  bool _allowSelfSigned = false;
  bool _loaded = false;

  bool get _isEdit => widget.instanceId != null;

  @override
  void dispose() {
    _name.dispose();
    _localUrl.dispose();
    _externalUrl.dispose();
    _apiKey.dispose();
    _username.dispose();
    _password.dispose();
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
    }
    // A qBittorrent instance saved with key auth reopens on the API-key tab.
    _qbitUseApiKey = instance.kind == ServiceKind.qbittorrent &&
        instance.auth is InstanceAuthApiKey;
  }

  InstanceAuth _buildAuth() {
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
      );

  void _clearConnectionTest(String _) {
    setState(() {
      _connectionTestMessage = null;
      _connectionTestFailed = false;
    });
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
    await controller.upsertInstance(profile.id, instance);
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _testSpeedtestConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _testingConnection = true;
      _connectionTestFailed = false;
      _connectionTestMessage = null;
    });
    final Instance candidate = _buildInstance(
      widget.instanceId ?? 'speedtest-connection-test',
    );
    Dio? dio;
    try {
      dio = await ref.read(dioFactoryProvider).create(
            candidate,
            globalHeaders: ref.read(globalHeadersProvider),
          );
      final SpeedtestTrackerApi api = SpeedtestTrackerApi(dio);
      await api.checkHealth();
      await api.listResults(pageSize: 1);
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionTestMessage = speedtestConnectionSuccessMessage;
      });
    } on SpeedtestTrackerException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionTestFailed = true;
        _connectionTestMessage = speedtestConnectionErrorMessage(error);
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionTestFailed = true;
        _connectionTestMessage =
            'Could not test the Speedtest Tracker connection.';
      });
    } finally {
      dio?.close(force: true);
      if (mounted) {
        setState(() => _testingConnection = false);
      }
    }
  }

  Future<void> _delete() async {
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
            DropdownMenu<ServiceKind>(
              initialSelection: _kind,
              label: const Text('Service'),
              expandedInsets: EdgeInsets.zero,
              leadingIcon: UnconstrainedBox(
                child: _buildServiceIcon(_kind, size: 24),
              ),
              dropdownMenuEntries: <DropdownMenuEntry<ServiceKind>>[
                for (final ServiceKind k in ServiceKind.values)
                  DropdownMenuEntry<ServiceKind>(
                    value: k,
                    label: '${k.displayName} - ${k.tagline}',
                    leadingIcon: _buildServiceIcon(k),
                  ),
              ],
              onSelected: (ServiceKind? k) => setState(() {
                _kind = k ?? _kind;
                _connectionTestMessage = null;
              }),
            ),
            const SizedBox(height: Insets.md),
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
            const SizedBox(height: Insets.lg),
            Text(
              'Connection',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Insets.sm),
            TextFormField(
              controller: _localUrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Local URL',
                hintText: _kind.defaultPort == null
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
                labelText: 'External URL',
                hintText: _kind == ServiceKind.speedtestTracker
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: Insets.sm),
                  const Expanded(
                    child: Text(
                      'An external or Tailscale HTTP URL does not protect the '
                      'bearer token with TLS. Use HTTPS when possible.',
                    ),
                  ),
                ],
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
                _connectionTestMessage = null;
              }),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              'Authentication',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Insets.sm),
            ..._authFields(),
            const SizedBox(height: Insets.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow self-signed certificates'),
              subtitle: const Text(
                'Skip TLS validation for this instance only.',
              ),
              value: _allowSelfSigned,
              onChanged: (bool v) => setState(() {
                _allowSelfSigned = v;
                _connectionTestMessage = null;
              }),
            ),
            if (_kind == ServiceKind.speedtestTracker) ...<Widget>[
              const SizedBox(height: Insets.sm),
              OutlinedButton.icon(
                onPressed: _testingConnection ? null : _testSpeedtestConnection,
                icon: _testingConnection
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cable_outlined),
                label: Text(
                  _testingConnection ? 'Testing...' : 'Test connection',
                ),
              ),
              if (_connectionTestMessage != null) ...<Widget>[
                const SizedBox(height: Insets.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _connectionTestFailed
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 18,
                      color: _connectionTestFailed
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(child: Text(_connectionTestMessage!)),
                  ],
                ),
              ],
            ],
            if (_kind == ServiceKind.glances) ...<Widget>[
              const SizedBox(height: Insets.lg),
              Text(
                'Polling',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: Insets.sm),
              TextFormField(
                controller: _pollingInterval,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Polling Interval (seconds)',
                  hintText: '5',
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
            const SizedBox(height: Insets.xl),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEdit ? 'Save changes' : 'Add service'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _authFields() {
    switch (_kind.authStyle) {
      case AuthStyle.apiKey:
        return <Widget>[
          TextFormField(
            controller: _apiKey,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'API key',
            ),
            autocorrect: false,
            validator: (String? v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
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
          TextFormField(
            controller: _apiKey,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Plex token (X-Plex-Token)',
            ),
            autocorrect: false,
            validator: (String? v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ];
      case AuthStyle.userPass:
      case AuthStyle.cookieLogin:
        // Emby/Jellyfin accounts may legitimately have no password; every other
        // username/password service (e.g. qBittorrent) requires one, where an
        // empty submission guarantees a failed login.
        final bool passwordOptional =
            _kind == ServiceKind.emby || _kind == ServiceKind.jellyfin;
        final List<Widget> userPass = <Widget>[
          TextFormField(
            controller: _username,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Username',
            ),
            autocorrect: false,
            textInputAction: TextInputAction.next,
            validator: (String? v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
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
          ),
        ];
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
      case AuthStyle.none:
        return const <Widget>[];
    }
  }

  /// At least one of local / external must be a valid URL.
  String? _validateUrlsTogether(String? _) {
    final bool localOk = _isValidUrl(_localUrl.text);
    final bool externalOk = _isValidUrl(_externalUrl.text);
    if (!localOk && !externalOk) {
      return 'Enter at least one valid URL (local or external)';
    }
    return null;
  }

  bool _isValidUrl(String raw) {
    if (raw.trim().isEmpty) {
      return false;
    }
    final Uri? uri = Uri.tryParse(raw.trim());
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  Widget _buildServiceIcon(ServiceKind kind, {double size = 24}) {
    if (kind == ServiceKind.sabnzbd || kind == ServiceKind.speedtestTracker) {
      return Icon(ServiceVisuals.icon(kind), size: size);
    }
    return Image.asset(
      'assets/service_icons/${kind.name}.png',
      width: size,
      height: size,
    );
  }
}
