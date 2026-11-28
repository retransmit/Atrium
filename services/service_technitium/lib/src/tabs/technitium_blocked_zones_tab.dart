import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/technitium_blocked_zone.dart';
import '../technitium_providers.dart';

/// Blocked zones management: listing, adding, removing, and triggering updates.
class TechnitiumBlockedZonesTab extends ConsumerStatefulWidget {
  const TechnitiumBlockedZonesTab({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<TechnitiumBlockedZonesTab> createState() =>
      _TechnitiumBlockedZonesTabState();
}

class _TechnitiumBlockedZonesTabState
    extends ConsumerState<TechnitiumBlockedZonesTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _updating = false;

  Instance get _instance => widget.instance;
  TechnitiumActions get _actions =>
      ref.read(technitiumActionsProvider(_instance));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addZone() async {
    final TextEditingController controller = TextEditingController();
    final String? domain = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Add Blocked Zone'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Domain name',
            hintText: 'e.g. ads.example.com',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final String val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (domain == null || domain.isEmpty) return;
    try {
      await _actions.addBlockedZone(domain);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $domain to Blocked Zones')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add zone: $e')),
        );
      }
    }
  }

  Future<void> _deleteZone(String domain) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Blocked Zone'),
        content: Text('Remove $domain from blocked zones?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _actions.deleteBlockedZone(domain);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $domain')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete zone: $e')),
        );
      }
    }
  }

  Future<void> _forceUpdateBlockLists() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await _actions.forceUpdateBlockLists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block lists update triggered')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update block lists: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<TechnitiumBlockedZone>> zonesAsync =
        ref.watch(technitiumBlockedZonesProvider(_instance));

    return Scaffold(
      body: Column(
        children: <Widget>[
          // Header action strip
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Filter blocked zones...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(_searchController.clear),
                            )
                          : null,
                      filled: true,
                      fillColor: cs.surfaceContainerHigh,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: Insets.md),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                IconButton.filledTonal(
                  tooltip: 'Force update block lists',
                  onPressed: _updating ? null : _forceUpdateBlockLists,
                  icon: _updating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Zone list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _actions.refreshBlockedZones,
              child: zonesAsync.when(
                data: (List<TechnitiumBlockedZone> zones) {
                  final String query =
                      _searchController.text.trim().toLowerCase();
                  final List<TechnitiumBlockedZone> filtered = query.isEmpty
                      ? zones
                      : zones
                          .where(
                            (TechnitiumBlockedZone z) =>
                                z.domain.toLowerCase().contains(query),
                          )
                          .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: Insets.sm),
                          Text(
                            query.isEmpty
                                ? 'No custom blocked zones'
                                : 'No matching zones',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext ctx, int index) {
                      final TechnitiumBlockedZone zone = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.errorContainer,
                          child: Icon(Icons.block, size: 20, color: cs.error),
                        ),
                        title: Text(
                          zone.domain,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          tooltip: 'Delete zone',
                          onPressed: () => _deleteZone(zone.domain),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(Insets.lg),
                  children: <Widget>[
                    const SizedBox(height: Insets.xl),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Failed to load blocked zones: $e',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Insets.md),
                          OutlinedButton.icon(
                            onPressed: () => ref.invalidate(
                              technitiumBlockedZonesProvider(_instance),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'technitium-add-blocked-zone',
        onPressed: _addZone,
        icon: const Icon(Icons.add),
        label: const Text('Add zone'),
      ),
    );
  }
}
