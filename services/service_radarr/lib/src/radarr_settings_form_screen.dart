import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/radarr_movie.dart';
import 'radarr_providers.dart';

class RadarrSettingsFormScreen extends ConsumerStatefulWidget {
  const RadarrSettingsFormScreen({
    required this.instance,
    required this.movie,
    super.key,
  });

  final Instance instance;
  final RadarrMovie movie;

  @override
  ConsumerState<RadarrSettingsFormScreen> createState() =>
      _RadarrSettingsFormScreenState();
}

class _RadarrSettingsFormScreenState
    extends ConsumerState<RadarrSettingsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pathController;
  late final Future<Map<String, dynamic>> _rawMovieFuture;

  bool _monitored = true;
  int? _selectedQualityProfileId;
  String _minimumAvailability = 'announced';
  List<int> _selectedTagIds = [];

  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController();
    _rawMovieFuture = ref
        .read(radarrApiProvider(widget.instance).future)
        .then((api) => api.getMovieRaw(widget.movie.id));
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _initializeValues(Map<String, dynamic> rawMovie) {
    if (_initialized) return;
    _initialized = true;

    _pathController.text = (rawMovie['path'] as String?) ?? '';
    _monitored = (rawMovie['monitored'] as bool?) ?? true;
    _selectedQualityProfileId = rawMovie['qualityProfileId'] as int?;
    _minimumAvailability =
        (rawMovie['minimumAvailability'] as String?) ?? 'announced';
    _selectedTagIds =
        List<int>.from((rawMovie['tags'] as Iterable?) ?? <int>[]);
  }

  Future<void> _save(Map<String, dynamic> rawMovie) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final api = await ref.read(radarrApiProvider(widget.instance).future);

      final Map<String, dynamic> payload = Map<String, dynamic>.from(rawMovie);
      payload['path'] = _pathController.text.trim();
      payload['monitored'] = _monitored;
      payload['qualityProfileId'] = _selectedQualityProfileId;
      payload['minimumAvailability'] = _minimumAvailability;
      payload['tags'] = _selectedTagIds;

      await api.updateMovieRaw(payload);
      ref.invalidate(
        radarrMovieByIdProvider((widget.instance, widget.movie.id)),
      );
      ref.invalidate(radarrMoviesProvider(widget.instance));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movie settings saved successfully!')),
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
        ref.watch(radarrQualityProfilesProvider(widget.instance));
    final tagsAsync = ref.watch(radarrTagsProvider(widget.instance));

    return FutureBuilder<Map<String, dynamic>>(
      future: _rawMovieFuture,
      builder: (context, snapshot) {
        final rawMovie = snapshot.data;
        if (rawMovie != null) {
          _initializeValues(rawMovie);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Movie Settings'),
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
              else if (rawMovie != null)
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => _save(rawMovie),
                ),
            ],
          ),
          body: snapshot.hasError
              ? Center(
                  child: Text(
                    'Error loading movie metadata: ${snapshot.error}',
                  ),
                )
              : rawMovie == null
                  ? const Center(child: ExpressiveProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(Insets.md),
                        children: [
                          Text(
                            widget.movie.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: Insets.md),

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

                          SwitchListTile(
                            title: const Text('Monitored'),
                            subtitle: const Text(
                              'Monitor and download new releases for this movie',
                            ),
                            secondary: const Icon(Icons.bookmark_outline),
                            value: _monitored,
                            onChanged: (val) {
                              setState(() => _monitored = val);
                            },
                          ),
                          const SizedBox(height: Insets.md),

                          profilesAsync.when(
                            loading: () => const Center(
                              child: ExpressiveProgressIndicator(),
                            ),
                            error: (err, stack) =>
                                Text('Error loading profiles: $err'),
                            data: (profiles) {
                              final hasSelected = profiles.any(
                                (p) => p['id'] == _selectedQualityProfileId,
                              );
                              if (!hasSelected) {
                                _selectedQualityProfileId = profiles.isNotEmpty
                                    ? profiles.first['id'] as int?
                                    : null;
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
                                    child: Text(
                                      (p['name'] as String?) ?? 'Unknown',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(
                                    () => _selectedQualityProfileId = val,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: Insets.md),

                          DropdownButtonFormField<String>(
                            initialValue: _minimumAvailability,
                            decoration: const InputDecoration(
                              labelText: 'Minimum Availability',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.star_border),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'announced',
                                child: Text('Announced'),
                              ),
                              DropdownMenuItem(
                                value: 'inCinemas',
                                child: Text('In Cinemas'),
                              ),
                              DropdownMenuItem(
                                value: 'released',
                                child: Text('Released'),
                              ),
                              DropdownMenuItem(
                                value: 'preDB',
                                child: Text('PreDB'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _minimumAvailability = val);
                              }
                            },
                          ),
                          const SizedBox(height: Insets.md),

                          tagsAsync.when(
                            loading: () => const Center(
                              child: ExpressiveProgressIndicator(),
                            ),
                            error: (err, stack) =>
                                Text('Error loading tags: $err'),
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
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: Insets.xs),
                                  Wrap(
                                    spacing: Insets.xs,
                                    runSpacing: Insets.xs,
                                    children: tags.map((t) {
                                      final id = t['id'] as int;
                                      final label =
                                          (t['label'] as String?) ?? '';
                                      final isSelected =
                                          _selectedTagIds.contains(id);
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
                    ),
        );
      },
    );
  }
}
