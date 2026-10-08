import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../adguard_home_blocking.dart';
import '../adguard_home_format.dart';
import '../adguard_home_log_actions.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_filtering.dart';
import '../models/adguard_home_query_log.dart';
import 'adguard_home_client_sheet.dart';
import 'adguard_home_fields.dart';
import 'adguard_home_result_chip.dart';

/// Opens everything [entry] carries in a sheet, with what can be done about
/// it. [onChanged] is called when the client was shut out or let back in:
/// the log then says something else about every entry of that client.
Future<void> showAdguardHomeQueryDetail(
  BuildContext context, {
  required Instance instance,
  required AdguardHomeQueryLogEntry entry,
  VoidCallback? onChanged,
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
    builder: (BuildContext _) => AdguardHomeQueryDetail(
      instance: instance,
      entry: entry,
      onChanged: onChanged,
    ),
  );
}

/// What the menu beside the main action offers for the entry's client.
enum _ClientAction { show, blockForClient, access }

/// One query in full: the request, the response and the client, over the
/// web UI's three actions.
///
/// The actions sit under the scrolling part rather than at the end of it,
/// so Block is in reach however much the entry carries.
class AdguardHomeQueryDetail extends ConsumerStatefulWidget {
  const AdguardHomeQueryDetail({
    required this.instance,
    required this.entry,
    this.onChanged,
    super.key,
  });

  final Instance instance;
  final AdguardHomeQueryLogEntry entry;
  final VoidCallback? onChanged;

  @override
  ConsumerState<AdguardHomeQueryDetail> createState() =>
      _AdguardHomeQueryDetailState();
}

class _AdguardHomeQueryDetailState
    extends ConsumerState<AdguardHomeQueryDetail> {
  /// Whether a change to the client's access is being asked about or
  /// written. Nothing else can be started from the sheet meanwhile.
  bool _busy = false;

  Instance get instance => widget.instance;

  AdguardHomeQueryLogEntry get entry => widget.entry;

  /// Blocks or unblocks the name, for everyone or for [clientAddress].
  void _block({String? clientAddress}) {
    // What the change needs is taken from this context before anything is
    // awaited, so the sheet can close at once and the result is said on the
    // screen behind it.
    unawaited(
      adguardHomeToggleBlocking(
        context,
        ref,
        instance,
        entry.domain,
        block: !entry.isFiltered,
        clientAddress: clientAddress,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _access() async {
    // Both are taken now. By the time the server has answered the sheet may
    // have been closed, and then "the route on top" is the screen itself.
    final ModalRoute<Object?>? sheet = ModalRoute.of(context);
    final VoidCallback? onChanged = widget.onChanged;
    setState(() => _busy = true);
    final bool changed = await adguardHomeToggleClientAccess(
      context,
      ref,
      instance,
      address: entry.client,
      disallowed: entry.clientDisallowed,
      // The server fills this in for every client. It only names what shuts
      // a client out while the client is shut out.
      disallowedRule: entry.clientDisallowed ? entry.clientDisallowedRule : '',
    );
    if (changed) {
      // Only this sheet, and only if it is still what is showing.
      if (sheet != null && sheet.isCurrent) sheet.navigator?.pop();
      onChanged?.call();
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AdguardHomeFiltering? filtering =
        ref.watch(adguardHomeFilteringProvider(instance)).value;
    final String name =
        entry.clientName.isNotEmpty ? entry.clientName : entry.clientId;
    final String action = entry.isFiltered ? 'Unblock' : 'Block';
    // A query for the root has no name, and a rule for no name is "||^".
    final bool named = entry.domain.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      // The scrolling part is as wide as the sheet, not as its widest line,
      // so a short entry is not centred.
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
                  entry.displayName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (entry.unicodeName.isNotEmpty)
                  Text(
                    entry.domain,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                const SizedBox(height: Insets.sm),
                AdguardHomeResultChip(
                  label: entry.resultLabel,
                  tone: entry.result.tone,
                ),
                const AdguardHomeHeading('Request'),
                AdguardHomeField(
                  'Time',
                  formatAdguardHomeLogMoment(entry.time),
                ),
                AdguardHomeField('Type', entry.type),
                AdguardHomeField(
                  'Protocol',
                  adguardHomeProtocolLabel(entry.protocol),
                ),
                const AdguardHomeHeading('Response'),
                AdguardHomeField('Response code', entry.status),
                AdguardHomeField('Blocked service', entry.serviceName),
                AdguardHomeField('DNS server', entry.upstream),
                if (entry.cached)
                  const AdguardHomeField('Served from cache', 'Yes'),
                if (entry.dnssec)
                  const AdguardHomeField('Validated with DNSSEC', 'Yes'),
                AdguardHomeField(
                  'Elapsed',
                  formatAdguardHomeElapsed(entry.elapsed),
                ),
                if (entry.rules.isNotEmpty)
                  AdguardHomeBlock(
                    entry.rules.length == 1 ? 'Rule' : 'Rules',
                    <Widget>[
                      for (final AdguardHomeMatchedRule rule
                          in entry.rules) ...<Widget>[
                        Text(rule.text, style: _mono(theme)),
                        Text(
                          adguardHomeFilterListName(filtering, rule.listId),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                if (entry.answers.isNotEmpty)
                  AdguardHomeBlock('Response', _records(theme, entry.answers)),
                if (entry.originalAnswers.isNotEmpty)
                  AdguardHomeBlock(
                    'Original response',
                    _records(theme, entry.originalAnswers),
                  ),
                if (entry.client.isNotEmpty || name.isNotEmpty) ...<Widget>[
                  const AdguardHomeHeading('Client'),
                  AdguardHomeField('IP address', entry.client),
                  AdguardHomeField('Name', name),
                  AdguardHomeField('Country', entry.clientCountry),
                  AdguardHomeField('City', entry.clientCity),
                  AdguardHomeField('Network', entry.clientNetwork),
                  if (entry.clientDisallowed)
                    Padding(
                      padding: const EdgeInsets.only(top: Insets.sm),
                      child: Text(
                        entry.clientDisallowedRule.isEmpty
                            ? 'Not among the allowed clients'
                            : 'Disallowed by ${entry.clientDisallowedRule}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.error),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (_busy)
          const LinearProgressIndicatorM3E(
            size: LinearProgressM3ESize.s,
            shape: ProgressM3EShape.flat,
          )
        else
          const Divider(height: 1),
        SafeArea(
          top: false,
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
                  child: FilledButton.tonal(
                    onPressed: named && !_busy ? _block : null,
                    child: Text(action),
                  ),
                ),
                if (entry.client.isEmpty)
                  const SizedBox(width: Insets.sm)
                else
                  PopupMenuButton<_ClientAction>(
                    tooltip: 'More actions',
                    useRootNavigator: true,
                    enabled: !_busy,
                    onSelected: (_ClientAction chosen) {
                      switch (chosen) {
                        case _ClientAction.show:
                          // Over this sheet, which is there to come back
                          // to: who the client is, and a way to its
                          // settings or to making it a persistent one.
                          unawaited(
                            showAdguardHomeClientSheet(
                              context,
                              instance: instance,
                              address: entry.client,
                            ),
                          );
                        case _ClientAction.blockForClient:
                          _block(clientAddress: entry.client);
                        case _ClientAction.access:
                          unawaited(_access());
                      }
                    },
                    itemBuilder: (BuildContext _) =>
                        <PopupMenuEntry<_ClientAction>>[
                      const PopupMenuItem<_ClientAction>(
                        value: _ClientAction.show,
                        child: Text('Show client'),
                      ),
                      PopupMenuItem<_ClientAction>(
                        value: _ClientAction.blockForClient,
                        enabled: named,
                        child: Text('$action for this client only'),
                      ),
                      PopupMenuItem<_ClientAction>(
                        value: _ClientAction.access,
                        child: Text(
                          entry.clientDisallowed
                              ? 'Allow this client'
                              : 'Disallow this client',
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static TextStyle? _mono(ThemeData theme) =>
      theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');

  /// Each record as the web UI writes it.
  static List<Widget> _records(
    ThemeData theme,
    List<AdguardHomeDnsAnswer> answers,
  ) =>
      <Widget>[
        for (final AdguardHomeDnsAnswer answer in answers)
          Text(
            '${answer.type}: ${answer.value} (ttl=${answer.ttl})',
            style: _mono(theme),
          ),
      ];
}
