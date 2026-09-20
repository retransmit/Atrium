# Atrium - Status

> Snapshot of what genuinely works and what is left, as of 2026-09-21.
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
- **Dashboard widgets**, reorderable from Customize dashboard: Active
  downloads, Now streaming, Upcoming releases, Recently added, Recently
  downloaded, Requests (Seerr and Ombi), Glances, Dashdot, Speedtest
  results, MySpeed, Gluetun VPN and Wake on LAN
- **Settings**: theme, biometric lock, profile import/export (SAF,
  live-verified), **Wake-on-LAN devices** (profile-stored, magic packets
  over pure Dart UDP), **custom HTTP headers** (global + per-instance,
  for reverse-proxy auth, kept intact when an instance's own form is
  saved), all carried by profile export/import
- Material 3 Expressive look app-wide: tonal cards, pills,
  poster-palette theming, backdrop session cards, M3 pull-to-refresh

## What works today (live-verified unless noted; all still in progress)

- Core foundation: profiles, multi-instance, dual-URL routing, secure
  key storage, import/export, per-service health dots, theming
- **qBittorrent**: cookie login (qBit 5.x 204 fix), 3s realtime polling,
  add magnet/file (with skip hash check), categories, tag and tracker
  filters, pause/resume/delete/recheck, queue moves and reordering
  (top/up/down/bottom) with sort by queue position, torrent detail
  (overview/files/trackers), per-file priority, and a settings screen
  mirroring the web UI across nine tabs. The four settings that would cut
  Atrium off from the server - web UI address and port, CSRF and
  clickjacking protection - confirm before applying, because once the
  address moves the app can no longer reach the server to undo it. An
  execution log tab (contributed by lxBlazarxl in PR #159) reads the
  server's log on demand, with copy, and the settings screen offers the
  network interfaces the server actually routes
- **Sonarr** (the canonical *arr module): poster/banner grid with
  client-side sort & filter (status, network, airing, added, size on
  disk) and per-series disk sizes, series detail (fanart backdrop,
  season monitor/search), search-and-add (the list's search query carries
  over to the Add screen, contributed by Bhavyashah94 in PR #160),
  queue/wanted/history/blocklist/system tabs, and a full Settings editor
  (17 panels) - settings writes live-verified
- **Radarr**: same depth as Sonarr, movie flavored
- **Lidarr** (beta, added in 1.5.0): artists and discography with grid and
  list views and bulk actions, artist detail with release-type filters,
  album and track detail with a file inspector and single-track search,
  album studio, track file rename/retag previews and manual import, wanted
  (missing and cutoff unmet), queue/history/blocklist, the full settings
  tree (profiles, download clients, indexers, import lists, notifications,
  metadata, media management, quality definitions), system diagnostics and
  an in-app log viewer with level filtering and search. Album releases also
  appear in the shared calendar. Marked beta: it has not been exercised
  against a live Lidarr for long
- **Prowlarr**: indexers (add/edit/test from schema), manual search
  across indexers with grab-to-client, history, full settings menu,
  system
- **Bazarr**: series/movies with per-episode subtitle status, manual
  provider search/download/delete, wanted, history, blacklist, system
- **Seerr** (Jellyseerr / Overseerr): discover (trending/upcoming/genres),
  search, item detail with request submission (profile/folder/server
  selection), requests management (approve/decline/delete/retry)
- **Ombi** (beta, added 2026-09-19, live-verified against 4.53): requests
  for movies, TV and, where Lidarr is set up, music, filtered as Ombi's own
  Requests page filters them, with approve / deny (with a reason) / delete;
  search and a Discover tab (popular and upcoming movies, popular and
  trending TV) whose request sheet reads a title's state before offering to
  request it; Ombi rows on the dashboard's Requests widget. Every state is
  worded the way Ombi's own pages word it
- **Tautulli**: activity (10s poll) with backdrop session cards and a
  detail sheet (codecs, decisions, bandwidth, terminate with inline
  errors), history, 30-day stats, users - restyled to the expressive
  look 2026-07-10
- **Tracearr** (live-verified against 2.x; first contributed by lxBlazarxl in
  PR #75, rebuilt by Bhavyashah94 in PR #104): monitors playback across Plex,
  Jellyfin and Emby from one place, as five destinations built strictly on the
  public v1 and v2 OpenAPI - Overview (fleet health, live stream pulse, 24h
  summary, 7-day histogram), Activity (stream cards with a diagnostics sheet
  and terminate, paginated watch history), Media (fleet storage, poster grid,
  item detail with per-server availability and a watchers leaderboard), People
  (user directory and per-user dossiers) and Security (policy violation
  ledger). Deliberately kept out of the shared Activity feed and dashboard
  widgets: it reports the same Plex session Plex already reports, so including
  it would count every stream twice. Artwork is harvested from the responses
  that already carry a thumb path and kept in a bounded Hive box, so the poster
  grid does not fan out a request per tile. Acknowledging or dismissing a
  violation is device-local and says so: those write routes need session auth
  and are closed to public API keys
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
  transport commands are exercised best-effort. Since 2026-09-18 the
  instance form offers a plex.tv sign-in beside the token field, which
  fills in a server that answers
- **Navidrome** (beta, added 2026-09-10, depth by lxBlazarxl 2026-09-12 to
  09-14): Subsonic API with signed requests and the envelope read for
  errors; an overview tab; artists in list and grid views with section
  badges; artist and album screens with half-page banners, biographies,
  metadata badges and tracklists with artwork; five-star ratings and
  favorites for artists and albums; custom playlists (create, rename,
  delete, add tracks); search in the shape of Emby's; quick library scan;
  artwork and web UI links respect a reverse-proxy sub-path
- **Glances**: per-instance polling, CPU/memory gauges, swap + per-core
  bars, network with interface pinning, disks, uptime
- **Beszel**: systems list, live metrics, and a per-system detail screen
- **dashdot**: live CPU, memory, disk, and GPU usage with a system-info tab,
  and a dashboard widget with a circular monitor and live vitals
- **Unraid** (beta): array state with parity and per-disk usage, temperature
  and health, system with per-core CPU load and an About card, Docker
  containers with a detail sheet and start/stop/pause/resume, and virtual
  machines with start, shut down, pause, resume, reboot, force stop and reset
- **Gluetun** (contributed by monuk7735 in PR #157, 2026-09-17; out of beta
  since 2026-09-20): VPN
  status with public IP, location and the forwarded port, reconnect in one
  tap, stop the VPN or DNS behind a confirmation, refused changes reported
  rather than claimed, an optional API key (a control server can run a
  no-auth role), a per-instance polling interval, and a Gluetun VPN
  dashboard widget. The connection test judges the connection rather than
  the VPN behind it, and the health dot warns when Gluetun reports its VPN
  down. Update Servers on ProtonVPN says what it needs
- **MySpeed** (added 2026-09-20 by lxBlazarxl, live-verified against 1.0.9):
  execution status with a manual run, the last 24 hours of results, a
  history with averages and a search by test id, the server's config and
  storage figures. Password-protected instances work: the password is
  sent the way 1.0.9 reads it and the way newer builds prefer it.
  Live-verified behind a reverse proxy with a required header as well. A
  dashboard widget (lxBlazarxl, PR #162) shows the latest figures and runs
  a test from the board
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
- **Transmission** (live-verified against 4.1.3, RPC 19; out of beta since
  2026-09-20, when it was brought to parity with Transmission's own web UI):
  RPC client that rides the shared Dio and handles the CSRF-token handshake
  (409 plus a rotating session id) transparently, with optional HTTP Basic.
  Torrent list with the web UI's nine filters (Active, Downloading, Seeding,
  Paused, Finished, Error, Private, Public), tracker and label chips, search,
  ten sort fields, compact rows, long-press selection with bulk actions, pause
  all / start all, and per-torrent resume / resume now / pause / verify /
  reannounce / set location / rename / edit labels / copy magnet link / queue
  moves / remove / trash; a detail screen whose Info tab carries every line the
  web UI's inspector shows, a Files tab as a folder tree with per-folder
  wanted and priority, Peers with the flag letters and their legend plus web
  seeds, and Trackers grouped by tier with announce and scrape state; a
  Settings tab mirroring the web UI's Torrents / Speed / Peers / Network
  preferences (each change written on its own, then read back) with the
  session and all-time statistics, a per-protocol port test and blocklist
  update; add by magnet / .torrent URL / file with the daemon's folder
  prefilled and its free space shown; dashboard widget and Activity feed
  integration. Every action and every setting was exercised against the live
  daemon. Restyled to the expressive look on 2026-09-20, and the screen owns
  its scaffold so back unwinds a selection, then the tab, then the drawer,
  before it leaves

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

1. Run iOS on a real device or simulator (the target builds on CI, nothing
   more)
2. Live-stack testing of SABnzbd
3. Possible profile loss after Android hard-kill (seen once -
   investigate crash-safe Hive writes/backup)
4. Polish: tablet layouts, localization
5. The website's service list and showcase still stop at 1.6.1: Ombi,
   Navidrome, Gluetun and MySpeed need icons and screenshots there

## Contributing

PRs target `development`. Generated freezed/json files are gitignored -
run build_runner in each changed package after pulling model changes.
All imperative navigation must use `pushScreen` from core_ui (root
navigator), and do not run repo-wide `dart format` (it fights the lint
config); see CONTRIBUTING.md.
