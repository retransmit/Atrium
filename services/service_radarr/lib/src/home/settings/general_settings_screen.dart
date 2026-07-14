import 'dart:math';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../radarr_providers.dart';

class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<GeneralSettingsScreen> createState() =>
      _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _bindAddressController;
  late final TextEditingController _portController;
  late final TextEditingController _sslPortController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _branchController;

  bool _enableSsl = false;
  String _logLevel = 'info';

  bool _saving = false;
  bool _initialized = false;
  Map<String, dynamic>? _rawHostConfig;

  static const List<String> _logLevels = [
    'fatal',
    'error',
    'warn',
    'info',
    'debug',
    'trace',
  ];

  @override
  void initState() {
    super.initState();
    _bindAddressController = TextEditingController();
    _portController = TextEditingController();
    _sslPortController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _apiKeyController = TextEditingController();
    _branchController = TextEditingController();
  }

  @override
  void dispose() {
    _bindAddressController.dispose();
    _portController.dispose();
    _sslPortController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _apiKeyController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  void _initializeValues(Map<String, dynamic> config) {
    if (_initialized) return;
    _initialized = true;
    _rawHostConfig = config;

    _bindAddressController.text = (config['bindAddress'] as String?) ?? '*';
    _portController.text = (config['port'] as int? ?? 7878).toString();
    _sslPortController.text = (config['sslPort'] as int? ?? 7979).toString();
    _usernameController.text = (config['username'] as String?) ?? '';
    _passwordController.text = (config['password'] as String?) ?? '';
    _apiKeyController.text = (config['apiKey'] as String?) ?? '';

    _enableSsl = config['enableSsl'] as bool? ?? false;
    _logLevel = (config['logLevel'] as String?) ?? 'info';
    _branchController.text = (config['branch'] as String?) ?? 'master';
  }

  Future<void> _regenerateApiKey() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Regenerate API Key?'),
        content: const Text(
          'This replaces the Radarr API key. The server key changes '
          'immediately once you save, and this app will lose access to this '
          'instance until you update its API key in the instance settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final rand = Random.secure();
    final values = List<int>.generate(16, (i) => rand.nextInt(256));
    final key = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    setState(() {
      _apiKeyController.text = key;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rawHostConfig == null) return;

    setState(() => _saving = true);

    try {
      final api = await ref.read(radarrApiProvider(widget.instance).future);
      final payload = Map<String, dynamic>.from(_rawHostConfig!);

      payload['bindAddress'] = _bindAddressController.text.trim();
      payload['port'] = int.tryParse(_portController.text.trim()) ?? 7878;
      payload['sslPort'] = int.tryParse(_sslPortController.text.trim()) ?? 7979;
      payload['username'] = _usernameController.text.trim();
      if (_passwordController.text.isNotEmpty) {
        payload['password'] = _passwordController.text;
      }
      payload['apiKey'] = _apiKeyController.text.trim();
      payload['enableSsl'] = _enableSsl;
      payload['logLevel'] = _logLevel;
      payload['branch'] = _branchController.text.trim();

      await api.updateHostConfig(payload);
      ref.invalidate(radarrHostConfigProvider(widget.instance));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('General configuration settings saved!'),),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save general configuration: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hostConfigAsync =
        ref.watch(radarrHostConfigProvider(widget.instance));

    return Scaffold(
      appBar: AppBar(
        title: const Text('General Settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: ExpressiveProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: hostConfigAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (config) {
          _initializeValues(config);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(Insets.md),
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Host Config',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: Insets.md),
                        TextFormField(
                          controller: _bindAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Bind Address',
                            border: OutlineInputBorder(),
                            helperText: 'Use * for all interfaces',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: Insets.md),
                        TextFormField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: Insets.md),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable SSL'),
                          value: _enableSsl,
                          onChanged: (val) => setState(() => _enableSsl = val),
                        ),
                        if (_enableSsl) ...[
                          const SizedBox(height: Insets.md),
                          TextFormField(
                            controller: _sslPortController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'SSL Port',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security Config',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: Insets.md),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            helperText: 'Leave empty to keep existing password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _apiKeyController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'API Key',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.refresh),
                              onPressed: _regenerateApiKey,
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _apiKeyController.text),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('API Key copied to clipboard!'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logging & Updates',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: Insets.md),
                        DropdownButtonFormField<String>(
                          initialValue: _logLevel,
                          decoration: const InputDecoration(
                            labelText: 'Log Level',
                            border: OutlineInputBorder(),
                          ),
                          items: _logLevels
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(l.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() {
                            if (val != null) _logLevel = val;
                          }),
                        ),
                        const SizedBox(height: Insets.md),
                        TextFormField(
                          controller: _branchController,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
