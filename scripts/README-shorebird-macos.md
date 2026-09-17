# Shorebird OTA patches for the macOS App Store build

Shorebird cannot patch a Mac App Store build out of the box: Apple re-processes the
submitted `.pkg` before it reaches users, so the installed binary no longer matches the
`macos/app` artifact Shorebird captured at release time. A patch built from that artifact
downloads but fails to load at runtime.

Upstream tracking issue: [shorebirdtech/shorebird#3223](https://github.com/shorebirdtech/shorebird/issues/3223)
(still open). Our own history: [OpenBikeControl/bikecontrol#143](https://github.com/OpenBikeControl/bikecontrol/issues/143).

`scripts/shorebird_mas_patch.rb` (vendored from
[this gist](https://gist.github.com/lukemmtt/d52a729010f30c74d004ecd169805dca)) works around
this by registering the **store-delivered** `.app` as a second release artifact
(`macos/app_mas_contents`) and pointing `shorebird patch` at it.

## Prerequisites

1. **The macOS build ships through Shorebird.** `.github/workflows/build.yml` runs
   `shorebird release macos` (not a plain `flutter build macos`) so a Shorebird release
   record exists for `x.y.z+build` and the store binary contains the updater. Without this
   there is nothing to patch.
2. **That build is live** on the Mac App Store (`READY_FOR_SALE`) for the same version.
3. A Mac signed into the App Store with an Apple ID that can download BikeControl.
4. App Store Connect API key credentials (the same key CI uses for uploads).
5. Shorebird auth: either `shorebird login` locally, or a `SHOREBIRD_TOKEN` API key
   (`sb_api_...`) from https://console.shorebird.dev. Legacy `shorebird login --ci`
   tokens still work but are deprecated.
6. `mas` CLI (`brew install mas`) if you want the script to download/update the live app for
   you. Recent `mas` needs `sudo` for install/update.

> **`register-baseline` cannot run in CI.** It needs a Mac logged into the App Store with the
> live app downloaded, so it is a local step Jonas runs once per macOS release. Only `patch`
> is CI-friendly (see `.github/workflows/patch.yml`, `build_mac` input, off by default).

## Environment

Run the script from the repo root (next to `pubspec.yaml` / `shorebird.yaml`). Set:

```bash
export APP_NAME="BikeControl"                 # default; /Applications/BikeControl.app
export APP_BUNDLE_ID="de.jonasbark.swiftPlay" # default
export ASC_APP_ID="<numeric Mac app id>"      # App Store Connect app id for the macOS app
export ASC_KEY_ID="<APPSTORE_API_KEY>"        # same key id CI uses
export ASC_ISSUER_ID="<APPSTORE_API_ISSUER_ID>"
export ASC_API_KEY_PATH="$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8"
# Local Shorebird auth via `shorebird login` is enough; otherwise:
# export SHOREBIRD_TOKEN="sb_api_..."    # API key from console.shorebird.dev
```

Optional:

```bash
export MACOS_APP_PATH="/Applications/BikeControl.app"   # default
export MAS_ARTIFACT_ARCH="app_mas_contents"             # bump to _v2 if a stale one exists
export MAS_UPDATE_COMMAND="sudo mas update --force --verbose $ASC_APP_ID"
export SHOREBIRD_PATCH_ARGS="--allow-asset-diffs --allow-native-diffs --split-debug-info=symbols"
```

Treat `SHOREBIRD_TOKEN` and the `.p8` key as secrets. Do not commit them.

## Usage

```bash
# Once per live Mac App Store release, after it is READY_FOR_SALE (local, needs App Store login):
ruby scripts/shorebird_mas_patch.rb register-baseline

# Read-only check that the MAS baseline artifact exists for the target release:
ruby scripts/shorebird_mas_patch.rb status

# Whenever you want to ship a macOS OTA patch for that release:
ruby scripts/shorebird_mas_patch.rb patch
```

`RELEASE_VERSION=x.y.z+build` targets a specific release; if omitted the script uses the
latest `READY_FOR_SALE` Mac App Store version. Set `DRY_RUN=true` to validate without
uploading (`register-baseline`) or without shipping (`patch`).

## How the patch step works

`shorebird patch` hardcodes the macOS release artifact arch as `app`. During `patch` the
script temporarily edits the local CLI source
(`~/.shorebird/packages/shorebird_cli/lib/src/commands/patch/macos_patcher.dart`) so
`primaryReleaseArtifactArch` honours `SHOREBIRD_MACOS_RELEASE_ARTIFACT_ARCH`, runs the patch
against `macos/app_mas_contents`, then restores the file and clears the CLI cache stamp.

Because it edits Shorebird CLI internals, **pin the Shorebird version** you use for macOS
patches — a CLI upgrade can change that file's shape and the script will refuse to patch with
a clear error rather than corrupt it.

## Operational notes

- If `register-baseline` finds an existing artifact with a different hash, register under a
  new arch (`MAS_ARTIFACT_ARCH=app_mas_contents_v2`) and pass the same value to `patch`.
- If the inner Mach-O hashes (`App.framework/App` or `Contents/MacOS/<exe>`) change between
  captures of the *same* version/build, stop and investigate — the binary baseline itself
  moved, not just the zip wrapper.
- Re-run `register-baseline` for every new macOS store release before its first patch.
- App Store Connect keeps the marketing version exactly as it was typed there (`6.6`),
  while Shorebird and the app bundle use the three-part pubspec version (`6.6.0`). The
  script matches those spellings semantically and then uses Shorebird's, so
  `RELEASE_VERSION` accepts either.
