import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../adguard_home_format.dart';
import '../models/adguard_home_services.dart';
import 'adguard_home_service_icon.dart';

/// The services the server can block, under its groups, each with a switch:
/// what is on is blocked.
///
/// It holds nothing but the search. What is blocked is the caller's, handed
/// in as [selected] and handed back whole through [onChanged].
class AdguardHomeServicePicker extends StatefulWidget {
  const AdguardHomeServicePicker({
    required this.catalogue,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final AdguardHomeServiceCatalogue catalogue;

  /// The ids of the services that are blocked.
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<AdguardHomeServicePicker> createState() =>
      _AdguardHomeServicePickerState();
}

class _AdguardHomeServicePickerState extends State<AdguardHomeServicePicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(String id, {required bool blocked}) {
    final Set<String> next = <String>{...widget.selected};
    if (blocked) {
      next.add(id);
    } else {
      next.remove(id);
    }
    widget.onChanged(next);
  }

  void _clearSearch() {
    _search.clear();
    setState(() {});
  }

  /// What the list shows: a heading, then the services under it, for every
  /// group that has any that match [query].
  List<Object> _rows(String query) {
    final AdguardHomeServiceCatalogue catalogue = widget.catalogue;
    bool matches(AdguardHomeBlockedService service) =>
        query.isEmpty ||
        service.name.toLowerCase().contains(query) ||
        service.id.toLowerCase().contains(query);

    final List<Object> rows = <Object>[];
    void add(String heading, Iterable<AdguardHomeBlockedService> services) {
      final List<AdguardHomeBlockedService> shown =
          services.where(matches).toList();
      if (shown.isEmpty) return;
      rows
        ..add(heading)
        ..addAll(shown);
    }

    for (final String group in catalogue.groups) {
      add(adguardHomeServiceGroupLabel(group), catalogue.inGroup(group));
    }
    // In no group, or in one the server did not list.
    add(
      adguardHomeServiceGroupLabel(''),
      catalogue.services.where(
        (AdguardHomeBlockedService service) =>
            !catalogue.groups.contains(service.groupId),
      ),
    );
    // Blocked, but no longer in the catalogue. The server refuses a client
    // that names a service it does not know, so these must be removable.
    final Set<String> known = <String>{
      for (final AdguardHomeBlockedService service in catalogue.services)
        service.id,
    };
    add(
      'No longer offered by the server',
      <AdguardHomeBlockedService>[
        for (final String id in widget.selected)
          if (!known.contains(id)) AdguardHomeBlockedService(id: id, name: id),
      ],
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AdguardHomeServiceCatalogue catalogue = widget.catalogue;
    if (catalogue.services.isEmpty && widget.selected.isEmpty) {
      return const EmptyView(
        icon: Icons.block,
        title: 'The server offers no services to block',
      );
    }

    final String query = _search.text.trim().toLowerCase();
    final List<Object> rows = _rows(query);
    return Column(
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
            onTapOutside: (PointerDownEvent _) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Search services',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                    ),
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // Not while searching: they would change what is not shown.
        if (query.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onChanged(<String>{
                      ...widget.selected,
                      for (final AdguardHomeBlockedService service
                          in catalogue.services)
                        service.id,
                    }),
                    child: const Text('Block all'),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onChanged(const <String>{}),
                    child: const Text('Unblock all'),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: rows.isEmpty
              ? const SingleChildScrollView(
                  child: EmptyView(
                    icon: Icons.search_off,
                    title: 'No service matches',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: Insets.lg),
                  itemCount: rows.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Object row = rows[index];
                    if (row is! AdguardHomeBlockedService) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Insets.lg,
                          Insets.lg,
                          Insets.lg,
                          Insets.xs,
                        ),
                        child: Text(
                          '$row',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      );
                    }
                    return SwitchListTile(
                      secondary: AdguardHomeServiceIcon(
                        icon: row.icon,
                        color: cs.onSurfaceVariant,
                      ),
                      title: Text(row.name),
                      value: widget.selected.contains(row.id),
                      onChanged: (bool blocked) =>
                          _set(row.id, blocked: blocked),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
