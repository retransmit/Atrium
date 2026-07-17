import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/seerr_discover.dart';
import 'models/seerr_request.dart';
import 'seerr_api.dart';
import 'seerr_discover_screen.dart';
import 'seerr_issues_screen.dart';
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
      length: 3,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Requests', icon: Icon(Icons.playlist_play)),
              Tab(text: 'Discover', icon: Icon(Icons.explore_outlined)),
              Tab(text: 'Issues', icon: Icon(Icons.report_problem_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _SeerrRequestsTab(instance: instance),
                SeerrDiscoverScreen(instance: instance),
                SeerrIssuesScreen(instance: instance),
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

    return M3RefreshIndicator(
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

/// One request as a tonal card: poster + title + requester + color-coded
/// status pills, with inline approve / decline for pending requests and the
/// overflow menu (retry, delete, etc.) top-right.
class _RequestTile extends ConsumerStatefulWidget {
  const _RequestTile({required this.instance, required this.request});

  final Instance instance;
  final SeerrRequest request;

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  bool _busy = false;

  Future<void> _handleAction(String action) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final SeerrApi api =
          await ref.read(seerrApiProvider(widget.instance).future);
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
      if (mounted) {
        ref.invalidate(seerrRequestsProvider(widget.instance));
        ref.invalidate(seerrRequestCountsProvider(widget.instance));
        messenger.showSnackBar(
          const SnackBar(content: Text('Action successful')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SeerrRequest request = widget.request;
    final String mediaType = request.media?.mediaType ?? request.type;
    final int? tmdbId = request.media?.tmdbId;

    if (mediaType.isEmpty || tmdbId == null) {
      return Card(
        child: ListTile(
          title: Text('Unknown Request #${request.id}'),
          subtitle: Text('Status: ${_statusString(request.status)}'),
        ),
      );
    }

    final AsyncValue<SeerrDiscoverResult> detailsAsync = ref.watch(
      seerrMediaDetailsProvider(
        (
          instance: widget.instance,
          mediaType: mediaType,
          tmdbId: tmdbId,
        ),
      ),
    );

    return detailsAsync.when(
      data: (SeerrDiscoverResult item) {
        return InkWell(
          onTap: () => pushScreen<void>(
            context,
            SeerrItemDetailScreen(instance: widget.instance, item: item),
          ),
          borderRadius: BorderRadius.circular(20),
          child: SeerrRequestCard(
            item: item,
              api: ref.watch(seerrApiProvider(widget.instance)).value,
            requestedBy: request.requestedBy?.displayName,
            mediaStatus: request.media?.status,
            requestStatus: request.status,
            trailing: _actionsMenu(),
            actions: _inlineActions(),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 180,
        child: Center(child: ExpressiveProgressIndicator()),
      ),
      error: (_, __) => ListTile(
        title: Text('Request #${request.id}'),
        subtitle: Text('Status: ${_statusString(request.status)}'),
        trailing: Icon(Icons.error, color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  /// The overflow menu keeps every request action reachable (approve /
  /// decline while pending, retry, delete).
  Widget _actionsMenu() {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 16,
          height: 16,
          child: ExpressiveProgressIndicator(strokeWidth: 2),
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
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            'Delete',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  /// Inline actions on the card: approve / decline while the request is
  /// pending. Delete is deliberately not inline - a one-tap destructive
  /// action invites mis-taps, so it stays in the overflow menu only.
  Widget? _inlineActions() {
    if (widget.request.status != 1) {
      return null;
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _handleAction('approve'),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve'),
          ),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _handleAction('decline'),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Decline'),
          ),
        ),
      ],
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
