import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_filter_rules.dart';
import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_filtering.dart';
import '../widgets/adguard_home_failure_dialog.dart';
import '../widgets/adguard_home_pullable.dart';
import '../widgets/adguard_home_refused_view.dart';

/// The blocklists, or with [allowlist] the allowlists: each with its
/// switch, a way to add one, and Check for updates. The blocklists also
/// carry how often all lists are fetched again.
class AdguardHomeFilterListsScreen extends ConsumerStatefulWidget {
  const AdguardHomeFilterListsScreen({
    required this.instance,
    required this.allowlist,
    super.key,
  });

  final Instance instance;
  final bool allowlist;

  @override
  ConsumerState<AdguardHomeFilterListsScreen> createState() =>
      _AdguardHomeFilterListsScreenState();
}

class _AdguardHomeFilterListsScreenState
    extends ConsumerState<AdguardHomeFilterListsScreen> {
  /// The addresses of the lists whose switch is being written.
  final Set<String> _toggling = <String>{};
  bool _refreshing = false;

  /// The interval being written, shown on its tile until the server's own
  /// says the same.
  int? _savingInterval;

  Instance get _instance => widget.instance;
  bool get _allow => widget.allowlist;
  String get _kind => _allow ? 'allowlist' : 'blocklist';

  AdguardHomeActions get _actions =>
      ref.read(adguardHomeActionsProvider(_instance));

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(AdguardHomeFilterList list, bool on) async {
    if (_toggling.contains(list.url)) return;
    setState(() => _toggling.add(list.url));
    try {
      await _actions.setListEnabled(list, allowlist: _allow, enabled: on);
    } on Object catch (error) {
      _say(describeAdguardHomeError(error));
    } finally {
      if (mounted) setState(() => _toggling.remove(list.url));
    }
  }

  Future<void> _checkForUpdates() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final int updated = await _actions.refreshLists(allowlist: _allow);
      _say(
        switch (updated) {
          0 => 'All lists are up to date',
          1 => '1 list updated',
          _ => '$updated lists updated',
        },
      );
    } on Object catch (error) {
      _say(describeAdguardHomeError(error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _pickInterval(int current) async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Update the lists'),
        children: <Widget>[
          for (final int hours in <int>[
            ...adguardHomeIntervalOptions,
            if (!adguardHomeIntervalOptions.contains(current)) current,
          ])
            ListTile(
              title: Text(adguardHomeIntervalLabel(hours)),
              trailing: hours == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(hours),
            ),
        ],
      ),
    );
    if (picked == null || picked == current || _savingInterval != null) {
      return;
    }
    setState(() => _savingInterval = picked);
    try {
      await _actions.setUpdateInterval(picked);
      // The write reads the lists again. Waited for, so the tile does not
      // go back to the old interval for a moment.
      await ref.read(adguardHomeFilteringProvider(_instance).future);
    } on Object catch (error) {
      if (mounted) setState(() => _savingInterval = null);
      _say(describeAdguardHomeError(error));
      return;
    }
    if (!mounted) return;
    setState(() => _savingInterval = null);
    _say(
      picked == 0
          ? 'The lists will no longer update by themselves'
          : 'The lists will update ${adguardHomeIntervalLabel(picked).toLowerCase()}',
    );
  }

  void _open([AdguardHomeFilterList? list]) => pushScreen<void>(
        context,
        AdguardHomeFilterListScreen(
          instance: _instance,
          allowlist: _allow,
          list: list,
        ),
      );

  Future<void> _refresh() async {
    ref.invalidate(adguardHomeFilteringProvider(_instance));
    try {
      await ref.read(adguardHomeFilteringProvider(_instance).future);
    } on Object {
      // The screen shows the failure itself.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeFiltering> filtering =
        ref.watch(adguardHomeFilteringProvider(_instance));
    final String title = _allow ? 'Allowlists' : 'Blocklists';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add $_kind',
            onPressed: _open,
          ),
          PopupMenuButton<void>(
            tooltip: 'More',
            useRootNavigator: true,
            itemBuilder: (BuildContext _) => <PopupMenuEntry<void>>[
              PopupMenuItem<void>(
                onTap: _checkForUpdates,
                child: const Text('Check for updates'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _refreshing || _savingInterval != null
              ? const LinearProgressIndicatorM3E(
                  size: LinearProgressM3ESize.s,
                  shape: ProgressM3EShape.flat,
                )
              : const SizedBox(height: 4),
        ),
      ),
      body: _body(filtering),
    );
  }

  Widget _body(AsyncValue<AdguardHomeFiltering> filtering) {
    if (filtering.error is AdguardHomeSignInRefused) {
      return AdguardHomeRefusedView(
        onRetry: _actions.retrySignIn,
        onEdit: () => context.pushNamed(
          AtriumRoutes.editInstanceName,
          pathParameters: <String, String>{'instanceId': _instance.id},
        ),
        hasCredentials: adguardHomeHasCredentials(_instance),
        refusals: ref.read(adguardHomeSessionProvider(_instance)).refusals,
      );
    }
    return filtering.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: ExpressiveProgressIndicator()),
      error: (Object error, StackTrace _) => AdguardHomePullable(
        onRefresh: _refresh,
        child: ErrorView(
          message: describeAdguardHomeError(error),
          onRetry: () =>
              ref.invalidate(adguardHomeFilteringProvider(_instance)),
        ),
      ),
      data: (AdguardHomeFiltering filtering) {
        final List<AdguardHomeFilterList> lists =
            _allow ? filtering.allowlists : filtering.blocklists;
        final Widget? interval = _allow
            ? null
            : ListTile(
                leading: const Icon(Icons.update),
                title: const Text('Update the lists'),
                subtitle: Text(
                  adguardHomeIntervalLabel(
                    _savingInterval ?? filtering.intervalHours,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                enabled: _savingInterval == null,
                onTap: () => _pickInterval(filtering.intervalHours),
              );
        if (lists.isEmpty) {
          return AdguardHomePullable(
            onRefresh: _refresh,
            child: Column(
              children: <Widget>[
                if (interval != null) interval,
                EmptyView(
                  icon: Icons.playlist_add,
                  title: 'No ${_kind}s',
                  message: _allow
                      ? 'An allowlist lets through what the blocklists '
                          'would block.'
                      : 'A blocklist names the domains to block.',
                  action: FilledButton.tonalIcon(
                    onPressed: _open,
                    icon: const Icon(Icons.add),
                    label: Text('Add $_kind'),
                  ),
                ),
              ],
            ),
          );
        }
        return EasyRefresh(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: Insets.xl),
            children: <Widget>[
              if (interval != null) ...<Widget>[
                interval,
                const Divider(height: 1),
              ],
              for (final AdguardHomeFilterList list in lists)
                AdguardHomeFilterListRow(
                  list: list,
                  busy: _toggling.contains(list.url),
                  onTap: () => _open(list),
                  onToggle: (bool on) => _toggle(list, on),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One filter list: its name, its address, its rules and when it was last
/// fetched, and its switch.
class AdguardHomeFilterListRow extends StatelessWidget {
  const AdguardHomeFilterListRow({
    required this.list,
    required this.onTap,
    required this.onToggle,
    this.busy = false,
    super.key,
  });

  final AdguardHomeFilterList list;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  /// While its switch is being written.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final DateTime? updated = list.lastUpdated;
    final String state = <String>[
      // A list that is off has no rules loaded, so its count says nothing.
      if (list.enabled)
        '${formatAdguardHomeCount(list.rulesCount)} rules'
      else
        'Off',
      if (updated == null)
        'Never updated'
      else
        'Updated ${formatAdguardHomeDate(updated)}',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.md,
          Insets.sm,
          Insets.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    list.name.isEmpty ? list.url : list.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    list.url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    state,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Switch(
              value: list.enabled,
              onChanged: busy ? null : onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

/// A filter list's name and address, to add one or change it, with Delete
/// for one that is there.
class AdguardHomeFilterListScreen extends ConsumerStatefulWidget {
  const AdguardHomeFilterListScreen({
    required this.instance,
    required this.allowlist,
    this.list,
    super.key,
  });

  final Instance instance;
  final bool allowlist;

  /// The list to change. Null for a new one.
  final AdguardHomeFilterList? list;

  @override
  ConsumerState<AdguardHomeFilterListScreen> createState() =>
      _AdguardHomeFilterListScreenState();
}

class _AdguardHomeFilterListScreenState
    extends ConsumerState<AdguardHomeFilterListScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.list?.name ?? '');
  late final TextEditingController _url =
      TextEditingController(text: widget.list?.url ?? '');

  bool _busy = false;
  bool _checked = false;

  String get _kind => widget.allowlist ? 'allowlist' : 'blocklist';

  bool get _changed =>
      _name.text != (widget.list?.name ?? '') ||
      _url.text.trim() != (widget.list?.url ?? '');

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  /// After a refused sign-in, lets one more request out.
  void _retrySignIn() =>
      ref.read(adguardHomeActionsProvider(widget.instance)).retrySignIn();

  /// Closes this form, whatever stands over it by now.
  void _close(ModalRoute<Object?>? form, String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (form != null && form.isActive) {
      Navigator.of(context)
        ..popUntil((Route<Object?> route) => route == form)
        ..pop();
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_busy) return;
    final String? problem = adguardHomeListUrlProblem(_url.text);
    if (problem != null) {
      setState(() => _checked = true);
      return;
    }
    final AdguardHomeFilterList? list = widget.list;
    if (list != null && !_changed) {
      Navigator.of(context).pop();
      return;
    }
    final ModalRoute<Object?>? form = ModalRoute.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(adguardHomeActionsProvider(widget.instance)).saveList(
            original: list,
            allowlist: widget.allowlist,
            name: _name.text.trim(),
            url: _url.text.trim(),
          );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final bool again = await showAdguardHomeFailure(
        context,
        title: 'Not saved',
        error: error,
      );
      if (again && mounted) {
        _retrySignIn();
        await _save();
      }
      return;
    }
    if (!mounted) return;
    _close(form, list == null ? 'List added' : 'List saved');
  }

  Future<void> _delete() async {
    final AdguardHomeFilterList? list = widget.list;
    if (_busy || list == null) return;
    final String name = list.name.isEmpty ? list.url : list.name;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: Text(
          widget.allowlist
              ? 'What it lets through will be blocked again where a '
                  'blocklist names it.'
              : 'What only this list blocks will be let through.',
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
    final ModalRoute<Object?>? form = ModalRoute.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(adguardHomeActionsProvider(widget.instance))
          .removeList(list, allowlist: widget.allowlist);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final bool again = await showAdguardHomeFailure(
        context,
        title: 'Not deleted',
        error: error,
      );
      if (again && mounted) {
        _retrySignIn();
        await _delete();
      }
      return;
    }
    if (!mounted) return;
    _close(form, 'List deleted');
  }

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
    final String? problem = _checked ? adguardHomeListUrlProblem(_url.text) : null;
    final bool fetching =
        _busy && (widget.list == null || _url.text.trim() != widget.list!.url);
    return PopScope<Object?>(
      canPop: !_busy && !_changed,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop || _busy) return;
        _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.list == null ? 'New' : 'Edit'} $_kind'),
          actions: <Widget>[
            if (widget.list != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete list',
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
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: Insets.page,
            children: <Widget>[
              TextField(
                key: const Key('adguard-list-name'),
                controller: _name,
                onChanged: (String _) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Insets.lg),
              TextField(
                key: const Key('adguard-list-url'),
                controller: _url,
                onChanged: (String _) => setState(() {}),
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'https://',
                  helperText: 'A list on the web, or the full path of a file '
                      'on the server.',
                  helperMaxLines: 3,
                  errorText: problem,
                  errorMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (fetching) ...<Widget>[
                const SizedBox(height: Insets.lg),
                Text(
                  'Fetching the list. A large one can take a while.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
