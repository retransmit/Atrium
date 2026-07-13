import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_emby/service_emby.dart' as emby;
import 'package:service_jellyfin/service_jellyfin.dart' as jf;
import 'package:service_tautulli/service_tautulli.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:palette_generator/palette_generator.dart';

/// Live count of active sessions across every Tautulli, Jellyfin and Emby
/// instance. Instances still loading or in error contribute 0, so the
/// dashboard only surfaces the streams widget while someone is actually
/// watching.
final activeStreamCountProvider = Provider.autoDispose<int>((Ref ref) {
  final List<Instance> instances = ref.watch(activeInstancesProvider);
  int count = 0;
  for (final Instance i in instances) {
    switch (i.kind) {
      case ServiceKind.tautulli:
        count +=
            ref.watch(tautulliActivityProvider(i)).value?.sessions.length ?? 0;
      case ServiceKind.jellyfin:
        count += ref.watch(jf.jellyfinSessionsProvider(i)).value?.length ?? 0;
      case ServiceKind.emby:
        count += ref.watch(emby.embySessionsProvider(i)).value?.length ?? 0;
      default:
        break;
    }
  }
  return count;
});

class _StreamRow {
  const _StreamRow({
    required this.user,
    required this.title,
    required this.progress,
    required this.paused,
    required this.instance,
    this.device = '',
    this.posterUrl,
    this.backdropUrl,
    this.quality,
    this.transcoding = false,
    this.timeLabel,
  });

  final String user;
  final String title;
  final double progress;
  final bool paused;
  final Instance instance;

  /// Player / client the session is on (e.g. "Chrome", "Apple TV").
  final String device;
  final String? posterUrl;
  final String? backdropUrl;

  /// Stream resolution (e.g. "1080p"), when the backend reports it.
  final String? quality;

  /// Whether the server is transcoding the stream (vs direct play).
  final bool transcoding;

  /// Elapsed / total time (e.g. "12:04 / 45:00"), when available.
  final String? timeLabel;
}

/// "elapsed / total", or null when either side is missing.
String? _timeLabel(String position, String duration) {
  if (position.isEmpty || duration.isEmpty) {
    return null;
  }
  return '$position / $duration';
}

/// Active sessions across Tautulli, Jellyfin and Emby, each with its poster.
class DashboardStreamsWidget extends ConsumerWidget {
  const DashboardStreamsWidget({
    required this.tautulliInstances,
    required this.jellyfinInstances,
    required this.embyInstances,
    super.key,
  });

  final List<Instance> tautulliInstances;
  final List<Instance> jellyfinInstances;
  final List<Instance> embyInstances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final List<_StreamRow> rows = <_StreamRow>[];
    bool anyLoading = false;
    bool anyError = false;

    for (final Instance i in tautulliInstances) {
      final AsyncValue<TautulliActivity> activity =
          ref.watch(tautulliActivityProvider(i));
      anyLoading |= activity.isLoading && !activity.hasValue;
      anyError |= activity.hasError;
      final TautulliApi? api = ref.watch(tautulliApiProvider(i)).value;
      for (final TautulliSession s
          in activity.value?.sessions ?? const <TautulliSession>[]) {
        rows.add(_StreamRow(
          user: s.friendlyName,
          title: s.fullTitle,
          progress: (s.progressPercent / 100).clamp(0, 1).toDouble(),
          paused: s.state.toLowerCase() == 'paused',
          posterUrl: api?.imageUrl(s.posterThumb),
          backdropUrl: api?.imageUrl(s.art),
          device: s.player,
          quality: s.videoResolution.isEmpty ? null : s.videoResolution,
          transcoding: s.transcodeDecision.toLowerCase() == 'transcode',
          instance: i,
        ));
      }
    }
    for (final Instance i in jellyfinInstances) {
      final AsyncValue<List<jf.ActiveSession>> sessions =
          ref.watch(jf.jellyfinSessionsProvider(i));
      anyLoading |= sessions.isLoading && !sessions.hasValue;
      anyError |= sessions.hasError;
      for (final jf.ActiveSession s
          in sessions.value ?? const <jf.ActiveSession>[]) {
        rows.add(_StreamRow(
          user: s.user,
          title: s.episodeName == null
              ? s.showTitle
              : '${s.showTitle} - ${s.episodeName}',
          progress: (s.progressPercent / 100).clamp(0, 1).toDouble(),
          paused: s.status.toLowerCase() == 'paused',
          posterUrl: s.posterUrl,
          backdropUrl: s.backdropUrl,
          device: s.device,
          timeLabel: _timeLabel(s.timePosition, s.timeDuration),
          instance: i,
        ));
      }
    }
    for (final Instance i in embyInstances) {
      final AsyncValue<List<emby.ActiveSession>> sessions =
          ref.watch(emby.embySessionsProvider(i));
      anyLoading |= sessions.isLoading && !sessions.hasValue;
      anyError |= sessions.hasError;
      for (final emby.ActiveSession s
          in sessions.value ?? const <emby.ActiveSession>[]) {
        rows.add(_StreamRow(
          user: s.user,
          title: s.episodeName == null
              ? s.showTitle
              : '${s.showTitle} - ${s.episodeName}',
          progress: (s.progressPercent / 100).clamp(0, 1).toDouble(),
          paused: s.status.toLowerCase() == 'paused',
          posterUrl: s.posterUrl,
          backdropUrl: s.backdropUrl,
          device: s.device,
          timeLabel: _timeLabel(s.timePosition, s.timeDuration),
          instance: i,
        ));
      }
    }

    final List<_StreamRow> top = rows.take(3).toList();

    Widget body;
    if (rows.isEmpty && anyLoading) {
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
    } else if (rows.isEmpty && anyError) {
      body = DashboardErrorRow(onRetry: () => _refresh(ref));
    } else if (rows.isEmpty) {
      body = const DashboardIdleRow(text: 'No one is streaming');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int j = 0; j < top.length; j++) ...<Widget>[
            if (j > 0) const SizedBox(height: Insets.sm),
            _StreamBanner(row: top[j]),
          ],
          if (rows.length > top.length)
            Padding(
              padding: const EdgeInsets.only(top: Insets.sm),
              child:
                  DashboardIdleRow(text: '+${rows.length - top.length} more'),
            ),
        ],
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.streams,
      accent: cs.tertiary,
      trailing: rows.isNotEmpty
          ? DashboardPill(
              icon: Icons.play_arrow_rounded,
              label: '${rows.length} streaming',
              color: cs.tertiary,
            )
          : null,
      child: body,
    );
  }

  void _refresh(WidgetRef ref) {
    for (final Instance i in tautulliInstances) {
      ref.invalidate(tautulliActivityProvider(i));
    }
    for (final Instance i in jellyfinInstances) {
      ref.invalidate(jf.jellyfinSessionsProvider(i));
    }
    for (final Instance i in embyInstances) {
      ref.invalidate(emby.embySessionsProvider(i));
    }
  }
}

class _StreamBanner extends StatefulWidget {
  const _StreamBanner({required this.row});

  final _StreamRow row;

  @override
  State<_StreamBanner> createState() => _StreamBannerState();
}

class _StreamBannerState extends State<_StreamBanner> {
  PaletteGenerator? _palette;
  String? _lastPosterUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateColorScheme();
  }

  @override
  void didUpdateWidget(covariant _StreamBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.posterUrl != widget.row.posterUrl) {
      _updateColorScheme();
    }
  }

  void _updateColorScheme() {
    final String? posterUrl = widget.row.posterUrl;
    if (posterUrl == null || posterUrl == _lastPosterUrl) return;
    _lastPosterUrl = posterUrl;

    PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(posterUrl, maxWidth: 200, maxHeight: 300),
      size: const Size(200, 300),
    ).then((PaletteGenerator palette) {
      if (mounted) {
        setState(() {
          _palette = palette;
        });
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    if (_palette != null) {
      final Color dominant =
          _palette!.dominantColor?.color ?? theme.colorScheme.surface;
      final Color vibrant = _palette!.vibrantColor?.color ??
          _palette!.lightVibrantColor?.color ??
          dominant;
      theme = theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: vibrant,
        ),
      );
    }
    final ColorScheme cs = theme.colorScheme;
    final _StreamRow row = widget.row;

    final String? poster = row.posterUrl;
    final String? backdrop =
        (row.backdropUrl != null && row.backdropUrl!.trim().isNotEmpty)
            ? row.backdropUrl
            : poster;
    final bool hasArt = backdrop != null && backdrop.trim().isNotEmpty;

    final bool isLight = theme.brightness == Brightness.light;
    final Color scrim = isLight ? Colors.white : Colors.black;
    final Color onArt = isLight ? const Color(0xFF141414) : Colors.white;
    final Color titleColor = hasArt ? onArt : cs.onSurface;
    final Color subColor =
        hasArt ? onArt.withValues(alpha: 0.78) : cs.onSurfaceVariant;

    return Theme(
      data: theme,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 78,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (hasArt)
                CachedNetworkImage(
                  imageUrl: backdrop,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  memCacheWidth: 600,
                  errorWidget: (_, __, ___) => (backdrop != poster &&
                          poster != null &&
                          poster.trim().isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: poster,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          memCacheWidth: 600,
                          errorWidget: (_, __, ___) =>
                              Container(color: cs.surfaceContainerHighest),
                        )
                      : Container(color: cs.surfaceContainerHighest),
                )
              else
                Container(color: cs.surfaceContainerHighest),
              if (hasArt)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        scrim.withValues(alpha: 0.88),
                        scrim.withValues(alpha: 0.60),
                        scrim.withValues(alpha: 0.20),
                      ],
                      stops: const <double>[0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              InkWell(
                onTap: () => context.go(
                  AtriumRoutes.servicePath(
                      row.instance.kind.name, row.instance.id),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 66,
                        height: 66,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                maxWidth: 66,
                              ),
                              child: SizedBox(
                                height: 66,
                                child: (poster == null || poster.isEmpty)
                                    ? _posterFallback(cs)
                                    : CachedNetworkImage(
                                        imageUrl: poster,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 132,
                                        errorWidget: (_, __, ___) =>
                                            _posterFallback(cs),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    row.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                                if (row.quality != null) ...<Widget>[
                                  const SizedBox(width: Insets.sm),
                                  _QualityChip(
                                    label: row.quality!,
                                    transcoding: row.transcoding,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: <Widget>[
                                Icon(
                                  row.paused
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 14,
                                  color: subColor,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    row.device.isEmpty
                                        ? row.user
                                        : '${row.user} • ${row.device}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: subColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicatorM3E(
                                      size: LinearProgressM3ESize.s,
                                      shape: ProgressM3EShape.flat,
                                      value: row.progress.clamp(0, 1),
                                      activeColor: !row.paused
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline,
                                      trackColor: hasArt
                                          ? scrim.withValues(alpha: 0.15)
                                          : cs.surfaceContainerHighest,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Insets.sm),
                                Text(
                                  row.timeLabel ??
                                      '${(row.progress * 100).toStringAsFixed(0)}%',
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: subColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _posterFallback(ColorScheme cs) => Container(
        color: cs.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Icon(
          Icons.play_circle_outline,
          size: 18,
          color: cs.onSurfaceVariant,
        ),
      );
}

/// Stream resolution chip; a transcode marker and warmer colour when the
/// server is re-encoding, a calm tertiary tone for direct play.
class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.label, required this.transcoding});

  final String label;
  final bool transcoding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color color = transcoding ? cs.secondary : cs.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (transcoding) ...<Widget>[
            Icon(Icons.autorenew_rounded, size: 11, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
