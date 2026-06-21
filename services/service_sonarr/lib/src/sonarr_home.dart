import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
    final bool isOled = parentTheme.scaffoldBackgroundColor == Colors.black;

    // Create a brand-aligned color scheme for Sonarr (signature Steel Blue/Cyan seed)
    ColorScheme sonarrScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0084C2),
      brightness: parentTheme.brightness,
    );

    if (isOled) {
      sonarrScheme = sonarrScheme.copyWith(
        surface: Colors.black,
        surfaceContainer: Colors.black,
        surfaceContainerLow: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerHigh: Colors.black,
      );
    }

    final ThemeData sonarrTheme = parentTheme.copyWith(
      colorScheme: sonarrScheme,
      scaffoldBackgroundColor: isOled ? Colors.black : sonarrScheme.surface,
      splashFactory: InkRipple.splashFactory,
      cardTheme: parentTheme.cardTheme.copyWith(
        color: isOled
            ? Colors.grey.withValues(alpha: 0.12)
            : sonarrScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      inputDecorationTheme: parentTheme.inputDecorationTheme.copyWith(
        fillColor: sonarrScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      chipTheme: parentTheme.chipTheme.copyWith(
        backgroundColor: sonarrScheme.surfaceContainerHighest,
      ),
    );

    return Theme(
      data: sonarrTheme,
      child: Builder(
        builder: (BuildContext localContext) {
          return Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                NotificationListener<ScrollNotification>(
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
                          context.pop();
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
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: MediaQuery.of(localContext).padding.top + 24.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(localContext).scaffoldBackgroundColor,
                            Theme.of(localContext).scaffoldBackgroundColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 140.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(localContext).scaffoldBackgroundColor.withValues(alpha: 0.0),
                            Theme.of(localContext).scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: MediaQuery.of(localContext).viewInsets.bottom == 0
                ? _buildBottomNavigationBar(localContext)
                : null,
          );
        },
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
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: theme.brightness == Brightness.dark
              ? colors.surfaceContainer.withValues(alpha: 0.95)
              : colors.surface.withValues(alpha: 0.98),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(context, 0, Icons.movie_filter_outlined, Icons.movie_filter, 'Library'),
              _buildNavItem(context, 1, Icons.insights_outlined, Icons.insights, 'Activity'),
              _buildNavItem(context, 2, Icons.find_in_page_outlined, Icons.find_in_page, 'Wanted'),
              _buildNavItem(context, 3, Icons.grid_view_outlined, Icons.grid_view, 'More'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData inactiveIcon, IconData activeIcon, String label) {
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
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
