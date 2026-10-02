import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ombi_models.dart';
import '../ombi_strings.dart';
import 'ombi_status_badge.dart';
import 'ombi_visuals.dart';

/// One request as a card: poster, title, who asked and when, where it
/// stands, and what can be done about it.
///
/// A pending request carries Deny and Approve across its foot, since that
/// is what you most often want from a phone. Every card has a menu with
/// Delete, and tapping the card opens the title it is about.
class OmbiRequestCard extends StatelessWidget {
  const OmbiRequestCard({
    required this.request,
    required this.onApprove,
    required this.onDeny,
    required this.onDelete,
    this.onOpen,
    super.key,
  });

  final OmbiRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback onDelete;

  /// Opens the title the request is about. Null where there is no title
  /// page to open, which is every album.
  final VoidCallback? onOpen;

  bool get _pending => request.status == OmbiRequestStatus.pending;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle? quiet =
        theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final String? byLine = _byLine();
    final String? episodes = ombiEpisodesLine(request);
    // Ombi leaves the reason on a request whose denial was later overturned,
    // so it is only said where the card says Denied.
    final String? deniedReason = request.status == OmbiRequestStatus.denied
        ? request.deniedReason
        : null;
    final int? year = request.year;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  OmbiPoster(
                    url: request.posterUrl,
                    kind: request.kind,
                    width: 76,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text.rich(
                          TextSpan(
                            text: request.title,
                            children: <InlineSpan>[
                              if (year != null)
                                TextSpan(
                                  text: '  $year',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (byLine != null) ...<Widget>[
                          const SizedBox(height: Insets.xxs),
                          Text(
                            byLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: quiet,
                          ),
                        ],
                        const SizedBox(height: Insets.sm),
                        Wrap(
                          spacing: Insets.xs,
                          runSpacing: Insets.xs,
                          children: <Widget>[
                            OmbiStatusBadge(status: request.status),
                            if (request.has4K) const OmbiFourKBadge(),
                          ],
                        ),
                        if (episodes != null) ...<Widget>[
                          const SizedBox(height: Insets.sm),
                          Text(episodes, style: quiet),
                        ],
                        if (deniedReason != null) ...<Widget>[
                          const SizedBox(height: Insets.sm),
                          // In the Denied pill's colour, so it reads as the
                          // reason and not as one more line about the title.
                          Text(
                            deniedReason,
                            style: quiet?.copyWith(color: cs.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (String action) {
                      if (action == 'approve') {
                        onApprove();
                      } else if (action == 'deny') {
                        onDeny();
                      } else {
                        onDelete();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      if (_pending) ...const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'approve',
                          child: Text('Approve'),
                        ),
                        PopupMenuItem<String>(
                          value: 'deny',
                          child: Text('Deny'),
                        ),
                      ],
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              if (_pending) ...<Widget>[
                const SizedBox(height: Insets.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDeny,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Deny'),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _byLine() {
    final DateTime? at = request.requestedAt;
    final List<String> parts = <String>[
      if (request.requestedBy != null) request.requestedBy!,
      if (at != null) _ago(at, DateTime.now()),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

String _ago(DateTime when, DateTime now) {
  final Duration d = now.difference(when);
  if (d.inMinutes < 1) {
    return 'just now';
  }
  if (d.inHours < 1) {
    return '${d.inMinutes}m ago';
  }
  if (d.inDays < 1) {
    return '${d.inHours}h ago';
  }
  if (d.inDays < 30) {
    return '${d.inDays}d ago';
  }
  return DateFormat.yMMMd().format(when.toLocal());
}
