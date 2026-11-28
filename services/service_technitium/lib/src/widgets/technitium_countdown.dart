import 'dart:async';

import 'package:flutter/material.dart';

import '../technitium_format.dart';

/// A ticking countdown until [until].
class TechnitiumCountdown extends StatefulWidget {
  const TechnitiumCountdown({
    required this.until,
    this.onDone,
    this.style,
    this.now = DateTime.now,
    super.key,
  });

  final DateTime until;
  final VoidCallback? onDone;
  final TextStyle? style;
  final DateTime Function() now;

  @override
  State<TechnitiumCountdown> createState() => _TechnitiumCountdownState();
}

class _TechnitiumCountdownState extends State<TechnitiumCountdown> {
  Timer? _timer;
  bool _done = false;

  Duration get _left => widget.until.difference(widget.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(TechnitiumCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) {
      _done = false;
    }
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
  Widget build(BuildContext context) {
    return Text(formatTechnitiumCountdown(_left), style: widget.style);
  }
}
