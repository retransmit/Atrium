/// Public surface of `service_sonarr`.
library;

import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/legacy.dart';

export 'src/models/sonarr_episode.dart';
export 'src/models/sonarr_series.dart';
export 'src/series_detail_screen.dart';
export 'src/sonarr_add_series_search_screen.dart';
export 'src/sonarr_add_series_sheet.dart';
export 'src/sonarr_api.dart';
export 'src/sonarr_home.dart';
export 'src/sonarr_providers.dart';

final sonarrActiveTabBarIndexProvider =
    StateProvider.family<int, Instance>((ref, instance) => 0);
