import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/seerr_discover.dart';
import 'seerr_providers.dart';

/// Displays the details (overview, release date, etc.) for a single Seerr item.
class SeerrItemDetailScreen extends StatelessWidget {
  const SeerrItemDetailScreen({
    required this.instance,
    required this.item,
    super.key,
  });

  final Instance instance;
  final SeerrDiscoverResult item;

  @override
  Widget build(BuildContext context) {
    final bool isMovie = item.mediaType.toLowerCase() == 'movie';

    return Scaffold(
      appBar: AppBar(
        title: Text(item.displayTitle),
      ),
      body: SingleChildScrollView(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (item.posterPath != null)
              Center(
                child: ClipRRect(
                  borderRadius: Radii.card,
                  child: Image.network(
                    'https://image.tmdb.org/t/p/w500${item.posterPath}',
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: Insets.lg),
            Row(
              children: <Widget>[
                Icon(
                  isMovie ? Icons.movie_outlined : Icons.live_tv_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  isMovie ? 'Movie' : 'TV Show',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (item.voteAverage != null && item.voteAverage! > 0) ...<Widget>[
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    item.voteAverage!.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ],
            ),
            const SizedBox(height: Insets.md),
            if (item.displayDate != null) ...<Widget>[
              Text(
                'Release Date: ${item.displayDate}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: Insets.lg),
            ],
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: Insets.sm),
            _RequestButton(instance: instance, item: item),
            const SizedBox(height: Insets.md),
            Text(
              item.overview != null && item.overview!.isNotEmpty
                  ? item.overview!
                  : 'No overview available.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestButton extends ConsumerStatefulWidget {
  const _RequestButton({required this.instance, required this.item});

  final Instance instance;
  final SeerrDiscoverResult item;

  @override
  ConsumerState<_RequestButton> createState() => _RequestButtonState();
}

class _RequestButtonState extends ConsumerState<_RequestButton> {
  bool _isLoading = false;
  bool _requestedLocal = false;

  Future<void> _request() async {
    setState(() => _isLoading = true);
    try {
      final api = await ref.read(seerrApiProvider(widget.instance).future);
      await api.createRequest(
        mediaType: widget.item.mediaType,
        mediaId: widget.item.id,
      );
      if (mounted) {
        setState(() => _requestedLocal = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully!')),
        );
      }
      ref.invalidate(seerrRequestCountsProvider(widget.instance));
      ref.invalidate(seerrRequestsProvider(widget.instance));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request: $e')),
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
    final status = widget.item.mediaInfo?.status ?? 1;
    // 1 = unknown, 2 = pending, 3 = processing, 4 = partially available, 5 = available
    
    if (_requestedLocal || status == 2 || status == 3) {
      return Chip(
        label: Text(status == 3 ? 'Processing' : 'Requested'),
        avatar: const Icon(Icons.pending),
      );
    } else if (status == 4 || status == 5) {
      return const Chip(
        label: Text('Available'),
        avatar: Icon(Icons.check_circle, color: Colors.green),
      );
    }

    return FilledButton.icon(
      onPressed: _isLoading ? null : _request,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_to_queue),
      label: const Text('Request'),
    );
  }
}

