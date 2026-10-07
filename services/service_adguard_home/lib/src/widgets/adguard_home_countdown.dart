import 'dart:async';

import 'package:flutter/material.dart';

import '../adguard_home_format.dart';

/// The time left until [until], ticking each second.
///
/// The server reports a pause as time left when it was asked, and it is
/// only asked every few seconds, so the display counts down on its own in
/// between. [onDone] is called once, when the time runs out, so whoever
/// shows this can ask the server again at that moment rather than leave a
/// finished pause on screen until the next poll.
class AdguardHomeCountdown extends StatefulWidget {
  const AdguardHomeCountdown({
    required this.until,
    this.onDone,
    this.style,
    this.now = DateTime.now,
    super.key,
  });

  final DateTime until;
  final VoidCallback? onDone;
  final TextStyle? style;

  /// The clock. Tests hand in their own.
  final DateTime Function() now;

  @override
  State<AdguardHomeCountdown> createState() => _AdguardHomeCountdownState();
}

class _AdguardHomeCountdownState extends State<AdguardHomeCountdown> {
  Timer? _timer;
  bool _done = false;

  Duration get _left => widget.until.difference(widget.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer _) => _tick());
  }

  @override
  void didUpdateWidget(AdguardHomeCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) _done = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_done && _left <= Duration.zero) {
      _done = true;
      widget.onDone?.call();
    }
  }

  @override
  Widget build(BuildContext context) =>
      Text(formatAdguardHomeCountdown(_left), style: widget.style);
}
