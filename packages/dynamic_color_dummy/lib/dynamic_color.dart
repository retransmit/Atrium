library;

// Redirect everything to dynamic_system_colors so packages that depend on dynamic_color
// (like m3e_design) will continue to work without duplicate Android classes.
export 'package:dynamic_system_colors/dynamic_system_colors.dart';
