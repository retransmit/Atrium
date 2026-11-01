import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_blocking.dart';
import '../adguard_home_errors.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_filtering.dart';
import '../models/adguard_home_filters.dart';
import '../models/adguard_home_query_log.dart';
import '../models/adguard_home_services.dart';
import 'adguard_home_check_client_picker.dart';
import 'adguard_home_fields.dart';
import 'adguard_home_result_chip.dart';

/// Asks the server what it would do with [name], and shows the answer in a
/// sheet with Block or Unblock.
Future<void> showAdguardHomeHostCheck(
  BuildContext context, {
  required Instance instance,
  required String name,
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
    builder: (BuildContext _) =>
        AdguardHomeHostCheckSheet(instance: instance, name: name),
  );
}

/// What the server would do with a name, in the web UI's words: the
/// result, the rules that matched and their lists, a blocked service, a
/// CNAME or addresses.
class AdguardHomeHostCheckSheet extends ConsumerStatefulWidget {
  const AdguardHomeHostCheckSheet({
    required this.instance,
    required this.name,
    super.key,
  });

  final Instance instance;
  final String name;

  @override
  ConsumerState<AdguardHomeHostCheckSheet> createState() =>
      _AdguardHomeHostCheckSheetState();
}

class _AdguardHomeHostCheckSheetState
    extends ConsumerState<AdguardHomeHostCheckSheet> {
  AdguardHomeHostCheck? _check;
  Object? _error;

  /// Whom the name is checked for. A client can have its own blocked
  /// services, schedule, protection and rules.
  AdguardHomeCheckClient _client = AdguardHomeCheckClient.any;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  Future<void> _ask() async {
    final AdguardHomeCheckClient client = _client;
    try {
      final AdguardHomeHostCheck check = await ref
          .read(adguardHomeActionsProvider(widget.instance))
          .checkHost(widget.name, client: client.address);
      // An answer for whom it is no longer asked about is dropped.
      if (mounted && identical(client, _client)) {
        setState(() => _check = check);
      }
    } on Object catch (error) {
      if (mounted && identical(client, _client)) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _pickClient() async {
    final AdguardHomeCheckClient? picked = await pickAdguardHomeCheckClient(
      context,
      instance: widget.instance,
      current: _client,
    );
    if (picked == null || !mounted || picked.address == _client.address) {
      return;
    }
    setState(() {
      _client = picked;
      _check = null;
      _error = null;
    });
    await _ask();
  }

  /// Asks again. After a refused sign-in the session sends nothing until
  /// it is asked to, and this is the asking: without it the button would
  /// only get the same refusal back, without a word to the server.
  void _retry() {
    if (_error is AdguardHomeSignInRefused) {
      ref.read(adguardHomeActionsProvider(widget.instance)).retrySignIn();
    }
    setState(() => _error = null);
    _ask();
  }

  void _toggle(AdguardHomeHostCheck check) {
    unawaited(
      adguardHomeToggleBlocking(
        context,
        ref,
        widget.instance,
        check.name,
        block: !check.isFiltered,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AdguardHomeHostCheck? check = _check;
    final Object? error = _error;
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
                  widget.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.devices_other),
                  title: const Text('Checked for'),
                  subtitle: Text(_client.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickClient,
                ),
                if (check != null)
                  ..._result(theme, check)
                else if (error != null) ...<Widget>[
                  Text(
                    describeAdguardHomeError(error),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: Insets.sm),
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
        if (check != null && _offersAction(check)) ...<Widget>[
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: FilledButton.tonal(
                onPressed: () => _toggle(check),
                child: Text(check.isFiltered ? 'Unblock' : 'Block'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Safe search, safe browsing and parental control are not rules the
  /// custom rules can turn around, so the web UI offers no button for them.
  static bool _offersAction(AdguardHomeHostCheck check) => switch (check.result) {
        AdguardHomeQueryResult.safeSearch ||
        AdguardHomeQueryResult.blockedThreat ||
        AdguardHomeQueryResult.blockedParental =>
          false,
        _ => true,
      };

  List<Widget> _result(ThemeData theme, AdguardHomeHostCheck check) {
    final AdguardHomeQueryResult result = check.result;
    final AdguardHomeFiltering? filtering =
        ref.watch(adguardHomeFilteringProvider(widget.instance)).value;
    // Read only to name a blocked service.
    final AdguardHomeServiceCatalogue? catalogue = check.serviceName.isEmpty
        ? null
        : ref.watch(adguardHomeServicesProvider(widget.instance)).value;
    return <Widget>[
      AdguardHomeResultChip(
        label: result == AdguardHomeQueryResult.other
            ? check.reason
            : result.label,
        tone: result.tone,
      ),
      if (check.serviceName.isNotEmpty)
        AdguardHomeField(
          'Service',
          catalogue?.nameOf(check.serviceName) ?? check.serviceName,
        ),
      if (check.rules.isNotEmpty)
        AdguardHomeBlock(
          check.rules.length == 1 ? 'Rule' : 'Rules',
          <Widget>[
            for (final AdguardHomeMatchedRule rule in check.rules) ...<Widget>[
              Text(
                rule.text,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontFamily: 'monospace'),
              ),
              Text(
                adguardHomeFilterListName(filtering, rule.listId),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        )
      else if (result == AdguardHomeQueryResult.processed)
        Padding(
          padding: const EdgeInsets.only(top: Insets.sm),
          child: Text(
            'No rule matches this name.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      AdguardHomeField('CNAME', check.cname),
      AdguardHomeField('Addresses', check.ipAddresses.join('\n')),
    ];
  }
}
