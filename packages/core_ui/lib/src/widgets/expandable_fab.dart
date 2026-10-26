import 'package:flutter/material.dart';

/// A floating action button that fans its actions out above itself.
///
/// The design the download clients share: one "+" that opens into the ways of
/// adding something, so the list keeps a single button instead of a row of
/// them. The actions are built lazily on every build by [builder], which is
/// handed a `close` callback so an action can fold the stack away before it
/// opens a sheet.
class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    required this.builder,
    this.tooltip = 'Add',
    this.step = 68,
    super.key,
  });

  /// The actions, nearest the main button first. That is also the order they
  /// are painted in, so the first one sits closest when the stack is open.
  final List<Widget> Function(BuildContext context, VoidCallback close) builder;

  /// What the main button says to a screen reader and on a long press while
  /// the stack is closed. Open, it says Close.
  final String tooltip;

  /// How far apart the actions sit, and how far each one travels.
  final double step;

  /// The main button's edge.
  static const double buttonSize = 56;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _open ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_open) {
      _toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = widget.builder(context, _close);
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (BuildContext context, Widget? child) {
        return SizedBox(
          width: ExpandableFab.buttonSize,
          height: ExpandableFab.buttonSize +
              (_expandAnimation.value * widget.step * actions.length),
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = 0; i < actions.length; i++)
            _ExpandingActionButton(
              maxDistance: (i + 1) * widget.step,
              progress: _expandAnimation,
              // Folded away they are still in the tree, scaled to nothing, so
              // a screen reader would otherwise read out buttons nobody can
              // see.
              child: ExcludeSemantics(excluding: !_open, child: actions[i]),
            ),
          FloatingActionButton(
            heroTag: null,
            tooltip: _open ? 'Close' : widget.tooltip,
            onPressed: _toggle,
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (BuildContext context, Widget? child) {
                return Transform.rotate(
                  angle: _expandAnimation.value * 0.7853981633974483,
                  child: const Icon(Icons.add),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandingActionButton extends StatelessWidget {
  const _ExpandingActionButton({
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (BuildContext context, Widget? child) {
        final double offset = maxDistance * progress.value;
        return Positioned(
          bottom: offset,
          left: 0,
          right: 0,
          child: Transform.scale(
            scale: progress.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
