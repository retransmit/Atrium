# Atrium - Status

> Snapshot of what genuinely works and what is left, as of 2026-07-10.
> Atrium is in early development and every module is still work in
> progress; nothing here is a release promise.

## Scope note

Atrium is a **controller** app. Video playback was removed by design
(2026-06-12): media servers are browse/manage/remote-control only, with
"open in the official app" deep links. Do not re-add a player.

## App shell

- Dashboard with role-grouped services sidebar (available on every tab
  via the shell drawer) and a profile switcher
- **Activity tab**: cross-instance live feed - summary bar, Now
  Streaming (backdrop session cards from Plex / Jellyfin / Emby /
  Tautulli, tap-through to each module's now-playing screen) and
  Transfers (qBittorrent downloads *and active uploads*, SABnzbd slots,
  Sonarr/Radarr queues). Per-instance resilience: an unreachable server
  degrades to a chip, never blocks the feed
- **Calendar tab**: month grid aggregating upcoming Sonarr + Radarr
  airings/releases with status dots
- **Settings**: theme, biometric lock, profile import/export (SAF,
  live-verified), **Wake-on-LAN devices** (profile-stored, magic packets
  over pure Dart UDP), **custom HTTP headers** (global + per-instance,
  for reverse-proxy auth), all carried by profile export/import
- Material 3 Expressive look app-wide: tonal cards, pills,
  poster-palette theming, backdrop session cards, M3 pull-to-refresh

## What works today (live-verified unless noted; all still in progress)

- Core foundation: profiles, multi-instance, dual-URL routing, secure
  key storage, import/export, per-service health dots, theming
- **qBittorrent**: cookie login (qBit 5.x 204 fix), 3s realtime polling,
  add magnet/file, categories, pause/resume/delete/recheck/queue moves,
  torrent detail (overview/files/trackers), per-file priority
- **Sonarr** (the canonical *arr module): poster/banner grid with
  client-side sort & filter (status, network, airing, added, size on
  disk) and per-series disk sizes, series detail (fanart backdrop,
  season monitor/search), search-and-add, queue/wanted/history/
  blocklist/system tabs, and a full Settings editor (17 panels) -
  settings writes live-verified
- **Radarr**: same depth as Sonarr, movie flavored
- **Prowlarr**: indexers (add/edit/test from schema), manual search
  across indexers with grab-to-client, history, full settings menu,
  system
- **Bazarr**: series/movies with per-episode subtitle status, manual
  provider search/download/delete, wanted, history, blacklist, system
- **Seerr** (Jellyseerr / Overseerr): discover (trending/upcoming/genres),
  search, item detail with request submission (profile/folder/server
  selection), requests management (approve/decline/delete/retry)
- **Tautulli**: activity (10s poll) with backdrop session cards and a
  detail sheet (codecs, decisions, bandwidth, terminate with inline
  errors), history, 30-day stats, users - restyled to the expressive
  look 2026-07-10
- **Jellyfin / Emby**: auth (incl. passwordless accounts), library
  browse, item detail (backdrop, palette accents, cast, series/episode
  info), season/episode screens, music, in-server search, resume rows,
  favorite + watched toggles, active-session screens with poster-palette
  theming and remote transport controls, remote artwork selection
  (https-validated, confirm-before-replace), deep links to the official
  apps
- **Plex** (full parity, 2026-07-09): Jellyfin-style home (featured
  hero, backdrop Now Streaming cards, per-library rows with See all),
  library grids with genre filtering, item detail with palette accents
  and inline seasons, episode watched toggles, music
  (artist/album/track), global search, **now-playing controller**
  (play/pause/seek/skip for Companion-controllable players, view-only
  otherwise; terminate degrades to a clear Plex Pass message), Open in
  Plex deep link. Note: real remote control needs a live stream on a
  controllable client - the UI and read-only data are verified, the
  transport commands are exercised best-effort
- **Glances**: per-instance polling, CPU/memory gauges, swap + per-core
  bars, network with interface pinning, disks, uptime

## Partially done

- **SABnzbd**: queue control only; missing history, categories, speed
  limits (also the one module never tested against a live server)

## App-wide TODO

1. Dashboard widgets (the aggregation providers behind the Activity tab
   were built to be reused; a Wake-on-LAN widget is planned)
2. Release signing + F-Droid metadata (debug-signed right now)
3. iOS platform scaffold
4. Live-stack testing of SABnzbd
5. Possible profile loss after Android hard-kill (seen once -
   investigate crash-safe Hive writes/backup)
6. Polish: tablet layouts, localization

## Contributing

PRs target `development`. Generated freezed/json files are gitignored -
run build_runner in each changed package after pulling model changes.
All imperative navigation must use `pushScreen` from core_ui (root
navigator), and do not run repo-wide `dart format` (it fights the lint
config); see CONTRIBUTING.md.
