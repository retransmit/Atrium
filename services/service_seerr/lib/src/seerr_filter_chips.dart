import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// The row of filter chips over a Seerr list (Requests, Issues). Built whole
/// and scrolled sideways, as more chips than a phone is wide still fit.
class SeerrFilterChips<T> extends StatelessWidget {
  const SeerrFilterChips({
    required this.values,
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<T> values;
  final String Function(T value) label;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: Insets.pageH,
        child: Row(
          spacing: Insets.sm,
          children: <Widget>[
            for (final T value in values)
              FilterChip(
                label: Text(label(value)),
                selected: value == selected,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ),
    );
  }
}

/// A chip picked in a tab, kept on the page for as long as it is open, so
/// going to another tab and back does not reset it.
mixin SeerrKeptFilter<W extends StatefulWidget, T> on State<W> {
  /// Names the tab's chip within the page.
  Object get filterKey;

  /// The chip a tab opens on.
  T get firstFilter;

  late T filter = PageStorage.maybeOf(context)
          ?.readState(context, identifier: filterKey) as T? ??
      firstFilter;

  void pickFilter(T value) {
    setState(() => filter = value);
    PageStorage.maybeOf(context)
        ?.writeState(context, value, identifier: filterKey);
  }
}
