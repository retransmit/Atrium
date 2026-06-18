import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'bazarr_subtitle_chips.dart';
import 'models/bazarr_models.dart';

/// Per-movie subtitle view: present and missing subtitles. Read-only for now;
/// manual search and download land here next.
class BazarrMovieDetailScreen extends StatelessWidget {
  const BazarrMovieDetailScreen({
    required this.instance,
    required this.movie,
    super.key,
  });

  final Instance instance;
  final BazarrMovie movie;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(movie.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: Insets.page,
        children: <Widget>[
          if (movie.year != null)
            Text('${movie.year}', style: theme.textTheme.titleMedium),
          const SizedBox(height: Insets.md),
          Text('Subtitles', style: theme.textTheme.titleSmall),
          const SizedBox(height: Insets.sm),
          if (movie.subtitles.isEmpty)
            Text(
              'None downloaded',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          else
            BazarrSubtitleChips(present: movie.subtitles),
          const SizedBox(height: Insets.lg),
          Text('Missing', style: theme.textTheme.titleSmall),
          const SizedBox(height: Insets.sm),
          if (movie.missingSubtitles.isEmpty)
            Text(
              'Nothing missing',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          else
            BazarrSubtitleChips(missing: movie.missingSubtitles),
        ],
      ),
    );
  }
}
