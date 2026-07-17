import 'dart:convert';

import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_widget_kind.dart';

/// One board entry: which widget, and whether it is currently shown.
class DashboardWidgetConfig {
  const DashboardWidgetConfig({required this.kind, required this.enabled});

  final DashboardWidgetKind kind;
  final bool enabled;

  DashboardWidgetConfig copyWith({bool? enabled}) =>
      DashboardWidgetConfig(kind: kind, enabled: enabled ?? this.enabled);
}

/// Stored JSON -> configs. Unknown kind names are dropped (forward compat);
/// null / corrupt / non-list input decodes to an empty list.
List<DashboardWidgetConfig> decodeLayout(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const <DashboardWidgetConfig>[];
  }
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const <DashboardWidgetConfig>[];
  }
  if (decoded is! List) {
    return const <DashboardWidgetConfig>[];
  }
  final List<DashboardWidgetConfig> out = <DashboardWidgetConfig>[];
  for (final Object? item in decoded) {
    if (item is! Map) {
      continue;
    }
    final DashboardWidgetKind? kind =
        DashboardWidgetKind.values.asNameMap()[item['kind']];
    if (kind == null) {
      continue;
    }
    out.add(
        DashboardWidgetConfig(kind: kind, enabled: item['enabled'] != false));
  }
  return out;
}

String encodeLayout(List<DashboardWidgetConfig> layout) => jsonEncode(<Object>[
      for (final DashboardWidgetConfig c in layout)
        <String, Object>{'kind': c.kind.name, 'enabled': c.enabled},
    ]);

/// Stored order is kept (first occurrence wins), kinds missing from storage
/// are appended enabled in enum order - so future widgets appear by default.
List<DashboardWidgetConfig> mergeLayout(List<DashboardWidgetConfig> stored) {
  final Set<DashboardWidgetKind> seen = <DashboardWidgetKind>{};
  final List<DashboardWidgetConfig> out = <DashboardWidgetConfig>[];
  for (final DashboardWidgetConfig c in stored) {
    if (seen.add(c.kind)) {
      out.add(c);
    }
  }
  for (final DashboardWidgetKind kind in DashboardWidgetKind.values) {
    if (seen.add(kind)) {
      out.add(DashboardWidgetConfig(kind: kind, enabled: true));
    }
  }
  return out;
}

/// Board layout (order + visibility), persisted in the app settings box.
final NotifierProvider<DashboardLayoutController, List<DashboardWidgetConfig>>
    dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutController, List<DashboardWidgetConfig>>(
  DashboardLayoutController.new,
);

class DashboardLayoutController extends Notifier<List<DashboardWidgetConfig>> {
  static const String _key = 'dashboard.widgetLayout';

  /// The settings box, when open. Null where Hive wasn't booted (widget
  /// tests) - the layout then just behaves in-memory.
  Box<String>? get _box => Hive.isBoxOpen(AtriumBoxes.settings)
      ? Hive.box<String>(AtriumBoxes.settings)
      : null;

  @override
  List<DashboardWidgetConfig> build() =>
      mergeLayout(decodeLayout(_box?.get(_key)));

  /// Reorders within the ENABLED subset (the reorderable list only shows
  /// enabled widgets). Disabled entries are re-appended after the enabled
  /// ones - their relative position is meaningless while hidden.
  void moveEnabled(int oldIndex, int newIndex) {
    final List<DashboardWidgetConfig> enabled = <DashboardWidgetConfig>[
      for (final DashboardWidgetConfig c in state)
        if (c.enabled) c,
    ];
    if (oldIndex < 0 || oldIndex >= enabled.length) {
      return;
    }
    final DashboardWidgetConfig moved = enabled.removeAt(oldIndex);
    enabled.insert(newIndex.clamp(0, enabled.length), moved);
    _save(<DashboardWidgetConfig>[
      ...enabled,
      for (final DashboardWidgetConfig c in state)
        if (!c.enabled) c,
    ]);
  }

  void setEnabled(DashboardWidgetKind kind, bool enabled) {
    _save(<DashboardWidgetConfig>[
      for (final DashboardWidgetConfig c in state)
        c.kind == kind ? c.copyWith(enabled: enabled) : c,
    ]);
  }

  void _save(List<DashboardWidgetConfig> next) {
    state = next;
    _box?.put(_key, encodeLayout(next));
  }
}
