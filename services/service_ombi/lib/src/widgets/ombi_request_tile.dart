import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ombi_models.dart';
import 'ombi_status_badge.dart';

/// One request: poster, title, who asked and when, where it stands, and
/// what can be done about it.
///
/// Pending requests get Approve and Deny right on the row, since that is
/// what you most often want from a phone. Every row has a menu with Delete.
class OmbiRequestTile extends StatelessWidget {
  const OmbiRequestTile({
    required this.request,
    required this.onApprove,
    required this.onDeny,
    required this.onDelete,
    super.key,
  });

  final OmbiRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback onDelete;

  bool get _pending => request.status == OmbiRequestStatus.pending;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? byLine = _byLine();
    final int? year = request.year;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 56, height: 84, child: _poster(cs)),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  year == null ? request.title : '${request.title} ($year)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (byLine != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    byLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: Insets.xs),
                Wrap(
                  spacing: Insets.xs,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    OmbiStatusBadge(status: request.status),
                    if (request.has4K) const OmbiFourKBadge(),
                  ],
                ),
                if (request.deniedReason != null) ...<Widget>[
                  const SizedBox(height: Insets.xs),
                  Text(
                    request.deniedReason!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (_pending) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    children: <Widget>[
                      FilledButton.tonal(
                        onPressed: onApprove,
                        child: const Text('Approve'),
                      ),
                      OutlinedButton(
                        onPressed: onDeny,
                        child: const Text('Deny'),
                      ),
                    ],
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
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (_pending) ...const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'approve', child: Text('Approve')),
                PopupMenuItem<String>(value: 'deny', child: Text('Deny')),
              ],
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _poster(ColorScheme cs) {
    final Widget fallback = Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        switch (request.kind) {
          OmbiMediaKind.movie => Icons.movie_outlined,
          OmbiMediaKind.tv => Icons.live_tv_outlined,
          OmbiMediaKind.music => Icons.album_outlined,
        },
        color: cs.onSurfaceVariant,
      ),
    );
    final String? url = request.posterUrl;
    if (url == null) {
      return fallback;
    }
    return AtriumNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 168,
      errorWidget: (_, __, ___) => fallback,
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
  return DateFormat.yMMMd().format(when);
}
