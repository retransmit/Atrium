import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'settings/connect_settings_screen.dart';
import 'settings/download_clients_screen.dart';
import 'settings/general_settings_screen.dart';
import 'settings/indexers_settings_screen.dart';
import 'settings/media_management_settings_screen.dart';
import 'settings/metadata_settings_screen.dart';
import 'settings/parse_title_dialog.dart';
import 'settings/profiles_settings_screen.dart';
import 'settings/quality_definitions_screen.dart';
import 'settings/tags_settings_screen.dart';
import 'settings/ui_settings_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Sonarr Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Insets.md),
        children: [
          _buildCategoryHeader(context, 'Media Handling'),
          _buildSettingsCard(
            context: context,
            title: 'Media Management',
            subtitle: 'Rename episodes, configure empty folders, copy links & permission details.',
            icon: Icons.folder_open_outlined,
            screen: MediaManagementSettingsScreen(instance: instance),
          ),
          _buildSettingsCard(
            context: context,
            title: 'Profiles',
            subtitle: 'Manage quality profiles, delay profiles, release profiles, and custom formats.',
            icon: Icons.high_quality_outlined,
            screen: ProfilesSettingsScreen(instance: instance),
          ),
          _buildSettingsCard(
            context: context,
            title: 'Quality Definitions',
            subtitle: 'Configure minimum, maximum, and preferred size limits per quality type.',
            icon: Icons.aspect_ratio_outlined,
            screen: QualityDefinitionsScreen(instance: instance),
          ),
          const SizedBox(height: Insets.md),

          _buildCategoryHeader(context, 'Network & Integration'),
          _buildSettingsCard(
            context: context,
            title: 'Indexers & Trackers',
            subtitle: 'RSS feeds, automatic search, indexers list, and import lists configurations.',
            icon: Icons.rss_feed_outlined,
            screen: IndexersSettingsScreen(instance: instance),
          ),
          _buildSettingsCard(
            context: context,
            title: 'Download Clients',
            subtitle: 'Clients list, connections, download tracking, and path override mappings.',
            icon: Icons.download_for_offline_outlined,
            screen: DownloadClientsScreen(instance: instance),
          ),
          _buildSettingsCard(
            context: context,
            title: 'Connect',
            subtitle: 'Discord, Telegram, Email, Plex notifications and trigger events.',
            icon: Icons.connect_without_contact,
            screen: ConnectSettingsScreen(instance: instance),
          ),
          _buildSettingsCard(
            context: context,
            title: 'Metadata Consumers',
            subtitle: 'Configure metadata files creation for Kodi, Plex, Emby, and WDTV.',
            icon: Icons.settings_applications_outlined,
            screen: MetadataSettingsScreen(instance: instance),
          ),
          const SizedBox(height: Insets.md),

          _buildCategoryHeader(context, 'Application System'),
          _buildSettingsCard(
            context: context,
            title: 'General',
            subtitle: 'Set server listening port, SSL certifications, API Keys, and logs.',
            icon: Icons.dns_outlined,
            screen: GeneralSettingsScreen(instance: instance),
          ),
          _buildSettingsCard(
            context: context,
            title: 'UI Settings',
            subtitle: 'Date formatting, first day of week selection, and color options.',
            icon: Icons.palette_outlined,
            screen: UiSettingsScreen(instance: instance),
          ),
          _buildSettingsCard(
            context: context,
            title: 'Tags',
            subtitle: 'Manage label identifiers for categories, series, and profiles.',
            icon: Icons.label_outline,
            screen: TagsSettingsScreen(instance: instance),
          ),
          const SizedBox(height: Insets.md),

          _buildCategoryHeader(context, 'Diagnostics & Troubleshooting'),
          _buildSettingsCard(
            context: context,
            title: 'Parse Title',
            subtitle: 'Extract metadata and check matching series database results for any release name.',
            icon: Icons.troubleshoot_outlined,
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (context) => SonarrParseTitleDialog(instance: instance),
              ).ignore();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.sm),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? screen,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: Radii.card,
      ),
      child: InkWell(
        borderRadius: Radii.card,
        onTap: onTap ?? () {
          if (screen != null) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => screen,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  icon,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
