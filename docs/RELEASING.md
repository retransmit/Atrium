# Releasing

Releases are built by CI and signed by hand. The keystore never leaves the
maintainer's machine, and it never goes into GitHub secrets.

The APKs published here are the reference F-Droid rebuilds and verifies against,
so this process is more constrained than it looks. Read [Why it is like
this](#why-it-is-like-this) before changing any of it.

## Cutting a release

1. **Bump the version.** `app/pubspec.yaml` (`version: X.Y.Z+N`), the version
   string in `app/lib/src/screens/settings_screen.dart`, a new entry in
   `app/lib/src/screens/changelog_screen.dart`, and a new
   `fastlane/metadata/android/en-US/changelogs/<N>.txt` named for the build
   number, not the version.

2. **Verify.** `flutter analyze` and `flutter test` from `app/`, both clean.

3. **Merge to `main`** and tag it there:

   ```sh
   git tag vX.Y.Z origin/main
   git push origin vX.Y.Z
   ```

   Pushing the tag triggers `.github/workflows/release.yml`, which builds the
   three split APKs **unsigned** at `/tmp/build` and uploads them as the
   `unsigned-apks` artifact.

4. **Download the artifact** from the workflow run.

5. **Sign each APK locally.** Use build-tools **34**, not the newest one:
   apksigner 35 and later write APKs that F-Droid's `apksigcopier` cannot
   verify, which silently breaks reproducible builds.

   ```sh
   # apksigner from build-tools 34 in the Android SDK; KEYSTORE is wherever you
   # keep the release key, which is not in this repository.
   for abi in arm64-v8a armeabi-v7a x86_64; do
     apksigner sign --ks "$KEYSTORE" --ks-key-alias atrium \
       --out "signed/app-$abi-release.apk" "unsigned/app-$abi-release.apk"
   done
   ```

6. **Check what you signed** before it goes anywhere:

   ```sh
   apksigner verify --print-certs signed/app-arm64-v8a-release.apk
   ```

   It must report `CN=Atrium, O=Atrium` and SHA-256
   `5ebad1ff2f9cdc63f28b364addf9e858330db26909d9eba8dfbccb998de37351`. A
   different fingerprint means the wrong key, and shipping it would break
   updates for everyone.

7. **Publish** the release with all three signed APKs attached. The asset names
   have to keep matching the `binary:` URLs in fdroiddata's
   `metadata/app.atrium.yml`, or F-Droid cannot find them.

8. **Bump fdroiddata.** `versionName`, `versionCode`, `commit` (a full commit
   hash, not a tag), `CurrentVersion` and `CurrentVersionCode` in each of the
   three build blocks. Version codes are `build number * 10 + abi`, where abi is
   1 armeabi-v7a, 2 arm64-v8a, 3 x86_64: see the override at the foot of
   `app/android/app/build.gradle.kts`, which must stay in step with the
   `VercodeOperation` in their metadata.

## Why it is like this

**The build path is part of the APK.** Flutter writes the absolute path of
`.dart_tool/flutter_build/dart_plugin_registrant.dart` into the AOT snapshot as
a string constant. Build at a different path and the bytes differ. There is no
Dart equivalent of `--remap-path-prefix`; matching the path is the only known
fix. This is why the workflow copies the checkout to `/tmp/build`, and why
fdroiddata's recipe moves its checkout to exactly the same place. **Changing one
without the other silently breaks verification.**

**Which is also why releases cannot be built by hand any more.** A local build
on another OS, or at any other path, can never match a Debian build at
`/tmp/build`. Every published APK has to come out of the workflow.

**The APKs are unsigned until step 5 on purpose.** F-Droid rebuilds the app from
source on their own machines, then copies the signature off the published APK
onto their build and asks apksigner to verify it. That only works if their build
carries no signature, which is why `app/android/app/build.gradle.kts` attaches
no signing config when `key.properties` is absent. It also means the keystore is
only ever needed on one machine.

**Everything is pinned.** Flutter, JDK and NDK versions all change the emitted
bytes. The workflow pins them and fdroiddata's recipe pins the same ones. Bump
them together or not at all.

## If verification fails

F-Droid's CI runs the comparison on every push to the merge request, so iterate
there rather than by cutting releases. The usual suspects, roughly in order:

- the build path drifted between the workflow and the recipe
- a toolchain version differs (Flutter, JDK, NDK, build-tools)
- the APK was signed with apksigner 35 or newer
- the wrong artifact shape: F-Droid must build the same split as the `binary:`
  URL points at, never a universal APK against split references
