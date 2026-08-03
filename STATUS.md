# Atrium - Status

> Snapshot of what genuinely works and what is left, as of 2026-07-31.
> Atrium is published on F-Droid and on the GitHub releases page. It is
> still in early development and every module is work in progress; nothing
> here is a release promise.

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
  Transfers (qBittorrent downloads *and active uploads*, Deluge,
  Transmission and rTorrent transfers,
  SABnzbd slots,
  NZBGet groups, Sonarr/Radarr queues). Per-instance resilience: an unreachable server
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
- **Speedtest Tracker** (live-verified): authenticated 1.1+ result history,
  latest metrics, combined download / upload chart, multi-instance dashboard
  widget, and confirmed 1.6+ remote runs with queued/running/terminal-state
  polling and automatic result refresh
- **NZBGet** (live-verified): Basic-auth JSON-RPC client, queue with drag
  reorder / per-item pause / priority / category, whole-queue pause and a
  speed-limit control, add NZB by URL or file, history with retry on
  failures, dashboard widget and Activity feed integration
- **Deluge** (live-verified against 2.2.0): JSON-RPC client over a session
  cookie, torrent list with per-item pause / resume / remove (optionally with
  data), force recheck, reannounce and queue moves, state and tracker filter
  chips read from the daemon's own filter tree, nine sort fields, whole-session
  pause and global bandwidth caps, add by magnet / .torrent URL / file, a
  detail screen with files, trackers and peers, plus dashboard widget and
  Activity feed integration
- **Transmission** (live-verified against 4.1.3, RPC 19): RPC client that rides
  the shared Dio and handles the CSRF-token handshake (409 plus a rotating
  session id) transparently, with optional HTTP Basic. Torrent list with
  start / stop / start-now / remove (optionally with data), verify, reannounce
  and queue moves; status and label filter chips built from the list itself;
  nine sort fields; global limits with their separate enabled flags plus turtle
  mode; add by magnet / .torrent URL / file, reporting duplicates as such; a
  detail screen with files (wanted toggling), peers and trackers; dashboard
  widget and Activity feed integration. The add, reannounce and remove paths
  were exercised against the live daemon

- **rTorrent** (live-verified against 0.16.17): the one client that speaks
  **XML-RPC** rather than JSON - a hand-rolled codec builds the `methodCall`
  documents and reads back the positional arrays `d.multicall2` returns, with
  faults (which arrive inside an HTTP 200) mapped to real errors and a proxy's
  HTML error page reported as "this is not the XML-RPC endpoint". Torrent list
  with start / stop / close / remove, hash check, reannounce and priority;
  status and label filter chips built from the list itself; eight sort fields;
  global bandwidth caps; add by magnet / .torrent URL / file with an optional
  destination; a detail screen with files (skip / normal / high priority),
  peers and trackers; dashboard widget and Activity feed integration. Because
  rTorrent publishes no status field, no ETA and no delete-with-data, all three
  are derived or plainly disclaimed rather than faked. Read paths, limits,
  priority, add and remove were all exercised against the live daemon. One
  quirk found doing so: rTorrent answers 0 and then silently does nothing when
  asked to load an http(s) `.torrent` by URL, over both http and https, so the
  app downloads the file itself and sends the bytes, which does work. That
  fetch deliberately uses a bare Dio rather than the instance one, so an
  instance's credentials are never sent to whatever host a pasted link names

- **iOS**: the target exists and CI builds it unsigned on macOS on every
  change, so it cannot rot unnoticed. Deep links already no-op off Android and
  dynamic colour falls back to Atrium's own seed, since iOS has no system
  palette. NEVER RUN on a device or simulator: verified to compile, nothing
  more. No App Store build is planned - GPL-3.0-or-later is incompatible with
  Apple's distribution terms - so iOS users build and sideload. iOS 14+, which
  is the floor file_picker imposes and costs no devices (iOS 14 runs on the
  same hardware as 13). Still open: Keychain Sharing may be needed by
  flutter_secure_storage, the app icon and launch screen are Flutter
  placeholders, and a denied local-network permission currently looks like a
  timeout to ConnectionResolver, which would pin Auto to the external URL

## Partially done

- **SABnzbd**: queue, history with retry, speed limit and server stats;
  missing categories (also the one module never tested against a live
  server)

## App-wide TODO

1. A Wake-on-LAN dashboard widget (the board and its eight widgets ship
   in 1.0.0)
2. iOS platform scaffold
3. Live-stack testing of SABnzbd
4. Possible profile loss after Android hard-kill (seen once -
   investigate crash-safe Hive writes/backup)
5. Polish: tablet layouts, localization

## Contributing

PRs target `development`. Generated freezed/json files are gitignored -
run build_runner in each changed package after pulling model changes.
All imperative navigation must use `pushScreen` from core_ui (root
navigator), and do not run repo-wide `dart format` (it fights the lint
config); see CONTRIBUTING.md.
