import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Lets something that does not scroll be pulled down to refresh: it is
/// given the height of the space it stands in, inside a list that always
/// answers a drag.
///
/// An empty list is the one that most wants reading again, and a message
/// that stands where a list would be is taller than the room a keyboard
/// leaves on a small phone, so it has to scroll too.
class AdguardHomePullable extends StatelessWidget {
  const AdguardHomePullable({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return EasyRefresh(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
