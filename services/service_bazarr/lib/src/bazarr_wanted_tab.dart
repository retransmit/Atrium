import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_providers.dart';
import 'models/bazarr_models.dart';

/// The Wanted tab: a badges header (wanted episodes / movies / provider count)
/// above a unified list of items still missing subtitles.
class BazarrWantedTab extends ConsumerWidget {
  const BazarrWantedTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BazarrWantedRow>> wanted =
        ref.watch(bazarrWantedProvider(instance));

    return EasyRefresh(
      header: const MaterialHeader(),
      onRefresh: () async {
        ref.invalidate(bazarrBadgesProvider(instance));
        ref.invalidate(bazarrWantedProvider(instance));
      },
      child: Column(
        children: <Widget>[
          _BadgesHeader(instance: instance),
          Expanded(
            child: AsyncValueView<List<BazarrWantedRow>>(
              value: wanted,
              onRetry: () => ref.invalidate(bazarrWantedProvider(instance)),
              data: (List<BazarrWantedRow> rows) {
                if (rows.isEmpty) {
                  return const EmptyView(
                    icon: Icons.subtitles_outlined,
                    title: 'All subtitled',
                    message: 'Nothing is waiting on subtitles.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    0,
                    Insets.lg,
                    Insets.lg,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Insets.sm),
                  itemBuilder: (BuildContext context, int index) =>
                      _WantedTile(row: rows[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgesHeader extends ConsumerWidget {
  const _BadgesHeader({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BazarrBadges? b = ref.watch(bazarrBadgesProvider(instance)).value;
    if (b == null) {
      return const SizedBox(height: Insets.sm);
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                icon: Icons.live_tv_outlined,
                value: b.episodes,
                label: 'Episodes',
                color: cs.secondary,
              ),
            ),
            Expanded(
              child: _StatTile(
                icon: Icons.movie_outlined,
                value: b.movies,
                label: 'Movies',
                color: cs.secondary,
              ),
            ),
            Expanded(
              child: _StatTile(
                icon: Icons.cloud_outlined,
                value: b.providers,
                label: 'Providers',
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(height: Insets.xs),
        Text(
          '$value',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _WantedTile extends StatelessWidget {
  const _WantedTile({required this.row});

  final BazarrWantedRow row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              row.isMovie ? Icons.movie_outlined : Icons.live_tv_outlined,
              color: cs.secondary,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  row.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (row.missing.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.xs,
                    runSpacing: Insets.xs,
                    children: <Widget>[
                      for (final BazarrSubtitle s in row.missing.take(3))
                        _LangPill(
                          label: s.code2.isNotEmpty
                              ? s.code2.toUpperCase()
                              : s.name,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact tonal pill for a missing subtitle language code.
class _LangPill extends StatelessWidget {
  const _LangPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
