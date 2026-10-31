import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../models/slskd_system_models.dart';
import '../slskd_api.dart';
import '../slskd_providers.dart';
import 'slskd_share_contents_sheet.dart';

/// View displaying local shares summary, real-time scanning progress, rescan controls, and shared directories.
class SlskdSharesView extends ConsumerStatefulWidget {
  const SlskdSharesView({
    required this.instance,
    required this.sharesState,
    super.key,
  });

  final Instance instance;
  final SlskdSharesState sharesState;

  @override
  ConsumerState<SlskdSharesView> createState() => _SlskdSharesViewState();
}

class _SlskdSharesViewState extends ConsumerState<SlskdSharesView> {
  bool _isActionInProgress = false;

  Future<void> _handleScanShares() async {
    setState(() => _isActionInProgress = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final SlskdApi api =
          await ref.read(slskdApiProvider(widget.instance).future);
      await api.scanShares();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Scanning local shares...'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      final msg = (e is DioException && e.response?.statusCode == 403)
          ? 'Scanning shares requires an API key with Administrator or ReadWrite role'
          : 'Failed to start share scan: $e';
      messenger.showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ref.invalidate(slskdApplicationStateProvider(widget.instance));
        ref.invalidate(slskdSharesProvider(widget.instance));
      }
    }
  }

  Future<void> _handleCancelScan() async {
    setState(() => _isActionInProgress = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final SlskdApi api =
          await ref.read(slskdApiProvider(widget.instance).future);
      await api.cancelShareScan();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Share scan cancelled'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      final msg = (e is DioException && e.response?.statusCode == 403)
          ? 'Cancelling scan requires an API key with Administrator or ReadWrite role'
          : 'Failed to cancel scan: $e';
      messenger.showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ref.invalidate(slskdApplicationStateProvider(widget.instance));
        ref.invalidate(slskdSharesProvider(widget.instance));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final sharesMapAsync = ref.watch(slskdSharesProvider(widget.instance));
    final bool isScanning = widget.sharesState.scanning || widget.sharesState.scanPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Summary & Scan Control Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(Insets.xs),
                      decoration: BoxDecoration(
                        color: isScanning
                            ? colorScheme.tertiaryContainer
                            : colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isScanning
                            ? Icons.sync_rounded
                            : Icons.folder_shared_rounded,
                        size: 20,
                        color: isScanning
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Shared Library',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.sharesState.files} files across ${widget.sharesState.directories} folders',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isScanning)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.sm,
                          vertical: Insets.xs / 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Scanning',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (widget.sharesState.faulted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.sm,
                          vertical: Insets.xs / 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Scan Faulted',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.sm,
                          vertical: Insets.xs / 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Ready',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (isScanning) ...<Widget>[
                  const SizedBox(height: Insets.md),
                  Builder(
                    builder: (context) {
                      final double rawProgress = widget.sharesState.scanProgress;
                      final double? norm = (rawProgress.isFinite && rawProgress > 0)
                          ? (rawProgress > 1.0 ? rawProgress / 100.0 : rawProgress)
                              .clamp(0.0, 1.0)
                              .toDouble()
                          : null;
                      final String scanText = (rawProgress.isFinite && rawProgress > 0)
                          ? 'Scanning: ${(rawProgress > 1.0 ? rawProgress : rawProgress * 100).clamp(0.0, 100.0).toStringAsFixed(1)}%'
                          : 'Indexing shared files...';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicatorM3E(
                              size: LinearProgressM3ESize.s,
                              shape: ProgressM3EShape.flat,
                              value: norm,
                              activeColor: colorScheme.primary,
                              trackColor: colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            scanText,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: Insets.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                        minimumSize: const Size.fromHeight(42),
                      ),
                      onPressed: _isActionInProgress ? null : _handleCancelScan,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancel Scan'),
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: Insets.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                          ),
                          onPressed: _isActionInProgress ? null : _handleScanShares,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Rescan Shares'),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                          ),
                          onPressed: () {
                            SlskdShareContentsSheet.show(
                              context,
                              instance: widget.instance,
                              title: 'All Shared Library',
                            );
                          },
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('Browse All'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Insets.md),
        Text(
          'Configured Shared Folders',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Insets.sm),
        sharesMapAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: ExpressiveProgressIndicator(),
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(
                'Failed to load shares: $error',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ),
          data: (sharesMap) {
            final List<Widget> hostWidgets = [];

            if (sharesMap.isEmpty) {
              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.xl),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.folder_off_rounded,
                          size: 40,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          'No Shared Folders Configured',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: Insets.xs),
                        Text(
                          'Add shared folder paths to slskd.yml to share music with the Soulseek network.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            for (final entry in sharesMap.entries) {
              final String host = entry.key;
              final List<SlskdLocalShare> shares = entry.value;

              hostWidgets.add(
                Padding(
                  padding: const EdgeInsets.only(top: Insets.xs, bottom: Insets.xs),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.dns_outlined,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: Insets.xs),
                      Text(
                        'Host: $host',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              for (final share in shares) {
                hostWidgets.add(
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: Insets.sm),
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.xs,
                      ),
                      onTap: share.isExcluded
                          ? null
                          : () {
                              SlskdShareContentsSheet.show(
                                context,
                                instance: widget.instance,
                                shareId: share.id.isNotEmpty ? share.id : null,
                                title: share.name.isNotEmpty
                                    ? share.name
                                    : share.path,
                                sharePath: share.path,
                              );
                            },
                      leading: Container(
                        padding: const EdgeInsets.all(Insets.xs),
                        decoration: BoxDecoration(
                          color: share.isExcluded
                              ? colorScheme.errorContainer
                              : colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          share.isExcluded
                              ? Icons.folder_off_rounded
                              : Icons.folder_rounded,
                          size: 20,
                          color: share.isExcluded
                              ? colorScheme.onErrorContainer
                              : colorScheme.onSecondaryContainer,
                        ),
                      ),
                      title: Text(
                        share.name.isNotEmpty ? share.name : share.path,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        share.path,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: share.isExcluded
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Insets.xs,
                                vertical: Insets.xs / 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Excluded',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    if (share.files != null)
                                      Text(
                                        '${share.files} files',
                                        style: textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (share.directories != null)
                                      Text(
                                        '${share.directories} dirs',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: Insets.xs),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: hostWidgets,
            );
          },
        ),
      ],
    );
  }
}
