/// Public surface of `service_radarr`.
library;

import 'package:core_models/core_models.dart';
import 'package:flutter_riverpod/legacy.dart';

export 'src/add_movie_screen.dart';
export 'src/home/radarr_rename_dialog.dart';
export 'src/models/radarr_blocklist_item.dart';
export 'src/models/radarr_history_item.dart';
export 'src/models/radarr_movie.dart';
export 'src/models/radarr_queue_item.dart';
export 'src/movie_detail_screen.dart';
export 'src/radarr_api.dart';
export 'src/radarr_home.dart';
export 'src/radarr_providers.dart';
export 'src/radarr_release_search_screen.dart';
export 'src/radarr_settings_form_screen.dart';

final radarrActiveTabBarIndexProvider =
    StateProvider.family<int, Instance>((ref, instance) => 0);
