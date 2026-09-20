import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_ombi/service_ombi.dart';
import 'package:service_seerr/service_seerr.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// One row on the widget, whichever service it came from.
sealed class _Entry {
  const _Entry(this.instance);

  final Instance instance;

  DateTime get at;
}

class _SeerrEntry extends _Entry {
  const _SeerrEntry(super.instance, this.request);

  final SeerrRequest request;

  @override
  DateTime get at =>
      DateTime.tryParse(request.createdAt ?? '') ?? DateTime(1970);
}

class _OmbiEntry extends _Entry {
  const _OmbiEntry(super.instance, this.request);

  final OmbiRequest request;

  @override
  DateTime get at => request.requestedAt ?? DateTime(1970);
}

/// Recent requests across every Seerr and Ombi instance, newest first, each
/// with its poster and where it stands, not just the approval queue.
class DashboardRequestsWidget extends ConsumerWidget {
  const DashboardRequestsWidget({required this.instances, super.key});

  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    int totalRequested = 0;
    final List<_Entry> entries = <_Entry>[];
    bool anyLoading = false;
    bool anyError = false;

    for (final Instance i in instances) {
      switch (i.kind) {
        case ServiceKind.seerr:
          totalRequested +=
              ref.watch(seerrRequestCountsProvider(i)).value?.total ?? 0;
          final AsyncValue<List<SeerrRequest>> list =
              ref.watch(seerrRequestsProvider(i));
          anyLoading |= list.isLoading && !list.hasValue;
          anyError |= list.hasError;
          for (final SeerrRequest r in list.value ?? const <SeerrRequest>[]) {
            entries.add(_SeerrEntry(i, r));
          }
        case ServiceKind.ombi:
          totalRequested += ref.watch(ombiCountsProvider(i)).value?.total ?? 0;
          final AsyncValue<List<OmbiRequest>> list =
              ref.watch(ombiRecentRequestsProvider(i));
          anyLoading |= list.isLoading && !list.hasValue;
          anyError |= list.hasError;
          for (final OmbiRequest r in list.value ?? const <OmbiRequest>[]) {
            entries.add(_OmbiEntry(i, r));
          }
        default:
          break;
      }
    }

    entries.sort((_Entry a, _Entry b) => b.at.compareTo(a.at));
    final List<_Entry> top = entries.take(3).toList();

    Widget body;
    if (entries.isEmpty && anyLoading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.sm),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    } else if (entries.isEmpty && anyError) {
      body = DashboardErrorRow(
        onRetry: () {
          for (final Instance i in instances) {
            if (i.kind == ServiceKind.ombi) {
              ref
                ..invalidate(ombiCountsProvider(i))
                ..invalidate(ombiRecentRequestsProvider(i));
            } else {
              ref
                ..invalidate(seerrRequestCountsProvider(i))
                ..invalidate(seerrRequestsProvider(i));
            }
          }
        },
      );
    } else if (entries.isEmpty) {
      body = const DashboardIdleRow(text: 'No requests yet');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int j = 0; j < top.length; j++) ...<Widget>[
            if (j > 0) const SizedBox(height: Insets.sm),
            switch (top[j]) {
              final _SeerrEntry e => _SeerrRequestRow(entry: e),
              final _OmbiEntry e => _OmbiRequestRow(entry: e),
            },
          ],
          if (entries.length > top.length)
            Padding(
              padding: const EdgeInsets.only(top: Insets.sm),
              child: DashboardIdleRow(
                text: '+${entries.length - top.length} more',
              ),
            ),
        ],
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.requests,
      accent: cs.secondary,
      onTap: instances.length == 1
          ? () => context.go(
                AtriumRoutes.servicePath(
                  instances.first.kind.name,
                  instances.first.id,
                ),
              )
          : null,
      trailing: totalRequested > 0
          ? DashboardPill(
              icon: Icons.bookmark_added_outlined,
              label: '$totalRequested requested',
              color: cs.secondary,
            )
          : null,
      child: body,
    );
  }
}

/// A Seerr request, with its title and poster looked up the way the Seerr
/// requests tab does it.
class _SeerrRequestRow extends ConsumerWidget {
  const _SeerrRequestRow({required this.entry});

  final _SeerrEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final SeerrRequest r = entry.request;

    // Fall back to the request type while it loads or when there is no
    // TMDB id.
    final int? tmdbId = r.media?.tmdbId;
    String title = r.type == 'movie' ? 'Movie request' : 'Series request';
    String? posterPath;
    if (tmdbId != null) {
      final String mediaType =
          (r.media?.mediaType ?? '').isNotEmpty ? r.media!.mediaType : r.type;
      final SeerrDiscoverResult? details = ref
          .watch(
            seerrMediaDetailsProvider(
              (instance: entry.instance, mediaType: mediaType, tmdbId: tmdbId),
            ),
          )
          .value;
      if (details != null) {
        title = details.displayTitle;
        posterPath = details.posterPath;
      }
    }
    final SeerrApi? api = ref.watch(seerrApiProvider(entry.instance)).value;
    final (String label, Color color) = _status(r, cs);

    return _RequestRowShell(
      instance: entry.instance,
      title: title,
      posterUrl: api?.imageUrl(posterPath, size: 'w185'),
      fallbackIcon:
          r.type == 'movie' ? Icons.movie_outlined : Icons.live_tv_outlined,
      statusLabel: label,
      statusColor: color,
      by: r.requestedBy?.displayName ?? '',
    );
  }

  /// Approval status wins; otherwise the media's availability (1 unknown,
  /// 2 pending, 3 processing, 4 partial, 5 available).
  (String, Color) _status(SeerrRequest r, ColorScheme cs) {
    if (r.status == 3) {
      return ('Declined', cs.onSurfaceVariant);
    }
    if (r.status == 1) {
      return ('Needs approval', cs.primary);
    }
    return switch (r.media?.status ?? 1) {
      5 => ('Available', cs.tertiary),
      4 => ('Partial', cs.tertiary),
      3 => ('Processing', cs.secondary),
      _ => ('Requested', cs.onSurfaceVariant),
    };
  }
}

/// An Ombi request, worded the way Ombi's own Recently Requested cards word
/// it. Ombi's lists carry the title and poster already.
class _OmbiRequestRow extends StatelessWidget {
  const _OmbiRequestRow({required this.entry});

  final _OmbiEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final OmbiRequest r = entry.request;
    final String label = ombiRecentStatusLabel(r.recentStatus);
    final Color color = switch (r.recentStatus) {
      OmbiRecentStatus.pending => cs.primary,
      OmbiRecentStatus.approved => cs.secondary,
      OmbiRecentStatus.partlyAvailable ||
      OmbiRecentStatus.available =>
        cs.tertiary,
      OmbiRecentStatus.denied => cs.onSurfaceVariant,
    };
    return _RequestRowShell(
      instance: entry.instance,
      title: r.title,
      posterUrl: r.posterUrl,
      fallbackIcon: switch (r.kind) {
        OmbiMediaKind.movie => Icons.movie_outlined,
        OmbiMediaKind.tv => Icons.live_tv_outlined,
        OmbiMediaKind.music => Icons.album_outlined,
      },
      statusLabel: label,
      statusColor: color,
      by: r.requestedBy ?? '',
    );
  }
}

/// The row layout both services share: artwork thumb, title, a status chip
/// and who asked. Tapping it opens the instance.
class _RequestRowShell extends StatelessWidget {
  const _RequestRowShell({
    required this.instance,
    required this.title,
    required this.posterUrl,
    required this.fallbackIcon,
    required this.statusLabel,
    required this.statusColor,
    required this.by,
  });

  final Instance instance;
  final String title;
  final String? posterUrl;
  final IconData fallbackIcon;
  final String statusLabel;
  final Color statusColor;
  final String by;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Widget fallback = Container(
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, size: 18, color: cs.onSurfaceVariant),
    );
    final String? url = posterUrl;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go(
        AtriumRoutes.servicePath(instance.kind.name, instance.id),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 56,
              child: url == null
                  ? fallback
                  : AtriumNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      errorWidget: (_, __, ___) => fallback,
                    ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    _StatusChip(label: statusLabel, color: statusColor),
                    if (by.isNotEmpty) ...<Widget>[
                      const SizedBox(width: Insets.sm),
                      Flexible(
                        child: Text(
                          by,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact filled status chip for a request row.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
