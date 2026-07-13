import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class DynamicSchemaForm extends StatefulWidget {
  const DynamicSchemaForm({
    required this.fields,
    required this.onSave,
    this.onTest,
    super.key,
  });

  final List<Map<String, dynamic>> fields;
  final void Function(List<Map<String, dynamic>> updatedFields) onSave;
  final Future<void> Function(List<Map<String, dynamic>> testFields)? onTest;

  @override
  State<DynamicSchemaForm> createState() => _DynamicSchemaFormState();
}

class _DynamicSchemaFormState extends State<DynamicSchemaForm> {
  final _formKey = GlobalKey<FormState>();
  late List<Map<String, dynamic>> _localFields;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _initialTexts = {};
  bool _showAdvanced = false;
  bool _testing = false;
  String? _testError;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _localFields = widget.fields.map(Map<String, dynamic>.from).toList();
    for (final field in _localFields) {
      final name = field['name'] as String;
      final type = field['type'] as String?;
      final value = field['value'];

      if (type == 'checkbox' || type == 'select') continue;
      final text = value is List ? value.join(',') : value?.toString() ?? '';
      _controllers[name] = TextEditingController(text: text);
      _initialTexts[name] = text;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _applyControllerValues(List<Map<String, dynamic>> fields) {
    for (final field in fields) {
      final name = field['name'] as String;
      final controller = _controllers[name];
      if (controller == null) continue;

      final text = controller.text.trim();
      if (text == (_initialTexts[name] ?? '').trim()) continue;

      if (field['isFloat'] as bool? ?? false) {
        field['value'] = double.tryParse(text);
      } else if (field['type'] == 'number') {
        field['value'] = num.tryParse(text);
      } else if (field['value'] is List) {
        field['value'] = text
            .split(',')
            .map((term) => term.trim())
            .where((term) => term.isNotEmpty)
            .map((term) => num.tryParse(term) ?? term)
            .toList();
      } else {
        field['value'] = text;
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    _applyControllerValues(_localFields);

    widget.onSave(_localFields);
  }

  Future<void> _testConnection() async {
    if (widget.onTest == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _testing = true;
      _testError = null;
      _testSuccess = false;
    });

    final testFields = _localFields.map(Map<String, dynamic>.from).toList();
    _applyControllerValues(testFields);

    try {
      await widget.onTest!(testFields);
      if (mounted) {
        setState(() {
          _testSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAdvanced =
        _localFields.any((f) => f['advanced'] as bool? ?? false);

    final visibleFields = _localFields.where((f) {
      final hiddenMode = f['hidden'];
      if (hiddenMode == 'hidden' || hiddenMode == 'true') return false;
      if (hiddenMode == 'hiddenIfNotSet') {
        final value = f['value'];
        final notSet = value == null ||
            (value is String && value.isEmpty) ||
            (value is List && value.isEmpty);
        if (notSet) return false;
      }
      final isAdvanced = f['advanced'] as bool? ?? false;
      if (isAdvanced && !_showAdvanced) return false;
      return true;
    }).toList();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...visibleFields.map((field) => _buildFieldWidget(context, field)),
          const SizedBox(height: Insets.md),
          if (hasAdvanced) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Advanced Settings'),
              value: _showAdvanced,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _showAdvanced = val);
                }
              },
            ),
            const SizedBox(height: Insets.md),
          ],
          if (_testError != null) ...[
            Container(
              padding: const EdgeInsets.all(Insets.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Test Failed: $_testError',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
          ] else if (_testSuccess) ...[
            Container(
              padding: const EdgeInsets.all(Insets.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: theme.colorScheme.onPrimaryContainer),
                  const SizedBox(width: Insets.sm),
                  Text(
                    'Connection Test Successful!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.md),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onTest != null) ...[
                if (_testing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: ExpressiveProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _testConnection,
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('Test'),
                  ),
                const Spacer(),
              ],
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: Insets.sm),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWidget(BuildContext context, Map<String, dynamic> field) {
    final theme = Theme.of(context);
    final name = field['name'] as String;
    final label = (field['label'] as String?) ?? name;
    final helpText = field['helpText'] as String?;
    final type = field['type'] as String?;

    if (type == 'checkbox') {
      final value = field['value'] as bool? ?? false;
      return Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: helpText != null ? Text(helpText) : null,
          value: value,
          onChanged: (val) {
            setState(() {
              field['value'] = val;
            });
          },
        ),
      );
    }

    if (type == 'select') {
      final selectOptions = ((field['selectOptions'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
      final value = field['value'];

      final isMulti = selectOptions.isNotEmpty && value is List;

      if (isMulti) {
        final List<dynamic> listValue = List<dynamic>.from(value);
        return Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (helpText != null) ...[
                const SizedBox(height: 2),
                Text(
                  helpText,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.xs,
                runSpacing: Insets.xs,
                children: selectOptions.map((opt) {
                  final optName = (opt['name'] as String?) ??
                      (opt['value'] as Object).toString();
                  final optVal = opt['value'];
                  final selected = listValue.contains(optVal);
                  return FilterChip(
                    label: Text(optName),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          listValue.add(optVal);
                        } else {
                          listValue.remove(optVal);
                        }
                        field['value'] = listValue;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }

      dynamic matchedValue;
      final valStr = (value as Object?)?.toString();
      if (selectOptions
          .any((opt) => (opt['value'] as Object).toString() == valStr)) {
        matchedValue = selectOptions.firstWhere(
            (opt) => (opt['value'] as Object).toString() == valStr)['value'];
      } else if (selectOptions.isNotEmpty) {
        matchedValue = selectOptions.first['value'];
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: DropdownButtonFormField<dynamic>(
          initialValue: matchedValue,
          decoration: InputDecoration(
            labelText: label,
            helperText: helpText,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          items: selectOptions.map((opt) {
            final optName =
                (opt['name'] as String?) ?? (opt['value'] as Object).toString();
            return DropdownMenuItem<dynamic>(
              value: opt['value'],
              child: Text(optName),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              field['value'] = val;
            });
          },
        ),
      );
    }

    final isPassword = type == 'password';
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: TextFormField(
        controller: _controllers[name],
        obscureText: isPassword,
        keyboardType:
            type == 'number' ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          helperText: helpText,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        validator: (val) {
          return null;
        },
      ),
    );
  }
}
