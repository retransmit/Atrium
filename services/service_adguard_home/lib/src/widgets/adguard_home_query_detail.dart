import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_blocking.dart';
import '../adguard_home_format.dart';
import '../adguard_home_log_actions.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_filtering.dart';
import '../models/adguard_home_query_log.dart';
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
enum _ClientAction { blockForClient, access }

/// One query in full: the request, the response and the client, over the
/// web UI's three actions.
///
/// The actions sit under the scrolling part rather than at the end of it,
/// so Block is in reach however much the entry carries.
class AdguardHomeQueryDetail extends ConsumerWidget {
  const AdguardHomeQueryDetail({
    required this.instance,
    required this.entry,
    this.onChanged,
    super.key,
  });

  final Instance instance;
  final AdguardHomeQueryLogEntry entry;
  final VoidCallback? onChanged;

  /// Blocks or unblocks the name, for everyone or for [clientAddress].
  void _block(BuildContext context, WidgetRef ref, {String? clientAddress}) {
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

  Future<void> _access(BuildContext context, WidgetRef ref) async {
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
    if (!changed) return;
    if (context.mounted) Navigator.of(context).pop();
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AdguardHomeFiltering? filtering =
        ref.watch(adguardHomeFilteringProvider(instance)).value;
    final String name =
        entry.clientName.isNotEmpty ? entry.clientName : entry.clientId;
    final String action = entry.isFiltered ? 'Unblock' : 'Block';

    return Column(
      mainAxisSize: MainAxisSize.min,
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
                const _Heading('Request'),
                _Field('Time', formatAdguardHomeLogMoment(entry.time)),
                _Field('Type', entry.type),
                _Field('Protocol', adguardHomeProtocolLabel(entry.protocol)),
                const _Heading('Response'),
                _Field('Response code', entry.status),
                _Field('Blocked service', entry.serviceName),
                _Field('DNS server', entry.upstream),
                if (entry.cached) const _Field('Served from cache', 'Yes'),
                if (entry.dnssec)
                  const _Field('Validated with DNSSEC', 'Yes'),
                _Field('Elapsed', formatAdguardHomeElapsed(entry.elapsed)),
                if (entry.rules.isNotEmpty)
                  _Block(
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
                  _Block('Response', _records(theme, entry.answers)),
                if (entry.originalAnswers.isNotEmpty)
                  _Block(
                    'Original response',
                    _records(theme, entry.originalAnswers),
                  ),
                if (entry.client.isNotEmpty || name.isNotEmpty) ...<Widget>[
                  const _Heading('Client'),
                  _Field('IP address', entry.client),
                  _Field('Name', name),
                  _Field('Country', entry.clientCountry),
                  _Field('City', entry.clientCity),
                  _Field('Network', entry.clientNetwork),
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
                    onPressed: () => _block(context, ref),
                    child: Text(action),
                  ),
                ),
                if (entry.client.isEmpty)
                  const SizedBox(width: Insets.sm)
                else
                  PopupMenuButton<_ClientAction>(
                    tooltip: 'More actions',
                    useRootNavigator: true,
                    onSelected: (_ClientAction chosen) {
                      switch (chosen) {
                        case _ClientAction.blockForClient:
                          _block(context, ref, clientAddress: entry.client);
                        case _ClientAction.access:
                          unawaited(_access(context, ref));
                      }
                    },
                    itemBuilder: (BuildContext _) =>
                        <PopupMenuEntry<_ClientAction>>[
                      PopupMenuItem<_ClientAction>(
                        value: _ClientAction.blockForClient,
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

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// A name with what belongs to it underneath. One over the other rather
/// than side by side, so a long value has the width of the sheet at any
/// text size.
class _Block extends StatelessWidget {
  const _Block(this.label, this.children);

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Insets.xxs),
          ...children,
        ],
      ),
    );
  }
}

/// A name and one value. Leaves itself out when there is no value.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return _Block(
      label,
      <Widget>[Text(value, style: Theme.of(context).textTheme.bodyMedium)],
    );
  }
}
