import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/overseerr_request.dart';
import 'overseerr_api.dart';
import 'overseerr_providers.dart';

/// Overseerr's per-instance UI: the recent request list. Pending requests get
/// approve / decline actions - the key thing you want to do from a phone.
class OverseerrHome extends ConsumerWidget {
  const OverseerrHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OverseerrRequest>> requests =
        ref.watch(overseerrRequestsProvider(instance));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(overseerrRequestsProvider(instance)),
      child: AsyncValueView<List<OverseerrRequest>>(
        value: requests,
        onRetry: () => ref.invalidate(overseerrRequestsProvider(instance)),
        data: (List<OverseerrRequest> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.playlist_add_check_outlined,
              title: 'No requests',
              message: 'No media requests yet.',
            );
          }
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: list.length,
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
  final OverseerrRequest request;

  bool get _isPending => request.status == 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isMovie =
        (request.media?.mediaType ?? request.type).toLowerCase() == 'movie';
    final String who = request.requestedBy?.displayName.isNotEmpty == true
        ? request.requestedBy!.displayName
        : (request.requestedBy?.username ?? 'Unknown');

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: ListTile(
        leading: Icon(isMovie ? Icons.movie_outlined : Icons.live_tv_outlined),
        title: Text(isMovie ? 'Movie request' : 'Series request'),
        subtitle: Text('by $who'),
        trailing: _isPending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Approve',
                    icon: const Icon(Icons.check_circle_outline),
                    color: Colors.green,
                    onPressed: () => _act(ref, approve: true),
                  ),
                  IconButton(
                    tooltip: 'Decline',
                    icon: const Icon(Icons.cancel_outlined),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () => _act(ref, approve: false),
                  ),
                ],
              )
            : _StatusChip(status: request.status),
      ),
    );
  }

  Future<void> _act(WidgetRef ref, {required bool approve}) async {
    final OverseerrApi api =
        await ref.read(overseerrApiProvider(instance).future);
    if (approve) {
      await api.approve(request.id);
    } else {
      await api.decline(request.id);
    }
    ref.invalidate(overseerrRequestsProvider(instance));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final int status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      2 => ('Approved', Colors.green),
      3 => ('Declined', Theme.of(context).colorScheme.error),
      _ => ('Pending', Colors.orange),
    };
    return Chip(
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall,
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
