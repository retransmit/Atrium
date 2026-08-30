/// The kinds of self-hosted services Atrium can drive.
///
/// New services append to the end of this list. JSON serialization uses the
/// enum name (`sonarr`, `radarr`, ...) so reordering is safe, but renaming is
/// not - write a migration if you rename.
enum ServiceKind {
  sonarr,
  radarr,
  prowlarr,
  bazarr,
  seerr,
  tautulli,
  jellyfin,
  emby,
  plex,
  qbittorrent,
  sabnzbd,
  glances,
  speedtestTracker,
  nzbget,
  deluge,
  transmission,
  rtorrent,
  tracearr,
  beszel,
  dashdot,
  lidarr,
  unraid,
}

/// Static metadata about a [ServiceKind] - display name, default port, the
/// auth style the service uses, and the broad role it plays in the stack.
///
/// Lives next to the enum so that adding a new service is a one-file change.
extension ServiceKindX on ServiceKind {
  /// Capitalized human label shown in lists, settings, etc.
  String get displayName => switch (this) {
        ServiceKind.sonarr => 'Sonarr',
        ServiceKind.radarr => 'Radarr',
        ServiceKind.prowlarr => 'Prowlarr',
        ServiceKind.bazarr => 'Bazarr',
        ServiceKind.seerr => 'Seerr',
        ServiceKind.tautulli => 'Tautulli',
        ServiceKind.jellyfin => 'Jellyfin',
        ServiceKind.emby => 'Emby',
        ServiceKind.plex => 'Plex',
        ServiceKind.qbittorrent => 'qBittorrent',
        ServiceKind.sabnzbd => 'SABnzbd',
        ServiceKind.glances => 'Glances',
        ServiceKind.speedtestTracker => 'Speedtest Tracker',
        ServiceKind.nzbget => 'NZBGet',
        ServiceKind.deluge => 'Deluge',
        ServiceKind.transmission => 'Transmission',
        ServiceKind.rtorrent => 'rTorrent',
        ServiceKind.tracearr => 'Tracearr',
        ServiceKind.beszel => 'Beszel',
        ServiceKind.dashdot => 'Dashdot',
        ServiceKind.lidarr => 'Lidarr',
        ServiceKind.unraid => 'Unraid',
      };

  /// One-line role description.
  String get tagline => switch (this) {
        ServiceKind.sonarr => 'TV shows',
        ServiceKind.radarr => 'Movies',
        ServiceKind.prowlarr => 'Indexers',
        ServiceKind.bazarr => 'Subtitles',
        ServiceKind.seerr => 'Requests',
        ServiceKind.tautulli => 'Plex stats',
        ServiceKind.jellyfin => 'Media server',
        ServiceKind.emby => 'Media server',
        ServiceKind.plex => 'Media server',
        ServiceKind.qbittorrent => 'Torrent client',
        ServiceKind.sabnzbd => 'Usenet client',
        ServiceKind.glances => 'System monitor',
        ServiceKind.speedtestTracker => 'Internet performance',
        ServiceKind.nzbget => 'Usenet client',
        ServiceKind.deluge => 'Torrent client',
        ServiceKind.transmission => 'Torrent client',
        ServiceKind.rtorrent => 'Torrent client',
        ServiceKind.tracearr => 'Stream monitoring',
        ServiceKind.beszel => 'System monitor',
        ServiceKind.dashdot => 'System monitor',
        ServiceKind.lidarr => 'Music',
        ServiceKind.unraid => 'Server',
      };

  /// Whether this service's integration is still in beta. Surfaced as a
  /// "BETA" badge in the service picker, on the instance tile, and on the
  /// service's own screen so users know it is not yet fully stable.
  bool get isBeta => switch (this) {
        ServiceKind.transmission ||
        ServiceKind.deluge ||
        ServiceKind.rtorrent ||
        ServiceKind.lidarr ||
        ServiceKind.unraid =>
          true,
        _ => false,
      };

  /// Vendor-default port. Used as a hint when the user is entering a URL
  /// without one.
  int? get defaultPort => switch (this) {
        ServiceKind.sonarr => 8989,
        ServiceKind.radarr => 7878,
        ServiceKind.prowlarr => 9696,
        ServiceKind.bazarr => 6767,
        ServiceKind.seerr => 5055,
        ServiceKind.tautulli => 8181,
        ServiceKind.jellyfin => 8096,
        ServiceKind.emby => 8096,
        ServiceKind.plex => 32400,
        ServiceKind.qbittorrent => 8080,
        ServiceKind.sabnzbd => 8080,
        ServiceKind.glances => 61208,
        ServiceKind.speedtestTracker => null,
        ServiceKind.nzbget => 6789,
        ServiceKind.deluge => 8112,
        ServiceKind.transmission => 9091,
        // rTorrent's XML-RPC port. Setups fronted by ruTorrent often expose it
        // on the web port under /RPC2 instead, so the URL is what really
        // decides; this is only the hint.
        ServiceKind.rtorrent => 8000,
        ServiceKind.tracearr => 3000,
        ServiceKind.beszel => 8090,
        ServiceKind.dashdot => 3001,
        ServiceKind.lidarr => 8686,
        // Unraid's web UI answers on plain http 80 unless it has been moved.
        ServiceKind.unraid => 80,
      };

  /// What auth flow the service uses by default. Some services (Jellyfin) can
  /// be configured either way; this is the typical path.
  AuthStyle get authStyle => switch (this) {
        ServiceKind.sonarr ||
        ServiceKind.radarr ||
        ServiceKind.prowlarr ||
        ServiceKind.bazarr ||
        ServiceKind.seerr ||
        ServiceKind.tautulli ||
        ServiceKind.sabnzbd ||
        ServiceKind.tracearr ||
        ServiceKind.lidarr ||
        ServiceKind.unraid =>
          AuthStyle.apiKey,
        // Transmission and rTorrent both use HTTP Basic, and for both it is
        // *optional* - rTorrent's XML-RPC has no auth of its own and is only
        // protected when someone puts a proxy in front - so the form must not
        // demand credentials for them.
        ServiceKind.jellyfin ||
        ServiceKind.emby ||
        ServiceKind.nzbget ||
        ServiceKind.transmission ||
        ServiceKind.rtorrent =>
          AuthStyle.userPass,
        ServiceKind.plex => AuthStyle.plexToken,
        // Deluge's Web UI takes a password with no username; it is still a
        // login that hands back a session cookie.
        ServiceKind.qbittorrent || ServiceKind.deluge => AuthStyle.cookieLogin,
        ServiceKind.glances => AuthStyle.none,
        ServiceKind.speedtestTracker => AuthStyle.bearerToken,
        ServiceKind.beszel => AuthStyle.userPass,
        ServiceKind.dashdot => AuthStyle.none,
      };

  /// Broad role of the service in the stack - used for grouping in the
  /// dashboard.
  ServiceRole get role => switch (this) {
        ServiceKind.sonarr ||
        ServiceKind.radarr ||
        ServiceKind.prowlarr ||
        ServiceKind.bazarr ||
        ServiceKind.lidarr =>
          ServiceRole.automation,
        ServiceKind.seerr => ServiceRole.requests,
        ServiceKind.tautulli || ServiceKind.tracearr => ServiceRole.analytics,
        ServiceKind.jellyfin ||
        ServiceKind.emby ||
        ServiceKind.plex =>
          ServiceRole.mediaServer,
        ServiceKind.qbittorrent ||
        ServiceKind.sabnzbd ||
        ServiceKind.nzbget ||
        ServiceKind.deluge ||
        ServiceKind.transmission ||
        ServiceKind.rtorrent =>
          ServiceRole.downloader,
        ServiceKind.glances => ServiceRole.analytics,
        ServiceKind.speedtestTracker => ServiceRole.analytics,
        ServiceKind.beszel => ServiceRole.analytics,
        ServiceKind.dashdot => ServiceRole.analytics,
        ServiceKind.unraid => ServiceRole.analytics,
      };

  /// Whether this service can be handed a torrent - a magnet URI, a link to a
  /// `.torrent`, or the file's bytes.
  ///
  /// Narrower than [ServiceRole.downloader], which also covers the Usenet
  /// clients: SABnzbd and NZBGet take `.nzb` and cannot do anything with a
  /// torrent. Used to pick the targets offered when another app shares a
  /// torrent with Atrium.
  bool get acceptsTorrents => switch (this) {
        ServiceKind.qbittorrent ||
        ServiceKind.deluge ||
        ServiceKind.transmission ||
        ServiceKind.rtorrent =>
          true,
        _ => false,
      };
}

/// The auth flow a service uses to authenticate a request.
enum AuthStyle {
  /// Static API key passed in a header or query param.
  apiKey,

  /// Static API token passed in an `Authorization: Bearer` header.
  bearerToken,

  /// Username + password login that returns a session token.
  userPass,

  /// Plex `X-Plex-Token`, obtained from plex.tv login or pinned in the
  /// server's `Preferences.xml`.
  plexToken,

  /// Username + password login that returns a cookie carried on subsequent
  /// requests (qBittorrent).
  cookieLogin,

  /// No authentication required.
  none,
}

/// Coarse grouping for the dashboard.
enum ServiceRole {
  automation,
  requests,
  analytics,
  mediaServer,
  downloader,
}
