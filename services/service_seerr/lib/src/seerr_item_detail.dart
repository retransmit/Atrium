import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/seerr_discover.dart';
import 'models/seerr_service.dart';
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
  bool _requestedLocal = false;

  Future<void> _openRequestSheet() async {
    final bool? requested = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _RequestOptionsSheet(instance: widget.instance, item: widget.item),
    );
    if (requested == true && mounted) {
      setState(() => _requestedLocal = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully!')),
      );
      ref.invalidate(seerrRequestCountsProvider(widget.instance));
      ref.invalidate(seerrRequestsProvider(widget.instance));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.item.mediaInfo?.status ?? 1;
    // 1 = unknown, 2 = pending, 3 = processing, 4 = partial, 5 = available.
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
      onPressed: _openRequestSheet,
      icon: const Icon(Icons.add_to_queue),
      label: const Text('Request'),
    );
  }
}

/// Sheet to pick the quality profile / root folder / server before submitting
/// a request. Falls back to a defaults-only request when the service options
/// can't be loaded (e.g. the user lacks the advanced-request permission).
class _RequestOptionsSheet extends ConsumerStatefulWidget {
  const _RequestOptionsSheet({required this.instance, required this.item});

  final Instance instance;
  final SeerrDiscoverResult item;

  @override
  ConsumerState<_RequestOptionsSheet> createState() =>
      _RequestOptionsSheetState();
}

class _RequestOptionsSheetState extends ConsumerState<_RequestOptionsSheet> {
  int? _serverId;
  int? _profileId;
  String? _rootFolder;
  bool _submitting = false;
  String? _error;

  String get _mediaType => widget.item.mediaType;

  Future<void> _submit({int? serverId, int? profileId, String? rootFolder}) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = await ref.read(seerrApiProvider(widget.instance).future);
      await api.createRequest(
        mediaType: widget.item.mediaType,
        mediaId: widget.item.id,
        serverId: serverId,
        profileId: profileId,
        rootFolder: rootFolder,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Request failed: $e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<SeerrServer>> serversAsync = ref.watch(
      seerrServersProvider((instance: widget.instance, mediaType: _mediaType)),
    );

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
            Text(
              'Request',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 2),
            Text(widget.item.displayTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: Insets.lg),
            serversAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Insets.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, _) => _fallback(
                'Advanced options are unavailable. You can still request using '
                'the server defaults.',
              ),
              data: (List<SeerrServer> servers) => servers.isEmpty
                  ? _fallback(
                      'No ${_mediaType == 'tv' ? 'Sonarr' : 'Radarr'} server is '
                      'configured; requesting will use Seerr defaults.',
                    )
                  : _options(servers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _options(List<SeerrServer> servers) {
    final SeerrServer defaultServer = servers.firstWhere(
      (SeerrServer s) => s.isDefault,
      orElse: () => servers.first,
    );
    final int serverId = _serverId ?? defaultServer.id;
    final SeerrServer server = servers.firstWhere(
      (SeerrServer s) => s.id == serverId,
      orElse: () => defaultServer,
    );

    final AsyncValue<SeerrServerDetails> detailsAsync = ref.watch(
      seerrServerDetailsProvider(
        (instance: widget.instance, mediaType: _mediaType, serverId: serverId),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (servers.length > 1) ...<Widget>[
          DropdownButtonFormField<int>(
            initialValue: serverId,
            decoration: const InputDecoration(
              labelText: 'Server',
              border: OutlineInputBorder(),
            ),
            items: servers
                .map((SeerrServer s) => DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.name.isEmpty ? 'Server ${s.id}' : s.name),
                    ),)
                .toList(),
            onChanged: (int? v) => setState(() {
              _serverId = v;
              _profileId = null;
              _rootFolder = null;
            }),
          ),
          const SizedBox(height: Insets.md),
        ],
        detailsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Insets.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Could not load quality profiles for this server.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Insets.md),
              _submitButton(
                'Request with defaults',
                () => _submit(serverId: serverId),
              ),
            ],
          ),
          data: (SeerrServerDetails details) =>
              _form(server, details, serverId),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _form(SeerrServer server, SeerrServerDetails details, int serverId) {
    final List<SeerrProfile> profiles = details.profiles;
    final List<SeerrRootFolder> roots = details.rootFolders;

    // Resolve the effective selections, guarding against a default that isn't
    // in the list so the dropdown never asserts on an unknown value.
    int? profileId = _profileId ?? server.activeProfileId;
    if (!profiles.any((SeerrProfile p) => p.id == profileId)) {
      profileId = profiles.isNotEmpty ? profiles.first.id : null;
    }
    String? rootFolder = _rootFolder ?? server.activeDirectory;
    if (!roots.any((SeerrRootFolder r) => r.path == rootFolder)) {
      rootFolder = roots.isNotEmpty ? roots.first.path : null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (profiles.isNotEmpty)
          DropdownButtonFormField<int>(
            // Re-key per server so a server switch reseeds the initial value.
            key: ValueKey<String>('profile-$serverId'),
            initialValue: profileId,
            decoration: const InputDecoration(
              labelText: 'Quality profile',
              border: OutlineInputBorder(),
            ),
            items: profiles
                .map((SeerrProfile p) => DropdownMenuItem<int>(
                      value: p.id,
                      child: Text(p.name),
                    ),)
                .toList(),
            onChanged: (int? v) => setState(() => _profileId = v),
          ),
        if (roots.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.md),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('root-$serverId'),
            initialValue: rootFolder,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Root folder',
              border: OutlineInputBorder(),
            ),
            items: roots
                .map((SeerrRootFolder r) => DropdownMenuItem<String>(
                      value: r.path,
                      child: Text(r.path, overflow: TextOverflow.ellipsis),
                    ),)
                .toList(),
            onChanged: (String? v) => setState(() => _rootFolder = v),
          ),
        ],
        const SizedBox(height: Insets.lg),
        _submitButton(
          'Request',
          () => _submit(
            serverId: serverId,
            profileId: profileId,
            rootFolder: rootFolder,
          ),
        ),
      ],
    );
  }

  Widget _fallback(String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: Insets.lg),
        _submitButton('Request', _submit),
        if (_error != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _submitButton(String label, VoidCallback onPressed) {
    return FilledButton.icon(
      onPressed: _submitting ? null : onPressed,
      icon: _submitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_to_queue),
      label: Text(label),
    );
  }
}

