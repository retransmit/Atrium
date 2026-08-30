import 'package:flutter/material.dart';

/// The bottom navigation bar every screen with tabs uses.
///
/// Material's [NavigationBar] wraps itself in a SafeArea and *then* sizes to
/// its height, so what it actually occupies is that height plus the bottom
/// inset. Pinning it to a bare 80 eats the inset out of the bar itself: on
/// three-button devices, whose inset runs to roughly twice a gesture bar's,
/// that clips the selection pill and squeezes the icons down onto the labels.
/// Gesture devices have just enough slack to hide it, which is why it only
/// ever reproduces for some people.
///
/// This lives in one place because the last fix did not. It was made once in
/// the router's own bar, lost within the hour to a branch that predated it,
/// and never applied to the five service bars copied from the same shape.
class AtriumBottomNav extends StatelessWidget {
  const AtriumBottomNav({
    required this.visible,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  /// Hidden while scrolling down, so a long list is not read through the bar.
  final bool visible;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  /// The bar itself, before the system inset underneath it.
  static const double barHeight = 80;

  /// What the bar occupies in total on this device.
  ///
  /// `padding`, not `viewPadding`: it collapses to zero while the keyboard is
  /// up, which is exactly when the bar no longer needs the room. That is also
  /// the value the bar's own SafeArea consumes, so the two cannot drift.
  static double heightFor(BuildContext context) =>
      barHeight + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final double height = heightFor(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: visible ? height : 0,
      // The bar keeps its full height while the container shrinks past it,
      // which would otherwise overflow for the frames in between.
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: height,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
