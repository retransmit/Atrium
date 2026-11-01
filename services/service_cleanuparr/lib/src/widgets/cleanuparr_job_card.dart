import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../cleanuparr_errors.dart';
import '../cleanuparr_providers.dart';
import '../models/cleanuparr_job.dart';

/// Card row displaying a background job with its schedule and on-demand trigger button.
class CleanuparrJobCard extends ConsumerStatefulWidget {
  const CleanuparrJobCard({
    required this.job,
    required this.instance,
    super.key,
  });

  final CleanuparrJob job;
  final Instance instance;

  @override
  ConsumerState<CleanuparrJobCard> createState() => _CleanuparrJobCardState();
}

class _CleanuparrJobCardState extends ConsumerState<CleanuparrJobCard> {
  bool _isTriggering = false;

  Future<void> _triggerJob() async {
    setState(() => _isTriggering = true);
    try {
      final api = await ref.read(cleanuparrApiProvider(widget.instance).future);
      await api.triggerJob(widget.job.jobType);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Triggered ${widget.job.displayName}'),
          duration: const Duration(seconds: 2),
        ),
      );
      // Invalidate jobs to update status
      ref.invalidate(cleanuparrJobsProvider(widget.instance));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to trigger job: ${describeCleanuparrError(e)}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTriggering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String nextRunText = widget.job.nextRunTime != null
        ? 'Next: ${DateFormat('HH:mm').format(widget.job.nextRunTime!.toLocal())}'
        : (widget.job.intervalDescription ?? 'Manual');

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          widget.job.displayName,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      _StatusBadge(status: widget.job.status),
                    ],
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    nextRunText,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Run ${widget.job.displayName} now',
              icon: _isTriggering
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: ExpressiveProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.play_arrow_rounded,
                      color: colorScheme.primary,
                    ),
              onPressed: _isTriggering ? null : _triggerJob,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isRunning = status.toLowerCase() == 'running';

    final Color bg = isRunning
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final Color fg = isRunning
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xs + 2,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.chip,
      ),
      child: Text(
        status,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w500,
          fontSize: 10,
        ),
      ),
    );
  }
}
