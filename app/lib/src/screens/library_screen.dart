import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Cross-service library view. Placeholder until media-server modules
/// (Jellyfin/Emby/Plex) and *arr libraries land.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: const EmptyView(
        icon: Icons.video_library_outlined,
        title: 'Library coming soon',
        message:
            'A unified view across your media servers and *arr libraries will '
            'live here.',
      ),
    );
  }
}
