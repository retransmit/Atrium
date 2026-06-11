import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/tautulli_activity.dart';
import 'tautulli_providers.dart';

/// Tautulli's per-instance UI: the current activity (active Plex streams) with
/// who's watching what and how far in.
class TautulliHome extends ConsumerWidget {
  const TautulliHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TautulliActivity> activity =
        ref.watch(tautulliActivityProvider(instance));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tautulliActivityProvider(instance)),
      child: AsyncValueView<TautulliActivity>(
        value: activity,
        onRetry: () => ref.invalidate(tautulliActivityProvider(instance)),
        data: (TautulliActivity a) {
          if (a.sessions.isEmpty) {
            return const EmptyView(
              icon: Icons.podcasts_outlined,
              title: 'Nothing playing',
              message: 'No active streams right now.',
            );
          }
          return ListView.builder(
            padding: Insets.page,
            itemCount: a.sessions.length,
            itemBuilder: (BuildContext context, int index) =>
                _SessionCard(session: a.sessions[index]),
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final TautulliSession session;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double pct = (double.tryParse(session.progressPercent) ?? 0) / 100.0;
    final bool playing = session.state.toLowerCase() == 'playing';

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  playing ? Icons.play_arrow : Icons.pause,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: Text(
                    session.fullTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            LinearProgressIndicator(value: pct.clamp(0, 1)),
            const SizedBox(height: Insets.xs),
            Text(
              <String>[
                session.friendlyName,
                if (session.player.isNotEmpty) session.player,
                if (session.transcodeDecision.isNotEmpty)
                  session.transcodeDecision,
              ].join(' • '),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
