# TrainerActivity Widget Extension — Manual Xcode Setup

The source files in this directory are ready. You must wire them into an Xcode
Widget Extension target before the iOS build will succeed. These steps only need
to be done once.

---

## Steps

### 1. Open the workspace

Open `ios/Runner.xcworkspace` in Xcode (not the `.xcodeproj`).

### 2. Add a new Widget Extension target

- Menu: **File → New → Target…**
- Platform: **iOS**
- Template: **Widget Extension**
- Click **Next**

### 3. Configure the target

- **Product Name:** `TrainerActivity`
- **Include Live Activity:** ✅ checked
- **Include Configuration Intent:** ☐ unchecked
- Click **Finish**
- When prompted to activate the scheme, click **Activate**

### 4. Replace auto-generated files

Xcode will generate placeholder Swift files inside the new target group. Replace
them with the files already present in `ios/TrainerActivity/`:

1. In the Project Navigator, expand the **TrainerActivity** group Xcode created.
2. Delete the auto-generated Swift files (move to Trash).
3. Drag the following files from Finder (`ios/TrainerActivity/`) into the
   **TrainerActivity** group in Xcode, ensuring they are added to the
   **TrainerActivity** target (not Runner):
   - `TrainerActivity.swift`
   - `TrainerActivityAttributes.swift`
4. When prompted, choose **Copy items if needed** → uncheck it (the files are
   already in place), and make sure **Add to targets: TrainerActivity** is
   ticked.

> Alternatively: select the auto-generated files in Xcode, use
> **File → Show in Finder**, and overwrite them with the repo copies.

### 5. Signing & Capabilities

Select the **TrainerActivity** target → **Signing & Capabilities** tab:

- **Team:** set to the same Team as the Runner target.
- Click **+ Capability** → add **App Groups**.
- Tick `group.de.jonasbark.swiftcontrol.overlay` (create it if it does not yet
  appear; it must match the host app's entitlements).

The `TrainerActivity.entitlements` file in this directory already declares this
App Group — Xcode will link it automatically when you set up the capability.

### 6. Deployment Target

Select the **TrainerActivity** target → **General** tab → set
**Minimum Deployments** (Deployment Target) to **iOS 16.2**.

Live Activities require iOS 16.1+; 16.2 is the safe minimum.

### 7. Verify the Info.plist

Xcode may auto-assign the `Info.plist` to the target's build settings. Confirm
that **Build Settings → Info.plist File** points to
`TrainerActivity/Info.plist`. If Xcode created its own copy inside the project,
remove it and redirect the setting to the file in this directory.

### 8. Build

```bash
flutter build ios --debug --no-codesign
```

Both the **Runner** and **TrainerActivity** targets should compile without
errors. If Xcode reports missing `ActivityKit` or `WidgetKit` symbols, confirm
the Deployment Target is ≥ iOS 16.2 and that **Frameworks** are set to
**Link Binary With Libraries** in the TrainerActivity target's Build Phases.

---

## File reference

| File | Purpose |
|---|---|
| `TrainerActivity.swift` | Widget entry point (`@main`). Renders Lock Screen banner and Dynamic Island. |
| `TrainerActivityAttributes.swift` | `ActivityAttributes` struct shared between the extension and the host app. |
| `Info.plist` | Extension bundle metadata. |
| `TrainerActivity.entitlements` | Declares the App Group used for host ↔ extension data sharing. |
