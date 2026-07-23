import 'package:flutter/foundation.dart';

/// A category of change within a release, rendered as a colored label.
enum ChangeCategory { added, improved, fixed }

/// One category's bullets within a release.
@immutable
class ChangeGroup {
  const ChangeGroup(this.category, this.items);
  final ChangeCategory category;
  final List<String> items;
}

/// One version and what changed in it.
@immutable
class ReleaseNote {
  const ReleaseNote({
    required this.version,
    required this.date,
    required this.groups,
  });
  final String version;
  final String date;
  final List<ChangeGroup> groups;
}

/// Newest first. Update alongside appVersion and the pubspec at each release.
const List<ReleaseNote> releaseNotes = <ReleaseNote>[
  ReleaseNote(
    version: '1.1.0',
    date: '2026-07-23',
    groups: <ChangeGroup>[
      ChangeGroup(ChangeCategory.added, <String>[
        'Speedtest Tracker service, follow your download, upload and ping speeds from the dashboard.',
        'Test Connection button on every service, check the URL and login before you save.',
      ]),
    ],
  ),
  ReleaseNote(
    version: '1.0.7',
    date: '2026-07-19',
    groups: <ChangeGroup>[
      ChangeGroup(ChangeCategory.added, <String>[
        'Radarr settings now match Sonarr\'s, configurable to the same depth.',
      ]),
      ChangeGroup(ChangeCategory.improved, <String>[
        'New theming engine with a cleaner, flatter look and a live-updating Settings preview.',
        'Glances gauges follow your theme instead of fixed colors.',
        'Logs keep loading as you scroll instead of stopping after the first page.',
        'Series and movie detail screens scroll noticeably more smoothly.',
      ]),
      ChangeGroup(ChangeCategory.fixed, <String>[
        'Scrolling no longer over-stretches at the edges.',
        'Dashboard widgets keep their state as you move around.',
      ]),
    ],
  ),
  ReleaseNote(
    version: '1.0.6',
    date: '2026-07-17',
    groups: <ChangeGroup>[
      ChangeGroup(ChangeCategory.improved, <String>[
        'Unified pull to refresh across every screen, smoother and more responsive.',
        'Detail screens fade their title into the app bar, and the bottom bar hides as you scroll down.',
        'Seerr posters, backdrops and cast now load from your own Seerr server rather than TMDB.',
      ]),
      ChangeGroup(ChangeCategory.fixed, <String>[
        'Pull to refresh no longer fires when you swipe a poster row sideways.',
      ]),
    ],
  ),
  ReleaseNote(
    version: '1.0.5',
    date: '2026-07-17',
    groups: <ChangeGroup>[
      ChangeGroup(ChangeCategory.fixed, <String>[
        'Build numbers now follow F-Droid\'s scheme. If you came from an earlier GitHub build, Android needs a one-time reinstall, so export your profiles from Settings first. Nothing after this is affected.',
      ]),
    ],
  ),
  ReleaseNote(
    version: '1.0.4',
    date: '2026-07-17',
    groups: <ChangeGroup>[
      ChangeGroup(ChangeCategory.fixed, <String>[
        'Reproducible builds now match F-Droid\'s byte for byte, a library had carried a build-path fingerprint.',
      ]),
    ],
  ),
  ReleaseNote(
    version: '1.0.3',
    date: '2026-07-17',
    groups: <ChangeGroup>[
      ChangeGroup(ChangeCategory.improved, <String>[
        'Releases are now built by a server so F-Droid can rebuild and verify them, letting the two share one signature so you can move between them without reinstalling.',
      ]),
    ],
  ),
  ReleaseNote(
    version: '1.0.2',
    date: '2026-07-17',
    groups: <ChangeGroup>[
      ChangeGroup(ChangeCategory.fixed, <String>[
        'Removed an encrypted dependency list the Android tools embedded in every APK, it was Play only and never sent anywhere.',
      ]),
    ],
  ),
  ReleaseNote(
    version: '1.0.1',
    date: '2026-07-16',
    groups: <ChangeGroup>[
      ChangeGroup(ChangeCategory.fixed, <String>[
        'Security, 1.0.0 attached your Sonarr or Radarr API key to poster requests sent to TheTVDB, TMDB and Fanart.tv. If you ran 1.0.0, consider rotating those keys.',
        'Posters and backdrops now load from your own Sonarr and Radarr instances, so the artwork sites no longer see your address or what you are browsing.',
      ]),
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    date: '2026-07-16',
    groups: <ChangeGroup>[
      ChangeGroup(ChangeCategory.added, <String>[
        'Dashboard of at-a-glance widgets (downloads, now streaming, upcoming, recently added and downloaded, requests, server info), reorderable.',
        'Sonarr and Radarr management across library, queue, wanted, history, blocklist, system and settings.',
        'qBittorrent, SABnzbd, Prowlarr, Bazarr, Seerr, Tautulli and Glances modules.',
        'Jellyfin, Emby and Plex browsing with resume rows, item detail and now-playing sessions.',
        'Multiple profiles, each instance with a local and an external URL, plus import and export.',
        'Material 3 Expressive theming with dynamic color, custom palettes and an optional biometric lock.',
      ]),
    ],
  ),
];
