import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Cross-service activity view (download queues, active streams). Placeholder
/// until the download-client and media-server modules land.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: const EmptyView(
        icon: Icons.swap_vert_outlined,
        title: 'Activity coming soon',
        message:
            'Download queues from qBittorrent / SABnzbd and active streams '
            'from your media servers will aggregate here.',
      ),
    );
  }
}
