# Trainer Feedback Form — Design

Date: 2026-04-19
Branch at time of writing: `feat/proxy-device-details-page`

## Goal

Let authenticated BikeControl users send structured feedback about how their
smart trainer works with the app. The payload combines free-text feedback, an
optional rating, and diagnostic fields (trainer BLE identity, active control
mode, virtual-shifting config, gear ratios, app environment) so we can triage
compatibility issues per-trainer.

The backend endpoint `POST /functions/v1/submit-trainer-feedback` is already
in place. Only `user_feedback` (required, non-empty) and `user_rating`
(optional, radio select) are user-editable; every other field is derived from
existing app state or freshly read from the BLE Device Information /
Generic Access services.

## Entry point

In `lib/pages/trainer.dart`, below the existing `TrainerFeatures()` widget, add
a new `FeatureWidget`-styled card titled "Send Trainer Feedback".

Visibility: **only when** `core.connection.proxyDevices.isNotEmpty`. Feedback
without a connected trainer has no diagnostic value; hide the entry rather
than render an empty form.

The card rebuilds on `core.connection.connectionStream` events so it appears
and disappears as the user connects/disconnects trainers.

Tapping the card pushes `TrainerFeedbackPage(device: proxyDevice)`.

## TrainerFeedbackPage

New file: `lib/pages/trainer_feedback.dart`.

Scaffold mirrors `ProxyDeviceDetailsPage`: `AppBar` with back button, centered
`maxWidth: 800` scrollable column.

### Auth gate

If `core.supabase.auth.currentUser == null`, render a single card with an icon,
the copy "Sign in to send feedback", and a button that pushes
`LoginPage(pushed: true)`. Listen to `core.supabase.auth.onAuthStateChange`;
when the user signs in, re-render the page so the form replaces the gate.

### Form sections (when signed in)

1. **Rating** — `RadioGroup<TrainerFeedbackRating>` with three `RadioCard`s
   arranged in a row: *Works*, *Needs adjustment*, *Doesn't work at all*.
   Selection is optional.

2. **Feedback** — multi-line text input (`TextArea` equivalent in
   `shadcn_flutter`: `TextField(...).withMinLines(4)`). Required.
   Submit button disabled while the trimmed value is empty.

3. **Diagnostic data** — read-only preview card with label/value rows
   (reuse `SettingTile` where appropriate, or a plain `Row` list). Rows:

   | Label | Source |
   |---|---|
   | Bluetooth name | computed (see Data Sources) |
   | Manufacturer | `bluetoothDevice.manufacturerName` |
   | Firmware | `bluetoothDevice.firmwareVersion` |
   | Supports virtual shifting | `true` for proxy devices (hard-coded) |
   | Control mode | `SIM` or `ERG` |
   | Virtual shifting mode | `target_power` / `track_resistance` / `basic` |
   | Grade smoothing | `true` / `false` |
   | Gear ratios | comma-separated list, wrapped |
   | Trainer app | `core.settings.getTrainerApp()?.name` |
   | App version | version + optional Shorebird patch |
   | App platform | `ios` / `android` / `macos` / `windows` / `linux` / `web` |

   Rows with a `null` value render as dimmed "Not available" text so the user
   can see what is or isn't being sent.

4. **Submit** — full-width primary button "Send feedback".
   - Disabled when feedback is empty or a request is in flight.
   - Shows a `SmallProgressIndicator` while sending.
   - On success: green toast "Thanks for your feedback!" and pop the page.
   - On API error: red toast with `body['error']` if present, else
     "Failed to submit feedback".

## Data sources

Mapping from API field → source:

| API field | Source |
|---|---|
| `user_feedback` | form input, trimmed; required non-empty |
| `user_rating` | `RadioGroup` value → `"works"` / `"needs adjustment"` / `"does not work at all"`; omitted if unset |
| `bluetooth_name` | `"${deviceName} (HW: ${hardwareRevision})"` when both present; else whichever is available; else `proxyDevice.name` |
| `hardware_manufacturer` | `bluetoothDevice.manufacturerName` (new BLE read, see below) |
| `firmware_version` | `bluetoothDevice.firmwareVersion` (already read today) |
| `trainer_supports_virtual_shifting` | `true` |
| `trainer_control_mode` | `FitnessBikeDefinition.trainerMode.value` — mapped: `ergMode → "ERG"`, everything else → `"SIM"` |
| `virtual_shifting_mode` | `core.settings.getProxyVirtualShiftingMode()` mapped explicitly: `targetPower` → `"target_power"`, `trackResistance` → `"track_resistance"`, `basicResistance` → `"basic"` |
| `grade_smoothing` | `core.settings.getProxyGradeSmoothing()` |
| `gear_ratios` | `core.settings.getProxyGearRatios() ?? FitnessBikeDefinition.defaultGearRatios` |
| `app_version` | `packageInfo.version` + `"+${shorebirdPatch.number}"` when available (same format as `lib/widgets/title.dart:202`) |
| `app_platform` | `kIsWeb ? "web" : Platform.operatingSystem` |
| `trainer_app` | `core.settings.getTrainerApp()?.name`; capped at 100 chars |

Fields whose source is `null` are omitted from the JSON body so they default
to `null` server-side rather than being sent as explicit nulls (keeps the
payload small and matches the server's "optional field" contract).

## New BLE reads in `bluetooth_device.dart`

Add three `String?` fields on `BluetoothDevice`:

- `deviceName` — char `0x2A00`, service `0x1800` (Generic Access)
- `hardwareRevision` — char `0x2A27`, service `0x180A` (Device Information)
- `manufacturerName` — char `0x2A29`, service `0x180A` (Device Information)

Add constants in `BleUuid`:

- `GENERIC_ACCESS_SERVICE_UUID = "00001800-0000-1000-8000-00805f9b34fb"`
- `GENERIC_ACCESS_CHARACTERISTIC_DEVICE_NAME = "00002a00-0000-1000-8000-00805f9b34fb"`
- `DEVICE_INFORMATION_CHARACTERISTIC_HARDWARE_REVISION = "00002a27-0000-1000-8000-00805f9b34fb"`
- `DEVICE_INFORMATION_CHARACTERISTIC_MANUFACTURER_NAME = "00002a29-0000-1000-8000-00805f9b34fb"`

In `BluetoothDevice.connect()`, alongside the existing firmware read, read all
three characteristics when present. Each read is wrapped in its own
`try/catch` so a single missing characteristic on a quirky trainer does not
abort the whole connect flow. Decode bytes with `String.fromCharCodes`,
trimmed. Call `core.connection.signalChange(this)` once after all reads, not
per-read, to avoid UI thrash.

## Submission: `TrainerFeedbackService`

New file: `lib/services/trainer_feedback_service.dart`.

```dart
class TrainerFeedbackService {
  Future<void> submit(TrainerFeedbackPayload payload) async {
    final response = await core.supabase.functions.invoke(
      'submit-trainer-feedback',
      body: payload.toJson(),
    );
    if (response.status < 200 || response.status >= 300) {
      throw TrainerFeedbackException(_extractError(response.data));
    }
  }
}
```

`TrainerFeedbackPayload`:

- Plain Dart class, fields match the API one-to-one.
- `toJson()` drops keys whose value is `null`, and drops empty
  `gear_ratios` lists, so we never send empty arrays.
- Enum rating mapped via a small extension.

`TrainerFeedbackException` is a plain class wrapping a user-facing `String`
message. The page catches it and surfaces the message via the existing
`buildToast()` helper.

## Error handling

- Empty `user_feedback` after trim → submit button disabled; no request sent.
- 400/401/500 from the endpoint → red toast with the server's `error` string
  when present, otherwise "Failed to submit feedback".
- Any other exception (network, decode, etc.) → same generic toast path.
- No retry, no offline queue.

## Out of scope

- Localization: strings are hard-coded English for now. If/when the user
  requests i18n, move them into `intl_en.arb` et al.
- Analytics / telemetry on form interaction.
- Editing or resubmitting a previously submitted feedback.
- Listing past submissions in-app.
- Exposing the feedback form outside the Trainer page (e.g. settings,
  device details, overview).

## Files touched

New:

- `lib/pages/trainer_feedback.dart`
- `lib/services/trainer_feedback_service.dart` (and `TrainerFeedbackPayload`)

Edited:

- `lib/pages/trainer.dart` — entry card below `TrainerFeatures`, gated on
  `proxyDevices.isNotEmpty`.
- `lib/bluetooth/devices/bluetooth_device.dart` — new fields + reads.
- `lib/bluetooth/ble_uuid.dart` (or equivalent) — new UUID constants.
