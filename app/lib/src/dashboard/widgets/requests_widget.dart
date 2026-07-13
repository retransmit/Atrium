import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_seerr/service_seerr.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

class _PendingRequest {
  const _PendingRequest({required this.request, required this.instance});

  final SeerrRequest request;
  final Instance instance;
}

/// Seerr requests awaiting approval: count plus the newest titles.
class DashboardRequestsWidget extends ConsumerWidget {
  const DashboardRequestsWidget({required this.instances, super.key});

  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    int pendingCount = 0;
    final List<_PendingRequest> pending = <_PendingRequest>[];
    bool anyLoading = false;
    bool anyError = false;

    for (final Instance i in instances) {
      final AsyncValue<SeerrCounts> counts =
          ref.watch(seerrRequestCountsProvider(i));
      anyLoading |= counts.isLoading && !counts.hasValue;
      anyError |= counts.hasError;
      pendingCount += counts.valueOrNull?.pending ?? 0;

      final List<SeerrRequest> requests =
          ref.watch(seerrRequestsProvider(i)).valueOrNull ??
              const <SeerrRequest>[];
      for (final SeerrRequest r in requests) {
        // Request status 1 = pending approval.
        if (r.status == 1) {
          pending.add(_PendingRequest(request: r, instance: i));
        }
      }
    }

    pending.sort((_PendingRequest a, _PendingRequest b) {
      final DateTime da =
          DateTime.tryParse(a.request.createdAt ?? '') ?? DateTime(1970);
      final DateTime db =
          DateTime.tryParse(b.request.createdAt ?? '') ?? DateTime(1970);
      return db.compareTo(da);
    });
    final List<_PendingRequest> top = pending.take(2).toList();

    Widget body;
    if (pendingCount == 0 && pending.isEmpty && anyLoading) {
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
    } else if (pendingCount == 0 && pending.isEmpty && anyError) {
      body = DashboardErrorRow(
        onRetry: () {
          for (final Instance i in instances) {
            ref.invalidate(seerrRequestCountsProvider(i));
            ref.invalidate(seerrRequestsProvider(i));
          }
        },
      );
    } else if (pendingCount == 0 && pending.isEmpty) {
      body = const DashboardIdleRow(text: 'No pending requests');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final _PendingRequest p in top) _RequestRow(pending: p),
          if (pending.length > top.length)
            DashboardIdleRow(text: '+${pending.length - top.length} more'),
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
      trailing: pendingCount > 0
          ? DashboardPill(
              icon: Icons.hourglass_top_rounded,
              label: '$pendingCount pending',
              color: cs.secondary,
            )
          : null,
      child: body,
    );
  }
}

class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.pending});

  final _PendingRequest pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SeerrRequest r = pending.request;

    // Resolve the title like the Seerr requests tab does; fall back to the
    // request type while it loads or when there is no tmdb id.
    final int? tmdbId = r.media?.tmdbId;
    String title = r.type == 'movie' ? 'Movie request' : 'Series request';
    if (tmdbId != null) {
      final String mediaType =
          r.media!.mediaType.isNotEmpty ? r.media!.mediaType : r.type;
      final SeerrDiscoverResult? details = ref
          .watch(seerrMediaDetailsProvider(
            (instance: pending.instance, mediaType: mediaType, tmdbId: tmdbId),
          ))
          .valueOrNull;
      if (details != null) {
        title = details.displayTitle;
      }
    }
    final String by = r.requestedBy?.displayName ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: <Widget>[
          Icon(
            r.type == 'movie' ? Icons.movie_outlined : Icons.live_tv_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              by.isEmpty ? title : '$title - $by',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
