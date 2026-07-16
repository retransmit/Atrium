import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sonarr/service_sonarr.dart';

/// Aggregated calendar event representation.
sealed class CalendarEvent {
  const CalendarEvent(this.instance);
  final Instance instance;

  String get title;
  DateTime get date;
  bool get hasFile;
  bool get monitored;

  /// Series/movie name, for artwork-rich rows (the dashboard upcoming widget).
  String get primaryTitle;

  /// Episode code + name (or year marker), for artwork-rich rows.
  String get subtitle;

  /// Public artwork URLs (TMDB/fanart CDN remote urls), when the API included
  /// them; null renders a plain fallback.
  String? get posterUrl;
  String? get backdropUrl;
}

class RadarrCalendarEvent extends CalendarEvent {
  RadarrCalendarEvent(this.movie, super.instance, this.month);
  final RadarrMovie movie;
  final DateTime month;

  @override
  String get title => movie.title;

  @override
  DateTime get date {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 1)
        .subtract(const Duration(seconds: 1));

    final DateTime? digital = _parseDate(movie.digitalRelease);
    if (digital != null && digital.isAfter(start) && digital.isBefore(end)) {
      return digital;
    }
    final DateTime? physical = _parseDate(movie.physicalRelease);
    if (physical != null && physical.isAfter(start) && physical.isBefore(end)) {
      return physical;
    }
    final DateTime? cinemas = _parseDate(movie.inCinemas);
    if (cinemas != null && cinemas.isAfter(start) && cinemas.isBefore(end)) {
      return cinemas;
    }
    final DateTime? general = _parseDate(movie.releaseDate);
    if (general != null && general.isAfter(start) && general.isBefore(end)) {
      return general;
    }
    return cinemas ?? digital ?? physical ?? general ?? DateTime.now();
  }

  @override
  bool get hasFile => movie.hasFile;

  @override
  bool get monitored => movie.monitored;

  @override
  String get primaryTitle => movie.title;

  @override
  String get subtitle => movie.year == null ? 'Movie' : '${movie.year} - Movie';

  @override
  String? get posterUrl => _image('poster');

  @override
  String? get backdropUrl => _image('fanart');

  String? _image(String type) => movie.images
      .firstWhereOrNull((RadarrImage i) => i.coverType == type)
      ?.remoteUrl;

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }
}

class SonarrCalendarEvent extends CalendarEvent {
  SonarrCalendarEvent(this.episode, super.instance);
  final SonarrEpisode episode;

  @override
  String get title => episode.series != null
      ? '${episode.series!.title} - S${episode.seasonNumber.toString().padLeft(2, '0')}E${episode.episodeNumber.toString().padLeft(2, '0')}'
      : episode.title;

  @override
  DateTime get date {
    if (episode.airDateUtc == null || episode.airDateUtc!.isEmpty) {
      return DateTime.now();
    }
    return (DateTime.tryParse(episode.airDateUtc!) ?? DateTime.now()).toLocal();
  }

  @override
  bool get hasFile => episode.hasFile;

  @override
  bool get monitored => episode.monitored;

  @override
  String get primaryTitle => episode.series?.title ?? 'Unknown Series';

  @override
  String get subtitle {
    final String s = episode.seasonNumber.toString().padLeft(2, '0');
    final String e = episode.episodeNumber.toString().padLeft(2, '0');
    return episode.title.isEmpty ? 'S${s}E$e' : 'S${s}E$e - ${episode.title}';
  }

  @override
  String? get posterUrl => _image('poster');

  @override
  String? get backdropUrl => _image('fanart');

  String? _image(String type) => episode.series?.images
      .firstWhereOrNull((SonarrImage i) => i.coverType == type)
      ?.remoteUrl;
}

/// Aggregated calendar provider for all active Sonarr and Radarr instances.
final globalCalendarProvider =
    FutureProvider.autoDispose.family<List<CalendarEvent>, DateTime>((
  Ref ref,
  DateTime month,
) async {
  final List<Instance> instances = ref.watch(activeInstancesProvider);
  final List<CalendarEvent> allEvents = [];
  final List<Future<void>> futures = [];

  for (final Instance instance in instances) {
    if (instance.kind == ServiceKind.radarr) {
      final AsyncValue<List<RadarrMovie>> state =
          ref.watch(radarrCalendarProvider((instance, month)));

      if (state is AsyncLoading) {
        futures.add(
          ref
              .read(radarrCalendarProvider((instance, month)).future)
              .then((List<RadarrMovie> movies) {
            allEvents.addAll(
              movies.map(
                  (RadarrMovie m) => RadarrCalendarEvent(m, instance, month)),
            );
          }).catchError((Object e) {
            // Ignore error
          }),
        );
      } else if (state is AsyncData<List<RadarrMovie>>) {
        allEvents.addAll(
          state.value
              .map((RadarrMovie m) => RadarrCalendarEvent(m, instance, month)),
        );
      }
    } else if (instance.kind == ServiceKind.sonarr) {
      final AsyncValue<List<SonarrEpisode>> state =
          ref.watch(sonarrCalendarProvider((instance, month)));

      if (state is AsyncLoading) {
        futures.add(
          ref
              .read(sonarrCalendarProvider((instance, month)).future)
              .then((List<SonarrEpisode> episodes) {
            allEvents.addAll(
              episodes
                  .map((SonarrEpisode e) => SonarrCalendarEvent(e, instance)),
            );
          }).catchError((Object e) {
            // Ignore error
          }),
        );
      } else if (state is AsyncData<List<SonarrEpisode>>) {
        allEvents.addAll(
          state.value
              .map((SonarrEpisode e) => SonarrCalendarEvent(e, instance)),
        );
      }
    }
  }

  if (futures.isNotEmpty) {
    await Future.wait(futures).catchError((_) => []);
  }

  return allEvents;
});

/// Displays a unified schedule and release calendar across all configured
/// Radarr and Sonarr services.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;
  bool _showListView = false;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  Future<void> _handleRefresh() async {
    final List<Instance> instances = ref.read(activeInstancesProvider);
    final List<Future<void>> futures = [];
    for (final Instance instance in instances) {
      if (instance.kind == ServiceKind.radarr) {
        ref.invalidate(radarrCalendarProvider((instance, _visibleMonth)));
        futures.add(
            ref.read(radarrCalendarProvider((instance, _visibleMonth)).future));
      } else if (instance.kind == ServiceKind.sonarr) {
        ref.invalidate(sonarrCalendarProvider((instance, _visibleMonth)));
        futures.add(
            ref.read(sonarrCalendarProvider((instance, _visibleMonth)).future));
      }
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures).catchError((_) => []);
    }
    await ref
        .read(globalCalendarProvider(_visibleMonth).future)
        .catchError((_) => <CalendarEvent>[]);
  }

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    });
  }

  void _goToToday() {
    final DateTime now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      _selectedDay = day;
      if (day.month != _visibleMonth.month || day.year != _visibleMonth.year) {
        _visibleMonth = DateTime(day.year, day.month);
      }
    });
  }

  List<DateTime> _generateGridDays(DateTime month) {
    final DateTime first = DateTime(month.year, month.month);
    final int offset = first.weekday % 7;
    final DateTime start = first.subtract(Duration(days: offset));
    return List.generate(42, (int index) => start.add(Duration(days: index)));
  }

  void _showMonthYearPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final ThemeData theme = Theme.of(context);
            return Container(
              padding:
                  const EdgeInsets.fromLTRB(Insets.md, 0, Insets.md, Insets.md),
              height: 320,
              child: Column(
                children: <Widget>[
                  // Year Selector Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setModalState(() {
                            _visibleMonth = DateTime(
                                _visibleMonth.year - 1, _visibleMonth.month);
                          });
                          setState(() {});
                        },
                      ),
                      Text(
                        '${_visibleMonth.year}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setModalState(() {
                            _visibleMonth = DateTime(
                                _visibleMonth.year + 1, _visibleMonth.month);
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  // Month Grid (3x4)
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.6,
                        crossAxisSpacing: Insets.sm,
                        mainAxisSpacing: Insets.sm,
                      ),
                      itemCount: 12,
                      itemBuilder: (BuildContext context, int index) {
                        final int monthNum = index + 1;
                        final bool isCurrent = _visibleMonth.month == monthNum;
                        final String monthName =
                            DateFormat('MMMM').format(DateTime(2000, monthNum));
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _visibleMonth =
                                  DateTime(_visibleMonth.year, monthNum);
                            });
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: isCurrent
                                  ? null
                                  : Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.15),
                                    ),
                            ),
                            child: Text(
                              monthName.substring(0, 3),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: isCurrent
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CalendarEvent>> calendar =
        ref.watch(globalCalendarProvider(_visibleMonth));

    // Prefetch and cache adjacent months to ensure instant navigation transitions
    final DateTime nextMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    final DateTime prevMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    ref.watch(globalCalendarProvider(nextMonth));
    ref.watch(globalCalendarProvider(prevMonth));

    final bool hasCalendarServices = ref.watch(activeInstancesProvider).any(
          (Instance i) =>
              i.kind == ServiceKind.radarr || i.kind == ServiceKind.sonarr,
        );

    if (!hasCalendarServices) {
      return Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (BuildContext context) {
              return IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  openDrawer(context);
                },
              );
            },
          ),
          title: const Text('Calendar'),
        ),
        body: const EmptyView(
          icon: Icons.calendar_today_outlined,
          title: 'No calendar services',
          message:
              'Add a Sonarr or Radarr service to see your release schedule here.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                openDrawer(context);
              },
            );
          },
        ),
        title: const Text('Calendar'),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              _showListView ? Icons.calendar_month : Icons.format_list_bulleted,
            ),
            tooltip:
                _showListView ? 'Switch to grid view' : 'Switch to list view',
            onPressed: () {
              setState(() {
                _showListView = !_showListView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AsyncValueView<List<CalendarEvent>>(
        value: calendar,
        onRetry: _handleRefresh,
        data: (List<CalendarEvent> entries) {
          // Group entries by local date
          final Map<DateTime, List<CalendarEvent>> entriesMap = {};
          for (final CalendarEvent entry in entries) {
            final DateTime local = entry.date.toLocal();
            final DateTime key = DateTime(local.year, local.month, local.day);
            entriesMap.putIfAbsent(key, () => []).add(entry);
          }

          final ThemeData theme = Theme.of(context);
          final DateTime now = DateTime.now();

          final Widget content;
          if (_showListView) {
            final List<DateTime> eventDates = entriesMap.keys.toList()
              ..sort((a, b) => a.compareTo(b));

            content = GestureDetector(
              onHorizontalDragEnd: (DragEndDetails details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < 0) {
                  _nextMonth();
                } else if (details.primaryVelocity! > 0) {
                  _prevMonth();
                }
              },
              behavior: HitTestBehavior.translucent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: Insets.page,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: InkWell(
                          onTap: () => _showMonthYearPicker(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.xs,
                              vertical: 4,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  DateFormat('yyyy').format(_visibleMonth),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        DateFormat('MMMM')
                                            .format(_visibleMonth),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      size: 20,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      TextButton.icon(
                        onPressed: _goToToday,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding:
                              const EdgeInsets.symmetric(horizontal: Insets.sm),
                        ),
                        icon: const Icon(Icons.today, size: 16),
                        label: const Text('Today'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _prevMonth,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: Insets.xs),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextMonth,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.md),
                  if (eventDates.isEmpty)
                    Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: Insets.xxl),
                        child: Column(
                          children: <Widget>[
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 48,
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: Insets.md),
                            Text(
                              'No releases scheduled this month',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final DateTime date in eventDates) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: Insets.md,
                          bottom: Insets.xs,
                        ),
                        child: _DateHeader(date: date),
                      ),
                      for (final CalendarEvent event
                          in entriesMap[date]!
                            ..sort((a, b) => a.date.compareTo(b.date)))
                        _EventTile(event: event),
                    ],
                ],
              ),
            );
          } else {
            final List<DateTime> gridDays = _generateGridDays(_visibleMonth);

            // Selected day entries
            final DateTime selectedDayKey = DateTime(
                _selectedDay.year, _selectedDay.month, _selectedDay.day);
            final List<CalendarEvent> selectedDayEntries =
                entriesMap[selectedDayKey] ?? [];

            final DateTime todayKey = DateTime(now.year, now.month, now.day);

            content = ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: Insets.page,
              children: <Widget>[
                // Header Row
                Row(
                  children: <Widget>[
                    Expanded(
                      child: InkWell(
                        onTap: () => _showMonthYearPicker(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.xs,
                            vertical: 4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                DateFormat('yyyy').format(_visibleMonth),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      DateFormat('MMMM').format(_visibleMonth),
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.xs),
                    TextButton.icon(
                      onPressed: _goToToday,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding:
                            const EdgeInsets.symmetric(horizontal: Insets.sm),
                      ),
                      icon: const Icon(Icons.today, size: 16),
                      label: const Text('Today'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _prevMonth,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: Insets.xs),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _nextMonth,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                // Weekdays header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _buildWeekdayHeader(theme, 'Sun'),
                    _buildWeekdayHeader(theme, 'Mon'),
                    _buildWeekdayHeader(theme, 'Tue'),
                    _buildWeekdayHeader(theme, 'Wed'),
                    _buildWeekdayHeader(theme, 'Thu'),
                    _buildWeekdayHeader(theme, 'Fri'),
                    _buildWeekdayHeader(theme, 'Sat'),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                // Days Grid with horizontal swipe detection
                GestureDetector(
                  onHorizontalDragEnd: (DragEndDetails details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! < 0) {
                      // Swiped left (next month)
                      _nextMonth();
                    } else if (details.primaryVelocity! > 0) {
                      // Swiped right (prev month)
                      _prevMonth();
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: gridDays.length,
                    itemBuilder: (BuildContext context, int index) {
                      final DateTime day = gridDays[index];
                      final bool isCurrentMonth =
                          day.month == _visibleMonth.month;
                      final DateTime dayKey =
                          DateTime(day.year, day.month, day.day);
                      final bool isSelected = dayKey == selectedDayKey;
                      final bool isToday = dayKey == todayKey;

                      final List<CalendarEvent> dayEntries =
                          entriesMap[dayKey] ?? [];

                      // Dots calculations
                      final bool hasDownloaded =
                          dayEntries.any((CalendarEvent e) => e.hasFile);
                      final bool hasUpcoming = dayEntries.any(
                        (CalendarEvent e) => !e.hasFile && e.date.isAfter(now),
                      );
                      final bool hasMissing = dayEntries.any(
                        (CalendarEvent e) => !e.hasFile && e.date.isBefore(now),
                      );

                      return InkWell(
                        onTap: () => _onDayTapped(day),
                        borderRadius: Radii.card,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : isToday
                                        ? theme.colorScheme.primaryContainer
                                            .withValues(alpha: 0.45)
                                        : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isToday && !isSelected
                                    ? Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: Text(
                                '${day.day}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : isCurrentMonth
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.35),
                                  fontWeight: isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 6,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  if (hasDownloaded)
                                    const _Dot(color: Colors.green),
                                  if (hasUpcoming)
                                    _Dot(color: theme.colorScheme.primary),
                                  if (hasMissing)
                                    _Dot(color: theme.colorScheme.error),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: Insets.md),
                const Divider(),
                const SizedBox(height: Insets.sm),
                // Airings list header
                _DateHeader(date: _selectedDay),
                const SizedBox(height: Insets.sm),
                // Airings list items
                if (selectedDayEntries.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Insets.xl),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 40,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: Insets.sm),
                          Text(
                            'No releases scheduled',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (final CalendarEvent event in selectedDayEntries)
                    _EventTile(event: event),
              ],
            );
          }

          return M3RefreshIndicator(
            onRefresh: _handleRefresh,
            child: content,
          );
        },
      ),
    );
  }

  Widget _buildWeekdayHeader(ThemeData theme, String day) {
    return Expanded(
      child: Center(
        child: Text(
          day,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      _formatDate(date),
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  String _formatDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    final DateTime compare = DateTime(date.year, date.month, date.day);
    if (compare == today) {
      return 'Today';
    } else if (compare == tomorrow) {
      return 'Tomorrow';
    } else if (compare == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMMM d').format(date);
    }
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Instance instance = event.instance;

    Widget? posterWidget;
    String releaseType = '';
    VoidCallback? onTap;

    if (event is RadarrCalendarEvent) {
      final RadarrMovie movie = (event as RadarrCalendarEvent).movie;
      final RadarrApi? api = ref.watch(radarrApiProvider(instance)).value;
      final RadarrImage? poster = movie.images
          .firstWhereOrNull((RadarrImage i) => i.coverType == 'poster');
      final String? imageUrl = poster == null ? null : api?.posterUrl(poster);

      final DateTime eventDate = event.date;
      if (movie.digitalRelease != null &&
          DateTime.tryParse(movie.digitalRelease!)?.toLocal().day ==
              eventDate.day) {
        releaseType = 'Digital Release';
      } else if (movie.physicalRelease != null &&
          DateTime.tryParse(movie.physicalRelease!)?.toLocal().day ==
              eventDate.day) {
        releaseType = 'Physical Release';
      } else {
        releaseType = 'Cinema Release';
      }

      onTap = () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => MovieDetailScreen(
                instance: instance,
                movieId: movie.id,
              ),
            ),
          );

      posterWidget = _Poster(imageUrl: imageUrl, icon: Icons.movie_outlined);
    } else if (event is SonarrCalendarEvent) {
      final SonarrEpisode episode = (event as SonarrCalendarEvent).episode;
      final SonarrApi? api = ref.watch(sonarrApiProvider(instance)).value;
      final SonarrImage? poster = episode.series?.images
          .firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
      final String? imageUrl = poster == null ? null : api?.posterUrl(poster);

      releaseType =
          'S${episode.seasonNumber.toString().padLeft(2, '0')}E${episode.episodeNumber.toString().padLeft(2, '0')}';

      onTap = () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => SeriesDetailScreen(
                instance: instance,
                series: episode.series ??
                    SonarrSeries(id: episode.seriesId, title: ''),
              ),
            ),
          );

      posterWidget = _Poster(imageUrl: imageUrl, icon: Icons.tv_outlined);
    }

    final bool isFuture = event.date.isAfter(DateTime.now());
    final (String label, Color bg, Color fg, Color accentColor) = event.hasFile
        ? (
            'Downloaded',
            theme.colorScheme.primaryContainer,
            theme.colorScheme.onPrimaryContainer,
            Colors.green,
          )
        : isFuture
            ? (
                'Upcoming',
                theme.colorScheme.secondaryContainer,
                theme.colorScheme.onSecondaryContainer,
                theme.colorScheme.primary,
              )
            : (
                'Missing',
                theme.colorScheme.errorContainer,
                theme.colorScheme.onErrorContainer,
                theme.colorScheme.error,
              );

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: accentColor,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 78,
                  child: posterWidget,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: Insets.xs,
                      runSpacing: Insets.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            releaseType,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '•',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        Text(
                          instance.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.jm().format(event.date.toLocal()),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        Icon(
                          event.monitored
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.monitored ? 'Monitored' : 'Unmonitored',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: fg.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.imageUrl, required this.icon});
  final String? imageUrl;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget fallback = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(icon, color: theme.colorScheme.outline, size: 20),
    );
    if (imageUrl == null) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: 100,
      memCacheHeight: 150,
      placeholder: (_, __) =>
          Container(color: theme.colorScheme.surfaceContainerHighest),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
