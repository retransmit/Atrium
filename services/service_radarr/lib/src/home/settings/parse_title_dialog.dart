import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../radarr_providers.dart';

class RadarrParseTitleDialog extends ConsumerStatefulWidget {
  const RadarrParseTitleDialog({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<RadarrParseTitleDialog> createState() => _RadarrParseTitleDialogState();
}

class _RadarrParseTitleDialogState extends ConsumerState<RadarrParseTitleDialog> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final parseAsync = _query.trim().isNotEmpty
        ? ref.watch(radarrParseResultProvider((widget.instance, _query.trim())))
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parse Release Title',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Paste a release name or torrent title below to see how Radarr parses movie title, year, quality, and matching library details.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: _controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Inception.2010.1080p.BluRay.x264-GRP',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                ),
              ),
              const SizedBox(height: Insets.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _query = '';
                      });
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: Insets.sm),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _query = _controller.text;
                      });
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Parse'),
                  ),
                ],
              ),
              if (parseAsync != null) ...[
                const Divider(height: 32),
                Flexible(
                  child: parseAsync.when(
                    data: (data) {
                      if (data == null) {
                        return const Center(child: Text('Failed to parse title.'));
                      }
                      final parsedInfo = data['parsedMovieInfo'] as Map<String, dynamic>?;
                      if (parsedInfo == null) {
                        return const Center(child: Text('Could not extract movie details.'));
                      }

                      final String? movieTitle = parsedInfo['movieTitle'] as String?;
                      final int? year = parsedInfo['year'] as int?;
                      final String? releaseGroup = parsedInfo['releaseGroup'] as String?;
                      
                      final qualityMap = parsedInfo['quality'] as Map<String, dynamic>?;
                      final qualityInner = qualityMap?['quality'] as Map<String, dynamic>?;
                      final String? qualityName = qualityInner?['name'] as String?;
                      
                      final languages = parsedInfo['languages'] as List<dynamic>?;
                      final List<String> languageNames = languages
                              ?.map((l) => (l as Map<String, dynamic>)['name'] as String)
                              .toList() ??
                          [];

                      final matchingMovie = data['movie'] as Map<String, dynamic>?;
                      final matchingMovieTitle = matchingMovie?['title'] as String?;

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Extracted Metadata',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            _buildInfoRow(theme, 'Movie Title', movieTitle ?? 'N/A'),
                            _buildInfoRow(theme, 'Year', year?.toString() ?? 'N/A'),
                            _buildInfoRow(theme, 'Quality', qualityName ?? 'N/A'),
                            _buildInfoRow(theme, 'Release Group', releaseGroup ?? 'N/A'),
                            _buildInfoRow(theme, 'Language', languageNames.isNotEmpty ? languageNames.join(', ') : 'N/A'),
                            const SizedBox(height: Insets.md),
                            Text(
                              'Radarr Database Match',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            _buildInfoRow(
                              theme,
                              'Matches Movie',
                              matchingMovieTitle ?? 'No match in library',
                              valueColor: matchingMovieTitle != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(Insets.lg),
                        child: ExpressiveProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Error parsing title: $e',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
