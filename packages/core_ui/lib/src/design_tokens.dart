import 'package:flutter/widgets.dart';

/// Spacing, radius, and sizing constants used across Atrium.
///
/// Centralizing these keeps screens visually consistent and makes a future
/// density pass (e.g., compact mode) a one-file change.
abstract final class Insets {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Default page padding for scrollable content.
  static const EdgeInsets page = EdgeInsets.all(lg);

  /// Horizontal-only page padding (lists supply their own vertical gaps).
  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: lg);
}

abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(xl));
}

abstract final class Sizes {
  /// Edge length of the square service icon badge.
  static const double serviceBadge = 40;

  /// Poster aspect ratio (width : height) for movie/series art.
  static const double posterAspect = 2 / 3;

  /// Max content width on wide screens (tablets, foldables unfolded).
  static const double maxContentWidth = 720;
}
