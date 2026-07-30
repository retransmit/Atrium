import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator_plus/palette_generator_plus.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'models/tracearr_session.dart';

class TracearrSessionDetailScreen extends ConsumerStatefulWidget {
  const TracearrSessionDetailScreen({
    required this.session,
    this.posterUrl,
    super.key,
  });

  final TracearrSession session;
  final String? posterUrl;

  @override
  ConsumerState<TracearrSessionDetailScreen> createState() =>
      _TracearrSessionDetailScreenState();
}

class _TracearrSessionDetailScreenState
    extends ConsumerState<TracearrSessionDetailScreen> {
  PaletteGenerator? _palette;
  String? _lastPosterUrl;

  void _updateColorScheme(String? posterUrl, Brightness brightness) {
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

  String _formatMs(int ms) {
    final int sec = ms ~/ 1000;
    final int h = sec ~/ 3600;
    final int m = (sec % 3600) ~/ 60;
    final int s = sec % 60;
    return '${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final TracearrSession session = widget.session;
    final String? posterUrl = widget.posterUrl ?? session.thumbPath;

    ThemeData theme = Theme.of(context);
    _updateColorScheme(posterUrl, theme.brightness);
    if (_palette != null) {
      final Color dominant =
          _palette!.dominantColor?.color ?? theme.colorScheme.surface;
      final Color vibrant = _palette!.vibrantColor?.color ??
          _palette!.lightVibrantColor?.color ??
          dominant;
      final Color muted = _palette!.mutedColor?.color ??
          theme.colorScheme.surfaceContainerHighest;
      final Color darkMuted = _palette!.darkMutedColor?.color ?? dominant;
      final Color titleText = _palette!.dominantColor?.titleTextColor ??
          theme.colorScheme.onSurface;
      final Color bodyText = _palette!.dominantColor?.bodyTextColor ??
          theme.colorScheme.onSurfaceVariant;

      theme = theme.copyWith(
        scaffoldBackgroundColor: darkMuted,
        colorScheme: theme.colorScheme.copyWith(
          primary: vibrant,
          onPrimary: _palette!.vibrantColor?.titleTextColor ??
              theme.colorScheme.onPrimary,
          secondaryContainer: vibrant.withValues(alpha: 0.25),
          onSecondaryContainer: vibrant,
          surface: dominant,
          onSurface: titleText,
          onSurfaceVariant: bodyText,
          surfaceContainer: muted,
          surfaceContainerHighest: muted,
        ),
      );
    }

    final String type = session.mediaType.toLowerCase();
    String mainTitle;
    String? subTitle;

    if (type == 'track' || type == 'album' || type == 'audio') {
      mainTitle = session.mediaTitle;
      subTitle = session.artist ??
          session.artistName ??
          session.grandparentTitle ??
          session.parentTitle ??
          session.originalTitle;
    } else if (type == 'episode') {
      final String s = (session.seasonNumber ?? 0).toString().padLeft(2, '0');
      final String e = (session.episodeNumber ?? 0).toString().padLeft(2, '0');
      mainTitle = 'S${s}E$e - ${session.mediaTitle}';
      subTitle = session.grandparentTitle;
    } else {
      mainTitle = session.mediaTitle;
      subTitle = null;
    }

    return Theme(
      data: theme,
      child: Scaffold(
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
                'NOW STREAMING',
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
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (posterUrl != null)
              CachedNetworkImage(
                imageUrl: posterUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: theme.colorScheme.surface),
              ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0.0, 0.4, 1.0],
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.6),
                      theme.colorScheme.surface.withValues(alpha: 0.85),
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.xl, vertical: Insets.xl,),
                children: <Widget>[
                  const SizedBox(height: 40),
                  if (posterUrl != null)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: posterUrl,
                          height: 250,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  Text(
                    mainTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subTitle != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      subTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (session.state.toLowerCase() == 'playing' ||
                      session.state.toLowerCase() == 'paused' ||
                      session.state.toLowerCase() == 'buffering' ||
                      session.state.toLowerCase() == 'idle') ...<Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          _formatMs(session.progressMs),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatMs(session.totalDurationMs),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicatorM3E(
                        shape: ProgressM3EShape.flat,
                        value: (session.progressPercent / 100.0).clamp(0.0, 1.0),
                        trackColor: theme.colorScheme.surfaceContainerHighest,
                        activeColor: session.state.toLowerCase() == 'playing'
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
                  _buildDetailRow('State', session.state.toUpperCase(), theme),
                  _buildDetailRow('Player', session.playerName, theme),
                  _buildDetailRow('Platform', session.platform, theme),
                  _buildDetailRow('Product', session.product, theme),
                  _buildDetailRow('Quality', session.quality, theme),
                  if (session.isTranscode) ...<Widget>[
                    _buildDetailRow('Transcode', 'Yes', theme, isWarning: true),
                    if (session.videoDecision != null)
                      _buildDetailRow('Video', session.videoDecision!, theme),
                    if (session.audioDecision != null)
                      _buildDetailRow('Audio', session.audioDecision!, theme),
                  ] else ...<Widget>[
                    _buildDetailRow('Transcode', 'Direct Play', theme,
                        isSuccess: true,),
                  ],
                  _buildDetailRow('IP Address', session.ipAddress, theme),
                  _buildDetailRow('Location', session.location, theme),
                  if (session.geoLat != null && session.geoLon != null)
                    _buildDetailRow(
                      'Coordinates',
                      '${session.geoLat!.toStringAsFixed(4)}, ${session.geoLon!.toStringAsFixed(4)}',
                      theme,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme,
      {bool isWarning = false, bool isSuccess = false,}) {
    if (value.isEmpty) return const SizedBox.shrink();

    Color valueColor = theme.colorScheme.onSurface;
    if (isWarning) valueColor = Colors.orangeAccent;
    if (isSuccess) valueColor = Colors.greenAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
