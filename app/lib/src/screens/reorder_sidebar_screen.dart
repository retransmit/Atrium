import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen allowing drag-and-drop reordering of configured services in the sidebar.
class ReorderSidebarScreen extends ConsumerStatefulWidget {
  const ReorderSidebarScreen({super.key});

  @override
  ConsumerState<ReorderSidebarScreen> createState() =>
      _ReorderSidebarScreenState();
}

class _ReorderSidebarScreenState extends ConsumerState<ReorderSidebarScreen> {
  List<Instance>? _localInstances;

  @override
  Widget build(BuildContext context) {
    final Profile? profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('No active profile')),
      );
    }

    // Sync local instances state with active profile's instances.
    final List<Instance> providerInstances = profile.instances;
    if (_localInstances == null ||
        _localInstances!.length != providerInstances.length) {
      _localInstances = List<Instance>.from(providerInstances);
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Sidebar'),
      ),
      body: _localInstances!.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Text(
                  'No services configured.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg,
                    vertical: Insets.md,
                  ),
                  child: Text(
                    'Drag and drop service cards to rearrange their order in the sidebar.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: _localInstances!.length,
                    onReorderItem: (int oldIndex, int newIndex) {
                      setState(() {
                        final Instance item =
                            _localInstances!.removeAt(oldIndex);
                        _localInstances!.insert(newIndex, item);
                      });

                      // Persist the new order to the active profile.
                      ref
                          .read(profileListProvider.notifier)
                          .updateProfile(profile.copyWith(
                            instances: _localInstances!,
                          ));
                    },
                    proxyDecorator:
                        (Widget child, int index, Animation<double> animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (BuildContext context, Widget? child) {
                          final double animValue =
                              Curves.easeInOut.transform(animation.value);
                          final double scale = 1.0 + (animValue * 0.04);
                          return Transform.scale(
                            scale: scale,
                            child: Material(
                              elevation: 8,
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final Instance instance = _localInstances![index];
                      return Padding(
                        key: ValueKey<String>(instance.id),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.lg,
                          vertical: Insets.xs,
                        ),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: cs.outlineVariant,
                            ),
                          ),
                          color: cs.surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.md,
                              vertical: Insets.sm,
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: ServiceVisuals.accent(instance.kind)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    ServiceVisuals.icon(instance.kind),
                                    color: ServiceVisuals.accent(instance.kind),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: Insets.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        instance.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${ServiceVisuals.roleLabel(instance.kind.role)} • ${instance.kind.displayName}',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Insets.md),
                                Icon(
                                  Icons.drag_handle_rounded,
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
