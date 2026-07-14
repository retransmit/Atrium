/// Public surface of `core_ui`.
///
/// Material 3 theme (light/dark/dynamic-color), design tokens, and the
/// shared widget vocabulary used by both the app shell and every service
/// module.
library;

// Pull-to-refresh surfaced through core_ui so modules
// use it without each taking a direct easy_refresh dependency.
export 'package:easy_refresh/easy_refresh.dart';

export 'src/design_tokens.dart';
export 'src/navigation.dart';
export 'src/performance_logger.dart';
export 'src/service_visuals.dart';
export 'src/theme.dart';
export 'src/widgets/async_value_view.dart';

export 'src/widgets/expressive_progress_indicator.dart';
export 'src/widgets/expressive_slider.dart';
export 'src/widgets/overview_box.dart';
export 'src/widgets/service_tile.dart';
export 'src/widgets/state_views.dart';
export 'src/widgets/status_chip.dart';
