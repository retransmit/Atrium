import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gotify_format.dart';
import 'gotify_providers.dart';
import 'models/gotify_models.dart';

/// Gotify's messages, filterable by application, with swipe to delete and
/// clearing. Rendered inside the app's generic service scaffold.
class GotifyHome extends ConsumerStatefulWidget {
  const GotifyHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<GotifyHome> createState() => _GotifyHomeState();
}

class _GotifyHomeState extends ConsumerState<GotifyHome> {
  bool _loadingOlder = false;

  Instance get _instance => widget.instance;

  Future<void> _refresh() async {
    ref.invalidate(gotifyApplicationsProvider(_instance));
    ref.invalidate(gotifyMessagesProvider(_instance));
    try {
      await ref.read(gotifyMessagesProvider(_instance).future);
    } on Object {
      // Shown by the list's error view.
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_describe(error)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _delete(GotifyMessage message) async {
    try {
      await ref.read(gotifyMessagesProvider(_instance).notifier).delete(
            message.id,
          );
    } on Object catch (e) {
      _showError(e);
    }
  }

  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    try {
      await ref.read(gotifyMessagesProvider(_instance).notifier).loadOlder();
    } on Object catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _clear(String scope) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete messages?'),
        content: Text('Every message from $scope is deleted from the server. '
            'This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(gotifyMessagesProvider(_instance).notifier).clear();
    } on Object catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<GotifyApplication> apps =
        ref.watch(gotifyApplicationsProvider(_instance)).value ??
            const <GotifyApplication>[];
    final Map<int, GotifyApplication> appsById = <int, GotifyApplication>{
      for (final GotifyApplication a in apps) a.id: a,
    };
    final int? selected = ref.watch(gotifySelectedAppProvider(_instance));
    final AsyncValue<GotifyMessageFeed> feed =
        ref.watch(gotifyMessagesProvider(_instance));
    final bool hasMessages = feed.value?.messages.isNotEmpty ?? false;

    return Column(
      children: <Widget>[
        SizedBox(
          height: 56,
          child: Row(
            children: <Widget>[
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.sm,
                  ),
                  children: <Widget>[
                    _AppChip(
                      label: 'All',
                      selected: selected == null,
                      onSelected: () => ref
                          .read(gotifySelectedAppProvider(_instance).notifier)
                          .state = null,
                    ),
                    for (final GotifyApplication app in apps)
                      _AppChip(
                        label: app.name,
                        selected: selected == app.id,
                        onSelected: () => ref
                            .read(
                              gotifySelectedAppProvider(_instance).notifier,
                            )
                            .state = app.id,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete all shown',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: hasMessages
                    ? () => _clear(
                          selected == null
                              ? 'every application'
                              : appsById[selected]?.name ?? 'this application',
                        )
                    : null,
              ),
              const SizedBox(width: Insets.xs),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<GotifyMessageFeed>(
            value: feed,
            onRetry: _refresh,
            data: (GotifyMessageFeed data) => EasyRefresh(
              onRefresh: _refresh,
              child: data.messages.isEmpty
                  ? ListView(
                      children: const <Widget>[
                        SizedBox(height: 120),
                        EmptyView(
                          icon: Icons.notifications_none_outlined,
                          title: 'No messages',
                          message: 'New notifications show up here.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.lg,
                        0,
                        Insets.lg,
                        Insets.xl,
                      ),
                      itemCount: data.messages.length + (data.hasMore ? 1 : 0),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == data.messages.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: Insets.sm),
                            child: Center(
                              child: _loadingOlder
                                  ? const ExpressiveProgressIndicator()
                                  : TextButton.icon(
                                      onPressed: _loadOlder,
                                      icon: const Icon(Icons.expand_more),
                                      label: const Text('Load older'),
                                    ),
                            ),
                          );
                        }
                        final GotifyMessage message = data.messages[index];
                        return Dismissible(
                          key: ValueKey<int>(message.id),
                          direction: DismissDirection.endToStart,
                          background: const _DeleteBackground(),
                          onDismissed: (_) => _delete(message),
                          child: GotifyMessageCard(
                            message: message,
                            appName: appsById[message.appId]?.name,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppChip extends StatelessWidget {
  const _AppChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: Insets.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onSelected(),
        ),
      );
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Insets.xs),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: Radii.card,
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

/// One message: application, title, age, priority and the full text.
class GotifyMessageCard extends StatelessWidget {
  const GotifyMessageCard({required this.message, this.appName, super.key});

  final GotifyMessage message;
  final String? appName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = switch (message.level) {
      GotifyPriority.high => scheme.error,
      GotifyPriority.normal => scheme.primary,
      GotifyPriority.low => scheme.outline,
    };
    final String source = appName ?? 'Application ${message.appId}';
    final DateTime? date = message.date;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Text(
                    source.characters.first.toUpperCase(),
                    style: theme.textTheme.labelLarge?.copyWith(color: accent),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        message.title ?? source,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        <String>[
                          if (message.title != null) source,
                          if (date != null)
                            gotifyRelativeTime(date, DateTime.now()),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
                if (message.level == GotifyPriority.high)
                  Icon(Icons.priority_high_rounded, size: 18, color: accent),
              ],
            ),
            if (message.message.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.sm),
              SelectableText(message.message, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

String _describe(Object error) =>
    error is NetworkException ? error.message : error.toString();
