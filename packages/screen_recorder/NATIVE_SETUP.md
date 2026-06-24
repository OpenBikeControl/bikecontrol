# screen_recorder — native backend setup & status

Video-only screen recording. Dart spine + Android are done and tested. The three native
backends below were implemented on the `feat/screen-recording` branch; macOS and the iOS
plugin compile here, Windows and the iOS extension target need your machines.

## Status

| Platform | Backend | Verified |
| --- | --- | --- |
| Android | `flutter_screen_recording` + `gal` (in `lib/services/.../android_screen_recorder.dart`) | ✅ builds APK, tested |
| macOS | ScreenCaptureKit → AVAssetWriter (`macos/Classes/`) | ✅ `flutter build macos` passes — runtime (TCC + capture) still needs a Mac |
| iOS | ReplayKit broadcast: plugin picker bridge + Broadcast Upload Extension | ⚠️ plugin compiles (`flutter build ios` passes); **extension target needs Xcode wiring** |
| Windows | Windows.Graphics.Capture + Media Foundation (`windows/`) | ❌ **never compiled — build on Windows and iterate** |

## macOS — remaining
- Runtime test on a Mac: bind a key to "Record Screen", grant the Screen Recording TCC prompt (may need an app relaunch), record, confirm an mp4 in `~/Movies/BikeControl/`.
- If the App Sandbox blocks writing to `~/Movies`, fall back to an `NSOpenPanel`-selected folder or the app container's Movies dir (entitlement `com.apple.security.assets.movies.read-write` is already added).

## iOS — remaining (manual Xcode + portal, can't be scripted)
Identifiers (derived from the real app bundle id `de.jonasbark.swiftcontrol.darwin`):
- App Group: `group.de.jonasbark.swiftcontrol.darwin`
- Extension bundle id: `de.jonasbark.swiftcontrol.darwin.ScreenRecordBroadcast`

Steps:
1. **Apple Developer portal:** create App Group `group.de.jonasbark.swiftcontrol.darwin`; enable it on both the app and the extension identifiers.
2. **Xcode:** File ▸ New ▸ Target ▸ Broadcast Upload Extension, name `ScreenRecordBroadcast`, bundle id `de.jonasbark.swiftcontrol.darwin.ScreenRecordBroadcast`, **uncheck** "Include UI Extension". Replace the generated `SampleHandler.swift` with the repo's `ios/ScreenRecordBroadcast/SampleHandler.swift` (and use the repo's `Info.plist`).
3. **Signing & Capabilities:** add the App Groups capability (checked) to BOTH the Runner and the extension targets; set the team/provisioning on the extension.
4. Verify the `preferredExtension` string in `packages/screen_recorder/ios/Classes/ScreenRecorderPlugin.swift` matches the extension bundle id.
5. Device test: bind a key, tap **Start Broadcast** on the system sheet (one unavoidable tap), switch to a game, stop, confirm the mp4 lands in Photos.
- **Known refinement:** `stop()` reads `lastRecordingPath` from the App Group right after posting the stop Darwin notification — the extension may not have finished writing yet, so it can return `nil` on the first call. Add a short poll (e.g. up to 2 s at 100 ms) for the path / a "finished" flag before returning. Verify timing on-device.

## Windows — remaining (build + iterate, never compiled)
1. `flutter build windows --debug` — expect compile iteration on C++/WinRT headers and `windowsapp.lib`.
2. The `FrameArrived` D3D→Media Foundation path has `// VERIFY on Windows:` markers at the 5 likely trouble points (stride/orientation, even dimensions, thread safety, QPC, BGRA vs ARGB). Record 5 s, confirm a playable mp4; if upside-down, negate `MF_MT_DEFAULT_STRIDE`; if colors swapped, try `MFVideoFormat_ARGB32`.
3. Windows N/KN editions need the Media Feature Pack for the H.264 MFT — surface a message if `MFCreateSinkWriterFromURL` fails.
4. After `flutter pub run msix:create`, confirm `<uap:Capability Name="videosLibrary" />` is in the generated AppxManifest (added via `msix_config.capabilities`).

## Plugin pubspec note
`pubspec.yaml` now declares ios/macos/windows. If you ever need to temporarily disable a platform whose native code doesn't yet build, remove just that entry (declaring a platform with no/broken native code breaks that platform's plugin registrant — this was the original cross-platform-build trap).
