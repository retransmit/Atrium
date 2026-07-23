import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../external_links.dart';
import '../update_check/app_version.dart';
import 'changelog/available_release_card.dart';
import 'changelog/release_card.dart';
import 'changelog/release_notes.dart';

/// In-app change log as per-version cards, with a link out to the full
/// releases on GitHub.
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change log'),
        actions: <Widget>[
          IconButton(
            tooltip: 'View releases on GitHub',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openExternal(
              ScaffoldMessenger.of(context),
              AtriumLinks.releases,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: Insets.page,
        children: <Widget>[
          const AvailableReleaseCard(),
          for (final ReleaseNote note in releaseNotes)
            ReleaseCard(
              note: note,
              installed: note.version == appVersion,
            ),
        ],
      ),
    );
  }
}
