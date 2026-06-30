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

class EmbySessionDetailScreen extends ConsumerStatefulWidget {
  const EmbySessionDetailScreen({
    required this.instance,
    required this.initialSession,
    super.key,
  });

  final Instance instance;
  final ActiveSession initialSession;

  @override
  ConsumerState<EmbySessionDetailScreen> createState() =>
      _EmbySessionDetailScreenState();
}

class _EmbySessionDetailScreenState
    extends ConsumerState<EmbySessionDetailScreen> {
  bool _isDragging = false;
  double _dragPct = 0.0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ActiveSession>> sessionsAsync =
        ref.watch(embyFastSessionsProvider(widget.instance));
    final ActiveSession session = sessionsAsync.value?.firstWhereOrNull(
            (ActiveSession s) => s.id == widget.initialSession.id,) ??
        widget.initialSession;

    final ThemeData theme = Theme.of(context);
    final double pct =
        _isDragging ? _dragPct : (session.progressPercent / 100.0);
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
                                      session.posterUrl!,),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: session.posterUrl == null
                            ? Icon(Icons.movie_outlined,
                                color: theme.colorScheme.outline, size: 80,)
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(height: Insets.lg),

                  // Track Info
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          height: (theme.textTheme.titleLarge?.fontSize ?? 22) *
                              1.5,
                          child: AutoScrollText(
                            text: session.showTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (session.episodeName != null) ...<Widget>[
                          const SizedBox(height: Insets.xs),
                          SizedBox(
                            height:
                                (theme.textTheme.titleMedium?.fontSize ?? 16) *
                                    1.5,
                            child: AutoScrollText(
                              text: session.episodeName!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Progress Bar & Timestamps
                  Column(
                    children: <Widget>[
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 8,
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor:
                              theme.colorScheme.surfaceContainerHighest,
                          thumbColor: theme.colorScheme.primary,
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                        child: Slider(
                          value: pct.clamp(0.0, 1.0),
                          onChangeStart: (_) => setState(() {
                            _isDragging = true;
                            _dragPct = pct;
                          }),
                          onChanged: (double newValue) {
                            setState(() {
                              _dragPct = newValue;
                            });
                          },
                          onChangeEnd: (double newValue) async {
                            setState(() => _isDragging = false);
                            if (session.durationTicks <= 0) return;
                            try {
                              final int targetTicks =
                                  (session.durationTicks * newValue).round();
                              final EmbyClient client = await ref.read(
                                  embyClientProvider(widget.instance).future,);
                              await client.seekSession(session.id, targetTicks);
                              if (!context.mounted) return;
                              ref.invalidate(
                                  embyFastSessionsProvider(widget.instance),);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Action failed'),),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24,), // Align with slider track
                        child: Row(
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
                      ),
                    ],
                  ),

                  const SizedBox(height: Insets.md),

                  // Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () async {
                            try {
                              final EmbyClient client = await ref.read(
                                  embyClientProvider(widget.instance).future,);
                              // If more than 5 seconds have elapsed (50 million ticks),
                              // restart the track instead of skipping to previous.
                              if (session.positionTicks > 50000000) {
                                await client.seekSession(session.id, 0);
                              } else {
                                await client.previousTrack(session.id);
                              }
                              if (!context.mounted) return;
                              ref.invalidate(
                                  embyFastSessionsProvider(widget.instance),);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Action failed'),),
                                );
                              }
                            }
                          },
                          child: const Icon(Icons.skip_previous, size: 32),
                        ),
                      ),
                      const SizedBox(width: Insets.lg),
                      SizedBox(
                        width: 120,
                        height: 80,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () async {
                            try {
                              final EmbyClient client = await ref.read(
                                  embyClientProvider(widget.instance).future,);
                              await client.playPauseSession(session.id);
                              if (!context.mounted) return;
                              ref.invalidate(
                                  embyFastSessionsProvider(widget.instance),);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Action failed'),),
                                );
                              }
                            }
                          },
                          child: Icon(playing ? Icons.pause : Icons.play_arrow,
                              size: 40,),
                        ),
                      ),
                      const SizedBox(width: Insets.lg),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () async {
                            try {
                              final EmbyClient client = await ref.read(
                                  embyClientProvider(widget.instance).future,);
                              await client.nextTrack(session.id);
                              if (!context.mounted) return;
                              ref.invalidate(
                                  embyFastSessionsProvider(widget.instance),);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Action failed'),),
                                );
                              }
                            }
                          },
                          child: const Icon(Icons.skip_next, size: 32),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: Insets.lg),

                  // Stop Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 140,
                        height: 56,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            foregroundColor: theme.colorScheme.onErrorContainer,
                            backgroundColor: theme.colorScheme.errorContainer,
                          ),
                          onPressed: () async {
                            try {
                              final EmbyClient client = await ref.read(
                                  embyClientProvider(widget.instance).future,);
                              await client.stopSession(session.id);
                              if (!context.mounted) return;
                              ref.invalidate(
                                  embyFastSessionsProvider(widget.instance),);
                              Navigator.of(context).pop();
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Action failed'),),
                                );
                              }
                            }
                          },
                          child: const Icon(Icons.stop, size: 28),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      // Device Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8,),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.speaker,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              session.device,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // User Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8,),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
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
                    ],
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

class AutoScrollText extends StatefulWidget {
  const AutoScrollText({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
  late ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndScroll());
  }

  @override
  void didUpdateWidget(AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _isScrolling = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _checkAndScroll();
    }
  }

  void _checkAndScroll() async {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      if (_isScrolling) return;
      _isScrolling = true;
      _loopScroll();
    } else {
      // Keep checking if layout changes (e.g. text updates or bounds change)
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted && !_isScrolling) _checkAndScroll();
    }
  }

  void _loopScroll() async {
    while (mounted && _isScrolling) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) break;

      final double maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        final int durationMs = (maxExtent * 40).toInt().clamp(1000, 15000);
        await _scrollController.animateTo(
          maxExtent,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.linear,
        );
      }

      if (!mounted || !_scrollController.hasClients) break;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || !_scrollController.hasClients) break;

      final double currentExtent = _scrollController.position.maxScrollExtent;
      final int durationMs = (currentExtent * 40).toInt().clamp(1000, 15000);
      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}
