import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import 'bazarr_movies_tab.dart';
import 'bazarr_series_tab.dart';
import 'bazarr_wanted_tab.dart';

/// Bazarr's per-instance UI: a tabbed Series / Movies / Wanted view. Series and
/// Movies browse Sonarr/Radarr-backed content with subtitle status; Wanted is
/// the unified "missing subtitles" list with badge counts.
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
    _tab = TabController(length: 3, vsync: this);
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
            tabs: const <Widget>[
              Tab(text: 'Series'),
              Tab(text: 'Movies'),
              Tab(text: 'Wanted'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: <Widget>[
                BazarrSeriesTab(instance: widget.instance),
                BazarrMoviesTab(instance: widget.instance),
                BazarrWantedTab(instance: widget.instance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
