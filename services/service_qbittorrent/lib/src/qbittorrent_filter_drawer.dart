import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/qbit_torrent.dart';
import 'qbittorrent_providers.dart';

class QbittorrentFilterDrawer extends ConsumerWidget {
  const QbittorrentFilterDrawer({required this.instance, super.key});
  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(qbitFilterStatusProvider(instance));
    final categoryFilter = ref.watch(qbitFilterCategoryProvider(instance));

    final AsyncValue<List<String>> categoriesAsync =
        ref.watch(qbitCategoriesProvider(instance));
    final AsyncValue<List<QbitTorrent>> rawTorrentsAsync =
        ref.watch(qbitRawTorrentsProvider(instance));

    int getStatusCount(String status, List<QbitTorrent> torrents) {
      return torrents
          .where((QbitTorrent t) => qbitStatusMatches(status, t))
          .length;
    }

    int getCategoryCount(String category, List<QbitTorrent> torrents) {
      if (category == 'uncategorized') {
        return torrents.where((t) => t.category.isEmpty).length;
      }
      return torrents.where((t) => t.category == category).length;
    }

    return Drawer(
      child: rawTorrentsAsync.when(
        data: (torrents) {
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                child: Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              ExpansionTile(
                initiallyExpanded: true,
                title: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('Status'),
                ),
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  _FilterTile(
                    title: 'All',
                    count: torrents.length,
                    icon: Icons.filter_alt,
                    isSelected: statusFilter == null || statusFilter == 'all',
                    onTap: () {
                      ref
                          .read(qbitFilterStatusProvider(instance).notifier)
                          .state = 'all';
                    },
                  ),
                  _FilterTile(
                    title: 'Active',
                    count: getStatusCount('active', torrents),
                    icon: Icons.sync,
                    isSelected: statusFilter == 'active',
                    onTap: () {
                      ref
                          .read(qbitFilterStatusProvider(instance).notifier)
                          .state = 'active';
                    },
                  ),
                  _FilterTile(
                    title: 'Downloading',
                    count: getStatusCount('downloading', torrents),
                    icon: Icons.download,
                    isSelected: statusFilter == 'downloading',
                    onTap: () {
                      ref
                          .read(qbitFilterStatusProvider(instance).notifier)
                          .state = 'downloading';
                    },
                  ),
                  _FilterTile(
                    title: 'Seeding',
                    count: getStatusCount('seeding', torrents),
                    icon: Icons.upload,
                    isSelected: statusFilter == 'seeding',
                    onTap: () {
                      ref
                          .read(qbitFilterStatusProvider(instance).notifier)
                          .state = 'seeding';
                    },
                  ),
                  _FilterTile(
                    title: 'Stopped',
                    count: getStatusCount('stopped', torrents),
                    icon: Icons.stop,
                    isSelected: statusFilter == 'stopped',
                    onTap: () {
                      ref
                          .read(qbitFilterStatusProvider(instance).notifier)
                          .state = 'stopped';
                    },
                  ),
                  _FilterTile(
                    title: 'Completed',
                    count: getStatusCount('completed', torrents),
                    icon: Icons.check,
                    isSelected: statusFilter == 'completed',
                    onTap: () {
                      ref
                          .read(qbitFilterStatusProvider(instance).notifier)
                          .state = 'completed';
                    },
                  ),
                  _FilterTile(
                    title: 'Errored',
                    count: getStatusCount('errored', torrents),
                    icon: Icons.error_outline,
                    isSelected: statusFilter == 'errored',
                    onTap: () {
                      ref
                          .read(qbitFilterStatusProvider(instance).notifier)
                          .state = 'errored';
                    },
                  ),
                ],
              ),
              ExpansionTile(
                initiallyExpanded: true,
                title: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('Category'),
                ),
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  _FilterTile(
                    title: 'All Categories',
                    count: torrents.length,
                    icon: Icons.folder_copy,
                    isSelected: categoryFilter == null,
                    onTap: () {
                      ref
                          .read(qbitFilterCategoryProvider(instance).notifier)
                          .state = null;
                    },
                  ),
                  _FilterTile(
                    title: 'Uncategorized',
                    count: getCategoryCount('uncategorized', torrents),
                    icon: Icons.folder_open,
                    isSelected: categoryFilter == 'uncategorized',
                    onTap: () {
                      ref
                          .read(qbitFilterCategoryProvider(instance).notifier)
                          .state = 'uncategorized';
                    },
                  ),
                  ...categoriesAsync.maybeWhen(
                    data: (categories) => categories.map(
                      (cat) => _FilterTile(
                        title: cat,
                        count: getCategoryCount(cat, torrents),
                        icon: Icons.folder,
                        isSelected: categoryFilter == cat,
                        onTap: () {
                          ref
                              .read(
                                  qbitFilterCategoryProvider(instance).notifier,)
                              .state = cat;
                        },
                      ),
                    ),
                    orElse: () => [],
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        leading: Icon(icon),
        title: Text('$title ($count)',
            style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null),),
        onTap: onTap,
        selected: isSelected,
        selectedColor: Theme.of(context).colorScheme.onSecondaryContainer,
        selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      ),
    );
  }
}
