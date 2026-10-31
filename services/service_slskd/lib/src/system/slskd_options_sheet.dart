import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../slskd_api.dart';
import '../slskd_providers.dart';

/// Modal bottom sheet allowing inspection of daemon configuration and runtime diagnostics.
class SlskdOptionsSheet extends ConsumerStatefulWidget {
  const SlskdOptionsSheet({
    required this.instance,
    super.key,
  });

  final Instance instance;

  static Future<void> show(
    BuildContext context, {
    required Instance instance,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SlskdOptionsSheet(instance: instance),
    );
  }

  @override
  ConsumerState<SlskdOptionsSheet> createState() => _SlskdOptionsSheetState();
}

class _SlskdOptionsSheetState extends ConsumerState<SlskdOptionsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _triggerGarbageCollection() async {
    setState(() => _isActionInProgress = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final SlskdApi api =
          await ref.read(slskdApiProvider(widget.instance).future);
      await api.collectGarbage();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('.NET CLR Garbage Collection completed'),
          duration: Duration(seconds: 2),
        ),
      );
      ref.invalidate(slskdPrometheusKpisProvider(widget.instance));
    } catch (e) {
      if (mounted) {
        final msg = (e is DioException && e.response?.statusCode == 403)
            ? 'Garbage collection requires an API key with Administrator/ReadWrite role'
            : 'Failed to trigger GC: $e';
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _triggerLoopbackTest() async {
    setState(() => _isActionInProgress = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final SlskdApi api =
          await ref.read(slskdApiProvider(widget.instance).future);
      final testPayload = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'Atrium',
        'ping': 'pong',
      };
      await api.loopbackTest(testPayload);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Loopback echo test succeeded (HTTP 200 OK)'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      final msg = (e is DioException && e.response?.statusCode == 403)
          ? 'Loopback test requires an elevated API key'
          : 'Loopback test failed: $e';
      messenger.showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final optionsAsync = ref.watch(slskdOptionsProvider(widget.instance));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Sheet Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: Insets.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(Insets.xs),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.settings_suggest_rounded,
                        color: colorScheme.onSecondaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Configuration & Diagnostics',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Host options & runtime diagnostics',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Insets.xs),

              // Normal TabBar
              TabBar(
                controller: _tabController,
                dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                indicatorColor: colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelStyle: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: textTheme.titleSmall,
                tabs: const <Widget>[
                  Tab(text: 'Overview'),
                  Tab(text: 'Diagnostics'),
                ],
              ),

              // Body content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _buildOverview(context, optionsAsync, colorScheme, textTheme, scrollController),
                    _buildDiagnostics(context, colorScheme, textTheme),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverview(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> optionsAsync,
    ColorScheme colorScheme,
    TextTheme textTheme,
    ScrollController scrollController,
  ) {
    return optionsAsync.when(
      loading: () => const Center(child: ExpressiveProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Text(
            'Failed to load options: $err',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
      data: (options) {
        if (options.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Text(
                'Options unavailable or remote configuration disabled.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final soulseek = options['soulseek'] as Map? ?? const {};
        final directories = options['directories'] as Map? ?? const {};
        final flags = options['flags'] as Map? ?? const {};
        final network = options['network'] as Map? ?? const {};

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(Insets.md),
          children: <Widget>[
            // Soulseek Network settings card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.public_rounded, size: 18, color: colorScheme.primary),
                        const SizedBox(width: Insets.xs),
                        Text(
                          'Soulseek Account & Listening',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    _buildConfigRow('Username', soulseek['username']?.toString() ?? 'N/A'),
                    _buildConfigRow('Listen Port', soulseek['listenPort']?.toString() ?? 'Auto'),
                    _buildConfigRow('UPnP Enabled', (network['upnp'] ?? false).toString()),
                    _buildConfigRow('Remote Config Allowed', (options['remoteConfiguration'] ?? false).toString()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: Insets.md),

            // Directories card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.folder_copy_rounded, size: 18, color: colorScheme.secondary),
                        const SizedBox(width: Insets.xs),
                        Text(
                          'Host Storage Locations',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    _buildConfigRow('Downloads Dir', directories['downloads']?.toString() ?? 'Default'),
                    _buildConfigRow('Incomplete Dir', directories['incomplete']?.toString() ?? 'Default'),
                    _buildConfigRow('Remote File Mgmt', (options['remoteFileManagement'] ?? false).toString()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: Insets.md),

            // Runtime Flags card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.flag_rounded, size: 18, color: colorScheme.tertiary),
                        const SizedBox(width: Insets.xs),
                        Text(
                          'Startup Flags',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    _buildConfigRow('Debug Mode', (options['debug'] ?? false).toString()),
                    _buildConfigRow('No Config Watch', (flags['noConfigWatch'] ?? false).toString()),
                    _buildConfigRow('Dumpable', (flags['dumpable'] ?? false).toString()),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfigRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnostics(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme, [
    ScrollController? scrollController,
  ]) {
    final debugTransfersAsync = ref.watch(slskdDebugTransfersProvider(widget.instance));

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(Insets.md),
      children: <Widget>[
        Text(
          'Runtime Diagnostic Actions',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: Insets.xs),

        // GC Button Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            leading: Icon(Icons.cleaning_services_rounded, color: colorScheme.primary),
            title: const Text('Force Garbage Collection'),
            subtitle: const Text('Triggers .NET CLR runtime memory cleanup immediately.'),
            trailing: FilledButton.tonal(
              onPressed: _isActionInProgress ? null : _triggerGarbageCollection,
              child: const Text('Run GC'),
            ),
          ),
        ),

        const SizedBox(height: Insets.sm),

        // Loopback Ping Card
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            leading: Icon(Icons.repeat_rounded, color: colorScheme.secondary),
            title: const Text('Loopback Echo Test'),
            subtitle: const Text('Verifies daemon REST API ingress and JSON payload roundtrip.'),
            trailing: FilledButton.tonal(
              onPressed: _isActionInProgress ? null : _triggerLoopbackTest,
              child: const Text('Ping'),
            ),
          ),
        ),

        const SizedBox(height: Insets.lg),

        Text(
          'Low-Level Soulseek Client State (/debug/transfers)',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: Insets.xs),

        debugTransfersAsync.when(
          loading: () => const Center(child: ExpressiveProgressIndicator()),
          error: (err, _) => Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text('Debug state unavailable: $err'),
            ),
          ),
          data: (debugData) {
            return Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: SelectableText(
                  debugData.isEmpty ? 'No active debug handles.' : debugData.toString(),
                  style: textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
