import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../adguard_home_clients_view.dart';
import '../adguard_home_format.dart';
import '../models/adguard_home_clients.dart';

/// A small label on a client's row: a tag, where it was learned, or a note
/// that it has something of its own.
class AdguardHomeClientMark extends StatelessWidget {
  const AdguardHomeClientMark(this.label, {this.strong = false, super.key});

  final String label;

  /// Filled in rather than outlined: for what sets the client apart, as
  /// against what merely describes it.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: BoxDecoration(
        color: strong ? cs.secondaryContainer : null,
        border: strong ? null : Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: strong ? cs.onSecondaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// How much a client asked, at the end of its row.
class _Queries extends StatelessWidget {
  const _Queries(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // A long figure shrinks rather than push the row past its width.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              formatAdguardHomeCount(count),
              style: theme.textTheme.labelLarge,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              'queries',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// What both kinds of row are built on: a name over lines of detail and a
/// run of marks, with the queries at the end.
class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.title,
    required this.details,
    required this.marks,
    required this.queries,
    required this.onTap,
  });

  final String title;
  final List<String> details;
  final List<Widget> marks;
  final int? queries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final int? queries = this.queries;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  for (final String detail in details)
                    Padding(
                      padding: const EdgeInsets.only(top: Insets.xxs),
                      child: Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  if (marks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Insets.sm),
                      child: Wrap(
                        spacing: Insets.xs,
                        runSpacing: Insets.xs,
                        children: marks,
                      ),
                    ),
                ],
              ),
            ),
            if (queries != null) ...<Widget>[
              const SizedBox(width: Insets.md),
              _Queries(queries),
            ],
          ],
        ),
      ),
    );
  }
}

/// A persistent client in the list: its name, what it goes by, its tags,
/// what it has of its own, and its queries where the statistics have them.
class AdguardHomePersistentClientRow extends StatelessWidget {
  const AdguardHomePersistentClientRow({
    required this.row,
    required this.onTap,
    super.key,
  });

  final AdguardHomePersistentRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AdguardHomeClient client = row.client;
    return _ClientRow(
      title: client.name,
      details: <String>[if (client.ids.isNotEmpty) client.ids.join(', ')],
      marks: <Widget>[
        for (final String tag in client.tags) AdguardHomeClientMark(tag),
        if (!client.useGlobalSettings)
          const AdguardHomeClientMark('Own settings', strong: true),
        // Its own list, even an empty one: then it is exempt from what the
        // server blocks for everyone.
        if (!client.useGlobalBlockedServices)
          AdguardHomeClientMark(
            adguardHomeServicesBlockedLabel(client.blockedServices.length),
            strong: true,
          ),
        if (client.upstreams.isNotEmpty)
          const AdguardHomeClientMark('Own upstreams', strong: true),
        // Both explain a missing or a small count.
        if (client.ignoreQueryLog)
          const AdguardHomeClientMark('Not in the query log', strong: true),
        if (client.ignoreStatistics)
          const AdguardHomeClientMark('Not in statistics', strong: true),
      ],
      queries: row.queries,
      onTap: onTap,
    );
  }
}

/// A runtime client in the list: the name the server found for it, its
/// address, where it was learned, and whose it is when it is somebody's.
class AdguardHomeRuntimeClientRow extends StatelessWidget {
  const AdguardHomeRuntimeClientRow({
    required this.row,
    required this.onTap,
    super.key,
  });

  final AdguardHomeRuntimeRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AdguardHomeRuntimeClient client = row.client;
    final String? owner = row.owner;
    final String source = adguardHomeClientSourceLabel(client.source);
    final String whois = client.whoisLine;
    return _ClientRow(
      title: client.name.isEmpty ? client.address : client.name,
      details: <String>[
        if (client.name.isNotEmpty) client.address,
        if (whois.isNotEmpty) whois,
      ],
      marks: <Widget>[
        if (source.isNotEmpty) AdguardHomeClientMark(source),
        if (owner != null) AdguardHomeClientMark(owner, strong: true),
      ],
      queries: row.queries,
      onTap: onTap,
    );
  }
}
