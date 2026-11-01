import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../service_icon.dart';

/// Every supported service on one page, grouped under a heading per
/// category, with a search field in the app bar.
///
/// Tapping a service opens the instance form for it.
class ServiceGridScreen extends StatefulWidget {
  const ServiceGridScreen({super.key});

  @override
  State<ServiceGridScreen> createState() => _ServiceGridScreenState();
}

class _ServiceGridScreenState extends State<ServiceGridScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  bool _matches(ServiceKind kind) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    return kind.displayName.toLowerCase().contains(_searchQuery) ||
        kind.tagline.toLowerCase().contains(_searchQuery) ||
        ServiceVisuals.roleLabel(kind.role)
            .toLowerCase()
            .contains(_searchQuery) ||
        kind.name.toLowerCase().contains(_searchQuery);
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

    // Sections follow the role order; a section with nothing matching the
    // search is left out rather than shown empty.
    final List<(ServiceRole, List<ServiceKind>)> sections =
        <(ServiceRole, List<ServiceKind>)>[
      for (final ServiceRole role in ServiceRole.values)
        (
          role,
          ServiceKind.sortedValues
              .where((ServiceKind k) => k.role == role && _matches(k))
              .toList(growable: false),
        ),
    ].where(((ServiceRole, List<ServiceKind>) s) => s.$2.isNotEmpty).toList();

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
                      onPressed: _searchController.clear,
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
      body: sections.isEmpty
          ? _NoResults(onReset: _searchController.clear)
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.sm,
                Insets.md,
                Insets.xl,
              ),
              children: <Widget>[
                for (final (ServiceRole role, List<ServiceKind> kinds)
                    in sections)
                  _ServiceSection(
                    key: Key('service_section_${role.name}'),
                    title: ServiceVisuals.roleLabel(role),
                    kinds: kinds,
                    onSelect: (ServiceKind kind) =>
                        _selectService(context, kind),
                  ),
              ],
            ),
    );
  }
}

/// One category as a card: its title, then a row per service.
class _ServiceSection extends StatelessWidget {
  const _ServiceSection({
    required this.title,
    required this.kinds,
    required this.onSelect,
    super.key,
  });

  final String title;
  final List<ServiceKind> kinds;
  final ValueChanged<ServiceKind> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.md,
                Insets.lg,
                Insets.xs,
              ),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (int i = 0; i < kinds.length; i++) ...<Widget>[
              if (i > 0)
                // Starts under the text, past the icon column.
                Divider(
                  height: 1,
                  indent: 72,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              _ServiceRow(kind: kinds[i], onTap: () => onSelect(kinds[i])),
            ],
            const SizedBox(height: Insets.xs),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.kind, required this.onTap});

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
      child: InkWell(
        key: ValueKey<String>('service_card_${kind.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.sm,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                alignment: Alignment.center,
                child: ServiceIcon(kind: kind, size: 26),
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            kind.displayName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (kind.isBeta) ...<Widget>[
                          const SizedBox(width: Insets.sm),
                          const BetaBadge(),
                        ],
                      ],
                    ),
                    Text(
                      kind.tagline,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off_rounded, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: Insets.md),
            Text('No services found', style: theme.textTheme.titleMedium),
            const SizedBox(height: Insets.xs),
            Text(
              'Try a different search.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.md),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}
