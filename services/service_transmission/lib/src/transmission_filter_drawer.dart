import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/transmission_torrent.dart';
import 'transmission_providers.dart';
import 'transmission_visuals.dart';

/// Transmission's filter drawer: the web UI's nine state filters, plus the
/// tracker and label lists it derives from the torrents themselves.
///
/// This is the right-hand drawer the torrent list opens, the shape the other
/// download clients use. Chip rows worked while a library was small; with
/// twenty labels and a dozen trackers they became three scrolling strips that
/// crowded the list off the screen. A drawer holds the same filters with room
/// for the counts.
///
/// Counts are taken after the search box, like the chips were, so a figure in
/// here says how many torrents that row would leave in the list.
class TransmissionFilterDrawer extends ConsumerWidget {
  const TransmissionFilterDrawer({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final List<TransmissionTorrent> all =
        ref.watch(transmissionRawTorrentsProvider(instance)).value ??
            const <TransmissionTorrent>[];
    final TransmissionFilter filter =
        ref.watch(transmissionFilterProvider(instance));
    final String search = ref.watch(transmissionSearchProvider(instance));

    // The list with the search applied and no filter, which is what each
    // count is measured against.
    final List<TransmissionTorrent> searched = filterTransmissionTorrents(
      all,
      const TransmissionFilter(),
      search: search,
    );
    final bool anyPrivate = all.any((TransmissionTorrent t) => t.isPrivate);
    final List<String> trackers = transmissionTrackers(all);
    final List<String> labels = transmissionLabels(all);

    void set(TransmissionFilter Function(TransmissionFilter f) change) =>
        ref.read(transmissionFilterProvider(instance).notifier).update(change);

    /// How many of [searched] survive [candidate]. The drawer's promise is
    /// that a figure matches what tapping the row will leave on screen.
    int countFor(TransmissionFilter candidate) => searched
        .where(
          (TransmissionTorrent t) =>
              candidate.mode.matches(t) &&
              (candidate.tracker.isEmpty ||
                  t.trackerHosts.contains(candidate.tracker)) &&
              (candidate.label.isEmpty || t.labels.contains(candidate.label)),
        )
        .length;

    Widget section(String title, List<Widget> children) => ExpansionTile(
          initiallyExpanded: true,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md),
            child: Text(title),
          ),
          shape: const Border(),
          collapsedShape: const Border(),
          children: children,
        );

    Widget tile({
      required String title,
      required int count,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) =>
        _FilterTile(
          title: title,
          count: count,
          icon: icon,
          isSelected: selected,
          onTap: onTap,
        );

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Insets.lg),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.xl,
                Insets.md,
                Insets.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Filters', style: theme.textTheme.titleMedium),
                  ),
                  if (filter.isActive)
                    TextButton(
                      onPressed: () => ref
                          .read(transmissionFilterProvider(instance).notifier)
                          .state = const TransmissionFilter(),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            if (filter.isActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.xl,
                  0,
                  Insets.xl,
                  Insets.sm,
                ),
                child: Wrap(
                  spacing: Insets.xs,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    TransmissionPill(
                      label: filter.mode.label,
                      foreground: cs.onPrimaryContainer,
                      background: cs.primaryContainer,
                    ),
                    if (filter.tracker.isNotEmpty)
                      TransmissionPill(
                        icon: Icons.dns_outlined,
                        label: filter.tracker,
                        foreground: cs.onSecondaryContainer,
                        background: cs.secondaryContainer,
                      ),
                    if (filter.label.isNotEmpty)
                      TransmissionPill(
                        icon: Icons.label_outline,
                        label: filter.label,
                        foreground: cs.onSecondaryContainer,
                        background: cs.secondaryContainer,
                      ),
                  ],
                ),
              ),
            section('Status', <Widget>[
              for (final TransmissionFilterMode m
                  in TransmissionFilterMode.values)
                // Private and Public say nothing on an all-public list, so
                // they are not offered rather than offered as a useless 0.
                if (anyPrivate ||
                    (m != TransmissionFilterMode.private &&
                        m != TransmissionFilterMode.public))
                  tile(
                    title: m.label,
                    count: countFor(filter.copyWith(mode: m)),
                    icon: _modeIcon(m),
                    selected: filter.mode == m,
                    onTap: () => set(
                      (TransmissionFilter f) => f.copyWith(mode: m),
                    ),
                  ),
            ]),
            if (trackers.isNotEmpty)
              section('Trackers', <Widget>[
                tile(
                  title: 'All trackers',
                  count: countFor(filter.copyWith(tracker: '')),
                  icon: Icons.dns,
                  selected: filter.tracker.isEmpty,
                  onTap: () => set(
                    (TransmissionFilter f) => f.copyWith(tracker: ''),
                  ),
                ),
                for (final String host in trackers)
                  tile(
                    title: host,
                    count: countFor(filter.copyWith(tracker: host)),
                    icon: Icons.dns_outlined,
                    selected: filter.tracker == host,
                    onTap: () => set(
                      (TransmissionFilter f) => f.copyWith(tracker: host),
                    ),
                  ),
              ]),
            if (labels.isNotEmpty)
              section('Labels', <Widget>[
                tile(
                  title: 'All labels',
                  count: countFor(filter.copyWith(label: '')),
                  icon: Icons.sell,
                  selected: filter.label.isEmpty,
                  onTap: () => set(
                    (TransmissionFilter f) => f.copyWith(label: ''),
                  ),
                ),
                for (final String label in labels)
                  tile(
                    title: label,
                    count: countFor(filter.copyWith(label: label)),
                    icon: Icons.label_outline,
                    selected: filter.label == label,
                    onTap: () => set(
                      (TransmissionFilter f) => f.copyWith(label: label),
                    ),
                  ),
              ]),
          ],
        ),
      ),
    );
  }

  static IconData _modeIcon(TransmissionFilterMode m) => switch (m) {
        TransmissionFilterMode.all => Icons.filter_alt,
        TransmissionFilterMode.active => Icons.sync,
        TransmissionFilterMode.downloading => Icons.download,
        TransmissionFilterMode.seeding => Icons.upload,
        TransmissionFilterMode.paused => Icons.pause,
        TransmissionFilterMode.finished => Icons.check_circle_outline,
        TransmissionFilterMode.error => Icons.error_outline,
        TransmissionFilterMode.private => Icons.lock_outline,
        TransmissionFilterMode.public => Icons.public,
      };
}

/// One filter row: the name, how many torrents it would leave, and whether it
/// is the one in force.
class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.title,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        leading: Icon(icon),
        title: Text(
          '$title ($count)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null),
        ),
        onTap: onTap,
        selected: isSelected,
        selectedColor: cs.onSecondaryContainer,
        selectedTileColor: cs.secondaryContainer,
      ),
    );
  }
}
