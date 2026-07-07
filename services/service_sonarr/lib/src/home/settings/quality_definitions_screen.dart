import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sonarr_providers.dart';

class QualityDefinitionsScreen extends ConsumerStatefulWidget {
  const QualityDefinitionsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<QualityDefinitionsScreen> createState() =>
      _QualityDefinitionsScreenState();
}

class _QualityDefinitionsScreenState extends ConsumerState<QualityDefinitionsScreen> {
  bool _initialized = false;
  bool _saving = false;
  late List<Map<String, dynamic>> _definitions;

  void _initializeValues(List<Map<String, dynamic>> data) {
    if (_initialized) return;
    _initialized = true;
    // Perform deep copy so editing doesn't mutate cache directly before save
    _definitions = data
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = await ref.read(sonarrApiProvider(widget.instance).future);
      await api.updateQualityDefinitions(_definitions);
      ref.invalidate(sonarrQualityDefinitionsProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quality definitions updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quality definitions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final definitionsAsync = ref.watch(sonarrQualityDefinitionsProvider(widget.instance));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Definitions'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: definitionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (data) {
          _initializeValues(data);

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: _definitions.length,
            itemBuilder: (context, index) {
              final def = _definitions[index];
              final qualityMap = def['quality'] as Map<String, dynamic>?;
              final qName = (qualityMap?['name'] as String?) ?? 'Unknown';
              
              // min/max/preferred are usually represented as double (MB per minute)
              final double minVal = (def['minSize'] as num?)?.toDouble() ?? 0.0;
              final double? maxVal = (def['maxSize'] as num?)?.toDouble();
              final double prefVal = (def['preferredSize'] as num?)?.toDouble() ?? minVal;

              final bool isUnlimited = maxVal == null || maxVal == 0;

              return Card(
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
                        qName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: Insets.md),

                      // Min size row
                      Text(
                        'Min Size: ${minVal.toStringAsFixed(1)} MB/min',
                        style: theme.textTheme.bodySmall,
                      ),
                      Slider(
                        value: minVal.clamp(0.0, 400.0),
                        max: 400.0,
                        divisions: 400,
                        onChanged: (val) {
                          setState(() {
                            def['minSize'] = val;
                            if (prefVal < val) {
                              def['preferredSize'] = val;
                            }
                          });
                        },
                      ),

                      // Preferred size row
                      Text(
                        'Preferred Size: ${prefVal.toStringAsFixed(1)} MB/min',
                        style: theme.textTheme.bodySmall,
                      ),
                      Slider(
                        value: prefVal.clamp(minVal, 400.0),
                        min: minVal,
                        max: 400.0,
                        divisions: 400,
                        onChanged: (val) {
                          setState(() {
                            def['preferredSize'] = val;
                          });
                        },
                      ),

                      // Max size row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isUnlimited
                                ? 'Max Size: Unlimited'
                                : 'Max Size: ${maxVal.toStringAsFixed(1)} MB/min',
                            style: theme.textTheme.bodySmall,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Unlimited'),
                              Checkbox(
                                value: isUnlimited,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      def['maxSize'] = null;
                                    } else {
                                      def['maxSize'] = prefVal + 50.0;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (!isUnlimited)
                        Slider(
                          value: maxVal.clamp(prefVal, 400.0),
                          min: prefVal,
                          max: 400.0,
                          divisions: 400,
                          onChanged: (val) {
                            setState(() {
                              def['maxSize'] = val;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
