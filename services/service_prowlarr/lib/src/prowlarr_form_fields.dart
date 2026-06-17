import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Renders one Prowlarr dynamic schema field (a `fields[]` entry) as a form
/// control: checkbox, single- or multi-select, number, password, or textbox.
///
/// The [field] map is mutated in place as the user edits, so a parent form that
/// round-trips the whole `fields` list picks up changes without extra wiring.
/// Ephemeral UI state (password visibility) lives here. A `select` field whose
/// `value` is a list is rendered as a multi-select (e.g. an app's sync
/// categories, which has dozens of options).
///
/// Shared by the indexer and application config forms. Give each instance a
/// `ValueKey(field['name'])` so per-field state stays put when the Advanced
/// toggle inserts or removes fields around it.
class ProwlarrDynamicField extends StatefulWidget {
  const ProwlarrDynamicField({required this.field, super.key});

  final Map<String, dynamic> field;

  @override
  State<ProwlarrDynamicField> createState() => _ProwlarrDynamicFieldState();
}

class _ProwlarrDynamicFieldState extends State<ProwlarrDynamicField> {
  bool _obscure = true;

  Map<String, dynamic> get _f => widget.field;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String type = (_f['type'] as String?) ?? 'textbox';
    final String label =
        (_f['label'] as String?) ?? (_f['name'] as String? ?? '');
    final String? help = _f['helpText'] as String?;

    switch (type) {
      case 'checkbox':
        return Container(
          margin: const EdgeInsets.only(bottom: Insets.md),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: Radii.card,
          ),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md),
            title: Text(label),
            subtitle: help != null ? Text(help) : null,
            value: (_f['value'] as bool?) ?? false,
            onChanged: (bool v) => setState(() => _f['value'] = v),
          ),
        );
      case 'select':
        if (_f['value'] is List) {
          return _multiSelect(theme, label);
        }
        return _singleSelect(label, help);
      case 'number':
        return Container(
          margin: const EdgeInsets.only(bottom: Insets.md),
          child: TextFormField(
            initialValue: (_f['value'] ?? '').toString(),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              helperText: help,
              border: const OutlineInputBorder(),
            ),
            onChanged: (String v) => _f['value'] = num.tryParse(v) ?? v,
          ),
        );
      case 'password':
        return Container(
          margin: const EdgeInsets.only(bottom: Insets.md),
          child: TextFormField(
            initialValue: (_f['value'] ?? '').toString(),
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: label,
              helperText: help,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (String v) => _f['value'] = v,
          ),
        );
      case 'textbox':
      default:
        return Container(
          margin: const EdgeInsets.only(bottom: Insets.md),
          child: TextFormField(
            initialValue: (_f['value'] ?? '').toString(),
            decoration: InputDecoration(
              labelText: label,
              helperText: help,
              border: const OutlineInputBorder(),
            ),
            onChanged: (String v) => _f['value'] = v,
          ),
        );
    }
  }

  Widget _singleSelect(String label, String? help) {
    final List<Map<String, dynamic>> options = _options();
    final dynamic current = _f['value'];
    final bool hasMatch =
        options.any((Map<String, dynamic> o) => o['value'] == current);
    final dynamic dropdownValue = hasMatch
        ? current
        : (options.isNotEmpty ? options.first['value'] : null);
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      child: DropdownButtonFormField<dynamic>(
        initialValue: dropdownValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          helperText: help,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map(
              (Map<String, dynamic> o) => DropdownMenuItem<dynamic>(
                value: o['value'],
                child: Text((o['name'] ?? o['value'] ?? '').toString()),
              ),
            )
            .toList(),
        onChanged: (dynamic v) => setState(() => _f['value'] = v),
      ),
    );
  }

  /// A multi-select (e.g. sync categories) shown as a tappable summary tile that
  /// opens a scrollable checkbox dialog - the option list is far too long to
  /// inline as chips.
  Widget _multiSelect(ThemeData theme, String label) {
    final List<Map<String, dynamic>> options = _options();
    final List<dynamic> selected =
        List<dynamic>.from((_f['value'] as List<dynamic>?) ?? <dynamic>[]);
    final List<String> names = options
        .where((Map<String, dynamic> o) => selected.contains(o['value']))
        .map((Map<String, dynamic> o) => (o['name'] ?? o['value'] ?? '').toString())
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: Radii.card,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md),
        title: Text(label),
        subtitle: Text(
          selected.isEmpty ? 'None selected' : names.join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _editMulti(options, label),
      ),
    );
  }

  Future<void> _editMulti(
    List<Map<String, dynamic>> options,
    String label,
  ) async {
    final Set<dynamic> initial =
        Set<dynamic>.from((_f['value'] as List<dynamic>?) ?? <dynamic>[]);
    final List<dynamic>? result = await showDialog<List<dynamic>>(
      context: context,
      builder: (BuildContext ctx) {
        final Set<dynamic> sel = Set<dynamic>.from(initial);
        return AlertDialog(
          title: Text(label),
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (BuildContext ctx, StateSetter setLocal) => ListView(
                shrinkWrap: true,
                children: options.map((Map<String, dynamic> o) {
                  final dynamic v = o['value'];
                  return CheckboxListTile(
                    dense: true,
                    value: sel.contains(v),
                    title: Text((o['name'] ?? v ?? '').toString()),
                    onChanged: (bool? checked) => setLocal(() {
                      if (checked ?? false) {
                        sel.add(v);
                      } else {
                        sel.remove(v);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, sel.toList()),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _f['value'] = result);
    }
  }

  List<Map<String, dynamic>> _options() =>
      ((_f['selectOptions'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .toList();
}

/// A bordered switch tile for a resource's top-level boolean (a download
/// client's "Enabled", a notification's "On Health Issue", ...). Matches the
/// look of [ProwlarrDynamicField]'s checkbox so the two read as one form.
class ProwlarrSwitchTile extends StatelessWidget {
  const ProwlarrSwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: Radii.card,
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md),
        title: Text(label),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// A labelled integer field for a resource's top-level number (a download
/// client's "Priority", ...).
class ProwlarrIntField extends StatelessWidget {
  const ProwlarrIntField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          border: const OutlineInputBorder(),
        ),
        onChanged: (String v) {
          final int? n = int.tryParse(v);
          if (n != null) {
            onChanged(n);
          }
        },
      ),
    );
  }
}
