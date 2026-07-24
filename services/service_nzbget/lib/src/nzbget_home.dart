import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import 'nzbget_history_tab.dart';
import 'nzbget_queue_tab.dart';

/// NZBGet's per-instance UI: Queue / History tabs.
class NzbgetHome extends StatelessWidget {
  const NzbgetHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Queue', icon: Icon(Icons.download_outlined)),
              Tab(text: 'History', icon: Icon(Icons.history)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                NzbgetQueueTab(instance: instance),
                NzbgetHistoryTab(instance: instance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
