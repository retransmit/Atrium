import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/seerr_request.dart';
import 'seerr_discover_screen.dart';
import 'seerr_item_detail.dart';
import 'seerr_media_card.dart';
import 'seerr_providers.dart';

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
    ),),);

    return detailsAsync.when(
      data: (item) {
        return InkWell(
          onTap: () => pushScreen<void>(
            context,
            SeerrItemDetailScreen(instance: instance, item: item),
          ),
          borderRadius: BorderRadius.circular(20),
          child: SeerrRequestCard(
            item: item,
            requestedBy: request.requestedBy?.displayName,
            mediaStatus: request.media?.status,
            requestStatus: request.status,
            trailing: _RequestActionsMenu(
              instance: instance,
              request: request,
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => ListTile(
        title: Text('Request #${request.id}'),
        subtitle: Text('Status: ${_statusString(request.status)}'),
        trailing: const Icon(Icons.error, color: Colors.red),
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
      icon: const Icon(Icons.more_vert, color: Colors.white),
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
