import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cleanuparr_event.dart';

/// Bottom sheet displaying deep diagnostics and tracking info for an audit event.
class CleanuparrEventDetailSheet extends StatelessWidget {
  const CleanuparrEventDetailSheet({required this.event, super.key});

  final CleanuparrEvent event;

  static Future<void> show(BuildContext context, CleanuparrEvent event) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      builder: (BuildContext ctx) => CleanuparrEventDetailSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String formattedDate =
        DateFormat('MMM d, yyyy HH:mm:ss').format(event.timestamp.toLocal());

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.lg, Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: Radii.chip,
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    event.eventType,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _SeverityChip(severity: event.severity),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              formattedDate,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            const Divider(height: Insets.xl),
            if (event.downloadItemTitle != null) ...<Widget>[
              _DetailRow(
                label: 'Release Title',
                value: event.downloadItemTitle!,
              ),
              const SizedBox(height: Insets.sm),
            ],
            if (event.downloadClientName != null) ...<Widget>[
              _DetailRow(
                label: 'Client',
                value: event.downloadClientName!,
              ),
              const SizedBox(height: Insets.sm),
            ],
            if (event.hash != null && event.hash!.isNotEmpty) ...<Widget>[
              _DetailRow(
                label: 'Hash',
                value: event.hash!,
              ),
              const SizedBox(height: Insets.sm),
            ],
            if (event.deleteReason != null) ...<Widget>[
              _DetailRow(
                label: 'Delete Reason',
                value: event.deleteReason!,
              ),
              const SizedBox(height: Insets.sm),
            ],
            _DetailRow(
              label: 'Message',
              value: event.message,
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Insets.xxs),
        SelectableText(
          value,
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String lower = severity.toLowerCase();
    Color bg = colorScheme.surfaceContainerHighest;
    Color fg = colorScheme.onSurfaceVariant;

    if (lower == 'error' || lower == 'critical') {
      bg = colorScheme.errorContainer;
      fg = colorScheme.onErrorContainer;
    } else if (lower == 'warning' || lower == 'warn') {
      bg = colorScheme.tertiaryContainer;
      fg = colorScheme.onTertiaryContainer;
    } else if (lower == 'important') {
      bg = colorScheme.secondaryContainer;
      fg = colorScheme.onSecondaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.chip,
      ),
      child: Text(
        severity,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
