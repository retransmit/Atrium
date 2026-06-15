# Atrium

The central courtyard for your self-hosted media stack.
One Android app that fronts Sonarr, Radarr, Prowlarr, Bazarr,
Overseerr / Jellyseerr, Tautulli, Jellyfin, Emby, Plex, qBittorrent
and SABnzbd - and routes every request through the right URL whether
you're on the home Wi-Fi or out in the world.

> **Status:** early development. Nothing is shippable yet.

## Why

[LunaSea][lunasea] (Flutter, GPL-3) was archived in 2024 and the niche is
open. Atrium picks up that space with a modern Flutter codebase, a focus
on multi-instance setups, and first-class handling of split local /
external URLs.

## Highlights

- **Multi-instance per service.** Run two Sonarrs, three qBits, whatever
  - every instance is a first-class profile entry.
- **Dual-URL routing.** Every instance has a LAN URL and a WAN URL. The
  app probes the LAN URL with a short timeout, caches the verdict per
  network, and falls back to WAN. You can pin Force-Local or
  Force-External per instance.
- **Hardware-backed credentials.** API keys live in the Android Keystore
  via `flutter_secure_storage`. Optional biometric unlock on launch.
- **F-Droid first.** Reproducible build; no proprietary blobs as hard
  deps. Google Cast support ships as a separate Play flavor.

## Services

| Service                | Status   |
| ---------------------- | -------- |
| Sonarr                 | planned  |
| Radarr                 | planned  |
| Prowlarr               | planned  |
| Bazarr                 | planned  |
| Overseerr / Jellyseerr | planned  |
| Tautulli               | planned  |
| Jellyfin               | planned  |
| Emby                   | planned  |
| Plex                   | planned  |
| qBittorrent            | planned  |
| SABnzbd                | planned  |

## Build

Requires Flutter `^3.27` and Dart `^3.6` (pub workspaces).

```sh
flutter pub get
flutter run -d <device>
```

Code-generation step (run after edits to any freezed / json_serializable
model). To run code generation for a specific package, navigate to that package's directory and run:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Alternatively, to run code generation for all packages in the workspace from the repository root, run:

```sh
dart run tool/build_all.dart
```

## Repo layout

```
app/                     Flutter application - the APK target
packages/                Cross-service infrastructure
  core_models/           Domain models (Profile, Instance, ServiceKind)
  core_storage/          Secure storage, Hive boxes, biometric unlock
  core_networking/       Dio factory, dual-URL resolver
  core_profile/          Profile CRUD, providers, import/export
  core_ui/               Material 3 theme + shared widgets
  core_router/           GoRouter setup
services/                One feature package per integrated service
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution guide.

## License

[GPL-3.0-or-later](LICENSE) - the same license as Sonarr, Radarr,
Jellyfin, qBittorrent, and LunaSea.

[lunasea]: https://github.com/JagandeepBrar/LunaSea
