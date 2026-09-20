import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/myspeed_config.dart';
import '../models/myspeed_storage.dart';
import '../myspeed_providers.dart';

/// Tab 2: Configuration information.
///
/// Fetches `GET /api/config` and `GET /api/storage` to display settings,
/// cron schedule, test provider info, and storage / database statistics.
class MySpeedConfigTab extends ConsumerStatefulWidget {
  const MySpeedConfigTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<MySpeedConfigTab> createState() => _MySpeedConfigTabState();
}

class _MySpeedConfigTabState extends ConsumerState<MySpeedConfigTab> {
  String _filterQuery = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MySpeedConfig> configAsync =
        ref.watch(myspeedConfigProvider(widget.instance));
    final AsyncValue<MySpeedStorage> storageAsync =
        ref.watch(myspeedStorageProvider(widget.instance));

    return AsyncValueView<MySpeedConfig>(
      value: configAsync,
      onRetry: () {
        ref.invalidate(myspeedConfigProvider(widget.instance));
        ref.invalidate(myspeedStorageProvider(widget.instance));
      },
      data: (MySpeedConfig config) {
        final Map<String, dynamic> filteredEntries = <String, dynamic>{
          for (final MapEntry<String, dynamic> entry in config.entries.entries)
            if (_filterQuery.isEmpty ||
                entry.key.toLowerCase().contains(_filterQuery.toLowerCase()) ||
                entry.value.toString().toLowerCase().contains(_filterQuery.toLowerCase()))
              entry.key: entry.value,
        };

        return EasyRefresh(
          onRefresh: () async {
            ref.invalidate(myspeedConfigProvider(widget.instance));
            ref.invalidate(myspeedStorageProvider(widget.instance));
            await Future.wait(<Future<dynamic>>[
              ref.read(myspeedConfigProvider(widget.instance).future),
              ref.read(myspeedStorageProvider(widget.instance).future),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: Insets.page,
            children: <Widget>[
              _buildOverviewCard(context, config),
              const SizedBox(height: Insets.md),
              _buildStorageCard(context, storageAsync, config),
              const SizedBox(height: Insets.md),
              _buildSearchBar(context),
              const SizedBox(height: Insets.md),
              _buildEntriesCard(context, filteredEntries),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard(BuildContext context, MySpeedConfig config) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Configuration overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Insets.md),
            if (config.cron != null && config.cron!.isNotEmpty) ...<Widget>[
              _overviewRow(
                context,
                icon: Icons.schedule_rounded,
                label: 'Cron schedule',
                value: config.cron!,
                color: colors.primary,
              ),
              const SizedBox(height: Insets.sm),
            ],
            if (config.provider != null && config.provider!.isNotEmpty) ...<Widget>[
              _overviewRow(
                context,
                icon: Icons.hub_rounded,
                label: 'Test provider',
                value: config.provider!,
                color: colors.tertiary,
              ),
              const SizedBox(height: Insets.sm),
            ],
            if (config.server != null && config.server!.isNotEmpty) ...<Widget>[
              _overviewRow(
                context,
                icon: Icons.dns_rounded,
                label: 'Server / Node',
                value: config.server!,
                color: colors.secondary,
              ),
              const SizedBox(height: Insets.sm),
            ],
            _overviewRow(
              context,
              icon: Icons.settings_ethernet_rounded,
              label: 'Active properties',
              value: '${config.entries.length} keys loaded',
              color: colors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard(
    BuildContext context,
    AsyncValue<MySpeedStorage> storageAsync,
    MySpeedConfig config,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Storage and retention',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Insets.md),
            storageAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: Insets.sm),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (error, _) => Text(
                'Could not load storage info',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.outline),
              ),
              data: (MySpeedStorage storage) {
                final String? retention = config.entries['retentionDays']?.toString();
                return Column(
                  children: <Widget>[
                    _overviewRow(
                      context,
                      icon: Icons.storage_rounded,
                      label: 'Database size',
                      value: storage.formattedSize,
                      color: colors.primary,
                    ),
                    const SizedBox(height: Insets.sm),
                    _overviewRow(
                      context,
                      icon: Icons.analytics_outlined,
                      label: 'Tests stored',
                      value: '${storage.testCount ?? 0}',
                      color: colors.secondary,
                    ),
                    if (retention != null && retention.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Insets.sm),
                      _overviewRow(
                        context,
                        icon: Icons.auto_delete_outlined,
                        label: 'Data retention',
                        value: '$retention days',
                        color: colors.tertiary,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Insets.sm),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return TextField(
      decoration: InputDecoration(
        hintText: 'Filter configuration keys...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _filterQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() => _filterQuery = ''),
              )
            : null,
        filled: true,
        fillColor: colors.surfaceContainer,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      onChanged: (String val) => setState(() => _filterQuery = val.trim()),
    );
  }

  Widget _buildEntriesCard(BuildContext context, Map<String, dynamic> entries) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    if (entries.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
        ),
        color: colors.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Insets.xl),
          child: Center(
            child: Text(
              'No matching configuration keys.',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.outline),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      color: colors.surfaceContainer,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colors.outlineVariant.withValues(alpha: 0.3),
        ),
        itemBuilder: (BuildContext context, int index) {
          final String key = entries.keys.elementAt(index);
          final dynamic value = entries.values.elementAt(index);

          return ListTile(
            title: Text(
              key,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              value.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy value',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value.toString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied "$key" to clipboard'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
