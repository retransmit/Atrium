import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sonarr_providers.dart';

class UiSettingsScreen extends ConsumerStatefulWidget {
  const UiSettingsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<UiSettingsScreen> createState() => _UiSettingsScreenState();
}

class _UiSettingsScreenState extends ConsumerState<UiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  int _firstDayOfWeek = 0;
  bool _showRelativeDates = true;
  bool _enableColorImpairedMode = false;

  late final TextEditingController _shortDateFormatController;
  late final TextEditingController _longDateFormatController;
  late final TextEditingController _timeFormatController;

  bool _saving = false;
  bool _initialized = false;
  Map<String, dynamic>? _rawUiConfig;

  @override
  void initState() {
    super.initState();
    _shortDateFormatController = TextEditingController();
    _longDateFormatController = TextEditingController();
    _timeFormatController = TextEditingController();
  }

  @override
  void dispose() {
    _shortDateFormatController.dispose();
    _longDateFormatController.dispose();
    _timeFormatController.dispose();
    super.dispose();
  }

  void _initializeValues(Map<String, dynamic> config) {
    if (_initialized) return;
    _initialized = true;
    _rawUiConfig = config;

    _firstDayOfWeek = config['firstDayOfWeek'] as int? ?? 0;
    _showRelativeDates = config['showRelativeDates'] as bool? ?? true;
    _enableColorImpairedMode =
        config['enableColorImpairedMode'] as bool? ?? false;

    _shortDateFormatController.text =
        (config['shortDateFormat'] as String?) ?? 'MMM dd yyyy';
    _longDateFormatController.text =
        (config['longDateFormat'] as String?) ?? 'dddd, MMMM dd yyyy';
    _timeFormatController.text = (config['timeFormat'] as String?) ?? 'h:mmtt';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rawUiConfig == null) return;

    setState(() => _saving = true);

    try {
      final api = await ref.read(sonarrApiProvider(widget.instance).future);
      final payload = Map<String, dynamic>.from(_rawUiConfig!);

      payload['firstDayOfWeek'] = _firstDayOfWeek;
      payload['showRelativeDates'] = _showRelativeDates;
      payload['enableColorImpairedMode'] = _enableColorImpairedMode;
      payload['shortDateFormat'] = _shortDateFormatController.text.trim();
      payload['longDateFormat'] = _longDateFormatController.text.trim();
      payload['timeFormat'] = _timeFormatController.text.trim();

      await api.updateUiConfig(payload);
      ref.invalidate(sonarrUiConfigProvider(widget.instance));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UI configuration settings saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save UI configuration: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uiConfigAsync = ref.watch(sonarrUiConfigProvider(widget.instance));

    return Scaffold(
      appBar: AppBar(
        title: const Text('UI Settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: ExpressiveProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: uiConfigAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (config) {
          _initializeValues(config);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(Insets.md),
              children: [
                // --- Calendar & Week Section ---
                Card(
                  margin: const EdgeInsets.only(bottom: Insets.md),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: Radii.card,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calendar & Dates',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        DropdownButtonFormField<int>(
                          initialValue: _firstDayOfWeek,
                          decoration: const InputDecoration(
                            labelText: 'First Day of Week',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Sunday')),
                            DropdownMenuItem(value: 1, child: Text('Monday')),
                            DropdownMenuItem(value: 2, child: Text('Tuesday')),
                            DropdownMenuItem(
                                value: 3, child: Text('Wednesday')),
                            DropdownMenuItem(value: 4, child: Text('Thursday')),
                            DropdownMenuItem(value: 5, child: Text('Friday')),
                            DropdownMenuItem(value: 6, child: Text('Saturday')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _firstDayOfWeek = val);
                            }
                          },
                        ),
                        const SizedBox(height: Insets.sm),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show Relative Dates'),
                          subtitle: const Text(
                              'Show relative terms like "Yesterday", "Today", or "In 2 days"'),
                          value: _showRelativeDates,
                          onChanged: (val) =>
                              setState(() => _showRelativeDates = val),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Date Formatting Section ---
                Card(
                  margin: const EdgeInsets.only(bottom: Insets.md),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: Radii.card,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Formatting Rules',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        TextFormField(
                          controller: _shortDateFormatController,
                          decoration: const InputDecoration(
                            labelText: 'Short Date Format',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                        ),
                        const SizedBox(height: Insets.md),
                        TextFormField(
                          controller: _longDateFormatController,
                          decoration: const InputDecoration(
                            labelText: 'Long Date Format',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                        ),
                        const SizedBox(height: Insets.md),
                        TextFormField(
                          controller: _timeFormatController,
                          decoration: const InputDecoration(
                            labelText: 'Time Format',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) =>
                              (val == null || val.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Display Settings Section ---
                Card(
                  margin: const EdgeInsets.only(bottom: Insets.md),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                    borderRadius: Radii.card,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Display Options',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: Insets.md),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable Color-Impaired Mode'),
                          subtitle: const Text(
                              'Uses high-contrast borders and symbols instead of green/red/orange'),
                          value: _enableColorImpairedMode,
                          onChanged: (val) =>
                              setState(() => _enableColorImpairedMode = val),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
