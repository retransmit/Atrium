import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../screens/calendar_screen.dart';
import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// First-of-month keys for every month the [now, now+7d] window touches.
List<DateTime> upcomingWindowMonths(DateTime now) {
  final DateTime start = DateTime(now.year, now.month, 1);
  final DateTime end =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 8));
  final DateTime endMonth = DateTime(end.year, end.month, 1);
  return <DateTime>[start, if (endMonth != start) endMonth];
}

/// The next 7 days of Sonarr/Radarr releases as day-grouped artwork banners:
/// poster thumb, backdrop background, and a downloaded/pending status icon.
class DashboardUpcomingWidget extends ConsumerWidget {
  const DashboardUpcomingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final DateTime now = DateTime.now();
    final DateTime windowStart = DateTime(now.year, now.month, now.day);
    final DateTime windowEnd = windowStart.add(const Duration(days: 8));
    final List<DateTime> months = upcomingWindowMonths(now);

    final List<CalendarEvent> events = <CalendarEvent>[];
    final Set<CalendarEvent> seen = <CalendarEvent>{};
    bool anyLoading = false;
    bool anyError = false;
    for (final DateTime month in months) {
      final AsyncValue<List<CalendarEvent>> value =
          ref.watch(globalCalendarProvider(month));
      anyLoading |= value.isLoading && !value.hasValue;
      anyError |= value.hasError;
      for (final CalendarEvent e in value.valueOrNull ?? const <CalendarEvent>[]) {
        if (seen.add(e)) {
          events.add(e);
        }
      }
    }

    final List<CalendarEvent> upcoming = events
        .where((CalendarEvent e) {
          final DateTime d = e.date.toLocal();
          return !d.isBefore(windowStart) && d.isBefore(windowEnd);
        })
        .toList()
      ..sort((CalendarEvent a, CalendarEvent b) => a.date.compareTo(b.date));
    final List<CalendarEvent> top = upcoming.take(5).toList();

    Widget body;
    if (upcoming.isEmpty && anyLoading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.sm),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    } else if (upcoming.isEmpty && anyError) {
      body = DashboardErrorRow(
        onRetry: () {
          for (final DateTime m in months) {
            ref.invalidate(globalCalendarProvider(m));
          }
        },
      );
    } else if (upcoming.isEmpty) {
      body = const DashboardIdleRow(text: 'Nothing airing in the next 7 days');
    } else {
      final List<Widget> rows = <Widget>[];
      DateTime? lastDay;
      for (final CalendarEvent e in top) {
        final DateTime d = e.date.toLocal();
        final DateTime day = DateTime(d.year, d.month, d.day);
        if (lastDay == null || day != lastDay) {
          lastDay = day;
          rows.add(Padding(
            padding: EdgeInsets.only(
              top: rows.isEmpty ? 0 : Insets.md,
              bottom: Insets.xs,
              left: 2,
            ),
            child: Text(
              _dayLabel(day, windowStart),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: day == windowStart ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ));
        } else {
          rows.add(const SizedBox(height: Insets.sm));
        }
        rows.add(_ReleaseBanner(event: e));
      }
      if (upcoming.length > top.length) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: Insets.sm),
          child: DashboardIdleRow(text: '+${upcoming.length - top.length} more'),
        ));
      }
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.upcoming,
      accent: cs.secondary,
      onTap: () => context.goNamed(AtriumRoutes.calendarName),
      trailing: upcoming.isNotEmpty
          ? DashboardPill(
              icon: Icons.calendar_today_outlined,
              label:
                  '${upcoming.length} release${upcoming.length == 1 ? '' : 's'}',
              color: cs.primary,
            )
          : null,
      child: body,
    );
  }

  static String _dayLabel(DateTime day, DateTime today) {
    if (day == today) {
      return 'Today';
    }
    if (day == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    }
    return DateFormat('EEE, MMM d').format(day);
  }
}

/// One release as an artwork banner: fanart background with a scrim, poster
/// thumb, title + episode line, and a downloaded/pending badge.
class _ReleaseBanner extends StatelessWidget {
  const _ReleaseBanner({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? backdrop = event.backdropUrl;
    final String? poster = event.posterUrl;
    final bool hasArt = backdrop != null;
    final Color titleColor = hasArt ? Colors.white : cs.onSurface;
    final Color subColor =
        hasArt ? Colors.white.withValues(alpha: 0.75) : cs.onSurfaceVariant;
    final Color edge = event.hasFile ? cs.tertiary : cs.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (hasArt)
              CachedNetworkImage(
                imageUrl: backdrop,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                errorWidget: (BuildContext context, String url, Object error) =>
                    Container(color: cs.surfaceContainerHighest),
              )
            else
              Container(color: cs.surfaceContainerHighest),
            if (hasArt)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.78),
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: edge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.sm,
              ),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 38,
                      height: 56,
                      child: poster == null
                          ? Container(
                              color: cs.surfaceContainerHigh,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.movie_outlined,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: poster,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
                              errorWidget: (BuildContext context, String url,
                                      Object error) =>
                                  Container(
                                color: cs.surfaceContainerHigh,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.movie_outlined,
                                  size: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          event.primaryTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: subColor),
                        ),
                      ],
                    ),
                  ),
                  if (event.hasFile) ...<Widget>[
                    const SizedBox(width: Insets.sm),
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (hasArt ? Colors.white : cs.onSurface)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: cs.tertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
