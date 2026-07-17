import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../external_links.dart';

/// One version and what changed in it.
class _Release {
  const _Release({required this.version, required this.changes});

  final String version;
  final List<String> changes;
}

/// Newest first. Update alongside the version in the app's pubspec.
const List<_Release> _releases = <_Release>[
  _Release(
    version: '1.0.5',
    changes: <String>[
      'Nothing changes in the app itself. The internal build numbers now '
          'follow the scheme F-Droid asks of Flutter apps. If you installed an '
          'earlier release from GitHub, Android will refuse this as an update '
          'and you will have to reinstall once; export your profiles from '
          'Settings first. Nothing after this release is affected.',
    ],
  ),
  _Release(
    version: '1.0.4',
    changes: <String>[
      'Nothing changes in the app itself. F-Droid could not quite reproduce '
          'the 1.0.3 builds: one library came out of the compiler carrying a '
          'fingerprint of where the build tools happened to live, so their copy '
          'differed from this one in twenty bytes and nothing else. The build '
          'now uses the same tool paths they do, and their rebuild matches.',
    ],
  ),
  _Release(
    version: '1.0.3',
    changes: <String>[
      'Nothing changes in the app itself. Releases are now built by a server '
          'rather than by hand, so that F-Droid can rebuild them and check they '
          'match. That lets F-Droid ship the same signature this release page '
          'uses, and means you can move between the two without reinstalling.',
    ],
  ),
  _Release(
    version: '1.0.2',
    changes: <String>[
      'The Android build tools were writing an encrypted list of the app\'s '
          'dependencies into every APK, in a form only Google Play can read. '
          'Nothing sent it anywhere, but it has no business being in the app '
          'and is gone.',
      'Groundwork for the F-Droid listing.',
    ],
  ),
  _Release(
    version: '1.0.1',
    changes: <String>[
      'Security fix: 1.0.0 sent your Sonarr or Radarr API key to the artwork '
          'sites TheTVDB, TMDB and Fanart.tv, as a header on the poster '
          'requests made by the recently downloaded widget. Those keys grant '
          'full control of the server. If you ran 1.0.0, consider rotating the '
          'API key of every Sonarr and Radarr instance you use.',
      'Posters and backdrops on the dashboard and in the calendar now load '
          'from your own Sonarr and Radarr instances, which already cache '
          'them, rather than from those artwork sites. They no longer see your '
          'address or what you are browsing.',
    ],
  ),
  _Release(
    version: '1.0.0',
    changes: <String>[
      'Dashboard board of at-a-glance widgets: active downloads, now streaming, '
          'upcoming releases, recently added, recently downloaded, requests and '
          'server info, reorderable from an inline edit mode.',
      'Sonarr and Radarr management across library, queue, wanted, history, '
          'blocklist, system and settings.',
      'qBittorrent, SABnzbd, Prowlarr, Bazarr, Seerr, Tautulli and Glances '
          'modules.',
      'Jellyfin, Emby and Plex browsing with resume rows, item detail and '
          'now-playing sessions.',
      'Multiple profiles, each instance carrying a local and an external URL, '
          'with profile import and export.',
      'Material 3 Expressive theming with dynamic color, custom palettes and '
          'an optional biometric lock.',
    ],
  ),
];

/// In-app change log, with a link out to the full releases on GitHub.
class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change log'),
        actions: <Widget>[
          IconButton(
            tooltip: 'View releases on GitHub',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openExternal(
              ScaffoldMessenger.of(context),
              AtriumLinks.releases,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: Insets.page,
        children: <Widget>[
          for (final _Release release in _releases) ...<Widget>[
            Text(
              release.version,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: Insets.sm),
            for (final String change in release.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: Insets.sm),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(change, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Insets.md),
          ],
        ],
      ),
    );
  }
}
