import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../adguard_home_format.dart';
import '../adguard_home_time_zones.dart';
import '../models/adguard_home_clients.dart';
import '../models/adguard_home_filters.dart';

/// Picks a time of day, from [current]. Null when nothing was picked.
typedef AdguardHomeTimePicker = Future<Duration?> Function(
  BuildContext context,
  Duration current,
);

/// The Material time picker, on the 24-hour clock.
Future<Duration?> adguardHomePickTime(
  BuildContext context,
  Duration current,
) async {
  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: current.inHours % 24,
      minute: current.inMinutes % 60,
    ),
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (picked == null) return null;
  return Duration(hours: picked.hour, minutes: picked.minute);
}

/// When blocking of services pauses: the time zone, then the seven days,
/// Monday first. A day opens a sheet to change it.
///
/// It holds nothing: what is shown comes in as [schedule], and every change
/// goes out whole through [onChanged].
class AdguardHomeScheduleEditor extends StatelessWidget {
  const AdguardHomeScheduleEditor({
    required this.schedule,
    required this.onChanged,
    this.enabled = true,
    this.pickTime = adguardHomePickTime,
    super.key,
  });

  final AdguardHomeSchedule schedule;
  final ValueChanged<AdguardHomeSchedule> onChanged;

  /// Off while the schedule does not apply, or while it is being written.
  final bool enabled;

  /// How From and To are picked. Tests hand in their own.
  final AdguardHomeTimePicker pickTime;

  Future<void> _pickTimeZone(BuildContext context) async {
    final String? zone = await pushScreen<String>(
      context,
      AdguardHomeTimeZoneScreen(selected: schedule.timeZone),
    );
    if (zone != null && zone != schedule.timeZone) {
      onChanged(schedule.withTimeZone(zone));
    }
  }

  Future<void> _openDay(BuildContext context, String day) async {
    final AdguardHomeSchedule? changed =
        await showModalBottomSheet<AdguardHomeSchedule>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => AdguardHomePauseSheet(
        day: day,
        schedule: schedule,
        pickTime: pickTime,
      ),
    );
    if (changed != null) onChanged(changed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          enabled: enabled,
          leading: const Icon(Icons.public),
          title: const Text('Time zone'),
          subtitle: Text(adguardHomeTimeZoneLabel(schedule.timeZone)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pickTimeZone(context),
        ),
        for (final String day in adguardHomeWeekdays)
          ListTile(
            enabled: enabled,
            title: Text(adguardHomeWeekdayName(day)),
            subtitle: Text(_dayLabel(day)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _openDay(context, day),
          ),
      ],
    );
  }

  String _dayLabel(String day) {
    final AdguardHomeServicePause? pause = schedule.pauseOn(day);
    return pause == null ? 'Not paused' : adguardHomePauseLabel(pause);
  }
}

/// One day of a pause schedule: whether blocking pauses, from when to
/// when, and the other days the same goes for. Closes with the whole new
/// schedule, or with nothing when cancelled.
class AdguardHomePauseSheet extends StatefulWidget {
  const AdguardHomePauseSheet({
    required this.day,
    required this.schedule,
    this.pickTime = adguardHomePickTime,
    super.key,
  });

  final String day;
  final AdguardHomeSchedule schedule;
  final AdguardHomeTimePicker pickTime;

  @override
  State<AdguardHomePauseSheet> createState() => _AdguardHomePauseSheetState();
}

class _AdguardHomePauseSheetState extends State<AdguardHomePauseSheet> {
  static const Duration _dayEnd = Duration(hours: 24);

  /// A day with no pause yet starts as working hours.
  late final AdguardHomeServicePause? _was =
      widget.schedule.pauseOn(widget.day);
  late bool _paused = true;
  late Duration _start = _was?.start ?? const Duration(hours: 9);
  late Duration _end = _was?.end ?? const Duration(hours: 17);
  late final Set<String> _days = <String>{widget.day};

  bool get _toEndOfDay => _end == _dayEnd;

  /// What the button does, said on it. A day opened to add a pause starts
  /// switched on, so one tap adds it; the button says so, rather than a
  /// plain Save that would add a pause nobody asked for by name.
  String get _action {
    if (_was == null && _paused) return 'Add pause';
    if (_was != null && !_paused) return 'Remove pause';
    return 'Save';
  }

  String? get _problem =>
      _paused ? adguardHomeScheduleProblem(_start, _end) : null;

  Future<void> _pick({required bool start}) async {
    final Duration current = start ? _start : (_toEndOfDay ? Duration.zero : _end);
    final Duration? picked = await widget.pickTime(context, current);
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _save() {
    AdguardHomeSchedule next = widget.schedule;
    for (final String day in _days) {
      next = _paused
          ? next.withPause(day, start: _start, end: _end)
          : next.withoutPause(day);
    }
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? problem = _problem;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                  child: Text(
                    adguardHomeWeekdayName(widget.day),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Pause blocking'),
                  subtitle: const Text(
                    'The blocked services are let through for this time',
                  ),
                  value: _paused,
                  onChanged: (bool on) => setState(() => _paused = on),
                ),
                ListTile(
                  enabled: _paused,
                  title: const Text('From'),
                  trailing: Text(
                    formatAdguardHomeClock(_start),
                    style: theme.textTheme.titleMedium,
                  ),
                  onTap: () => _pick(start: true),
                ),
                ListTile(
                  enabled: _paused && !_toEndOfDay,
                  title: const Text('To'),
                  trailing: Text(
                    formatAdguardHomeClock(_end),
                    style: theme.textTheme.titleMedium,
                  ),
                  onTap: () => _pick(start: false),
                ),
                SwitchListTile(
                  title: const Text('Until the end of the day'),
                  value: _toEndOfDay,
                  onChanged: _paused
                      ? (bool on) => setState(
                            () => _end = on ? _dayEnd : const Duration(hours: 17),
                          )
                      : null,
                ),
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                    child: Text(
                      problem,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    Insets.md,
                    Insets.lg,
                    Insets.xs,
                  ),
                  child: Text(
                    'The same on',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                  child: Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.xs,
                    children: <Widget>[
                      for (final String day in adguardHomeWeekdays)
                        if (day != widget.day)
                          FilterChip(
                            label: Text(
                              adguardHomeWeekdayName(day).substring(0, 3),
                            ),
                            selected: _days.contains(day),
                            onSelected: (bool on) => setState(() {
                              if (on) {
                                _days.add(day);
                              } else {
                                _days.remove(day);
                              }
                            }),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.md,
              Insets.lg,
              Insets.md,
            ),
            // Wraps onto two lines rather than run off a narrow screen at a
            // large text size.
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: Insets.sm,
              overflowSpacing: Insets.xs,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: problem == null ? _save : null,
                  child: Text(_action),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Picks the time zone of a schedule: the server's own first, then the
/// IANA names, searchable. Closes with the one picked.
class AdguardHomeTimeZoneScreen extends StatefulWidget {
  const AdguardHomeTimeZoneScreen({required this.selected, super.key});

  final String selected;

  @override
  State<AdguardHomeTimeZoneScreen> createState() =>
      _AdguardHomeTimeZoneScreenState();
}

class _AdguardHomeTimeZoneScreenState extends State<AdguardHomeTimeZoneScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _search.text.trim().toLowerCase().replaceAll(' ', '_');
    final List<String> zones = <String>[
      if (query.isEmpty) adguardHomeServerTimeZone,
      for (final String zone in adguardHomeTimeZones)
        if (query.isEmpty || zone.toLowerCase().contains(query)) zone,
    ];
    final String selected = widget.selected.isEmpty
        ? adguardHomeServerTimeZone
        : widget.selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Time zone')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.sm,
              Insets.lg,
              Insets.sm,
            ),
            child: TextField(
              controller: _search,
              onChanged: (String _) => setState(() {}),
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Search time zones',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: zones.isEmpty
                ? const SingleChildScrollView(
                    child: EmptyView(
                      icon: Icons.search_off,
                      title: 'No time zone matches',
                    ),
                  )
                : ListView.builder(
                    itemCount: zones.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String zone = zones[index];
                      return ListTile(
                        title: Text(adguardHomeTimeZoneLabel(zone)),
                        trailing: zone == selected
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.of(context).pop(zone),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
