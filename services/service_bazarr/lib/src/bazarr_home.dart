import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import 'bazarr_blacklist_tab.dart';
import 'bazarr_history_tab.dart';
import 'bazarr_movies_tab.dart';
import 'bazarr_series_tab.dart';
import 'bazarr_wanted_tab.dart';

/// Bazarr's per-instance UI: tabbed Series / Movies / Wanted / History /
/// Blacklist. Series and Movies browse Sonarr/Radarr-backed content with
/// subtitle status (and manual search, download, delete); Wanted lists what is
/// still missing; History logs subtitle activity; Blacklist manages blocked
/// subtitles.
class BazarrHome extends StatefulWidget {
  const BazarrHome({required this.instance, super.key});

  final Instance instance;

  @override
  State<BazarrHome> createState() => _BazarrHomeState();
}

class _BazarrHomeState extends State<BazarrHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const <Widget>[
              Tab(text: 'Series'),
              Tab(text: 'Movies'),
              Tab(text: 'Wanted'),
              Tab(text: 'History'),
              Tab(text: 'Blacklist'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: <Widget>[
                BazarrSeriesTab(instance: widget.instance),
                BazarrMoviesTab(instance: widget.instance),
                BazarrWantedTab(instance: widget.instance),
                BazarrHistoryTab(instance: widget.instance),
                BazarrBlacklistTab(instance: widget.instance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
