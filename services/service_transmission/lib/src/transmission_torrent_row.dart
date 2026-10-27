import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'models/transmission_torrent.dart';
import 'transmission_format.dart';
import 'transmission_row_strings.dart';
import 'transmission_torrent_actions.dart';
import 'transmission_visuals.dart';

/// One torrent in the list, full or compact, selectable.
///
/// A state icon, the name, the state pill with the privacy badge and sizes,
/// the progress bar, then the speeds and ratio. A torrent with an error says
/// what the error is under the bar.
///
/// Compact is its own single-line layout rather than the full one with the
/// pills dropped: one line of name and percentage, the bar, and the one
/// summary line the web UI's compact renderer has. The state pill is left out
/// there so a paused torrent says "Paused" once, in that summary.
class TransmissionTorrentRow extends StatelessWidget {
  const TransmissionTorrentRow({
    required this.torrent,
    required this.compact,
    required this.selected,
    required this.selectionMode,
    required this.labelsSupported,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
    super.key,
  });

  final TransmissionTorrent torrent;
  final bool compact;
  final bool selected;
  final bool selectionMode;
  final bool labelsSupported;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(TransmissionTorrentAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TransmissionVisual v = transmissionVisualFor(cs, torrent);
    final double progress = trBarValue(torrent);
    final bool complete = progress >= 1.0 || torrent.status.isSeeding;
    final bool dlActive = torrent.downloadRate > 0;
    final bool upActive = torrent.uploadRate > 0;
    final Color onTile = selected ? cs.onPrimaryContainer : cs.onSurface;
    final Color onTileQuiet = selected
        ? cs.onPrimaryContainer.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.xs,
          Insets.md,
          Insets.xs,
        ),
        child: Material(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.xs,
                Insets.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                              : v.container,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          selected ? Icons.check : v.icon,
                          size: 18,
                          color:
                              selected ? cs.onPrimaryContainer : v.onContainer,
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text(
                          torrent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected ? cs.onPrimaryContainer : onTile,
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: selected ? cs.onPrimaryContainer : v.color,
                        ),
                      ),
                      if (!selectionMode)
                        PopupMenuButton<TransmissionTorrentAction>(
                          tooltip: 'Torrent actions',
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: onTileQuiet,
                          ),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(32, 32),
                            maximumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                          itemBuilder: (BuildContext _) =>
                              transmissionActionMenuItems(
                            anyStopped: torrent.status.isStopped,
                            single: true,
                            labelsSupported: labelsSupported,
                          ),
                          onSelected: onAction,
                        )
                      else
                        const SizedBox(width: Insets.xs),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.sm),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicatorM3E(
                        shape: ProgressM3EShape.flat,
                        value: progress,
                        activeColor: complete ? cs.tertiary : v.color,
                        trackColor: selected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                            : cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    trCompactLine(torrent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: torrent.hasError ? cs.error : onTileQuiet,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final Widget tile = Material(
      color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                          : v.container,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      selected ? Icons.check : v.icon,
                      size: 22,
                      color: selected ? cs.onPrimaryContainer : v.onContainer,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          torrent.name,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected ? cs.onPrimaryContainer : onTile,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // A Wrap, so that where the pill and the badge leave
                        // the sizes no room they move down a line rather
                        // than being cut short.
                        Wrap(
                          spacing: Insets.sm,
                          runSpacing: Insets.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            // The pill and the badge keep to each other, and
                            // part only where one line cannot hold both.
                            Wrap(
                              spacing: Insets.xs,
                              runSpacing: Insets.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                // An error outranks the state: a stopped
                                // torrent that failed should not read as one
                                // that was merely paused.
                                _StatePill(
                                  label: torrent.hasError
                                      ? 'Error'
                                      : torrent.stateString,
                                  visual: v,
                                ),
                                if (torrent.isPrivate)
                                  const _PrivacyBadge(isPrivate: true),
                              ],
                            ),
                            Text(
                              torrent.isDone
                                  ? trFmtBytes(torrent.totalSize)
                                  : (torrent.hasEta && !complete
                                      ? '${trFmtBytes(torrent.doneBytes)} / ${trFmtBytes(torrent.sizeWhenDone)} • ${trFmtEta(torrent.eta)}'
                                      : '${trFmtBytes(torrent.doneBytes)} / ${trFmtBytes(torrent.sizeWhenDone)}'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: onTileQuiet,
                              ),
                            ),
                            if (labelsSupported)
                              for (final String label in torrent.labels)
                                TransmissionPill(
                                  label: label,
                                  icon: Icons.label_outline,
                                  foreground: cs.onSecondaryContainer,
                                  background: cs.secondaryContainer,
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!selectionMode)
                    PopupMenuButton<TransmissionTorrentAction>(
                      tooltip: 'Torrent actions',
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: onTileQuiet,
                      ),
                      itemBuilder: (BuildContext _) =>
                          transmissionActionMenuItems(
                        anyStopped: torrent.status.isStopped,
                        single: true,
                        labelsSupported: labelsSupported,
                      ),
                      onSelected: onAction,
                    ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicatorM3E(
                        shape: ProgressM3EShape.flat,
                        value: progress,
                        activeColor: complete ? cs.tertiary : v.color,
                        trackColor: selected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                            : cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? cs.onPrimaryContainer : v.color,
                    ),
                  ),
                ],
              ),
              if (torrent.hasError) ...<Widget>[
                const SizedBox(height: Insets.sm),
                Text(
                  torrent.errorString,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: selected ? cs.onPrimaryContainer : cs.error,
                  ),
                ),
              ],
              const SizedBox(height: Insets.md),
              TransmissionPillLine(
                pills: <TransmissionMeasuredPill>[
                  TransmissionSpeedPill(
                    icon: Icons.south,
                    label: trFmtRate(torrent.downloadRate),
                    color: cs.primary,
                    active: dlActive,
                    selected: selected,
                  ),
                  TransmissionSpeedPill(
                    icon: Icons.north,
                    label: trFmtRate(torrent.uploadRate),
                    color: cs.tertiary,
                    active: upActive,
                    selected: selected,
                  ),
                  TransmissionRatioPill(
                    ratio: torrent.uploadRatio,
                    selected: selected,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xs,
        Insets.md,
        Insets.xs,
      ),
      child: tile,
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.visual});

  final String label;
  final TransmissionVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: visual.container,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: visual.onContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.isPrivate});

  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPrivate
            ? cs.tertiaryContainer.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isPrivate ? Icons.lock : Icons.public,
            size: 10,
            color: isPrivate ? cs.onTertiaryContainer : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            isPrivate ? 'Private' : 'Public',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isPrivate ? cs.onTertiaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
