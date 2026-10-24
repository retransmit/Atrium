import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../service_icon.dart';

/// Screen displaying a searchable and categorized grid of all supported services.
///
/// Tapping a service directs the user to the instance configuration form
/// pre-populated for that service.
class ServiceGridScreen extends StatefulWidget {
  const ServiceGridScreen({super.key});

  @override
  State<ServiceGridScreen> createState() => _ServiceGridScreenState();
}

class _ServiceGridScreenState extends State<ServiceGridScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _categoryController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // One tab for "All", then one per role; index 0 maps to no role filter,
    // mirroring the tab strip used on the Emby and Jellyfin homes. The shared
    // controller keeps the strip and the swipeable grid pages in sync.
    _categoryController = TabController(
      length: ServiceRole.values.length + 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  /// Services for one tab page: the page's role, intersected with the search
  /// query typed in the app bar.
  List<ServiceKind> _filteredServices(ServiceRole? pageRole) {
    return ServiceKind.sortedValues.where((ServiceKind kind) {
      if (pageRole != null && kind.role != pageRole) {
        return false;
      }
      if (_searchQuery.isEmpty) {
        return true;
      }
      final String name = kind.displayName.toLowerCase();
      final String tagline = kind.tagline.toLowerCase();
      final String role = ServiceVisuals.roleLabel(kind.role).toLowerCase();
      final String key = kind.name.toLowerCase();
      return name.contains(_searchQuery) ||
          tagline.contains(_searchQuery) ||
          role.contains(_searchQuery) ||
          key.contains(_searchQuery);
    }).toList(growable: false);
  }

  Future<void> _selectService(BuildContext context, ServiceKind kind) async {
    final Object? result = await context.pushNamed(
      AtriumRoutes.addInstanceFormName,
      pathParameters: <String, String>{'kind': kind.name},
    );
    if (result == true && context.mounted && context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Insets.sm,
        title: SizedBox(
          height: 44,
          child: TextField(
            key: const Key('service_search_bar'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search services...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged();
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.xl),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            controller: _categoryController,
            tabs: <Widget>[
              const Tab(
                key: Key('category_tab_all'),
                text: 'All',
              ),
              for (final ServiceRole role in ServiceRole.values)
                Tab(
                  key: Key('category_tab_${role.name}'),
                  text: ServiceVisuals.roleLabel(role),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _categoryController,
              children: <Widget>[
                _buildGridPage(null),
                for (final ServiceRole role in ServiceRole.values)
                  _buildGridPage(role),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One grid page of the [TabBarView]; role is null for the All page.
  Widget _buildGridPage(ServiceRole? role) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final List<ServiceKind> services = _filteredServices(role);
    final double width = MediaQuery.sizeOf(context).width;
    final double textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final int crossAxisCount = width > 900
        ? 4
        : width > 600
            ? 3
            : 2;
    final double baseRatio = width < 360 ? 1.05 : 1.12;
    final double childAspectRatio =
        (baseRatio / textScale.clamp(1.0, 2.0)).clamp(0.55, 1.2);

    if (services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: Insets.md),
              Text(
                'No services found',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Try a different search query or filter category.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Insets.md),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _categoryController.animateTo(0);
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset filters'),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(Insets.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: Insets.md,
        mainAxisSpacing: Insets.md,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: services.length,
      itemBuilder: (BuildContext context, int index) {
        final ServiceKind kind = services[index];
        return _ServiceGridCard(
          kind: kind,
          onTap: () => _selectService(context, kind),
        );
      },
    );
  }
}

class _ServiceGridCard extends StatelessWidget {
  const _ServiceGridCard({
    required this.kind,
    required this.onTap,
  });

  final ServiceKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent = ServiceVisuals.accent(kind);

    return Semantics(
      button: true,
      label: 'Add ${kind.displayName}',
      child: Card(
        key: ValueKey<String>('service_card_${kind.name}'),
        elevation: 0,
        color: cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: Insets.sm,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 58,
                            maxHeight: 58,
                          ),
                          padding: const EdgeInsets.all(Insets.xs),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          child: Center(
                            child: FittedBox(
                              child: ServiceIcon(kind: kind, size: 40),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        kind.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Insets.xxs),
                      Text(
                        kind.tagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (kind.isBeta)
                const Positioned(
                  top: Insets.xs,
                  right: Insets.xs,
                  child: BetaBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
