import 'dart:io';

import 'package:core_profile/core_profile.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator_plus/palette_generator_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../preferences.dart';
import '../profile_io.dart';
import 'custom_headers_screen.dart';
import 'wake_on_lan_screen.dart';

/// App settings: theme mode, optional biometric unlock, network tools
/// (Wake-on-LAN, custom headers), and profile import/export.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Preferences prefs = ref.watch(preferencesProvider);
    final PreferencesController controller =
        ref.read(preferencesProvider.notifier);
    final int wolCount =
        ref.watch(activeProfileProvider)?.wolDevices.length ?? 0;

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
          const _SectionHeader('Theme Styling'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Insets.lg),
            child: _ThemeSettingsSection(),
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
          const _SectionHeader('Network'),
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: const Text('Wake-on-LAN'),
            subtitle: Text(
              wolCount == 0
                  ? 'No devices configured'
                  : '$wolCount device${wolCount == 1 ? '' : 's'} configured',
            ),
            onTap: () => pushScreen<void>(context, const WakeOnLanScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Custom Headers'),
            subtitle: const Text('Add headers for reverse-proxy auth'),
            onTap: () =>
                pushScreen<void>(context, const CustomHeadersScreen()),
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

class _ThemeSettingsSection extends ConsumerStatefulWidget {
  const _ThemeSettingsSection();

  @override
  ConsumerState<_ThemeSettingsSection> createState() =>
      _ThemeSettingsSectionState();
}

class _ThemeSettingsSectionState extends ConsumerState<_ThemeSettingsSection> {
  bool _isExtracting = false;
  List<Color> _extractedColors = [];
  late final TextEditingController _hexController;

  static const List<(String, Color)> _presets = [
    ('Violet', Color(0xFF6750A4)),
    ('Blue', Color(0xFF0061A4)),
    ('Forest', Color(0xFF006E1C)),
    ('Crimson', Color(0xFFBA1A1A)),
    ('Orange', Color(0xFF8B5000)),
    ('Mint', Color(0xFF006B5B)),
    ('Amber', Color(0xFF755B00)),
    ('Rose', Color(0xFF984061)),
  ];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesProvider);
    final hex = prefs.customSeedColorHex ?? '6750A4';
    _hexController = TextEditingController(text: hex.toUpperCase());
    
    if (prefs.themeSource == ThemeSource.customImage && prefs.customImagePath != null) {
      _loadPalette(prefs.customImagePath!);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _loadPalette(String path) async {
    setState(() => _isExtracting = true);
    try {
      final File file = File(path);
      if (await file.exists()) {
        final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
          FileImage(file),
          size: const Size(200, 200),
          timeout: Duration.zero,
        );
        final List<Color> colors = <Color>{
          if (palette.vibrantColor?.color != null) palette.vibrantColor!.color,
          if (palette.lightVibrantColor?.color != null) palette.lightVibrantColor!.color,
          if (palette.darkVibrantColor?.color != null) palette.darkVibrantColor!.color,
          if (palette.mutedColor?.color != null) palette.mutedColor!.color,
          if (palette.lightMutedColor?.color != null) palette.lightMutedColor!.color,
          if (palette.darkMutedColor?.color != null) palette.darkMutedColor!.color,
          if (palette.dominantColor?.color != null) palette.dominantColor!.color,
        }.toList();
        
        setState(() {
          _extractedColors = colors;
        });
      }
    } catch (_) {}
    setState(() => _isExtracting = false);
  }

  Future<void> _pickImage() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        final String filePath = result.files.single.path!;
        final Directory appDir = await getApplicationSupportDirectory();
        final String ext = filePath.contains('.') 
            ? filePath.substring(filePath.lastIndexOf('.')) 
            : '.png';
        final String localPath = '${appDir.path}/custom_theme_image$ext';
        
        await File(filePath).copy(localPath);
        
        final controller = ref.read(preferencesProvider.notifier);
        await controller.setCustomImagePath(localPath);
        await controller.setThemeSource(ThemeSource.customImage);
        
        await _loadPalette(localPath);
        if (_extractedColors.isNotEmpty) {
          final Color seed = _extractedColors.first;
          final String hex = seed.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
          await controller.setCustomSeedColorHex(hex);
          _hexController.text = hex.toUpperCase();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final Preferences prefs = ref.watch(preferencesProvider);
    final PreferencesController controller = ref.read(preferencesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Insets.xs),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeSource>(
            segments: const <ButtonSegment<ThemeSource>>[
              ButtonSegment<ThemeSource>(
                value: ThemeSource.system,
                label: Text('System'),
                icon: Icon(Icons.palette_outlined),
              ),
              ButtonSegment<ThemeSource>(
                value: ThemeSource.preset,
                label: Text('Presets'),
                icon: Icon(Icons.color_lens_outlined),
              ),
              ButtonSegment<ThemeSource>(
                value: ThemeSource.customImage,
                label: Text('Image'),
                icon: Icon(Icons.image_outlined),
              ),
            ],
            selected: <ThemeSource>{prefs.themeSource},
            onSelectionChanged: (Set<ThemeSource> selection) {
              controller.setThemeSource(selection.first);
              if (selection.first == ThemeSource.customImage && prefs.customImagePath != null) {
                _loadPalette(prefs.customImagePath!);
              }
            },
          ),
        ),
        const SizedBox(height: Insets.md),
        
        if (prefs.themeSource == ThemeSource.preset) ...[
          Text(
            'Preset Colors',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final String hex = p.$2.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
              final bool isSelected = prefs.customSeedColorHex?.toLowerCase() == hex.toLowerCase();
              return GestureDetector(
                onTap: () {
                  controller.setCustomSeedColorHex(hex);
                  _hexController.text = hex.toUpperCase();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.$2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: p.$2.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Insets.md),
          TextField(
            controller: _hexController,
            decoration: InputDecoration(
              labelText: 'Custom Hex Color',
              prefixText: '# ',
              hintText: '6750A4',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLength: 6,
            onChanged: (String value) {
              if (value.length == 6) {
                final reg = RegExp(r'^[0-9a-fA-F]{6}$');
                if (reg.hasMatch(value)) {
                  controller.setCustomSeedColorHex(value);
                }
              }
            },
          ),
        ],

        if (prefs.themeSource == ThemeSource.customImage) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prefs.customImagePath != null ? 'Custom Image Loaded' : 'No Image Selected',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (prefs.customImagePath != null)
                      Text(
                        prefs.customImagePath!.split('/').last,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              FilledButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('Pick Image'),
              ),
            ],
          ),
          if (_isExtracting) ...[
            const SizedBox(height: Insets.md),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: Insets.md),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (_extractedColors.isNotEmpty) ...[
            const SizedBox(height: Insets.md),
            Text(
              'Extracted Palettes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _extractedColors.map((Color c) {
                final String hex = c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
                final bool isSelected = prefs.customSeedColorHex?.toLowerCase() == hex.toLowerCase();
                
                return GestureDetector(
                  onTap: () {
                    controller.setCustomSeedColorHex(hex);
                    _hexController.text = hex.toUpperCase();
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ],
    );
  }
}
