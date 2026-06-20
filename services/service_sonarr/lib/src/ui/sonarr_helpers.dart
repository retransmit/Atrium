part of '../sonarr_home.dart';

// ──────────────────────────────────────────────────────
// Navigation helper functions & formatting
// ──────────────────────────────────────────────────────

/// Pushes [SeriesDetailScreen] using a smooth One UI-style fade + micro-slide.
void _pushSeriesDetail(BuildContext context, Instance instance, int seriesId) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) =>
          SeriesDetailScreen(instance: instance, seriesId: seriesId),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim.drive(CurveTween(curve: Curves.easeOut)),
        child: SlideTransition(
          position: anim.drive(
            Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Pushes [AddSeriesScreen] with a fade-only One UI transition.
void _pushAddSeries(BuildContext context, Instance instance) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => AddSeriesScreen(instance: instance),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim.drive(CurveTween(curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

/// Shows a bottom-sheet confirmation for a destructive queue remove action.
/// Returns `true` if the user confirmed, `false`/`null` otherwise.
Future<bool?> _showDeleteConfirm(BuildContext context, String title) {
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetCtx) {
      final ThemeData theme = Theme.of(sheetCtx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Remove from Queue?',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  minimumSize: const Size.fromHeight(48),),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(sheetCtx, true);
              },
              child: const Text('Remove'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),),
              onPressed: () => Navigator.pop(sheetCtx, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    },
  );
}

/// Groups a history/log date into human-readable section labels.
String _formatDateGroupKey(DateTime localDate) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime recordDay =
      DateTime(localDate.year, localDate.month, localDate.day);
  final int diff = today.difference(recordDay).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEEE, d MMMM').format(localDate);
}

/// Formats bytes into a human readable string.
String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  final i = (math.log(bytes) / math.log(1024)).floor();
  return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
}
