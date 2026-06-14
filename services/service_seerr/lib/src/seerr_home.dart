import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/seerr_request.dart';
import 'seerr_api.dart';
import 'seerr_discover_screen.dart';
import 'seerr_providers.dart';
import 'seerr_item_detail.dart';

/// Seerr's per-instance UI: the recent request list. Pending requests get
/// approve / decline actions - the key thing you want to do from a phone.
class SeerrHome extends StatelessWidget {
  const SeerrHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Requests', icon: Icon(Icons.playlist_play)),
              Tab(text: 'Discover', icon: Icon(Icons.explore_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _SeerrRequestsTab(instance: instance),
                SeerrDiscoverScreen(instance: instance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeerrRequestsTab extends ConsumerWidget {
  const _SeerrRequestsTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SeerrRequest>> requests =
        ref.watch(seerrRequestsProvider(instance));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(seerrRequestsProvider(instance));
        ref.invalidate(seerrRequestCountsProvider(instance));
      },
      child: AsyncValueView<List<SeerrRequest>>(
        value: requests,
        onRetry: () {
          ref.invalidate(seerrRequestsProvider(instance));
          ref.invalidate(seerrRequestCountsProvider(instance));
        },
        data: (List<SeerrRequest> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.playlist_add_check_outlined,
              title: 'No requests',
              message: 'No media requests yet.',
            );
          }
          return ListView.separated(
            padding: Insets.page,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
            itemBuilder: (BuildContext context, int index) =>
                _RequestTile(instance: instance, request: list[index]),
          );
        },
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.instance, required this.request});

  final Instance instance;
  final SeerrRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaType = request.media?.mediaType ?? request.type;
    final tmdbId = request.media?.tmdbId;

    if (mediaType.isEmpty || tmdbId == null) {
      return Card(
        child: ListTile(
          title: Text('Unknown Request #${request.id}'),
          subtitle: Text('Status: ${_statusString(request.status)}'),
        ),
      );
    }

    final detailsAsync = ref.watch(seerrMediaDetailsProvider((
      instance: instance,
      mediaType: mediaType,
      tmdbId: tmdbId,
    )));

    return Card(
      child: detailsAsync.when(
        data: (item) {
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SeerrItemDetailScreen(
                    instance: instance,
                    item: item,
                  ),
                ),
              );
            },
            borderRadius: Radii.card,
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(Insets.sm),
                  child: Row(
                    children: <Widget>[
                      if (item.posterPath != null)
                        ClipRRect(
                          borderRadius: Radii.card,
                          child: Image.network(
                            'https://image.tmdb.org/t/p/w200${item.posterPath}',
                            width: 80,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 80,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: Radii.card,
                          ),
                          child: const Icon(Icons.image_not_supported),
                        ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.displayTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Requested by: ${request.requestedBy?.displayName ?? 'Unknown'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: Insets.sm),
                            _StatusChip(status: request.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _RequestActionsMenu(
                    instance: instance,
                    request: request,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => ListTile(
          title: Text('Request #${request.id}'),
          subtitle: Text('Status: ${_statusString(request.status)}'),
          trailing: const Icon(Icons.error, color: Colors.red),
        ),
      ),
    );
  }

  String _statusString(int status) {
    switch (status) {
      case 1:
        return 'Pending';
      case 2:
        return 'Approved';
      case 3:
        return 'Declined';
      default:
        return 'Unknown ($status)';
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 1: // Pending
        color = Colors.orange;
        label = 'Pending Approval';
        icon = Icons.pending;
        break;
      case 2: // Approved
        color = Colors.green;
        label = 'Approved';
        icon = Icons.check_circle;
        break;
      case 3: // Declined
        color = Colors.red;
        label = 'Declined';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
        icon = Icons.help;
    }

    return Chip(
      label: Text(label),
      avatar: Icon(icon, color: color, size: 16),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}

class _RequestActionsMenu extends ConsumerStatefulWidget {
  const _RequestActionsMenu({required this.instance, required this.request});
  
  final Instance instance;
  final SeerrRequest request;

  @override
  ConsumerState<_RequestActionsMenu> createState() => _RequestActionsMenuState();
}

class _RequestActionsMenuState extends ConsumerState<_RequestActionsMenu> {
  bool _isLoading = false;

  Future<void> _handleAction(String action) async {
    setState(() => _isLoading = true);
    try {
      final api = await ref.read(seerrApiProvider(widget.instance).future);
      switch (action) {
        case 'approve':
          await api.approve(widget.request.id);
          break;
        case 'decline':
          await api.decline(widget.request.id);
          break;
        case 'delete':
          await api.deleteRequest(widget.request.id);
          break;
        case 'retry':
          await api.retryRequest(widget.request.id);
          break;
      }
      ref.invalidate(seerrRequestsProvider(widget.instance));
      ref.invalidate(seerrRequestCountsProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action successful')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: _handleAction,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        if (widget.request.status == 1) ...<PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'approve',
            child: Text('Approve'),
          ),
          const PopupMenuItem<String>(
            value: 'decline',
            child: Text('Decline'),
          ),
        ],
        const PopupMenuItem<String>(
          value: 'retry',
          child: Text('Retry'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
