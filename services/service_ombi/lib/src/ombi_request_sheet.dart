import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ombi_models.dart';
import 'ombi_failure.dart';
import 'ombi_providers.dart';
import 'services/ombi_client.dart';

/// Opens the request sheet for [hit] on the root navigator.
Future<void> showOmbiRequestSheet({
  required BuildContext context,
  required Instance instance,
  required OmbiSearchHit hit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext _) => OmbiRequestSheet(instance: instance, hit: hit),
  );
}

/// Where a title stands in Ombi, and a way to request it if it can be.
class OmbiRequestSheet extends ConsumerStatefulWidget {
  const OmbiRequestSheet({
    required this.instance,
    required this.hit,
    super.key,
  });

  final Instance instance;
  final OmbiSearchHit hit;

  @override
  ConsumerState<OmbiRequestSheet> createState() => _OmbiRequestSheetState();
}

class _OmbiRequestSheetState extends ConsumerState<OmbiRequestSheet> {
  bool _busy = false;

  OmbiTitleKey get _key => (
        instance: widget.instance,
        kind: widget.hit.kind,
        tmdbId: widget.hit.tmdbId,
      );

  Future<void> _request(Future<void> Function(OmbiClient client) action) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await runOmbiAction(ref, widget.instance, action);
      ref.invalidate(ombiTitleStateProvider(_key));
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Requested ${widget.hit.title}')),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeOmbiFailure(error))),
      );
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OmbiSearchHit hit = widget.hit;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              hit.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              hit.kind == OmbiMediaKind.movie ? 'Movie' : 'TV show',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (hit.overview != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              Text(
                hit.overview!,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: Insets.lg),
            ref.watch(ombiTitleStateProvider(_key)).when(
                  loading: () => const LinearProgressIndicator(),
                  error: (Object error, StackTrace _) => Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          describeOmbiFailure(error, lookup: OmbiLookup.title),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(ombiTitleStateProvider(_key)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  data: (OmbiTitleState state) => _body(theme, state),
                ),
          ],
        ),
      ),
    );
  }

  /// Worded the way Ombi's own title page words it.
  Widget _body(ThemeData theme, OmbiTitleState state) {
    if (state.available) {
      return _line(theme, Icons.check_circle_outline, 'Available');
    }
    if (state.denied) {
      final String? reason = state.deniedReason;
      return _line(
        theme,
        Icons.block,
        reason == null ? 'Denied' : 'Denied: $reason',
      );
    }
    if (state.requested) {
      return _line(theme, Icons.schedule, 'Requested');
    }

    final OmbiSearchHit hit = widget.hit;
    final List<Widget> buttons = hit.kind == OmbiMediaKind.movie
        ? <Widget>[
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _request(
                        (OmbiClient c) =>
                            c.requestService.requestMovie(hit.tmdbId),
                      ),
              icon: const Icon(Icons.add),
              label: const Text('Request'),
            ),
          ]
        : <Widget>[
            for (final (OmbiTvSeasons seasons, String label)
                in const <(OmbiTvSeasons, String)>[
              (OmbiTvSeasons.all, 'All seasons'),
              (OmbiTvSeasons.first, 'First season'),
              (OmbiTvSeasons.latest, 'Latest season'),
            ])
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _request(
                          (OmbiClient c) =>
                              c.requestService.requestTv(hit.tmdbId, seasons),
                        ),
                child: Text(label),
              ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.partlyAvailable) ...<Widget>[
          _line(theme, Icons.incomplete_circle, 'Partially Available'),
          const SizedBox(height: Insets.sm),
        ],
        for (final Widget button in buttons) ...<Widget>[
          button,
          const SizedBox(height: Insets.sm),
        ],
        Text(
          "Requests made here are made as Ombi's admin, so Ombi approves "
          'them and sends them on straight away.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _line(ThemeData theme, IconData icon, String text) => Row(
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      );
}
