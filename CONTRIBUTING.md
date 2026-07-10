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

Generated files are gitignored. You can run this **from inside the package
directory** after pulling any change that touches a `models/` file in that specific package, or you can run it for **all packages in the workspace** from the repository root using the helper script:

```sh
dart run tool/build_all.dart
```

## Navigation rule (important)

The app shell is a GoRouter `StatefulShellRoute`: every bottom-nav tab has
its own branch navigator that GoRouter rebuilds declaratively. A page pushed
imperatively onto a branch navigator is not in GoRouter's route table, so
the next shell rebuild silently removes it - the screen opens, then
vanishes. It will look fine in quick testing and break later.

So: never call `Navigator.of(context).push(...)` directly. Use the shared
helper from `core_ui`, which targets the root navigator:

```dart
pushScreen<void>(context, MyDetailScreen(...));
```

For dialogs, sheets, and search pages the same rule applies via flags:
`showDialog` already defaults to the root navigator; pass
`useRootNavigator: true` to `showModalBottomSheet` and `showSearch`.

## Adding a service

1. Create a new package under `services/` matching the existing layout
   (see `service_sonarr/` as the canonical template).
2. Register it in the root `pubspec.yaml` `workspace:` list.
3. Add a `ServiceKind` enum value in `packages/core_models/`.
4. Wire it into the dashboard registry in `packages/core_ui/`.
5. Add the package as a dependency in `app/pubspec.yaml`.

## Style

The repo enforces `analysis_options.yaml` at the root - `flutter analyze`
must report **No issues found** on every PR. Notable rules: single quotes,
trailing commas, `prefer_const_*`, no `print` (use a logger),
`sort_pub_dependencies`.

**Do not run repo-wide `dart format`.** Dart's newer "tall" formatter is
deliberately incompatible with the `require_trailing_commas` lint this
repo enforces - a whole-tree format adds hundreds of analyze issues and
buries your actual change in noise. Format only the lines you touch, in
the existing style of the file.

**Dependencies need a check before they land.** Atrium targets F-Droid:
every dependency must be FOSS-licensed and must not fetch anything from
the network at runtime. Mention any new dependency in the PR description
so it can be vetted.

## Commit / PR

Conventional Commits style is preferred but not enforced:

```
feat(service_sonarr): add manual search screen
fix(core_networking): retry on connection-reset
```

Open PRs against `development` (the default branch). `main` only receives
merges from `development` at stable milestones. Squash-merge is the default.

### Fork Synchronization & Feature Branch Workflow

Since PRs are squash-merged, your fork's `development` branch will diverge from upstream after a merge. To avoid merge conflict issues, follow this workflow:

1. **Add the upstream remote** (do this once):
   ```sh
   git remote add upstream https://github.com/retransmit/Atrium.git
   ```

2. **Sync your local `development` branch** before starting any new work:
   ```sh
   git fetch upstream
   git checkout development
   git merge --ff-only upstream/development
   git push origin development
   ```
   *Note: If your branch has already diverged due to a squash-merge, you can reset it to align with upstream:*
   ```sh
   git reset --hard upstream/development
   git push origin development --force
   ```

3. **Create a feature branch** off the fresh `development` branch for your changes:
   ```sh
   git checkout -b my-feature-branch
   ```
   Always commit your changes to and open PRs from feature branches rather than your fork's `development` branch. This keeps your local commits organized and prevents unrelated commits from leaking into your PRs.

## License

By contributing you agree your contribution is licensed under
[GPL-3.0-or-later](LICENSE).
