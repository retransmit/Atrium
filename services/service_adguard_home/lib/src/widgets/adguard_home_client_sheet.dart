import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_clients_view.dart';
import '../adguard_home_errors.dart';
import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_clients.dart';
import '../screens/adguard_home_client_screen.dart';
import 'adguard_home_fields.dart';

/// Opens a sheet that says who is behind [address], and offers to edit the
/// persistent client it belongs to or to make it one.
///
/// With a [lookup] the sheet shows that. Without one it asks the server
/// when it opens, which is how an address from the statistics or the query
/// log gets here. [queries] is shown when the caller knows them.
Future<void> showAdguardHomeClientSheet(
  BuildContext context, {
  required Instance instance,
  required String address,
  AdguardHomeClientLookup? lookup,
  int? queries,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (BuildContext _) => AdguardHomeClientSheet(
      instance: instance,
      address: address,
      lookup: lookup,
      queries: queries,
    ),
  );
}

/// One client: what it goes by, what the server knows of it, and the one
/// thing to do next.
class AdguardHomeClientSheet extends ConsumerStatefulWidget {
  const AdguardHomeClientSheet({
    required this.instance,
    required this.address,
    this.lookup,
    this.queries,
    super.key,
  });

  final Instance instance;
  final String address;

  /// What is already known. Null to have the sheet ask.
  final AdguardHomeClientLookup? lookup;
  final int? queries;

  @override
  ConsumerState<AdguardHomeClientSheet> createState() =>
      _AdguardHomeClientSheetState();
}

class _AdguardHomeClientSheetState
    extends ConsumerState<AdguardHomeClientSheet> {
  late AdguardHomeClientLookup? _lookup = widget.lookup;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.lookup == null) _find();
  }

  Future<void> _find() async {
    try {
      final AdguardHomeClientLookup lookup = await ref
          .read(adguardHomeActionsProvider(widget.instance))
          .findClient(widget.address, queries: widget.queries);
      if (mounted) setState(() => _lookup = lookup);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _find();
  }

  Future<void> _open(AdguardHomeClientLookup lookup) async {
    // Taken now: by the time the form is back, "the route on top" may be
    // something else.
    final ModalRoute<Object?>? sheet = ModalRoute.of(context);
    final AdguardHomeClient? client = lookup.persistent;
    final AdguardHomeClientOutcome? outcome = await adguardHomeEditClient(
      context,
      instance: widget.instance,
      supportedTags: lookup.supportedTags,
      client: client,
      name: client == null ? lookup.runtime?.name ?? '' : '',
      id: lookup.address,
    );
    // Saved or deleted, what this sheet says is no longer so.
    if (outcome != null && sheet != null && sheet.isCurrent) {
      sheet.navigator?.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AdguardHomeClientLookup? lookup = _lookup;
    final Object? error = _error;
    final String title = lookup?.title ?? widget.address;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Flexible(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (title != widget.address)
                  Text(
                    widget.address,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                if (lookup != null)
                  ..._details(theme, lookup)
                else if (error != null) ...<Widget>[
                  const SizedBox(height: Insets.lg),
                  Text(
                    describeAdguardHomeError(error),
                    style:
                        theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                  ),
                  const SizedBox(height: Insets.sm),
                  // After a refused sign-in this sends nothing: the session
                  // answers for the server until Try again is asked for.
                  FilledButton.tonalIcon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Insets.xl),
                    child: Center(child: ExpressiveProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
        if (lookup != null) ...<Widget>[
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.md,
                Insets.lg,
                Insets.md,
              ),
              child: lookup.persistent == null
                  ? FilledButton.icon(
                      onPressed: () => _open(lookup),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Add as persistent client'),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () => _open(lookup),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit client'),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _details(ThemeData theme, AdguardHomeClientLookup lookup) {
    final AdguardHomeClient? client = lookup.persistent;
    final AdguardHomeRuntimeClient? seen = lookup.runtime;
    final int? queries = lookup.queries;
    return <Widget>[
      if (queries != null)
        AdguardHomeField('Queries', formatAdguardHomeCount(queries)),
      if (client != null) ...<Widget>[
        const AdguardHomeHeading('Persistent client'),
        AdguardHomeField('Identifiers', client.ids.join('\n')),
        AdguardHomeField('Tags', client.tags.join(', ')),
        AdguardHomeField(
          'Settings',
          client.useGlobalSettings ? 'Global' : 'Its own',
        ),
        AdguardHomeField(
          'Blocked services',
          client.useGlobalBlockedServices
              ? 'Global'
              : adguardHomeServicesBlockedLabel(client.blockedServices.length),
        ),
        AdguardHomeField('Upstream servers', client.upstreams.join('\n')),
      ],
      if (seen != null &&
          (seen.name.isNotEmpty ||
              seen.source.isNotEmpty ||
              seen.whois.isNotEmpty)) ...<Widget>[
        const AdguardHomeHeading('Seen by the server'),
        // The sheet is already called this unless it has a client's name.
        if (seen.name != lookup.title) AdguardHomeField('Name', seen.name),
        AdguardHomeField(
          'Learned from',
          adguardHomeClientSourceLabel(seen.source),
        ),
        AdguardHomeField('WHOIS', seen.whoisLine),
      ],
      if (client == null)
        Padding(
          padding: const EdgeInsets.only(top: Insets.lg),
          child: Text(
            // Only on the server's word. A server too old to be asked
            // leaves the matching to this app, which cannot tell a device
            // that a client names by its MAC address.
            !lookup.serverSaid
                ? 'No persistent client lists it. This server cannot say '
                    'whether one that goes by a MAC address is this device.'
                : seen == null
                    ? 'AdGuard Home has no settings for it and has not seen '
                        'it under a name.'
                    : 'AdGuard Home has no settings for it. As a persistent '
                        'client it can have its own.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
    ];
  }
}
