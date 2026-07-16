import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sonarr/service_sonarr.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

class _RecentDownloadItem {
  const _RecentDownloadItem({
    required this.title,
    required this.date,
    required this.isMovie,
    required this.instance,
    this.posterUrl,
    this.subtitle,
  });

  final String title;
  final DateTime date;
  final bool isMovie;
  final Instance instance;
  final String? posterUrl;
  final String? subtitle;
}

/// The most recently downloaded Sonarr series and Radarr movies across every
/// instance, merged and shown as a horizontally scrollable poster row.
class DashboardRecentlyDownloadedWidget extends ConsumerWidget {
  const DashboardRecentlyDownloadedWidget({
    required this.sonarrInstances,
    required this.radarrInstances,
    super.key,
  });

  final List<Instance> sonarrInstances;
  final List<Instance> radarrInstances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final List<_RecentDownloadItem> items = <_RecentDownloadItem>[];
    bool anyLoading = false;
    bool anyError = false;

    for (final Instance i in sonarrInstances) {
      final AsyncValue<List<SonarrHistoryItem>> history =
          ref.watch(sonarrHistoryProvider(i));
      anyLoading |= history.isLoading && !history.hasValue;
      anyError |= history.hasError;
      for (final SonarrHistoryItem h in history.value ?? const <SonarrHistoryItem>[]) {
        final DateTime? date = DateTime.tryParse(h.date ?? '');
        if (date == null || h.series == null) {
          continue;
        }
        items.add(_RecentDownloadItem(
          title: h.episode?.title ?? h.series!.title,
          date: date,
          isMovie: false,
          instance: i,
          subtitle: h.episode != null ? h.series!.title : null,
          posterUrl: h.series!.images
              .firstWhereOrNull((SonarrImage im) => im.coverType == 'poster')
              ?.remoteUrl,
        ));
      }
    }
    for (final Instance i in radarrInstances) {
      final AsyncValue<List<RadarrHistoryItem>> history =
          ref.watch(radarrHistoryProvider(i));
      anyLoading |= history.isLoading && !history.hasValue;
      anyError |= history.hasError;
      for (final RadarrHistoryItem h in history.value ?? const <RadarrHistoryItem>[]) {
        final DateTime? date = DateTime.tryParse(h.date ?? '');
        if (date == null || h.movie == null) {
          continue;
        }
        items.add(_RecentDownloadItem(
          title: h.movie!.title,
          date: date,
          isMovie: true,
          instance: i,
          subtitle: h.movie!.year?.toString(),
          posterUrl: h.movie!.images
              .firstWhereOrNull((RadarrImage im) => im.coverType == 'poster')
              ?.remoteUrl,
        ));
      }
    }

    items.sort((_RecentDownloadItem a, _RecentDownloadItem b) => b.date.compareTo(a.date));
    final List<_RecentDownloadItem> top = items.take(15).toList();

    Widget body;
    if (items.isEmpty && anyLoading) {
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
    } else if (items.isEmpty && anyError) {
      body = DashboardErrorRow(
        onRetry: () {
          for (final Instance i in sonarrInstances) {
            ref.invalidate(sonarrHistoryProvider(i));
          }
          for (final Instance i in radarrInstances) {
            ref.invalidate(radarrHistoryProvider(i));
          }
        },
      );
    } else if (items.isEmpty) {
      body = const DashboardIdleRow(text: 'No recent downloads found');
    } else {
      body = SizedBox(
        height: 184,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: top.length,
          separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
          itemBuilder: (BuildContext context, int index) {
            final _RecentDownloadItem item = top[index];
            return SizedBox(
              width: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Material(
                        color: cs.surfaceContainerHigh,
                        clipBehavior: Clip.antiAlias,
                        borderRadius: BorderRadius.circular(Insets.sm),
                        child: InkWell(
                          onTap: () {
                            context.go(AtriumRoutes.servicePath(
                              item.instance.kind.name,
                              item.instance.id,
                            ));
                          },
                          child: item.posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: item.posterUrl!,
                                  fit: BoxFit.cover,
                                  httpHeaders: switch (
                                      item.instance.auth) {
                                    InstanceAuthApiKey(:final String apiKey) =>
                                      <String, String>{
                                        'X-Api-Key': apiKey
                                      },
                                    _ => const <String, String>{},
                                  },
                                  errorWidget: (_, __, ___) => Icon(
                                    item.isMovie
                                        ? Icons.movie
                                        : Icons.tv,
                                    color: cs.onSurfaceVariant,
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    item.isMovie
                                        ? Icons.movie
                                        : Icons.tv,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.recentlyDownloaded,
      accent: cs.primary,
      child: body,
    );
  }
}
