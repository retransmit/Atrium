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
/// The tile the other torrent clients use: a tinted block for the state, a
/// state pill and label chips under the name, the bar with its percentage,
/// then the two lines the web UI shows. The wave on the bar is the one
/// flourish, and only while bytes move.
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
    final TextTheme text = theme.textTheme;
    final TransmissionVisual v = transmissionVisualFor(cs, torrent);
    final bool moving = torrent.downloadRate > 0 || torrent.uploadRate > 0;
    final Color onTile = selected ? cs.onPrimaryContainer : cs.onSurface;
    final Color onTileQuiet =
        selected ? cs.onPrimaryContainer.withValues(alpha: 0.8) : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(TransmissionPanel.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.all(compact ? Insets.sm : Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TransmissionIconBlock(
                      icon: selected ? Icons.check_rounded : v.icon,
                      background: selected
                          ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                          : v.container,
                      foreground: selected ? cs.onPrimaryContainer : v.onContainer,
                      size: compact ? 36 : 44,
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
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: onTile,
                            ),
                          ),
                          if (!compact) ...<Widget>[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: Insets.xs,
                              runSpacing: Insets.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                TransmissionPill(
                                  label: torrent.stateString,
                                  foreground: v.onContainer,
                                  background: v.container,
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
                        ],
                      ),
                    ),
                    if (!selectionMode)
                      PopupMenuButton<TransmissionTorrentAction>(
                        tooltip: 'Torrent actions',
                        padding: EdgeInsets.zero,
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
                SizedBox(height: compact ? Insets.sm : Insets.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicatorM3E(
                          value: trBarValue(torrent),
                          // The expressive wave reads as "moving right now",
                          // so it is spent only on torrents shifting bytes.
                          shape: moving
                              ? ProgressM3EShape.wavy
                              : ProgressM3EShape.flat,
                          size: LinearProgressM3ESize.s,
                          activeColor: v.color,
                          trackColor: selected
                              ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                              : cs.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Text(
                      '${trPct(trBarValue(torrent))}%',
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? cs.onPrimaryContainer : v.color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? Insets.xs : Insets.sm),
                if (compact)
                  Text(
                    trCompactLine(torrent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: torrent.hasError ? cs.error : onTileQuiet,
                    ),
                  )
                else ...<Widget>[
                  Text(
                    trProgressLine(torrent),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: onTileQuiet),
                  ),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: <Widget>[
                      TransmissionSpeedPill(
                        icon: Icons.south,
                        label: trFmtRate(torrent.downloadRate),
                        color: cs.primary,
                        active: torrent.downloadRate > 0,
                      ),
                      const SizedBox(width: Insets.sm),
                      TransmissionSpeedPill(
                        icon: Icons.north,
                        label: trFmtRate(torrent.uploadRate),
                        color: cs.tertiary,
                        active: torrent.uploadRate > 0,
                      ),
                      const Spacer(),
                      Icon(Icons.swap_vert, size: 14, color: onTileQuiet),
                      const SizedBox(width: 2),
                      Text(
                        trRatioString(torrent.uploadRatio),
                        style: text.labelSmall?.copyWith(color: onTileQuiet),
                      ),
                      if (torrent.hasEta) ...<Widget>[
                        const SizedBox(width: Insets.sm),
                        Icon(Icons.schedule, size: 14, color: onTileQuiet),
                        const SizedBox(width: 2),
                        Text(
                          trFmtEta(torrent.eta),
                          style: text.labelSmall?.copyWith(color: onTileQuiet),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    trStatusLine(torrent),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: torrent.hasError
                          ? cs.error
                          : (selected ? cs.onPrimaryContainer : v.color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
