import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SelectServiceScreen extends StatelessWidget {
  const SelectServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Group ServiceKinds by their roles for a cleaner, grouped selection UI.
    final Map<ServiceRole, List<ServiceKind>> groupedServices = {};
    for (final ServiceKind kind in ServiceKind.values) {
      groupedServices.putIfAbsent(kind.role, () => []).add(kind);
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select service to add'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        children: <Widget>[
          for (final ServiceRole role in ServiceRole.values)
            if (groupedServices.containsKey(role)) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(
                  top: Insets.lg,
                  bottom: Insets.xs,
                  left: Insets.xs,
                ),
                child: Text(
                  _getRoleDisplayName(role),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: Insets.xs),
              Card(
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                color: cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: cs.outlineVariant.withAlpha(50),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    for (int i = 0;
                        i < groupedServices[role]!.length;
                        i++) ...<Widget>[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: cs.outlineVariant.withAlpha(30),
                        ),
                      _ServiceListTile(
                        kind: groupedServices[role]![i],
                        onTap: () {
                          context.goNamed(
                            AtriumRoutes.addInstanceFormName,
                            pathParameters: <String, String>{
                              'kind': groupedServices[role]![i].name,
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }

  String _getRoleDisplayName(ServiceRole role) {
    return switch (role) {
      ServiceRole.automation => 'AUTOMATION',
      ServiceRole.requests => 'REQUESTS',
      ServiceRole.analytics => 'ANALYTICS & METRICS',
      ServiceRole.mediaServer => 'MEDIA SERVERS',
      ServiceRole.downloader => 'DOWNLOADERS',
    };
  }
}

class _ServiceListTile extends StatelessWidget {
  const _ServiceListTile({
    required this.kind,
    required this.onTap,
  });

  final ServiceKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      leading: Container(
        padding: const EdgeInsets.all(Insets.xs),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _buildServiceIcon(kind, size: 28),
      ),
      title: Text(
        kind.displayName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        kind.tagline,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: cs.onSurfaceVariant.withAlpha(150),
      ),
      onTap: onTap,
    );
  }

  Widget _buildServiceIcon(ServiceKind kind, {double size = 24}) {
    if (kind.name == 'sabnzbd') {
      return Icon(Icons.cloud_download_outlined, size: size);
    }
    return Image.asset(
      'assets/service_icons/${kind.name}.png',
      width: size,
      height: size,
    );
  }
}
