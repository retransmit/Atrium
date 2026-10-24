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
/// Styled similarly to qBittorrent's clean, modern cards with proper
/// screen margins, state icon block, progress bar, and speed pills,
/// while featuring Transmission-specific capabilities: expressive wavy
/// progress animations while transferring, rich swarm peer stats,
/// and a direct actions menu.
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
    final Color onTileQuiet = selected
        ? cs.onPrimaryContainer.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;

    final String sizeText = torrent.needsMetadata
        ? ''
        : (torrent.isDone
            ? trFmtBytes(torrent.totalSize)
            : '${trFmtBytes(torrent.doneBytes)} / ${trFmtBytes(torrent.sizeWhenDone)}');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xs,
        Insets.md,
        Insets.xs,
      ),
      child: Material(
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
                    TransmissionIconBlock(
                      icon: selected ? Icons.check_rounded : v.icon,
                      background: selected
                          ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                          : v.container,
                      foreground:
                          selected ? cs.onPrimaryContainer : v.onContainer,
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
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: Insets.sm,
                            runSpacing: Insets.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              TransmissionPill(
                                label: torrent.stateString,
                                foreground: v.onContainer,
                                background: v.container,
                              ),
                              if (torrent.isPrivate)
                                TransmissionPill(
                                  icon: Icons.lock_outline,
                                  label: 'Private',
                                  foreground: cs.onTertiaryContainer,
                                  background: cs.tertiaryContainer,
                                ),
                              if (sizeText.isNotEmpty)
                                Text(
                                  sizeText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(
                                    color: onTileQuiet,
                                    fontWeight: FontWeight.w500,
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
                          value: trBarValue(torrent),
                          shape: moving
                              ? ProgressM3EShape.wavy
                              : ProgressM3EShape.flat,
                          size: LinearProgressM3ESize.s,
                          activeColor: torrent.isDone ? cs.tertiary : v.color,
                          trackColor: selected
                              ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                              : cs.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Text(
                      '${(trBarValue(torrent) * 100).toStringAsFixed(0)}%',
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? cs.onPrimaryContainer : v.color,
                      ),
                    ),
                  ],
                ),
                if (compact) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Text(
                    trCompactLine(torrent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: torrent.hasError ? cs.error : onTileQuiet,
                    ),
                  ),
                ] else ...<Widget>[
                  if (torrent.hasError) ...<Widget>[
                    const SizedBox(height: Insets.xs),
                    Text(
                      torrent.errorString,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: cs.error),
                    ),
                  ] else if (torrent.needsMetadata) ...<Widget>[
                    const SizedBox(height: Insets.xs),
                    Text(
                      trProgressLine(torrent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: onTileQuiet),
                    ),
                  ] else if (torrent.status == TransmissionStatus.checking) ...<Widget>[
                    const SizedBox(height: Insets.xs),
                    Text(
                      trStatusLine(torrent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: onTileQuiet),
                    ),
                  ],
                  const SizedBox(height: Insets.md),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: Insets.xs,
                      children: <Widget>[
                        Wrap(
                          spacing: Insets.sm,
                          runSpacing: Insets.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            TransmissionSpeedPill(
                              icon: Icons.south,
                              label: trFmtRate(torrent.downloadRate),
                              color: cs.primary,
                              active: torrent.downloadRate > 0,
                              selected: selected,
                            ),
                            TransmissionSpeedPill(
                              icon: Icons.north,
                              label: trFmtRate(torrent.uploadRate),
                              color: cs.tertiary,
                              active: torrent.uploadRate > 0,
                              selected: selected,
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: Insets.sm,
                          runSpacing: Insets.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.swap_vert,
                                  size: 14,
                                  color: onTileQuiet,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  trRatioString(torrent.uploadRatio),
                                  style: text.labelSmall?.copyWith(
                                    color: onTileQuiet,
                                  ),
                                ),
                              ],
                            ),
                            if (torrent.hasEta && !torrent.isDone)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: onTileQuiet,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    trFmtEta(torrent.eta),
                                    style: text.labelSmall?.copyWith(
                                      color: onTileQuiet,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
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
