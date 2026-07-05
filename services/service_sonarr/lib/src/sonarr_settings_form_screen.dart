import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/sonarr_series.dart';
import 'sonarr_providers.dart';

class SonarrSettingsFormScreen extends ConsumerStatefulWidget {
  const SonarrSettingsFormScreen({
    required this.instance,
    required this.series,
    super.key,
  });

  final Instance instance;
  final SonarrSeries series;

  @override
  ConsumerState<SonarrSettingsFormScreen> createState() =>
      _SonarrSettingsFormScreenState();
}

class _SonarrSettingsFormScreenState
    extends ConsumerState<SonarrSettingsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pathController;

  String _monitorOption = 'all';
  int? _selectedQualityProfileId;
  String _seriesType = 'standard';
  bool _seasonFolder = true;
  List<int> _selectedTagIds = [];

  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _initializeValues(Map<String, dynamic> rawSeries) {
    if (_initialized) return;
    _initialized = true;

    _pathController.text = (rawSeries['path'] as String?) ?? '';
    _monitorOption = (rawSeries['monitorOption'] as String?) ?? 'all';
    _selectedQualityProfileId = rawSeries['qualityProfileId'] as int?;
    _seriesType = (rawSeries['seriesType'] as String?) ?? 'standard';
    _seasonFolder = (rawSeries['seasonFolder'] as bool?) ?? true;
    _selectedTagIds =
        List<int>.from((rawSeries['tags'] as Iterable?) ?? <int>[]);
  }

  Future<void> _save(Map<String, dynamic> rawSeries) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final api = await ref.read(sonarrApiProvider(widget.instance).future);

    // Mutate the raw series map
    final Map<String, dynamic> payload = Map<String, dynamic>.from(rawSeries);
    payload['path'] = _pathController.text.trim();
    payload['monitored'] = _monitorOption != 'none';
    payload['monitorOption'] = _monitorOption;
    payload['qualityProfileId'] = _selectedQualityProfileId;
    payload['seriesType'] = _seriesType;
    payload['seasonFolder'] = _seasonFolder;
    payload['tags'] = _selectedTagIds;

    try {
      await api.updateSeriesRaw(payload);
      ref.invalidate(
          sonarrSeriesByIdProvider((widget.instance, widget.series.id)));
      ref.invalidate(sonarrSeriesProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Series settings saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final profilesAsync =
        ref.watch(sonarrQualityProfilesProvider(widget.instance));
    final tagsAsync = ref.watch(sonarrTagsProvider(widget.instance));

    // Fetch the raw series metadata asynchronously for the settings form
    final rawSeriesAsync = ref
        .watch(sonarrSeriesByIdProvider((widget.instance, widget.series.id)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Series Settings'),
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
            rawSeriesAsync.maybeWhen(
              data: (freshSeries) => IconButton(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  final api =
                      await ref.read(sonarrApiProvider(widget.instance).future);
                  final rawJson = await api.getSeriesRaw(widget.series.id);
                  await _save(rawJson);
                },
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: rawSeriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error loading series metadata: $err')),
        data: (freshSeries) {
          // Trigger initialization using the loaded SonarrSeries structure
          return FutureBuilder<Map<String, dynamic>>(
            future: ref
                .read(sonarrApiProvider(widget.instance).future)
                .then((api) => api.getSeriesRaw(widget.series.id)),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              _initializeValues(snapshot.data!);

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(Insets.md),
                  children: [
                    Text(
                      widget.series.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: Insets.md),

                    // Path field
                    TextFormField(
                      controller: _pathController,
                      decoration: const InputDecoration(
                        labelText: 'Path',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.folder_open),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Path cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Insets.md),

                    // Monitor status dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _monitorOption,
                      decoration: const InputDecoration(
                        labelText: 'Monitor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bookmark_outline),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All Episodes')),
                        DropdownMenuItem(
                            value: 'future', child: Text('Future Episodes')),
                        DropdownMenuItem(
                            value: 'missing', child: Text('Missing Episodes')),
                        DropdownMenuItem(
                            value: 'existing',
                            child: Text('Existing Episodes')),
                        DropdownMenuItem(
                            value: 'firstSeason',
                            child: Text('First Season Only')),
                        DropdownMenuItem(
                            value: 'latestSeason',
                            child: Text('Latest Season Only')),
                        DropdownMenuItem(
                            value: 'none', child: Text('None (Unmonitored)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _monitorOption = val);
                        }
                      },
                    ),
                    const SizedBox(height: Insets.md),

                    // Quality Profile dropdown
                    profilesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) =>
                          Text('Error loading profiles: $err'),
                      data: (profiles) {
                        // Ensure selected profile is valid or select first
                        if (_selectedQualityProfileId == null &&
                            profiles.isNotEmpty) {
                          _selectedQualityProfileId =
                              profiles.first['id'] as int?;
                        }
                        return DropdownButtonFormField<int>(
                          initialValue: _selectedQualityProfileId,
                          decoration: const InputDecoration(
                            labelText: 'Quality Profile',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.high_quality),
                          ),
                          items: profiles.map((p) {
                            return DropdownMenuItem<int>(
                              value: p['id'] as int,
                              child: Text((p['name'] as String?) ?? 'Unknown'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedQualityProfileId = val);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: Insets.md),

                    // Series Type dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _seriesType,
                      decoration: const InputDecoration(
                        labelText: 'Series Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tv),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'standard', child: Text('Standard')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'anime', child: Text('Anime')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _seriesType = val);
                        }
                      },
                    ),
                    const SizedBox(height: Insets.md),

                    // Season Folder switch
                    SwitchListTile(
                      title: const Text('Use Season Folder'),
                      subtitle: const Text(
                          'Store files in subfolders for each season'),
                      value: _seasonFolder,
                      onChanged: (val) {
                        setState(() => _seasonFolder = val);
                      },
                    ),
                    const SizedBox(height: Insets.md),

                    // Tags multi-selector section
                    tagsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Error loading tags: $err'),
                      data: (tags) {
                        if (tags.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tags',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: Insets.xs),
                            Wrap(
                              spacing: Insets.xs,
                              runSpacing: Insets.xs,
                              children: tags.map((t) {
                                final id = t['id'] as int;
                                final label = (t['label'] as String?) ?? '';
                                final isSelected = _selectedTagIds.contains(id);
                                return FilterChip(
                                  label: Text(label),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedTagIds.add(id);
                                      } else {
                                        _selectedTagIds.remove(id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
