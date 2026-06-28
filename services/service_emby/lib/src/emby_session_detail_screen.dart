import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'emby_client.dart';
import 'emby_providers.dart';
import 'models/emby_session.dart';

class EmbySessionDetailScreen extends ConsumerWidget {
  const EmbySessionDetailScreen({
    required this.instance,
    required this.initialSession,
    super.key,
  });

  final Instance instance;
  final ActiveSession initialSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ActiveSession>> sessionsAsync =
        ref.watch(embySessionsProvider(instance));
    final ActiveSession session = sessionsAsync.value?.firstWhereOrNull(
            (ActiveSession s) => s.id == initialSession.id) ??
        initialSession;

    final ThemeData theme = Theme.of(context);
    final double pct = session.progressPercent / 100.0;
    final bool playing = session.status == 'Playing';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: <Widget>[
            Text(
              'STREAMING ON',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              session.device,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Background blurred image
          if (session.posterUrl != null)
            Image.network(
              session.posterUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: theme.colorScheme.surface),
            ),
          // Blur and gradient overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    theme.colorScheme.surface.withValues(alpha: 0.35),
                    theme.colorScheme.surface.withValues(alpha: 0.35),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Spacer(),

                  // Artwork
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 380, maxWidth: 380),
                    child: AspectRatio(
                      aspectRatio: session.aspectRatio != null &&
                              session.aspectRatio! > 0.0
                          ? session.aspectRatio!
                          : (2 / 3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: Radii.card,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          image: session.posterUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(
                                      session.posterUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: session.posterUrl == null
                            ? Icon(Icons.movie_outlined,
                                color: theme.colorScheme.outline, size: 80)
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(height: Insets.xxl),

                  // Track Info
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          session.showTitle,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (session.episodeName != null) ...<Widget>[
                          const SizedBox(height: Insets.xs),
                          Text(
                            session.episodeName!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: Insets.xl),

                  // Progress Bar
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 6,
                      activeTrackColor: theme.colorScheme.primary,
                      inactiveTrackColor:
                          theme.colorScheme.surfaceContainerHighest,
                      thumbColor: theme.colorScheme.primary,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: pct.clamp(0.0, 1.0),
                      onChanged: null, // Display only
                    ),
                  ),

                  const SizedBox(height: Insets.xs),

                  // Timestamps
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        session.timePosition,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        session.timeDuration,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: Insets.lg),

                  // Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        iconSize: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                        onPressed: () async {
                          final EmbyClient? client =
                              ref.read(embyClientProvider(instance)).value;
                          if (client != null) {
                            await client.previousTrack(session.id);
                            ref.invalidate(embySessionsProvider(instance));
                          }
                        },
                      ),
                      const SizedBox(width: Insets.md),
                      IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                        ),
                        iconSize: 80,
                        color: theme.colorScheme.primary,
                        onPressed: () async {
                          final EmbyClient? client =
                              ref.read(embyClientProvider(instance)).value;
                          if (client != null) {
                            if (playing) {
                              await client.pauseSession(session.id);
                            } else {
                              await client.unpauseSession(session.id);
                            }
                            ref.invalidate(embySessionsProvider(instance));
                          }
                        },
                      ),
                      const SizedBox(width: Insets.md),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        iconSize: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                        onPressed: () async {
                          final EmbyClient? client =
                              ref.read(embyClientProvider(instance)).value;
                          if (client != null) {
                            await client.nextTrack(session.id);
                            ref.invalidate(embySessionsProvider(instance));
                          }
                        },
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Footer
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.person,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          session.user,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
