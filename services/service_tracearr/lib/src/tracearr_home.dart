import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'auth/tracearr_auth_interceptor.dart';
import 'auth/tracearr_auth_manager.dart';
import 'models/tracearr_active_sessions.dart';
import 'models/tracearr_session.dart';
import 'tracearr_api.dart';
import 'tracearr_providers.dart';

class TracearrHome extends ConsumerWidget {
  const TracearrHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TracearrActiveSessions> sessions =
        ref.watch(tracearrSessionsProvider(instance));
    final Map<String, String> servers = ref.watch(tracearrServersProvider(instance)).value ?? <String, String>{};
    final TracearrApi? api = ref.watch(tracearrApiProvider(instance)).value;

    return AsyncValueView<TracearrActiveSessions>(
      value: sessions,
      onRetry: () => ref.invalidate(tracearrSessionsProvider(instance)),
      data: (TracearrActiveSessions data) {
        if (data.sessions.isEmpty) {
          return EasyRefresh(
            header: const ClassicHeader(
              dragText: 'Pull to refresh',
              armedText: 'Release ready',
              readyText: 'Refreshing...',
              processingText: 'Refreshing...',
              processedText: 'Succeeded',
              failedText: 'Failed',
              messageText: 'Last updated at %T',
            ),
            onRefresh: () async => ref.invalidate(tracearrSessionsProvider(instance)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const <Widget>[
                SizedBox(height: 100),
                EmptyView(
                  icon: Icons.podcasts_outlined,
                  title: 'Nothing playing',
                  message: 'No active streams right now.',
                ),
              ],
            ),
          );
        }

        final List<TracearrSession> embySessions = <TracearrSession>[];
        final List<TracearrSession> plexSessions = <TracearrSession>[];
        final List<TracearrSession> jellyfinSessions = <TracearrSession>[];

        final Set<String> seen = <String>{};

        for (final TracearrSession s in data.sessions) {
          final String key = '${s.playerName}|${s.displayTitle}|${s.device}';
          if (seen.contains(key)) continue;
          seen.add(key);

          final String type = s.serverType.toLowerCase();
          if (type.contains('plex')) {
            plexSessions.add(s);
          } else if (type.contains('emby')) {
            embySessions.add(s);
          } else {
            jellyfinSessions.add(s);
          }
        }

        return EasyRefresh(
          header: const ClassicHeader(
            dragText: 'Pull to refresh',
            armedText: 'Release ready',
            readyText: 'Refreshing...',
            processingText: 'Refreshing...',
            processedText: 'Succeeded',
            failedText: 'Failed',
            messageText: 'Last updated at %T',
          ),
          onRefresh: () async => ref.invalidate(tracearrSessionsProvider(instance)),
          child: ListView(
            padding: Insets.page,
            children: <Widget>[
              if (embySessions.isNotEmpty) ...<Widget>[
                const _SectionHeader(title: 'Emby Servers'),
                for (final TracearrSession s in embySessions)
                  _SessionCard(session: s, serverUrl: servers[s.serverId]),
                const SizedBox(height: Insets.lg),
              ],
              if (plexSessions.isNotEmpty) ...<Widget>[
                const _SectionHeader(title: 'Plex Servers'),
                for (final TracearrSession s in plexSessions)
                  _SessionCard(session: s, serverUrl: servers[s.serverId]),
                const SizedBox(height: Insets.lg),
              ],
              if (jellyfinSessions.isNotEmpty) ...<Widget>[
                const _SectionHeader(title: 'JellyFin Servers'),
                for (final TracearrSession s in jellyfinSessions)
                  _SessionCard(session: s, serverUrl: servers[s.serverId]),
                const SizedBox(height: Insets.lg),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md, left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, this.serverUrl});

  final TracearrSession session;
  final String? serverUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double pct = session.progressPercent / 100.0;
    final bool playing = session.state.toLowerCase() == 'playing';
    
    String? imageUrl;
    if (serverUrl != null && session.thumbPath != null) {
      final String cleanPath = session.thumbPath!.startsWith('/') 
          ? session.thumbPath! 
          : '/${session.thumbPath!}';
      imageUrl = '$serverUrl$cleanPath';
    }

    String formatMs(int ms) {
      final Duration d = Duration(milliseconds: ms);
      final int h = d.inHours;
      final int m = d.inMinutes.remainder(60);
      final int sec = d.inSeconds.remainder(60);
      return h > 0
          ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
          : '$m:${sec.toString().padLeft(2, '0')}';
    }

    final String meta = <String>[
      if (session.device.isNotEmpty) session.device,
      if (session.quality.isNotEmpty) session.quality,
    ].join(' · ');

    final String locationInfo = session.location;

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.md),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (BuildContext context, String _) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (BuildContext context, String _, Object __) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
              )
            else
              ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.person, size: 14, color: Colors.white70),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    session.playerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      if (session.isTranscode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Transcode',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (locationInfo.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.location_on, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          locationInfo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          playing ? Icons.play_arrow : Icons.pause,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      Expanded(
                        child: Text(
                          session.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${formatMs(session.progressMs)} / ${formatMs(session.totalDurationMs)}',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicatorM3E(
                shape: ProgressM3EShape.flat,
                value: pct.clamp(0, 1),
                activeColor: playing ? theme.colorScheme.primary : theme.colorScheme.outline,
                trackColor: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
