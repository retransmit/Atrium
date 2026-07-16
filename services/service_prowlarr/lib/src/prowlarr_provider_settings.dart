import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prowlarr_api.dart';
import 'prowlarr_form_fields.dart';
import 'prowlarr_providers.dart';

/// Describes a Servarr "provider" settings resource (download client,
/// notification, indexer proxy) so one generic list + form can serve them all.
/// They share the `/{endpoint}`, `/{endpoint}/schema`, `/{endpoint}/test` and
/// `/{endpoint}/{id}` routes; only the title and a few top-level fields differ.
class ProwlarrProviderConfig {
  const ProwlarrProviderConfig({
    required this.endpoint,
    required this.title,
    required this.resourceLabel,
    required this.icon,
    this.topLevel,
  });

  /// API path segment, e.g. `downloadclient`.
  final String endpoint;

  /// Plural screen title, e.g. `Download Clients`.
  final String title;

  /// Singular noun for messages, e.g. `download client`.
  final String resourceLabel;

  final IconData icon;

  /// Builds the resource-specific top-level controls (enable/priority, an app's
  /// event toggles, ...). Mutates [raw] in place; call `onChanged` to rebuild.
  final List<Widget> Function(
    BuildContext context,
    Map<String, dynamic> raw,
    VoidCallback onChanged,
  )? topLevel;
}

/// Generic list screen for a provider resource: shows each configured instance
/// (tap to edit) and an Add FAB. Pushed from the Prowlarr Settings menu.
class ProwlarrProviderScreen extends ConsumerWidget {
  const ProwlarrProviderScreen({
    required this.instance,
    required this.config,
    super.key,
  });

  final Instance instance;
  final ProwlarrProviderConfig config;

  ProwlarrProviderArgs get _args =>
      (instance: instance, endpoint: config.endpoint);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> list =
        ref.watch(prowlarrProvidersProvider(_args));
    return Scaffold(
      appBar: AppBar(title: Text(config.title)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'prowlarr-add-${config.endpoint}',
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: M3RefreshIndicator(
        onRefresh: () async => ref.invalidate(prowlarrProvidersProvider(_args)),
        child: AsyncValueView<List<Map<String, dynamic>>>(
          value: list,
          onRetry: () => ref.invalidate(prowlarrProvidersProvider(_args)),
          data: (List<Map<String, dynamic>> items) {
            if (items.isEmpty) {
              return EmptyView(
                icon: config.icon,
                title: 'No ${config.title.toLowerCase()}',
                message: 'Tap Add to configure a ${config.resourceLabel}.',
              );
            }
            return ListView.builder(
              padding: Insets.pageH,
              itemCount: items.length,
              itemBuilder: (BuildContext context, int i) {
                final Map<String, dynamic> m = items[i];
                final String name = (m['name'] as String?) ?? 'Unknown';
                final String impl = (m['implementationName'] as String?) ?? '';
                final bool hasEnable = m.containsKey('enable');
                final bool enabled = m['enable'] == true;
                return ListTile(
                  leading: hasEnable
                      ? Icon(
                          enabled ? Icons.check_circle : Icons.cancel_outlined,
                          color: enabled
                              ? Colors.green
                              : Theme.of(context).colorScheme.outline,
                        )
                      : Icon(config.icon),
                  title: Text(name),
                  subtitle: impl.isNotEmpty ? Text(impl) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _openForm(context, id: (m['id'] as num?)?.toInt()),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _openForm(BuildContext context, {int? id}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => _ProviderFormScreen(
          instance: instance,
          config: config,
          id: id,
        ),
      ),
    );
  }
}

/// Add or edit one provider instance. ADD shows a searchable schema list, then
/// the config form; EDIT loads the raw object by id. Dynamic `fields` render via
/// [ProwlarrDynamicField]; resource-specific top-level controls come from
/// [ProwlarrProviderConfig.topLevel]. The payload round-trips the whole object.
class _ProviderFormScreen extends ConsumerStatefulWidget {
  const _ProviderFormScreen({
    required this.instance,
    required this.config,
    this.id,
  });

  final Instance instance;
  final ProwlarrProviderConfig config;
  final int? id;

  @override
  ConsumerState<_ProviderFormScreen> createState() =>
      _ProviderFormScreenState();
}

class _ProviderFormScreenState extends ConsumerState<_ProviderFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  Map<String, dynamic>? _selected; // chosen schema (add) or raw object (edit)
  List<Map<String, dynamic>> _fields = <Map<String, dynamic>>[];

  bool _showAdvanced = false;
  bool _testing = false;
  bool _saving = false;
  bool _deleting = false;
  String? _loadError;

  bool get _isEdit => widget.id != null;
  ProwlarrProviderConfig get _cfg => widget.config;
  ProwlarrProviderArgs get _args =>
      (instance: widget.instance, endpoint: _cfg.endpoint);

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadRaw();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadRaw() async {
    if (_loadError != null) {
      setState(() => _loadError = null);
    }
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(widget.instance).future);
      final Map<String, dynamic> raw =
          await api.getProviderRaw(_cfg.endpoint, widget.id!);
      if (!mounted) {
        return;
      }
      setState(() => _adopt(raw));
    } on Object catch (e) {
      if (mounted) {
        setState(() => _loadError = _errorMessage(e));
      }
    }
  }

  void _adopt(Map<String, dynamic> source) {
    _selected = source;
    _nameController.text = (source['name'] as String?) ??
        (source['implementationName'] as String?) ??
        '';
    _fields = ((source['fields'] as List<dynamic>?) ?? <dynamic>[])
        .map(
          (dynamic f) => Map<String, dynamic>.from(f as Map<dynamic, dynamic>),
        )
        .toList();
  }

  Map<String, dynamic> _buildPayload() {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(_selected!);
    payload['name'] = _nameController.text.trim();
    payload['fields'] = _fields;
    payload['tags'] = (payload['tags'] as List<dynamic>?) ?? <dynamic>[];
    return payload;
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _testing = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(widget.instance).future);
      await api.testProvider(_cfg.endpoint, _buildPayload());
      messenger.showSnackBar(const SnackBar(content: Text('Test passed')));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Test failed: ${_errorMessage(e)}')),
      );
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(widget.instance).future);
      final Map<String, dynamic> payload = _buildPayload();
      if (_isEdit) {
        await api.updateProvider(_cfg.endpoint, payload);
      } else {
        await api.createProvider(_cfg.endpoint, payload);
      }
      ref.invalidate(prowlarrProvidersProvider(_args));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? '${_capitalize(_cfg.resourceLabel)} saved'
                : '${_capitalize(_cfg.resourceLabel)} added',
          ),
        ),
      );
      nav.pop();
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: ${_errorMessage(e)}')),
      );
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete ${_cfg.resourceLabel}?'),
        content: Text('Remove "${_nameController.text}" from Prowlarr?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    final NavigatorState nav = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(widget.instance).future);
      await api.deleteProvider(_cfg.endpoint, widget.id!);
      ref.invalidate(prowlarrProvidersProvider(_args));
      messenger.showSnackBar(
        SnackBar(content: Text('${_capitalize(_cfg.resourceLabel)} deleted')),
      );
      nav.pop();
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: ${_errorMessage(e)}')),
      );
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && _selected == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Edit ${_cfg.resourceLabel}')),
        body: _loadError != null
            ? ErrorView(
                title: 'Could not load ${_cfg.resourceLabel}',
                message: _loadError!,
                onRetry: _loadRaw,
              )
            : const Center(child: ExpressiveProgressIndicator()),
      );
    }
    if (_selected == null) {
      return _ProviderSchemaPicker(
        instance: widget.instance,
        config: _cfg,
        onPick: (Map<String, dynamic> schema) => setState(() => _adopt(schema)),
      );
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    final String impl = (_selected!['implementationName'] as String?) ?? '';
    final String title = _isEdit ? 'Edit ${_nameController.text}' : 'Add $impl';

    final List<Map<String, dynamic>> visibleFields =
        _fields.where((Map<String, dynamic> f) {
      if (!_showAdvanced && f['advanced'] == true) {
        return false;
      }
      if (f['hidden'] == 'hidden') {
        return false;
      }
      return true;
    }).toList();

    final List<Widget> topLevel =
        _cfg.topLevel?.call(context, _selected!, () => setState(() {})) ??
            const <Widget>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: ExpressiveProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: _deleting ? null : _delete,
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Advanced', style: TextStyle(fontSize: 12)),
              Switch(
                value: _showAdvanced,
                onChanged: (bool v) => setState(() => _showAdvanced = v),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: Insets.page,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: Insets.md),
            ...topLevel,
            ...visibleFields.map(
              (Map<String, dynamic> f) => ProwlarrDynamicField(
                key: ValueKey<String>('${f['name']}'),
                field: f,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: ExpressiveProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.science_outlined),
                    label: const Text('Test'),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: ExpressiveProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isEdit ? 'Save' : 'Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The searchable list of provider definitions shown in ADD mode.
class _ProviderSchemaPicker extends ConsumerStatefulWidget {
  const _ProviderSchemaPicker({
    required this.instance,
    required this.config,
    required this.onPick,
  });

  final Instance instance;
  final ProwlarrProviderConfig config;
  final ValueChanged<Map<String, dynamic>> onPick;

  @override
  ConsumerState<_ProviderSchemaPicker> createState() =>
      _ProviderSchemaPickerState();
}

class _ProviderSchemaPickerState extends ConsumerState<_ProviderSchemaPicker> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String _name(Map<String, dynamic> s) =>
      (s['implementationName'] as String?) ??
      (s['name'] as String?) ??
      'Unknown';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProwlarrProviderArgs args =
        (instance: widget.instance, endpoint: widget.config.endpoint);
    final AsyncValue<List<Map<String, dynamic>>> schemas =
        ref.watch(prowlarrProviderSchemasProvider(args));
    return Scaffold(
      appBar: AppBar(title: Text('Add ${widget.config.resourceLabel}')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: Insets.page,
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Map<String, dynamic>>>(
              value: schemas,
              onRetry: () =>
                  ref.invalidate(prowlarrProviderSchemasProvider(args)),
              data: (List<Map<String, dynamic>> list) {
                final String q = _query.text.trim().toLowerCase();
                final List<Map<String, dynamic>> filtered = q.isEmpty
                    ? list
                    : list
                        .where(
                          (Map<String, dynamic> s) =>
                              _name(s).toLowerCase().contains(q),
                        )
                        .toList();
                if (filtered.isEmpty) {
                  return const EmptyView(
                    icon: Icons.search_off,
                    title: 'No matches',
                    message: 'No definition matches your search.',
                  );
                }
                return ListView.builder(
                  padding: Insets.pageH,
                  itemCount: filtered.length,
                  itemBuilder: (BuildContext context, int i) {
                    final Map<String, dynamic> s = filtered[i];
                    final String proto = (s['protocol'] as String?) ?? '';
                    return ListTile(
                      leading: Icon(widget.config.icon),
                      title: Text(_name(s)),
                      subtitle: proto.isNotEmpty
                          ? Text(proto, style: theme.textTheme.labelSmall)
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onPick(s),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _errorMessage(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
