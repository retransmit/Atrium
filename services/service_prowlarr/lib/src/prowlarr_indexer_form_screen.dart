import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prowlarr_indexer_stats.dart';
import 'prowlarr_api.dart';
import 'prowlarr_form_fields.dart';
import 'prowlarr_providers.dart';

/// Add or edit a Prowlarr indexer.
///
/// In ADD mode ([indexerId] null) it first shows a searchable list of indexer
/// definitions (`/indexer/schema` - Prowlarr returns hundreds), then the config
/// form for the chosen one. In EDIT mode it loads the raw indexer by id and
/// shows the same form. Dynamic `fields` are rendered from the schema, mirroring
/// the *arr settings-form pattern; the payload round-trips the whole object.
class ProwlarrIndexerFormScreen extends ConsumerStatefulWidget {
  const ProwlarrIndexerFormScreen({
    required this.instance,
    this.indexerId,
    super.key,
  });

  final Instance instance;
  final int? indexerId;

  @override
  ConsumerState<ProwlarrIndexerFormScreen> createState() =>
      _ProwlarrIndexerFormScreenState();
}

class _ProwlarrIndexerFormScreenState
    extends ConsumerState<ProwlarrIndexerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  Map<String, dynamic>? _selected; // chosen schema (add) or raw indexer (edit)
  List<Map<String, dynamic>> _fields = <Map<String, dynamic>>[];

  bool _enabled = true;
  int _priority = 25;
  int? _appProfileId;

  bool _showAdvanced = false;
  bool _testing = false;
  bool _saving = false;
  bool _deleting = false;

  // Edit-mode raw load error (null while loading or once loaded).
  String? _loadError;

  bool get _isEdit => widget.indexerId != null;

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
          await api.getIndexerRaw(widget.indexerId!);
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

  /// Seed the form state from a schema or raw indexer map.
  void _adopt(Map<String, dynamic> source) {
    _selected = source;
    _nameController.text = (source['name'] as String?) ??
        (source['implementationName'] as String?) ??
        '';
    _fields = ((source['fields'] as List<dynamic>?) ?? <dynamic>[])
        .map((dynamic f) =>
            Map<String, dynamic>.from(f as Map<dynamic, dynamic>))
        .toList();
    _enabled = (source['enable'] as bool?) ?? true;
    _priority = (source['priority'] as num?)?.toInt() ?? 25;
    _appProfileId = (source['appProfileId'] as num?)?.toInt();
  }

  Map<String, dynamic> _buildPayload() {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(_selected!);
    payload['name'] = _nameController.text.trim();
    payload['fields'] = _fields;
    payload['enable'] = _enabled;
    payload['priority'] = _priority;
    if (_appProfileId != null) {
      payload['appProfileId'] = _appProfileId;
    }
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
      await api.testIndexerRaw(_buildPayload());
      messenger.showSnackBar(
        const SnackBar(content: Text('Test passed')),
      );
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
        await api.updateIndexerRaw(payload);
      } else {
        await api.createIndexerRaw(payload);
      }
      ref.invalidate(prowlarrIndexersProvider(widget.instance));
      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Indexer saved' : 'Indexer added')),
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
        title: const Text('Delete indexer?'),
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
      await api.deleteIndexer(widget.indexerId!);
      ref.invalidate(prowlarrIndexersProvider(widget.instance));
      messenger.showSnackBar(const SnackBar(content: Text('Indexer deleted')));
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
        appBar: AppBar(title: const Text('Edit indexer')),
        body: _loadError != null
            ? ErrorView(
                title: 'Could not load indexer',
                message: _loadError!,
                onRetry: _loadRaw,
              )
            : const Center(child: ExpressiveProgressIndicator()),
      );
    }
    if (_selected == null) {
      return _SchemaPicker(
        instance: widget.instance,
        onPick: (Map<String, dynamic> schema) => setState(() => _adopt(schema)),
      );
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String impl = (_selected!['implementationName'] as String?) ?? '';
    final String title = _isEdit
        ? 'Edit ${_nameController.text}'
        : 'Add ${_selected!['name'] ?? impl}';

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
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: Radii.card,
              ),
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: Insets.md),
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: (bool v) => setState(() => _enabled = v),
              ),
            ),
            const SizedBox(height: Insets.md),
            TextFormField(
              initialValue: '$_priority',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Priority',
                helperText: 'Lower is higher priority (1-50, default 25)',
                border: OutlineInputBorder(),
              ),
              onChanged: (String v) => _priority = int.tryParse(v) ?? _priority,
              validator: (String? v) =>
                  (v == null || int.tryParse(v) == null) ? 'Number' : null,
            ),
            const SizedBox(height: Insets.md),
            _SyncProfileDropdown(
              instance: widget.instance,
              value: _appProfileId,
              onChanged: (int? v) => setState(() => _appProfileId = v),
            ),
            const SizedBox(height: Insets.md),
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
            if (_isEdit) ...<Widget>[
              const SizedBox(height: Insets.lg),
              _IndexerStatsSection(
                instance: widget.instance,
                indexerId: widget.indexerId!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The searchable list of indexer definitions shown in ADD mode.
class _SchemaPicker extends ConsumerStatefulWidget {
  const _SchemaPicker({required this.instance, required this.onPick});

  final Instance instance;
  final ValueChanged<Map<String, dynamic>> onPick;

  @override
  ConsumerState<_SchemaPicker> createState() => _SchemaPickerState();
}

class _SchemaPickerState extends ConsumerState<_SchemaPicker> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> schemas =
        ref.watch(prowlarrIndexerSchemasProvider(widget.instance));
    return Scaffold(
      appBar: AppBar(title: const Text('Add indexer')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: Insets.page,
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search indexers...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Map<String, dynamic>>>(
              value: schemas,
              onRetry: () => ref
                  .invalidate(prowlarrIndexerSchemasProvider(widget.instance)),
              data: (List<Map<String, dynamic>> list) {
                final String q = _query.text.trim().toLowerCase();
                final List<Map<String, dynamic>> filtered = q.isEmpty
                    ? list
                    : list
                        .where(
                          (Map<String, dynamic> s) =>
                              ((s['name'] ?? '') as String)
                                  .toLowerCase()
                                  .contains(q),
                        )
                        .toList();
                if (filtered.isEmpty) {
                  return const EmptyView(
                    icon: Icons.search_off,
                    title: 'No matches',
                    message: 'No indexer definition matches your search.',
                  );
                }
                return ListView.builder(
                  padding: Insets.pageH,
                  itemCount: filtered.length,
                  itemBuilder: (BuildContext context, int i) {
                    final Map<String, dynamic> s = filtered[i];
                    final String name = (s['name'] as String?) ?? 'Unknown';
                    final String proto = (s['protocol'] as String?) ?? '';
                    final String privacy = (s['privacy'] as String?) ?? '';
                    return ListTile(
                      title: Text(name),
                      subtitle: Text(
                        <String>[
                          if (proto.isNotEmpty) proto,
                          if (privacy.isNotEmpty) privacy,
                        ].join(' • '),
                        style: theme.textTheme.labelSmall,
                      ),
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

/// Sync-profile dropdown sourced from `/appprofile`. Falls back to a disabled
/// field while loading or if none are configured.
class _SyncProfileDropdown extends ConsumerWidget {
  const _SyncProfileDropdown({
    required this.instance,
    required this.value,
    required this.onChanged,
  });

  final Instance instance;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> profiles =
        ref.watch(prowlarrAppProfilesProvider(instance));
    return profiles.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Sync profile',
          border: OutlineInputBorder(),
        ),
        child: Text('Loading...'),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (List<Map<String, dynamic>> list) {
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }
        final int effective = list.any(
          (Map<String, dynamic> p) => (p['id'] as num?)?.toInt() == value,
        )
            ? value!
            : (list.first['id'] as num).toInt();
        // Seed the parent's value if it was unset/invalid.
        if (effective != value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChanged(effective);
          });
        }
        return DropdownButtonFormField<int>(
          initialValue: effective,
          decoration: const InputDecoration(
            labelText: 'Sync profile',
            border: OutlineInputBorder(),
          ),
          items: list
              .map(
                (Map<String, dynamic> p) => DropdownMenuItem<int>(
                  value: (p['id'] as num).toInt(),
                  child: Text((p['name'] ?? 'Profile') as String),
                ),
              )
              .toList(),
          onChanged: onChanged,
        );
      },
    );
  }
}

/// Read-only stats block for an existing indexer.
class _IndexerStatsSection extends ConsumerWidget {
  const _IndexerStatsSection({required this.instance, required this.indexerId});

  final Instance instance;
  final int indexerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ProwlarrIndexerStat? stat =
        ref.watch(prowlarrStatsByIdProvider(instance)).value?[indexerId];
    if (stat == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Statistics', style: theme.textTheme.titleMedium),
        const SizedBox(height: Insets.sm),
        _row(theme, 'Queries', '${stat.numberOfQueries}'),
        _row(theme, 'Grabs', '${stat.numberOfGrabs}'),
        _row(theme, 'RSS queries', '${stat.numberOfRssQueries}'),
        _row(theme, 'Failed queries', '${stat.numberOfFailedQueries}'),
        _row(theme, 'Failed grabs', '${stat.numberOfFailedGrabs}'),
        _row(theme, 'Avg response', '${stat.averageResponseTime} ms'),
      ],
    );
  }

  Widget _row(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
            Text(value, style: theme.textTheme.bodySmall),
          ],
        ),
      );
}

String _errorMessage(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
