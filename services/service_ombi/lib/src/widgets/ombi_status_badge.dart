import 'package:flutter/material.dart';

import '../models/ombi_models.dart';

/// Ombi's Recently Requested cards' words, which the dashboard shows.
String ombiRecentStatusLabel(OmbiRecentStatus status) => switch (status) {
      OmbiRecentStatus.pending => 'Pending',
      OmbiRecentStatus.approved => 'Approved',
      OmbiRecentStatus.partlyAvailable => 'Partially Available',
      OmbiRecentStatus.available => 'Available',
      OmbiRecentStatus.denied => 'Denied',
    };

/// Where a request stands, as a small filled pill, in the words of Ombi's
/// request list.
class OmbiStatusBadge extends StatelessWidget {
  const OmbiStatusBadge({required this.status, super.key});

  final OmbiRequestStatus status;

  static String labelFor(OmbiRequestStatus status) => switch (status) {
        OmbiRequestStatus.pending => 'Pending Approval',
        OmbiRequestStatus.processing => 'Processing Request',
        OmbiRequestStatus.available => 'Available',
        OmbiRequestStatus.denied => 'Denied',
      };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return _Pill(
      label: labelFor(status),
      color: switch (status) {
        OmbiRequestStatus.pending => cs.primary,
        OmbiRequestStatus.processing => cs.secondary,
        OmbiRequestStatus.available => cs.tertiary,
        OmbiRequestStatus.denied => cs.error,
      },
    );
  }
}

/// The tag Ombi puts beside a request that asked for a 4K copy too.
class OmbiFourKBadge extends StatelessWidget {
  const OmbiFourKBadge({super.key});

  @override
  Widget build(BuildContext context) =>
      _Pill(label: '4K', color: Theme.of(context).colorScheme.onSurfaceVariant);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
