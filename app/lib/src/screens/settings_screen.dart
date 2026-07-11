import 'dart:io';

import 'package:core_profile/core_profile.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator_plus/palette_generator_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../custom_theme_providers.dart';
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
  int _activeTab = 0;

  static const List<Color> _presets = [
    Color(0xFF6750A4), // Violet
    Color(0xFF0061A4), // Blue
    Color(0xFF006E1C), // Forest
    Color(0xFFBA1A1A), // Crimson
    Color(0xFF8B5000), // Orange
    Color(0xFF006B5B), // Mint
    Color(0xFF755B00), // Amber
    Color(0xFF984061), // Rose
  ];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesProvider);
    _activeTab = prefs.themeSource == ThemeSource.preset ? 1 : 0;
    
    if (prefs.customImagePath != null) {
      _loadPalette(prefs.customImagePath!);
    }
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
        }
      }
    } catch (_) {}
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _activeTab == index;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
          final controller = ref.read(preferencesProvider.notifier);
          final prefs = ref.read(preferencesProvider);
          if (index == 0) {
            if (prefs.customImagePath != null) {
              controller.setThemeSource(ThemeSource.customImage);
            } else {
              controller.setThemeSource(ThemeSource.system);
            }
          } else {
            controller.setThemeSource(ThemeSource.preset);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorCircle(Color c, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
  }

  @override
  Widget build(BuildContext context) {
    final Preferences prefs = ref.watch(preferencesProvider);
    final PreferencesController controller = ref.read(preferencesProvider.notifier);
    final systemColorScheme = ref.watch(systemColorSchemeProvider);
    final systemLight = systemColorScheme.light;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _ThemePreview(),
        const SizedBox(height: Insets.md),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTabButton(0, 'Wallpaper colours'),
            const SizedBox(width: Insets.md),
            _buildTabButton(1, 'Basic colours'),
          ],
        ),
        const SizedBox(height: Insets.md),
        
        if (_activeTab == 0) ...[
          if (prefs.customImagePath != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Wallpaper: ${prefs.customImagePath!.split(Platform.pathSeparator).last}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.change_circle_outlined, size: 16),
                  label: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
          ],
          
          if (_isExtracting) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: Insets.md),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (systemLight != null || _extractedColors.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (systemLight != null) ...[
                    Column(
                      children: [
                        _ColorPillStack(
                          colors: [
                            systemLight.primary,
                            systemLight.primaryContainer,
                            systemLight.secondaryContainer,
                            systemLight.surfaceContainerHigh,
                          ],
                          isSelected: prefs.themeSource == ThemeSource.system,
                          onTap: () {
                            controller.setThemeSource(ThemeSource.system);
                          },
                        ),
                        const SizedBox(height: 6),
                        const Text('System', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 14),
                  ],
                  
                  ..._extractedColors.map((Color seed) {
                    final String hex = seed.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
                    final bool isSelected = prefs.themeSource == ThemeSource.customImage &&
                        prefs.customSeedColorHex?.toLowerCase() == hex.toLowerCase();
                    
                    final ColorScheme previewScheme = ColorScheme.fromSeed(seedColor: seed);
                    final List<Color> pillColors = [
                      previewScheme.primary,
                      previewScheme.primaryContainer,
                      previewScheme.secondaryContainer,
                      previewScheme.surfaceContainerHigh,
                    ];
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 14.0),
                      child: Column(
                        children: [
                          _ColorPillStack(
                            colors: pillColors,
                            isSelected: isSelected,
                            onTap: () {
                              controller.setThemeSource(ThemeSource.customImage);
                              controller.setCustomSeedColorHex(hex);
                            },
                          ),
                          const SizedBox(height: 6),
                          const Text('Dynamic', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.wallpaper_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: Insets.sm),
                  const Text(
                    'No custom wallpaper loaded',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: Insets.xs),
                  const Text(
                    'Upload an image to generate coordinate dynamic color palettes',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: Insets.md),
                  FilledButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.upload, size: 18),
                    label: const Text('Pick Image'),
                  ),
                ],
              ),
            ),
          ],
        ],
        
        if (_activeTab == 1) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._presets.map((Color c) {
                final String hex = c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
                final bool isSelected = prefs.themeSource == ThemeSource.preset &&
                    prefs.customSeedColorHex?.toLowerCase() == hex.toLowerCase();
                
                return _buildColorCircle(c, isSelected, () {
                  controller.setThemeSource(ThemeSource.preset);
                  controller.setCustomSeedColorHex(hex);
                });
              }),
              
              if (prefs.customSeedColorHex != null && !_presets.any((c) => 
                  c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toLowerCase() == 
                  prefs.customSeedColorHex!.toLowerCase())) ...[
                _buildColorCircle(
                  Color(int.parse(prefs.customSeedColorHex!, radix: 16) | 0xFF000000),
                  prefs.themeSource == ThemeSource.preset,
                  () {
                    controller.setThemeSource(ThemeSource.preset);
                  },
                ),
              ],
              
              GestureDetector(
                onTap: () async {
                  final Color current = prefs.customSeedColorHex != null
                      ? Color(int.parse(prefs.customSeedColorHex!, radix: 16) | 0xFF000000)
                      : const Color(0xFF6750A4);
                  
                  final Color? picked = await showDialog<Color>(
                    context: context,
                    builder: (context) => _ColorPickerDialog(initialColor: current),
                  );
                  
                  if (picked != null) {
                    final String hex = picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
                    controller.setThemeSource(ThemeSource.preset);
                    controller.setCustomSeedColorHex(hex);
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '12:00',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.wifi, size: 14, color: cs.onSurface),
                  const SizedBox(width: 4),
                  Icon(Icons.battery_full, size: 14, color: cs.onSurface),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.wb_cloudy_outlined, size: 32, color: cs.onPrimaryContainer),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloudy • 21°C',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Atrium Theme',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQS(cs.primary, cs.onPrimary, Icons.wifi, 'Internet'),
              _buildQS(cs.primary, cs.onPrimary, Icons.bluetooth, 'Bluetooth'),
              _buildQS(cs.surfaceContainerHigh, cs.onSurfaceVariant, Icons.do_not_disturb_on, 'DND'),
              _buildQS(cs.surfaceContainerHigh, cs.onSurfaceVariant, Icons.flashlight_on, 'Torch'),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Icon(Icons.light_mode, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.7,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQS(Color bg, Color fg, IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: fg, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ColorPillStack extends StatelessWidget {
  const _ColorPillStack({
    required this.colors,
    required this.isSelected,
    required this.onTap,
  });

  final List<Color> colors;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 50,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                children: [
                  Expanded(child: Container(color: colors[0])),
                  Expanded(child: Container(color: colors[1])),
                  Expanded(child: Container(color: colors[2])),
                  Expanded(child: Container(color: colors[3])),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialColor});
  final Color initialColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _currentColor;
  late double _hue;
  late double _saturation;
  late double _lightness;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    final hsl = HSLColor.fromColor(_currentColor);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;
    _hexController = TextEditingController(
      text: _currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateColor() {
    setState(() {
      _currentColor = HSLColor.fromAHSL(1.0, _hue, _saturation, _lightness).toColor();
      _hexController.text = _currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Color'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Hue', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 12,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                trackShape: const _HueTrackShape(),
              ),
              child: Slider(
                value: _hue,
                min: 0.0,
                max: 360.0,
                onChanged: (val) {
                  setState(() {
                    _hue = val;
                    _updateColor();
                  });
                },
              ),
            ),
            
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Saturation', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            Slider(
              value: _saturation,
              min: 0.0,
              max: 1.0,
              activeColor: _currentColor,
              onChanged: (val) {
                setState(() {
                  _saturation = val;
                  _updateColor();
                });
              },
            ),
            
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Lightness', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            Slider(
              value: _lightness,
              min: 0.1,
              max: 0.9,
              activeColor: _currentColor,
              onChanged: (val) {
                setState(() {
                  _lightness = val;
                  _updateColor();
                });
              },
            ),
            const SizedBox(height: Insets.md),
            
            TextField(
              controller: _hexController,
              decoration: InputDecoration(
                labelText: 'Hex Code',
                prefixText: '# ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLength: 6,
              onChanged: (val) {
                if (val.length == 6) {
                  final reg = RegExp(r'^[0-9a-fA-F]{6}$');
                  if (reg.hasMatch(val)) {
                    final intColor = int.parse(val, radix: 16) | 0xFF000000;
                    final color = Color(intColor);
                    final hsl = HSLColor.fromColor(color);
                    setState(() {
                      _currentColor = color;
                      _hue = hsl.hue;
                      _saturation = hsl.saturation;
                      _lightness = hsl.lightness;
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_currentColor),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

class _HueTrackShape extends SliderTrackShape {
  const _HueTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 12.0;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext paintingContext,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final Canvas canvas = paintingContext.canvas;
    final Rect rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    
    final List<Color> colors = List.generate(360, (index) {
      return HSLColor.fromAHSL(1.0, index.toDouble(), 1.0, 0.5).toColor();
    });
    
    final Paint paint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(rect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      paint,
    );
  }
}
