import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../preferences.dart';
import '../profile_io.dart';

/// App settings: theme mode, optional biometric unlock, and profile
/// import/export.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Preferences prefs = ref.watch(preferencesProvider);
    final PreferencesController controller =
        ref.read(preferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                openDrawer(context);
              },
            );
          },
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          const _SectionHeader('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: prefs.themeMode,
            onChanged: (ThemeMode? m) {
              if (m != null) {
                controller.setThemeMode(m);
              }
            },
            child: const Column(
              children: <Widget>[
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('System default'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Light'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Dark'),
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('Font'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.xs),
            child: DropdownMenu<String?>(
              initialSelection: prefs.fontFamily,
              expandedInsets: EdgeInsets.zero,
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              dropdownMenuEntries: const <DropdownMenuEntry<String?>>[
                DropdownMenuEntry<String?>(
                  value: null,
                  label: 'System default',
                ),
                DropdownMenuEntry<String?>(
                  value: 'JetBrainsMono Nerd Font',
                  label: 'JetBrains Mono',
                ),
              ],
              onSelected: (String? f) {
                controller.setFontFamily(f);
              },
            ),
          ),
          const SizedBox(height: Insets.sm),
          const Divider(),
          const _SectionHeader('Security'),
          _BiometricTile(
            enabled: prefs.biometricEnabled,
            onChanged: controller.setBiometricEnabled,
          ),
          const Divider(),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Export active profile'),
            subtitle: const Text(
              'Save the active profile to a JSON file. Optionally include '
              'secrets.',
            ),
            onTap: () => ProfileIo.exportActiveProfile(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Import profile'),
            subtitle: const Text(
              'Add a profile from a JSON file. Your existing profiles are '
              'kept.',
            ),
            onTap: () => ProfileIo.importProfile(context, ref),
          ),
          const Divider(),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Atrium'),
            subtitle: Text('Version 0.1.0 • GPL-3.0-or-later'),
          ),
        ],
      ),
    );
  }
}

class _BiometricTile extends StatelessWidget {
  const _BiometricTile({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Require unlock on launch'),
      subtitle: const Text('Use biometrics or device PIN to open Atrium.'),
      value: enabled,
      onChanged: (bool want) async {
        if (!want) {
          onChanged(false);
          return;
        }
        final BiometricGate gate = BiometricGate();
        final bool available = await gate.isAvailable();
        if (!available) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No biometric or device credential enrolled.'),
              ),
            );
          }
          return;
        }
        final bool ok = await gate.authenticate(reason: 'Enable unlock');
        if (ok) {
          onChanged(true);
        }
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.lg,
        Insets.xs,
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
