import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'bazarr_languages_screen.dart';

/// The Settings tab: a menu of Bazarr configuration screens (languages, and -
/// added incrementally - providers and language profiles).
class BazarrSettingsTab extends StatelessWidget {
  const BazarrSettingsTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: Insets.pageH,
      children: <Widget>[
        const SizedBox(height: Insets.sm),
        _SettingsTile(
          icon: Icons.language,
          title: 'Languages',
          subtitle: 'Enable the subtitle languages Bazarr searches for',
          onTap: () => _push(
            context,
            BazarrLanguagesScreen(instance: instance),
          ),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
