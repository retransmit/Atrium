import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// A heading over a group of fields in a sheet or a form.
class AdguardHomeHeading extends StatelessWidget {
  const AdguardHomeHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// A name with what belongs to it underneath. One over the other rather
/// than side by side, so a long value has the width of the sheet at any
/// text size.
class AdguardHomeBlock extends StatelessWidget {
  const AdguardHomeBlock(this.label, this.children, {super.key});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Insets.xxs),
          ...children,
        ],
      ),
    );
  }
}

/// A name and one value. Leaves itself out when there is no value.
class AdguardHomeField extends StatelessWidget {
  const AdguardHomeField(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return AdguardHomeBlock(
      label,
      <Widget>[Text(value, style: Theme.of(context).textTheme.bodyMedium)],
    );
  }
}
