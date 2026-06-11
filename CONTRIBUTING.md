# Contributing

Thanks for your interest. This is an early-stage project; the surface area
moves fast. A few notes before you dive in.

## Repo layout

```
app/                     Flutter application - what gets built into an APK
packages/                Cross-service infrastructure
  core_models/           Domain models (Profile, Instance, ServiceKind)
  core_storage/          Secure storage, Hive boxes, biometric unlock
  core_networking/       Dio factory, dual-URL resolver, retry/auth interceptors
  core_profile/          Profile CRUD, Riverpod providers, import/export
  core_ui/               Material 3 theme, design tokens, shared widgets
  core_router/           GoRouter setup
services/                One feature package per integrated service
  service_sonarr/        Sonarr v3 API client + UI
  service_radarr/        Radarr v3 API client + UI
  ...
```

Each `service_*` package depends only on `core_*` packages, never on another
`service_*` package. That keeps services independently buildable and testable.

## Setup

```sh
flutter pub get          # resolves the whole workspace
flutter analyze          # static analysis
flutter test             # unit tests across the workspace
```

For each package, generated code (`*.g.dart`, `*.freezed.dart`) is produced by:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Adding a service

1. Create a new package under `services/` matching the existing layout
   (see `service_sonarr/` as the canonical template).
2. Register it in the root `pubspec.yaml` `workspace:` list.
3. Add a `ServiceKind` enum value in `packages/core_models/`.
4. Wire it into the dashboard registry in `packages/core_ui/`.
5. Add the package as a dependency in `app/pubspec.yaml`.

## Style

The repo enforces `analysis_options.yaml` at the root - `flutter analyze` must
pass. Notable rules: single quotes, trailing commas, `prefer_const_*`,
no `print` (use a logger), `sort_pub_dependencies`.

## Commit / PR

Conventional Commits style is preferred but not enforced:

```
feat(service_sonarr): add manual search screen
fix(core_networking): retry on connection-reset
```

Open PRs against `main`. Squash-merge is the default.

## License

By contributing you agree your contribution is licensed under
[GPL-3.0-or-later](LICENSE).
