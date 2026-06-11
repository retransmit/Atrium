import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prowlarr_release.dart';
import 'prowlarr_api.dart';
import 'prowlarr_providers.dart';

/// Sort orders for search results.
enum _SortBy { seeders, size, age }

/// Manual search across all of an instance's indexers, with grab-to-client.
///
/// Search is submit-driven (not debounced): one query fans out to every
/// enabled indexer and can take tens of seconds, so firing on every
/// keystroke would hammer the trackers.
class ProwlarrSearchScreen extends ConsumerStatefulWidget {
  const ProwlarrSearchScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<ProwlarrSearchScreen> createState() =>
      _ProwlarrSearchScreenState();
}

class _ProwlarrSearchScreenState extends ConsumerState<ProwlarrSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ProwlarrRelease>? _results;
  bool _searching = false;
  String? _error;
  _SortBy _sortBy = _SortBy.seeders;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final String term = query.trim();
    if (term.length < 2) {
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(widget.instance).future);
      final List<ProwlarrRelease> releases = await api.search(term);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = releases;
        _searching = false;
      });
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e is NetworkException ? e.message : '$e';
        _searching = false;
      });
    }
  }

  List<ProwlarrRelease> _sorted(List<ProwlarrRelease> list) {
    final List<ProwlarrRelease> out = List<ProwlarrRelease>.of(list);
    switch (_sortBy) {
      case _SortBy.seeders:
        out.sort(
          (ProwlarrRelease a, ProwlarrRelease b) =>
              (b.seeders ?? -1).compareTo(a.seeders ?? -1),
        );
      case _SortBy.size:
        out.sort(
          (ProwlarrRelease a, ProwlarrRelease b) => b.size.compareTo(a.size),
        );
      case _SortBy.age:
        out.sort(
          (ProwlarrRelease a, ProwlarrRelease b) =>
              (a.ageHours ?? a.age * 24).compareTo(b.ageHours ?? b.age * 24),
        );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search all indexers...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
        actions: <Widget>[
          PopupMenuButton<_SortBy>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sortBy,
            onSelected: (_SortBy v) => setState(() => _sortBy = v),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<_SortBy>>[
              PopupMenuItem<_SortBy>(
                value: _SortBy.seeders,
                child: Text('Seeders'),
              ),
              PopupMenuItem<_SortBy>(
                value: _SortBy.size,
                child: Text('Size'),
              ),
              PopupMenuItem<_SortBy>(
                value: _SortBy.age,
                child: Text('Age'),
              ),
            ],
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_searching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: Insets.lg),
            Text(
              'Searching your indexers...\nSlow trackers can take a while.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return ErrorView(
        title: 'Search failed',
        message: _error!,
        onRetry: () => _search(_controller.text),
      );
    }
    final List<ProwlarrRelease>? results = _results;
    if (results == null) {
      return const EmptyView(
        icon: Icons.travel_explore_outlined,
        title: 'Search your indexers',
        message: 'One query hits every enabled indexer and lets you '
            'grab a release straight to your download client.',
      );
    }
    if (results.isEmpty) {
      return const EmptyView(
        icon: Icons.search_off_outlined,
        title: 'No results',
        message: 'No indexer returned anything for that query.',
      );
    }
    final List<ProwlarrRelease> sorted = _sorted(results);
    return ListView.builder(
      padding: Insets.pageH,
      itemCount: sorted.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Text(
              '${sorted.length} releases',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          );
        }
        final ProwlarrRelease r = sorted[index - 1];
        return _ReleaseTile(
          release: r,
          onGrab: () => _grab(context, r),
          onTap: () => _showDetails(context, r),
        );
      },
    );
  }

  Future<void> _grab(BuildContext context, ProwlarrRelease release) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Grabbing "${release.title}"...')),
    );
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(widget.instance).future);
      await api.grabRelease(release);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Sent to download client')),
      );
    } on Object catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is NetworkException ? 'Grab failed: ${e.message}' : 'Grab failed',
          ),
        ),
      );
    }
  }

  void _showDetails(BuildContext context, ProwlarrRelease release) {
    // Root navigator: branch-navigator sheets get swept by GoRouter shell
    // rebuilds (see qBit add sheet for history).
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _ReleaseSheet(
        release: release,
        onGrab: () {
          Navigator.of(sheetContext).pop();
          _grab(context, release);
        },
      ),
    );
  }
}

class _ReleaseTile extends StatelessWidget {
  const _ReleaseTile({
    required this.release,
    required this.onGrab,
    required this.onTap,
  });

  final ProwlarrRelease release;
  final VoidCallback onGrab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> parts = <String>[
      if (release.indexer != null) release.indexer!,
      fmtReleaseBytes(release.size),
      release.ageLabel,
      if (release.isTorrent)
        'S:${release.seeders ?? '?'} L:${release.leechers ?? '?'}'
      else if (release.grabs != null)
        '${release.grabs} grabs',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        release.isTorrent ? Icons.swap_vert : Icons.newspaper_outlined,
        color: theme.colorScheme.outline,
      ),
      title: Text(
        release.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        parts.join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
      trailing: IconButton(
        tooltip: 'Grab',
        icon: const Icon(Icons.download_outlined),
        onPressed: onGrab,
      ),
    );
  }
}

class _ReleaseSheet extends StatelessWidget {
  const _ReleaseSheet({required this.release, required this.onGrab});

  final ProwlarrRelease release;
  final VoidCallback onGrab;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String categories = release.categories
        .map((ProwlarrReleaseCategory c) => c.name)
        .whereType<String>()
        .join(', ');
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Insets.lg,
          right: Insets.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(release.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: Insets.md),
            _DetailRow(label: 'Indexer', value: release.indexer ?? '-'),
            _DetailRow(label: 'Protocol', value: release.protocol ?? '-'),
            _DetailRow(label: 'Size', value: fmtReleaseBytes(release.size)),
            _DetailRow(label: 'Age', value: release.ageLabel),
            if (release.isTorrent)
              _DetailRow(
                label: 'Peers',
                value: '${release.seeders ?? '?'} seeders / '
                    '${release.leechers ?? '?'} leechers',
              ),
            if (release.grabs != null)
              _DetailRow(label: 'Grabs', value: '${release.grabs}'),
            if (categories.isNotEmpty)
              _DetailRow(label: 'Categories', value: categories),
            const SizedBox(height: Insets.lg),
            FilledButton.icon(
              onPressed: onGrab,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Grab'),
            ),
          ],
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
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Human-readable byte size for release rows.
String fmtReleaseBytes(num bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
