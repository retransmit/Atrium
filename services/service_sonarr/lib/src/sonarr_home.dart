import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'add_series_screen.dart';
import 'models/sonarr_add_models.dart';
import 'models/sonarr_blocklist.dart';
import 'models/sonarr_episode.dart';
import 'models/sonarr_history.dart';
import 'models/sonarr_manual_import.dart';
import 'models/sonarr_queue.dart';
import 'models/sonarr_series.dart';
import 'models/sonarr_settings_models.dart';
import 'models/sonarr_system.dart';
import 'models/sonarr_wanted.dart';
import 'series_detail_screen.dart';
import 'sonarr_api.dart';
import 'sonarr_providers.dart';
import 'sonarr_settings_form_screen.dart';

// Part declarations
part 'ui/sonarr_helpers.dart';
part 'ui/oneui_widgets.dart';
part 'ui/series_tab.dart';
part 'ui/activity_tab.dart';
part 'ui/wanted_tab.dart';
part 'ui/wanted_manual_import.dart';
part 'ui/more_tab.dart';
part 'ui/settings_panels.dart';
part 'ui/settings_forms.dart';
part 'ui/settings_advanced.dart';

// ──────────────────────────────────────────────────────
// SonarrHome main widget
// ──────────────────────────────────────────────────────

/// Sonarr's per-instance UI: a tabbed Series / Queue / Wanted / History / Blocklist / System view.
class SonarrHome extends ConsumerStatefulWidget {
  const SonarrHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<SonarrHome> createState() => _SonarrHomeState();
}

class _SonarrHomeState extends ConsumerState<SonarrHome> {
  int _currentIndex = 0;
  PageController? _pageController;

  // Persistent gesture tracking fields — must NOT be local to build().
  bool _startedAtZero = false;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(sonarrActiveTabBarIndexProvider(widget.instance).notifier).state = _currentIndex;
      }
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData parentTheme = Theme.of(context);
    return Theme(
      data: parentTheme.copyWith(
        splashFactory: InkRipple.splashFactory,
      ),
      child: Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            // Only listen to depth-0 horizontal scroll — that is the PageView itself.
            if (notification.depth == 0 && notification.metrics.axis == Axis.horizontal) {
              if (notification is ScrollStartNotification) {
                // Record whether the drag started at pixel 0 (Library page boundary).
                _startedAtZero = _currentIndex == 0 && notification.metrics.pixels == 0.0;
                _isPopping = false;
              } else if (notification is OverscrollNotification &&
                  notification.overscroll < 0 &&
                  _startedAtZero &&
                  !_isPopping) {
                // A right-drag past 60 logical pixels beyond the left boundary
                // triggers a back-navigation to the Atrium dashboard.
                if (notification.overscroll < -60.0) {
                  _isPopping = true;
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).maybePop();
                  return true;
                }
              } else if (notification is ScrollEndNotification) {
                _startedAtZero = false;
                _isPopping = false;
              }
            }
            return false;
          },
          child: PageView(
            controller: _pageController,
            // BouncingScrollPhysics is required on Android/Windows so that
            // the OverscrollNotification actually fires at the left boundary.
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            onPageChanged: (int index) {
              setState(() {
                _currentIndex = index;
              });
              ref.read(sonarrActiveTabBarIndexProvider(widget.instance).notifier).state = index;
            },
            children: <Widget>[
              _SeriesTab(instance: widget.instance),
              _ActivityTab(instance: widget.instance),
              _WantedTab(instance: widget.instance),
              _MoreTab(instance: widget.instance),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: theme.brightness == Brightness.dark
                ? colors.surfaceContainer.withValues(alpha: 0.75)
                : colors.surface.withValues(alpha: 0.9),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildNavItem(0, Icons.movie_filter_outlined, Icons.movie_filter, 'Library'),
                _buildNavItem(1, Icons.insights_outlined, Icons.insights, 'Activity'),
                _buildNavItem(2, Icons.find_in_page_outlined, Icons.find_in_page, 'Wanted'),
                _buildNavItem(3, Icons.grid_view_outlined, Icons.grid_view, 'More'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isSelected = _currentIndex == index;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        if (_currentIndex != index) {
          _pageController?.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill indicator behind icon (only when selected)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? colors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            // Label always visible below the icon
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
