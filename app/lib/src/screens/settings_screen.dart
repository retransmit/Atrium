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

  // Local state variables for staging selections
  ThemeSource _localSource = ThemeSource.system;
  String? _localSeedColorHex;
  String? _localImagePath;
  PaletteStyle _localPaletteStyle = PaletteStyle.tonalSpot;

  static const List<Color> _presets = [
    Color(0xFF6750A4), // Violet (Atrium default)
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
    
    _localSource = prefs.themeSource;
    _localSeedColorHex = prefs.customSeedColorHex ?? '6750A4';
    _localImagePath = prefs.customImagePath;
    _localPaletteStyle = prefs.paletteStyle;

    if (_localSource == ThemeSource.system) {
      _activeTab = 0;
    } else if (_localSource == ThemeSource.preset) {
      _activeTab = 1;
    } else {
      _activeTab = 2;
    }
    
    // Load stored dynamic colors if available, preventing recalculation
    if (prefs.customImageColorsCsv != null && prefs.customImageColorsCsv!.isNotEmpty) {
      try {
        _extractedColors = prefs.customImageColorsCsv!
            .split(',')
            .map((hex) => Color(int.parse(hex, radix: 16) | 0xFF000000))
            .toList();
      } catch (_) {
        if (_localImagePath != null) {
          _loadPalette(_localImagePath!);
        }
      }
    } else if (_localImagePath != null) {
      _loadPalette(_localImagePath!);
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
        final List<Color> rawColors = <Color>{
          if (palette.vibrantColor?.color != null) palette.vibrantColor!.color,
          if (palette.lightVibrantColor?.color != null) palette.lightVibrantColor!.color,
          if (palette.darkVibrantColor?.color != null) palette.darkVibrantColor!.color,
          if (palette.mutedColor?.color != null) palette.mutedColor!.color,
          if (palette.lightMutedColor?.color != null) palette.lightMutedColor!.color,
          if (palette.darkMutedColor?.color != null) palette.darkMutedColor!.color,
          if (palette.dominantColor?.color != null) palette.dominantColor!.color,
        }.toList();

        // Filter out colors that are visually too similar to each other
        final List<Color> distinctColors = [];
        for (final color in rawColors) {
          final hsl = HSLColor.fromColor(color);
          bool isDuplicate = false;
          for (final existing in distinctColors) {
            final existingHsl = HSLColor.fromColor(existing);
            final hueDiff = (hsl.hue - existingHsl.hue).abs();
            final minHueDiff = hueDiff > 180 ? 360 - hueDiff : hueDiff;
            final satDiff = (hsl.saturation - existingHsl.saturation).abs();
            final lightDiff = (hsl.lightness - existingHsl.lightness).abs();
            
            if (minHueDiff < 30.0 && satDiff < 0.2 && lightDiff < 0.2) {
              isDuplicate = true;
              break;
            }
          }
          if (!isDuplicate) {
            distinctColors.add(color);
          }
        }
        
        setState(() {
          _extractedColors = distinctColors;
        });

        // Store colors to prevent recalculation when reloading page
        final csv = distinctColors
            .map((c) => c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2))
            .join(',');
        await ref.read(preferencesProvider.notifier).setCustomImageColorsCsv(csv);
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
        final String originalName = result.files.single.name;
        final Directory appDir = await getApplicationSupportDirectory();
        
        // Preserve the original name in the copied wallpaper path
        final String localPath = '${appDir.path}/$originalName';
        
        // If a different custom image was previously stored, clean it up
        if (_localImagePath != null && _localImagePath != localPath) {
          try {
            final oldFile = File(_localImagePath!);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          } catch (_) {}
        }
        
        await File(filePath).copy(localPath);
        
        setState(() {
          _localImagePath = localPath;
          _localSource = ThemeSource.customImage;
          _activeTab = 2;
        });
        
        final controller = ref.read(preferencesProvider.notifier);
        await controller.setThemeSource(ThemeSource.customImage);
        await controller.setCustomImagePath(localPath);

        await _loadPalette(localPath);
        if (_extractedColors.isNotEmpty) {
          final Color seed = _extractedColors.first;
          final String hex = seed.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
          setState(() {
            _localSeedColorHex = hex;
          });
          await controller.setCustomSeedColorHex(hex);
        }
      }
    } catch (_) {}
  }

  Widget _buildTabButton(int index, String label, ColorScheme cs) {
    final isSelected = _activeTab == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final controller = ref.read(preferencesProvider.notifier);
          setState(() {
            _activeTab = index;
            if (index == 0) {
              _localSource = ThemeSource.system;
            } else if (index == 1) {
              _localSource = ThemeSource.preset;
            } else {
              _localSource = ThemeSource.customImage;
            }
          });

          if (index == 0) {
            await controller.setThemeSource(ThemeSource.system);
          } else if (index == 1) {
            await controller.setThemeSource(ThemeSource.preset);
            await controller.setCustomSeedColorHex(_localSeedColorHex);
          } else {
            await controller.setThemeSource(ThemeSource.customImage);
            await controller.setCustomSeedColorHex(_localSeedColorHex);
            await controller.setCustomImagePath(_localImagePath);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? cs.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
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
    final PreferencesController controller = ref.read(preferencesProvider.notifier);
    final systemColorScheme = ref.watch(systemColorSchemeProvider);
    final systemLight = systemColorScheme.light;
    final theme = Theme.of(context);

    // Compute preview color scheme
    final ColorScheme previewColorScheme;
    Color seedColor = const Color(0xFF6750A4);
    
    if (_activeTab == 0) {
      final systemScheme = theme.brightness == Brightness.dark
          ? systemColorScheme.dark
          : systemColorScheme.light;
      previewColorScheme = systemScheme ?? colorSchemeFromSeedAndStyle(
        seedColor,
        _localPaletteStyle,
        theme.brightness,
      );
    } else {
      if (_localSeedColorHex != null) {
        final int? val = int.tryParse(_localSeedColorHex!, radix: 16);
        if (val != null) {
          seedColor = Color(val | 0xFF000000);
        }
      }
      previewColorScheme = colorSchemeFromSeedAndStyle(
        seedColor,
        _localPaletteStyle,
        theme.brightness,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ThemePalettePreviewGrid(colorScheme: previewColorScheme),
        const SizedBox(height: Insets.md),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTabButton(0, 'System', previewColorScheme),
            const SizedBox(width: 6),
            _buildTabButton(1, 'Basic colours', previewColorScheme),
            const SizedBox(width: 6),
            _buildTabButton(2, 'Image', previewColorScheme),
          ],
        ),
        const SizedBox(height: Insets.md),

        if (_activeTab != 0) ...[
          DropdownButtonFormField<PaletteStyle>(
            initialValue: _localPaletteStyle,
            decoration: InputDecoration(
              labelText: 'Palette style',
              filled: true,
              fillColor: previewColorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: previewColorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: previewColorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: previewColorScheme.primary, width: 2),
              ),
              labelStyle: TextStyle(color: previewColorScheme.onSurfaceVariant),
            ),
            items: PaletteStyle.values.map((style) {
              final String label = switch (style) {
                PaletteStyle.tonalSpot => 'Tonal Spot',
                PaletteStyle.content => 'Content',
                PaletteStyle.expressive => 'Expressive',
                PaletteStyle.fidelity => 'Fidelity',
                PaletteStyle.fruitSalad => 'Fruit Salad',
                PaletteStyle.monochrome => 'Monochrome',
                PaletteStyle.neutral => 'Neutral',
                PaletteStyle.rainbow => 'Rainbow',
              };
              return DropdownMenuItem<PaletteStyle>(
                value: style,
                child: Text(label),
              );
            }).toList(),
            onChanged: (val) async {
              if (val != null) {
                setState(() {
                  _localPaletteStyle = val;
                });
                await controller.setPaletteStyle(val);
              }
            },
          ),
          const SizedBox(height: Insets.md),
        ],
        
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_activeTab == 0)
                Card(
                  elevation: 0,
                  color: previewColorScheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Row(
                      children: [
                        Icon(Icons.android, color: previewColorScheme.primary, size: 28),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'System Wallpaper Colors',
                                style: TextStyle(fontWeight: FontWeight.bold, color: previewColorScheme.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                systemLight != null 
                                    ? 'Using platform dynamic color matching (Android 12+).' 
                                    : 'Dynamic colors unavailable. Using default theme.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: previewColorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              if (_activeTab == 2) ...[
                if (_localImagePath != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Wallpaper thumbnail with original aspect ratio
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: previewColorScheme.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            constraints: const BoxConstraints(
                              maxHeight: 120,
                              maxWidth: 90,
                            ),
                            color: previewColorScheme.surfaceContainerHighest,
                            child: Image.file(
                              File(_localImagePath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      // Details and change button on the right
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Wallpaper',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: previewColorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _localImagePath!.split(Platform.pathSeparator).last,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: previewColorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            FilledButton.icon(
                              onPressed: _pickImage,
                              style: FilledButton.styleFrom(
                                backgroundColor: previewColorScheme.primary,
                                foregroundColor: previewColorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.change_circle_outlined, size: 16),
                              label: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                ],
                
                if (_isExtracting) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: Insets.md),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (_extractedColors.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: _extractedColors.map((Color seed) {
                          final String hex = seed.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
                          final bool isSelected = _localSource == ThemeSource.customImage &&
                              _localSeedColorHex?.toLowerCase() == hex.toLowerCase();
                          
                          final ColorScheme previewScheme = colorSchemeFromSeedAndStyle(
                            seed,
                            _localPaletteStyle,
                            theme.brightness,
                          );
                          
                          // Include two tertiary colors in the 6-band dynamic pill stack
                          final List<Color> pillColors = [
                            previewScheme.primary,
                            previewScheme.primaryContainer,
                            previewScheme.secondaryContainer,
                            previewScheme.tertiary,
                            previewScheme.tertiaryContainer,
                            previewScheme.surfaceContainerHigh,
                          ];
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 14.0),
                            child: _ColorPillStack(
                              colors: pillColors,
                              isSelected: isSelected,
                              activeColorScheme: previewColorScheme,
                              onTap: () async {
                                setState(() {
                                  _localSource = ThemeSource.customImage;
                                  _localSeedColorHex = hex;
                                });
                                await controller.setThemeSource(ThemeSource.customImage);
                                await controller.setCustomSeedColorHex(hex);
                                await controller.setCustomImagePath(_localImagePath);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Insets.lg),
                    decoration: BoxDecoration(
                      color: previewColorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: previewColorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.wallpaper_outlined, size: 40, color: previewColorScheme.onSurfaceVariant),
                        const SizedBox(height: Insets.sm),
                        Text(
                          'No custom wallpaper loaded',
                          style: TextStyle(fontWeight: FontWeight.w600, color: previewColorScheme.onSurface),
                        ),
                        const SizedBox(height: Insets.xs),
                        Text(
                          'Upload an image to generate dynamic color palettes',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: previewColorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: Insets.md),
                        FilledButton.icon(
                          onPressed: _pickImage,
                          style: FilledButton.styleFrom(
                            backgroundColor: previewColorScheme.primary,
                            foregroundColor: previewColorScheme.onPrimary,
                          ),
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
                      final bool isSelected = _localSource == ThemeSource.preset &&
                          _localSeedColorHex?.toLowerCase() == hex.toLowerCase();
                      
                      return _buildColorCircle(c, isSelected, () async {
                        setState(() {
                          _localSource = ThemeSource.preset;
                          _localSeedColorHex = hex;
                        });
                        await controller.setThemeSource(ThemeSource.preset);
                        await controller.setCustomSeedColorHex(hex);
                      });
                    }),
                    
                    if (_localSeedColorHex != null && !_presets.any((c) => 
                        c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toLowerCase() == 
                        _localSeedColorHex!.toLowerCase())) ...[
                      _buildColorCircle(
                        Color(int.parse(_localSeedColorHex!, radix: 16) | 0xFF000000),
                        _localSource == ThemeSource.preset,
                        () async {
                          setState(() {
                            _localSource = ThemeSource.preset;
                          });
                          await controller.setThemeSource(ThemeSource.preset);
                        },
                      ),
                    ],
                    
                    GestureDetector(
                      onTap: () async {
                        final Color current = _localSeedColorHex != null
                            ? Color(int.parse(_localSeedColorHex!, radix: 16) | 0xFF000000)
                            : const Color(0xFF6750A4);
                        
                        final Color? picked = await showDialog<Color>(
                          context: context,
                          builder: (context) => _ColorPickerDialog(initialColor: current),
                        );
                        
                        if (picked != null) {
                          final String hex = picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
                          setState(() {
                            _localSource = ThemeSource.preset;
                            _localSeedColorHex = hex;
                          });
                          await controller.setThemeSource(ThemeSource.preset);
                          await controller.setCustomSeedColorHex(hex);
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: previewColorScheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: previewColorScheme.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          color: previewColorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemePalettePreviewGrid extends StatelessWidget {
  const _ThemePalettePreviewGrid({required this.colorScheme});
  final ColorScheme colorScheme;

  Widget _buildSwatch(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fg.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '#${bg.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'JetBrainsMono Nerd Font',
              color: fg.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: cs.primary, size: 20),
              const SizedBox(width: Insets.xs),
              Text(
                'Palette Preview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: [
              _buildSwatch('Primary', cs.primary, cs.onPrimary),
              _buildSwatch('Primary Container', cs.primaryContainer, cs.onPrimaryContainer),
              _buildSwatch('Secondary', cs.secondary, cs.onSecondary),
              _buildSwatch('Secondary Container', cs.secondaryContainer, cs.onSecondaryContainer),
              _buildSwatch('Tertiary', cs.tertiary, cs.onTertiary),
              _buildSwatch('Tertiary Container', cs.tertiaryContainer, cs.onTertiaryContainer),
              _buildSwatch('Surface', cs.surface, cs.onSurface),
              _buildSwatch('Surface Container High', cs.surfaceContainerHigh, cs.onSurfaceVariant),
              _buildSwatch('Outline', cs.outline, cs.surface),
              _buildSwatch('Inverse Primary', cs.inversePrimary, cs.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorPillStack extends StatelessWidget {
  const _ColorPillStack({
    required this.colors,
    required this.isSelected,
    required this.activeColorScheme,
    required this.onTap,
  });

  final List<Color> colors;
  final bool isSelected;
  final ColorScheme activeColorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 54,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              border: Border.all(
                color: isSelected
                    ? activeColorScheme.primary
                    : Colors.transparent,
                width: 3.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: Column(
                children: [
                  Expanded(child: Container(color: colors[0])),
                  Expanded(child: Container(color: colors[1])),
                  Expanded(child: Container(color: colors[2])),
                  Expanded(child: Container(color: colors[3])),
                  Expanded(child: Container(color: colors[4])),
                  Expanded(child: Container(color: colors[5])),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: activeColorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors[5],
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: activeColorScheme.onPrimary,
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
