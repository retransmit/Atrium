import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../adguard_home_client_edit.dart';
import '../adguard_home_errors.dart';
import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_clients.dart';
import '../models/adguard_home_services.dart';
import '../widgets/adguard_home_fields.dart';
import 'adguard_home_services_screen.dart';

/// What became of the client a form was opened for.
enum AdguardHomeClientOutcome { saved, deleted }

/// Opens the form for [client], or for a new client when there is none. A
/// new one can start with a [name] and one identifier, [id], filled in.
///
/// The answer is what was done: null when the form was left with nothing
/// written. [supportedTags] are the tags the server offers.
Future<AdguardHomeClientOutcome?> adguardHomeEditClient(
  BuildContext context, {
  required Instance instance,
  required List<String> supportedTags,
  AdguardHomeClient? client,
  String name = '',
  String id = '',
}) =>
    pushScreen<AdguardHomeClientOutcome>(
      context,
      AdguardHomeClientScreen(
        instance: instance,
        supportedTags: supportedTags,
        client: client,
        name: name,
        id: id,
      ),
    );

/// The form for one persistent client: everything the web UI's form has but
/// the pause schedule, on one page.
class AdguardHomeClientScreen extends ConsumerWidget {
  const AdguardHomeClientScreen({
    required this.instance,
    required this.supportedTags,
    this.client,
    this.name = '',
    this.id = '',
    super.key,
  });

  final Instance instance;
  final List<String> supportedTags;

  /// The client to change. Null for a new one.
  final AdguardHomeClient? client;

  /// What a new client starts with.
  final String name;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AdguardHomeClient? client = this.client;
    if (client != null) {
      return _ClientForm(
        instance: instance,
        supportedTags: supportedTags,
        client: client,
        before: AdguardHomeClientDraft.of(client),
      );
    }

    // A new client starts from the server's own safe search, as in the web
    // UI. Without it the per-engine switches would have nothing to show.
    final AsyncValue<AdguardHomeSafeSearch> safeSearch =
        ref.watch(adguardHomeSafeSearchProvider(instance));
    return safeSearch.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('New client')),
        body: const Center(child: ExpressiveProgressIndicator()),
      ),
      error: (Object error, StackTrace _) => Scaffold(
        appBar: AppBar(title: const Text('New client')),
        body: SingleChildScrollView(
          child: ErrorView(
            message: describeAdguardHomeError(error),
            // After a refused sign-in this sends nothing.
            onRetry: () =>
                ref.invalidate(adguardHomeSafeSearchProvider(instance)),
          ),
        ),
      ),
      data: (AdguardHomeSafeSearch safeSearch) => _ClientForm(
        instance: instance,
        supportedTags: supportedTags,
        before: AdguardHomeClientDraft.blank(
          safeSearch: safeSearch,
          name: name,
          ids: <String>[id],
        ),
      ),
    );
  }
}

class _ClientForm extends ConsumerStatefulWidget {
  const _ClientForm({
    required this.instance,
    required this.supportedTags,
    required this.before,
    this.client,
  });

  final Instance instance;
  final List<String> supportedTags;

  /// What the form starts with.
  final AdguardHomeClientDraft before;
  final AdguardHomeClient? client;

  @override
  ConsumerState<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<_ClientForm> {
  /// What the form started with. A write changes only what differs from it.
  late final AdguardHomeClientDraft _before = widget.before;

  /// The settings that are not text. The text is in the controllers.
  late AdguardHomeClientDraft _settings = widget.before;

  late final TextEditingController _name =
      TextEditingController(text: _before.name);
  late final List<TextEditingController> _ids = <TextEditingController>[
    for (final String id in _before.ids) TextEditingController(text: id),
  ];
  late final TextEditingController _upstreams =
      TextEditingController(text: _before.upstreams);
  late final TextEditingController _cacheSize =
      TextEditingController(text: _before.upstreamsCacheSize);

  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _idsKey = GlobalKey();
  final GlobalKey _cacheKey = GlobalKey();

  /// Whether something is being written. Nothing else can be started then.
  bool _busy = false;

  /// Whether Save has been asked for once. Until then an empty field is not
  /// complained about: the form opens with several.
  bool _checked = false;

  Instance get _instance => widget.instance;

  /// The name the client has on the server. Null for a new one.
  String? get _originalName => widget.client?.name;

  @override
  void dispose() {
    _name.dispose();
    for (final TextEditingController id in _ids) {
      id.dispose();
    }
    _upstreams.dispose();
    _cacheSize.dispose();
    super.dispose();
  }

  /// Everything the form holds now.
  AdguardHomeClientDraft get _draft => _settings.copyWith(
        name: _name.text,
        ids: <String>[for (final TextEditingController id in _ids) id.text],
        upstreams: _upstreams.text,
        upstreamsCacheSize: _cacheSize.text,
      );

  bool get _changed =>
      !adguardHomeJsonEquals(_before.toJson(), _draft.toJson());

  void _set(AdguardHomeClientDraft settings) =>
      setState(() => _settings = settings);

  /// The complaints and the question on leaving follow the text.
  void _typed(String _) => setState(() {});

  void _addId() => setState(() => _ids.add(TextEditingController()));

  void _removeId(int row) {
    final TextEditingController removed = _ids.removeAt(row);
    setState(() {});
    // After the frame that no longer shows its field.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      removed.dispose();
    });
  }

  void _toggleTag(String tag, {required bool on}) => _set(
        _settings.copyWith(
          tags: <String>[
            for (final String own in _settings.tags)
              if (own != tag) own,
            if (on) tag,
          ],
        ),
      );

  Future<void> _pickServices() async {
    final String name = _name.text.trim();
    final Set<String>? picked = await pushScreen<Set<String>>(
      context,
      AdguardHomeServicesScreen(
        instance: _instance,
        title: name.isEmpty ? 'Blocked services' : 'Blocked for $name',
        selected: _settings.blockedServices.toSet(),
      ),
    );
    if (picked == null || !mounted) return;
    // The picker has read the catalogue by now, and it is kept.
    final AdguardHomeServiceCatalogue? catalogue =
        ref.read(adguardHomeServicesProvider(_instance)).value;
    final List<String> kept = <String>[
      for (final String id in _settings.blockedServices)
        if (picked.contains(id)) id,
    ];
    final List<String> added = <String>[
      // In the catalogue's order, where it is known.
      if (catalogue != null)
        for (final AdguardHomeBlockedService service in catalogue.services)
          if (picked.contains(service.id) && !kept.contains(service.id))
            service.id,
    ];
    _set(
      _settings.copyWith(
        blockedServices: <String>[
          ...kept,
          ...added,
          for (final String id in picked)
            if (!kept.contains(id) && !added.contains(id)) id,
        ],
      ),
    );
  }

  Future<void> _explain(String title, String message) => showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  /// Brings the first field that will not do into view.
  void _showProblem(AdguardHomeClientProblems problems) {
    final GlobalKey key = problems.name != null
        ? _nameKey
        : problems.ids != null
            ? _idsKey
            : _cacheKey;
    final BuildContext? field = key.currentContext;
    if (field == null) return;
    Scrollable.ensureVisible(
      field,
      alignment: 0.1,
      duration: const Duration(milliseconds: 200),
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    final AdguardHomeClientDraft draft = _draft;
    final AdguardHomeClientProblems problems = draft.problems;
    if (problems.any) {
      setState(() => _checked = true);
      _showProblem(problems);
      return;
    }
    final String? originalName = _originalName;
    // Nothing to write. A new client always has something.
    if (originalName != null && !_changed) {
      Navigator.of(context).pop();
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ModalRoute<Object?>? form = ModalRoute.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(adguardHomeActionsProvider(_instance)).saveClient(
            originalName: originalName,
            before: _before,
            after: draft,
          );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _explain('Not saved', describeAdguardHomeError(error));
      return;
    }
    if (!mounted) return;
    _close(form, AdguardHomeClientOutcome.saved);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Client "${draft.name.trim()}" '
            '${originalName == null ? 'added' : 'saved'}',
          ),
        ),
      );
  }

  Future<void> _delete() async {
    final String? name = _originalName;
    if (_busy || name == null) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
          'Its settings are removed. The device itself is not shut out: '
          'AdGuard Home goes on answering it, with the global settings.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ModalRoute<Object?>? form = ModalRoute.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(adguardHomeActionsProvider(_instance)).deleteClient(name);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _explain('Not deleted', describeAdguardHomeError(error));
      return;
    }
    if (!mounted) return;
    _close(form, AdguardHomeClientOutcome.deleted);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Client "$name" deleted')));
  }

  /// Closes the form once its client was written, handing back [outcome].
  ///
  /// [form] is the form's own route, taken before the write was awaited.
  /// "The route on top" will not do: by the time the server has answered,
  /// something else may stand over the form, and popping that with a
  /// client's outcome leaves both it and the form stuck. Whatever is over
  /// the form goes first, then the form.
  void _close(ModalRoute<Object?>? form, AdguardHomeClientOutcome outcome) {
    if (form == null || !form.isActive) return;
    Navigator.of(context)
      ..popUntil((Route<Object?> route) => route == form)
      ..pop(outcome);
  }

  /// Asked when the form is left with something changed.
  Future<void> _leave() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('What was changed here has not been saved.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AdguardHomeClient? client = widget.client;
    final AdguardHomeClientDraft settings = _settings;
    final AdguardHomeClientProblems problems = _checked
        ? _draft.problems
        : const AdguardHomeClientProblems();
    // Only wanted for the names of what is blocked. A client that blocks
    // nothing of its own does not cost the few hundred kilobytes of it.
    final AdguardHomeServiceCatalogue? catalogue =
        settings.blockedServices.isEmpty
            ? null
            : ref.watch(adguardHomeServicesProvider(_instance)).value;
    final bool ownSettings = !settings.useGlobalSettings;
    final bool ownServices = !settings.useGlobalBlockedServices;
    final TextStyle? note =
        theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    // The schedule is not something this form changes, but a client that
    // has one should not look as if it had none.
    final String? pauses = client == null || client.pauses.isEmpty
        ? null
        : formatAdguardHomePauses(client.pauses, client.pauseTimeZone);
    final List<String> tags = <String>[
      ...widget.supportedTags,
      // One it has that the server no longer offers, so it can be taken off.
      for (final String tag in _before.tags)
        if (!widget.supportedTags.contains(tag)) tag,
    ];

    return PopScope<Object?>(
      canPop: !_busy && !_changed,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        // While something is being written the form stays.
        if (didPop || _busy) return;
        _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(client == null ? 'New client' : 'Edit client'),
          actions: <Widget>[
            if (client != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete client',
                onPressed: _busy ? null : _delete,
              ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
            const SizedBox(width: Insets.md),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: _busy
                ? const LinearProgressIndicatorM3E(
                    size: LinearProgressM3ESize.s,
                    shape: ProgressM3EShape.flat,
                  )
                : const SizedBox(height: 4),
          ),
        ),
        // Nothing in the form can be touched while it is being written:
        // what was changed now would not be in what was sent, and a screen
        // opened now would stand over a form that is about to close.
        body: AbsorbPointer(
          absorbing: _busy,
          // The whole form is built, not only what is on screen. Save can
          // complain about a field at the other end of it, and has to be
          // able to bring that field into view.
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Insets.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Inset(
                  key: _nameKey,
                  top: Insets.lg,
                  child: TextField(
                    key: const Key('adguard-client-name'),
                    controller: _name,
                    onChanged: _typed,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: const OutlineInputBorder(),
                      errorText: problems.name,
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                _Inset(
                  key: _idsKey,
                  child: const AdguardHomeHeading('Identifiers'),
                ),
                _Inset(
                  top: Insets.xs,
                  child: Text(
                    'An IP address, a range such as 192.168.1.0/24, a MAC '
                    'address, or a ClientID.',
                    style: note,
                  ),
                ),
                for (int row = 0; row < _ids.length; row++)
                  _Inset(
                    top: Insets.sm,
                    child: TextField(
                      key: Key('adguard-client-id-$row'),
                      controller: _ids[row],
                      onChanged: _typed,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Identifier',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        errorText: row == 0 ? problems.ids : null,
                        errorMaxLines: 3,
                        suffixIcon: _ids.length < 2
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                tooltip: 'Remove identifier',
                                onPressed: () => _removeId(row),
                              ),
                      ),
                    ),
                  ),
                _Inset(
                  top: Insets.xs,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addId,
                      icon: const Icon(Icons.add),
                      label: const Text('Add identifier'),
                    ),
                  ),
                ),
                const _Inset(child: AdguardHomeHeading('Protection')),
                SwitchListTile(
                  title: const Text('Use global settings'),
                  subtitle: const Text('The settings of the server apply'),
                  value: settings.useGlobalSettings,
                  onChanged: (bool on) =>
                      _set(settings.copyWith(useGlobalSettings: on)),
                ),
                SwitchListTile(
                  title: const Text(
                    'Block domains using filters and hosts files',
                  ),
                  value: settings.filteringEnabled,
                  onChanged: ownSettings
                      ? (bool on) =>
                          _set(settings.copyWith(filteringEnabled: on))
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Browsing security'),
                  subtitle: const Text('Blocks malware and phishing domains'),
                  value: settings.safeBrowsingEnabled,
                  onChanged: ownSettings
                      ? (bool on) =>
                          _set(settings.copyWith(safeBrowsingEnabled: on))
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Parental control'),
                  subtitle: const Text('Blocks adult websites'),
                  value: settings.parentalEnabled,
                  onChanged: ownSettings
                      ? (bool on) =>
                          _set(settings.copyWith(parentalEnabled: on))
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Safe search'),
                  subtitle: const Text('Hides explicit results on the search '
                      'engines below'),
                  value: settings.safeSearch.enabled,
                  onChanged: ownSettings
                      ? (bool on) => _set(
                            settings.copyWith(
                              safeSearch:
                                  settings.safeSearch.copyWith(enabled: on),
                            ),
                          )
                      : null,
                ),
                for (final MapEntry<String, bool> engine
                    in settings.safeSearch.engines.entries)
                  SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(
                      left: Insets.xl,
                      right: Insets.lg,
                    ),
                    title: Text(adguardHomeSearchEngineLabel(engine.key)),
                    value: engine.value,
                    onChanged: ownSettings && settings.safeSearch.enabled
                        ? (bool on) => _set(
                              settings.copyWith(
                                safeSearch: settings.safeSearch
                                    .withEngine(engine.key, on: on),
                              ),
                            )
                        : null,
                  ),
                const _Inset(child: AdguardHomeHeading('Blocked services')),
                SwitchListTile(
                  title: const Text('Use global blocked services'),
                  subtitle: const Text('The list of the server applies'),
                  value: settings.useGlobalBlockedServices,
                  onChanged: (bool on) =>
                      _set(settings.copyWith(useGlobalBlockedServices: on)),
                ),
                ListTile(
                  enabled: ownServices,
                  title: const Text('Blocked for this client'),
                  subtitle: Text(
                    settings.blockedServices.isEmpty
                        ? 'None'
                        : <String>[
                            for (final String id in settings.blockedServices)
                              catalogue?.nameOf(id) ?? id,
                          ].join(', '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickServices,
                ),
                if (pauses != null)
                  _Inset(
                    top: Insets.xs,
                    child: Text(
                      'Blocking pauses $pauses. This schedule is kept as it '
                      'is. It can be changed in AdGuard Home.',
                      style: note,
                    ),
                  ),
                const _Inset(child: AdguardHomeHeading('Upstream DNS servers')),
                _Inset(
                  top: Insets.sm,
                  child: TextField(
                    key: const Key('adguard-client-upstreams'),
                    controller: _upstreams,
                    onChanged: _typed,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.multiline,
                    minLines: 3,
                    maxLines: 8,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: 'One server per line',
                      helperText: 'Leave empty to use the servers of the DNS '
                          'settings.',
                      helperMaxLines: 3,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Cache the answers of these servers'),
                  value: settings.upstreamsCacheEnabled,
                  onChanged: (bool on) =>
                      _set(settings.copyWith(upstreamsCacheEnabled: on)),
                ),
                _Inset(
                  key: _cacheKey,
                  top: Insets.xs,
                  child: TextField(
                    key: const Key('adguard-client-cache-size'),
                    controller: _cacheSize,
                    onChanged: _typed,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Cache size, in bytes',
                      border: const OutlineInputBorder(),
                      errorText: problems.cacheSize,
                      // The longest complaint, with the bound in it, is wider
                      // than the field at a large text size.
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                const _Inset(
                  child: AdguardHomeHeading('Query log and statistics'),
                ),
                SwitchListTile(
                  title: const Text('Ignore in the query log'),
                  subtitle: const Text(
                    'Its queries are not written to the log',
                  ),
                  value: settings.ignoreQueryLog,
                  onChanged: (bool on) =>
                      _set(settings.copyWith(ignoreQueryLog: on)),
                ),
                SwitchListTile(
                  title: const Text('Ignore in statistics'),
                  subtitle: const Text('Its queries are not counted'),
                  value: settings.ignoreStatistics,
                  onChanged: (bool on) =>
                      _set(settings.copyWith(ignoreStatistics: on)),
                ),
                // Last: there are some twenty of them, they are the least used
                // part of a client, and anywhere higher they would stand
                // between the identifiers and the settings on every visit.
                const _Inset(child: AdguardHomeHeading('Tags')),
                _Inset(
                  top: Insets.xs,
                  child: Text(
                    'A filtering rule can be written for a tag instead of a '
                    'client.',
                    style: note,
                  ),
                ),
                _Inset(
                  top: Insets.sm,
                  child: Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.xs,
                    children: <Widget>[
                      for (final String tag in tags)
                        FilterChip(
                          label: Text(tag),
                          selected: settings.tags.contains(tag),
                          onSelected: (bool on) => _toggleTag(tag, on: on),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A child of the form that is not a list tile, set in from the sides as
/// the tiles are.
class _Inset extends StatelessWidget {
  const _Inset({required this.child, this.top = 0, super.key});

  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Insets.lg, top, Insets.lg, 0),
        child: child,
      );
}
