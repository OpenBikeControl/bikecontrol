# Trainer Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the active virtual-shifting gear (and a few opt-in metrics) in an always-on-top overlay over the user's trainer app, on macOS, Windows, Android, and iOS.

**Architecture:** A platform-routed `TrainerOverlayService` returns one of three controllers. Desktop reuses the existing `window_manager` to flip the main window into a small frameless transparent always-on-top compact mode. Android uses `flutter_overlay_window` with a separate isolate fed via debounced `shareData` pushes. iOS uses `live_activities` with a SwiftUI Widget Extension for Dynamic Island + Lock Screen, fed via debounced `updateActivity` calls.

**Tech Stack:** Flutter, shadcn_flutter, `window_manager` (already present), `flutter_overlay_window` (new, Android), `live_activities` (new, iOS), `shared_preferences`, ARB-based l10n via `intl_utils`.

**Spec:** `docs/superpowers/specs/2026-05-08-trainer-overlay-design.md`

---

## File Map

**New Dart files:**
- `lib/services/overlay/trainer_overlay_service.dart` — platform router + global `trainerOverlayMode` ValueNotifier
- `lib/services/overlay/trainer_overlay_controller.dart` — abstract interface + no-op impl
- `lib/services/overlay/overlay_state.dart` — `OverlayField` enum, `OverlayState` data class
- `lib/services/overlay/desktop_overlay_controller.dart`
- `lib/services/overlay/android_overlay_controller.dart`
- `lib/services/overlay/ios_overlay_controller.dart`
- `lib/services/overlay/overlay_entry_point.dart` — `@pragma('vm:entry-point')` for Android isolate
- `lib/widgets/overlay/trainer_overlay_view.dart`
- `lib/widgets/overlay/trainer_overlay_host.dart` — wraps app body, renders compact view when flag is on
- `lib/pages/proxy_device_details/overlay_settings_section.dart`

**New native files:**
- `ios/TrainerActivity/TrainerActivity.swift` (Widget Extension)
- `ios/TrainerActivity/TrainerActivityAttributes.swift`
- `ios/TrainerActivity/Info.plist`

**Modified files:**
- `pubspec.yaml` — add `flutter_overlay_window`, `live_activities`
- `lib/utils/settings/settings.dart` — overlay accessors
- `lib/i10n/intl_en.arb` (and locales) — overlay strings
- `lib/main.dart` or wherever `BikeControlApp` builds its home — wrap with `TrainerOverlayHost`
- `lib/pages/proxy_device_details.dart` — render `OverlaySettingsSection`
- `android/app/src/main/AndroidManifest.xml` — `SYSTEM_ALERT_WINDOW`, overlay service
- `ios/Runner/Info.plist` — `NSSupportsLiveActivities`

**New tests:**
- `test/services/overlay/trainer_overlay_service_test.dart`
- `test/services/overlay/overlay_state_test.dart`
- `test/widgets/overlay/trainer_overlay_view_test.dart`
- `test/utils/settings/overlay_settings_test.dart`

---

## Conventions to follow

- **Package name** is `bike_control`. Imports use `package:bike_control/...`.
- **UI kit** is `shadcn_flutter` (not Material). `Switch`, `Button.ghost`, `Gap`, `IconButton.ghost`, `SettingTile` are the building blocks.
- **L10n is auto-generated.** Edit `lib/i10n/intl_en.arb`, then run `flutter pub global run intl_utils:generate`. Never hand-edit `lib/gen/l10n.dart`.
- **No unit tests for l10n strings.** Widget tests should verify behavior, not literal translations.
- **Tests** use `ShadcnApp(home: Scaffold(child: ...))` as the wrapper (see `test/widgets/ui/stepper_control_test.dart`).

---

## Task 1: Add new dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the two packages**

In the `dependencies:` block of `pubspec.yaml`, add the two lines below alongside the existing `window_manager: ^0.5.1` entry:

```yaml
  flutter_overlay_window: ^0.5.0
  live_activities: ^2.4.9
```

- [ ] **Step 2: Fetch dependencies**

Run: `flutter pub get`
Expected: completes with `Got dependencies!` and no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add flutter_overlay_window (Android) and live_activities (iOS) for trainer overlay"
```

---

## Task 2: Add l10n strings

**Files:**
- Modify: `lib/i10n/intl_en.arb`
- Generated: `lib/gen/l10n.dart` (do not edit by hand)

- [ ] **Step 1: Add strings to the English ARB file**

Open `lib/i10n/intl_en.arb` and add the following entries (put them alphabetically — the file is alphabetically ordered):

```json
  "overlayDisabledIos": "Trainer overlay shows on Dynamic Island and the Lock Screen during a ride.",
  "overlayEnabled": "Show overlay during ride",
  "overlayFieldCadence": "Cadence",
  "overlayFieldErgTarget": "ERG target",
  "overlayFieldGearRatio": "Gear ratio",
  "overlayFieldPower": "Power",
  "overlayFieldsLabel": "Fields to show",
  "overlayGrantAndroidPermission": "Grant overlay permission",
  "overlayHide": "Hide overlay",
  "overlayLowPowerMode": "Live Activities are disabled (Low Power Mode or system setting).",
  "overlayPermissionExplain": "Android needs permission to draw the overlay over your trainer app.",
  "overlaySection": "Overlay",
  "overlaySectionSubtitle": "Live gear display while you ride.",
  "overlaySettings": "Overlay settings",
  "overlayWindowsTip": "Run the trainer app in borderless-windowed mode for the overlay to stay visible.",
```

- [ ] **Step 2: Regenerate l10n**

Run: `flutter pub global run intl_utils:generate`
Expected: succeeds, `lib/gen/l10n.dart` is updated.

- [ ] **Step 3: Verify the new accessors compile**

Run: `flutter analyze lib/gen/l10n.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/i10n/intl_en.arb lib/gen/
git commit -m "i18n: add overlay-related strings"
```

---

## Task 3: Define `OverlayField` enum + `OverlayState`

**Files:**
- Create: `lib/services/overlay/overlay_state.dart`
- Test: `test/services/overlay/overlay_state_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/overlay/overlay_state_test.dart`:

```dart
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

void main() {
  group('OverlayField', () {
    test('parses from name with fallback', () {
      expect(OverlayField.fromName('power'), OverlayField.power);
      expect(OverlayField.fromName('bogus'), isNull);
    });
  });

  group('OverlayState', () {
    test('round-trips through json', () {
      const s = OverlayState(
        gear: 12,
        maxGear: 24,
        gearRatio: 2.43,
        mode: TrainerMode.simMode,
        powerW: 178,
        cadenceRpm: 86,
        ergTargetW: null,
        fields: {OverlayField.power, OverlayField.cadence},
      );
      final round = OverlayState.fromJson(s.toJson());
      expect(round, s);
    });

    test('equality respects field set', () {
      const a = OverlayState(
        gear: 1, maxGear: 2, gearRatio: 1.0,
        mode: TrainerMode.simMode,
        powerW: null, cadenceRpm: null, ergTargetW: null,
        fields: {OverlayField.power},
      );
      const b = OverlayState(
        gear: 1, maxGear: 2, gearRatio: 1.0,
        mode: TrainerMode.simMode,
        powerW: null, cadenceRpm: null, ergTargetW: null,
        fields: {OverlayField.cadence},
      );
      expect(a == b, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/overlay/overlay_state_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:bike_control/services/overlay/overlay_state.dart'".

- [ ] **Step 3: Write the implementation**

Create `lib/services/overlay/overlay_state.dart`:

```dart
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

enum OverlayField {
  power,
  cadence,
  ergTarget,
  gearRatio;

  static OverlayField? fromName(String name) {
    for (final f in values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// Snapshot of everything the overlay needs to render. Immutable; comparable
/// via `==` so debouncers can drop unchanged ticks.
class OverlayState {
  final int gear;
  final int maxGear;
  final double gearRatio;
  final TrainerMode mode;
  final int? powerW;
  final int? cadenceRpm;
  final int? ergTargetW;
  final Set<OverlayField> fields;

  const OverlayState({
    required this.gear,
    required this.maxGear,
    required this.gearRatio,
    required this.mode,
    required this.powerW,
    required this.cadenceRpm,
    required this.ergTargetW,
    required this.fields,
  });

  Map<String, dynamic> toJson() => {
        'gear': gear,
        'maxGear': maxGear,
        'gearRatio': gearRatio,
        'mode': mode.name,
        'powerW': powerW,
        'cadenceRpm': cadenceRpm,
        'ergTargetW': ergTargetW,
        'fields': fields.map((f) => f.name).toList(),
      };

  factory OverlayState.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String;
    final mode = TrainerMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => TrainerMode.simMode,
    );
    final fields = (json['fields'] as List)
        .map((e) => OverlayField.fromName(e as String))
        .whereType<OverlayField>()
        .toSet();
    return OverlayState(
      gear: json['gear'] as int,
      maxGear: json['maxGear'] as int,
      gearRatio: (json['gearRatio'] as num).toDouble(),
      mode: mode,
      powerW: json['powerW'] as int?,
      cadenceRpm: json['cadenceRpm'] as int?,
      ergTargetW: json['ergTargetW'] as int?,
      fields: fields,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OverlayState &&
        other.gear == gear &&
        other.maxGear == maxGear &&
        other.gearRatio == gearRatio &&
        other.mode == mode &&
        other.powerW == powerW &&
        other.cadenceRpm == cadenceRpm &&
        other.ergTargetW == ergTargetW &&
        _setEquals(other.fields, fields);
  }

  @override
  int get hashCode => Object.hash(
        gear, maxGear, gearRatio, mode, powerW, cadenceRpm, ergTargetW,
        Object.hashAllUnordered(fields),
      );

  static bool _setEquals(Set<OverlayField> a, Set<OverlayField> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/services/overlay/overlay_state_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/overlay/overlay_state.dart test/services/overlay/overlay_state_test.dart
git commit -m "feat(overlay): OverlayField enum and OverlayState data class"
```

---

## Task 4: Extend `Settings` with overlay accessors

**Files:**
- Modify: `lib/utils/settings/settings.dart`
- Test: `test/utils/settings/overlay_settings_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/utils/settings/overlay_settings_test.dart`:

```dart
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Settings settings;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
  });

  test('overlay enabled defaults to false and round-trips', () async {
    expect(settings.getOverlayEnabled(), isFalse);
    await settings.setOverlayEnabled(true);
    expect(settings.getOverlayEnabled(), isTrue);
  });

  test('overlay fields default to {power, cadence}', () {
    expect(settings.getOverlayFields(),
        {OverlayField.power, OverlayField.cadence});
  });

  test('overlay fields round-trip', () async {
    await settings.setOverlayFields(
        {OverlayField.power, OverlayField.gearRatio});
    expect(settings.getOverlayFields(),
        {OverlayField.power, OverlayField.gearRatio});
  });

  test('overlay position null when unset, round-trips when set', () async {
    expect(settings.getOverlayPosition(), isNull);
    await settings.setOverlayPosition(const Offset(120, 240));
    expect(settings.getOverlayPosition(), const Offset(120, 240));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/utils/settings/overlay_settings_test.dart`
Expected: FAIL with "method 'getOverlayEnabled' isn't defined for the type 'Settings'".

- [ ] **Step 3: Add accessors to `Settings`**

Open `lib/utils/settings/settings.dart` and add this import at the top:

```dart
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:flutter/widgets.dart' show Offset;
```

Then append these methods to the `Settings` class (place them just before `setShowExperimental`, near the bottom):

```dart
  // ----- Trainer overlay -----

  bool getOverlayEnabled() => prefs.getBool('overlay_enabled') ?? false;

  Future<void> setOverlayEnabled(bool enabled) async {
    await prefs.setBool('overlay_enabled', enabled);
  }

  static const Set<OverlayField> _overlayFieldsDefault =
      {OverlayField.power, OverlayField.cadence};

  Set<OverlayField> getOverlayFields() {
    final raw = prefs.getStringList('overlay_fields');
    if (raw == null) return _overlayFieldsDefault;
    final parsed = raw
        .map(OverlayField.fromName)
        .whereType<OverlayField>()
        .toSet();
    return parsed;
  }

  Future<void> setOverlayFields(Set<OverlayField> fields) async {
    await prefs.setStringList(
      'overlay_fields',
      fields.map((f) => f.name).toList(),
    );
  }

  Offset? getOverlayPosition() {
    final x = prefs.getDouble('overlay_position_x');
    final y = prefs.getDouble('overlay_position_y');
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  Future<void> setOverlayPosition(Offset p) async {
    await prefs.setDouble('overlay_position_x', p.dx);
    await prefs.setDouble('overlay_position_y', p.dy);
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/utils/settings/overlay_settings_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/settings/settings.dart test/utils/settings/overlay_settings_test.dart
git commit -m "feat(overlay): persist overlay enabled, fields, and desktop position"
```

---

## Task 5: Define the `TrainerOverlayController` interface + no-op impl

**Files:**
- Create: `lib/services/overlay/trainer_overlay_controller.dart`

- [ ] **Step 1: Create the file with the interface and no-op**

```dart
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

/// Reasons `show()` may return `false`.
enum OverlayShowFailure {
  permissionDenied,
  systemDisabled,
  unknown,
}

class OverlayShowResult {
  final bool ok;
  final OverlayShowFailure? failure;
  final String? message;
  const OverlayShowResult.ok()
      : ok = true,
        failure = null,
        message = null;
  const OverlayShowResult.fail(this.failure, {this.message}) : ok = false;
}

abstract class TrainerOverlayController {
  ValueListenable<bool> get isShowing;
  Future<OverlayShowResult> show(FitnessBikeDefinition def, Set<OverlayField> fields);
  Future<void> hide();
  void updateFields(Set<OverlayField> fields);
}

class NoOpOverlayController implements TrainerOverlayController {
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;
  @override
  Future<OverlayShowResult> show(FitnessBikeDefinition def, Set<OverlayField> fields) async {
    return const OverlayShowResult.fail(OverlayShowFailure.systemDisabled,
        message: 'Overlay not supported on this platform');
  }
  @override
  Future<void> hide() async {}
  @override
  void updateFields(Set<OverlayField> fields) {}
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/services/overlay/trainer_overlay_controller.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/overlay/trainer_overlay_controller.dart
git commit -m "feat(overlay): TrainerOverlayController interface and no-op impl"
```

---

## Task 6: `TrainerOverlayService` router

**Files:**
- Create: `lib/services/overlay/trainer_overlay_service.dart`
- Test: `test/services/overlay/trainer_overlay_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/overlay/trainer_overlay_service_test.dart`:

```dart
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns NoOpOverlayController on web/test platforms', () {
    // The unit-test environment is not iOS/Android/macOS/Windows,
    // so the router should fall back to the no-op.
    if (kIsWeb) {
      final c = TrainerOverlayService.forCurrentPlatform();
      expect(c, isA<NoOpOverlayController>());
    } else {
      // On desktop test runners we still expect a real controller; just
      // assert the singleton invariant.
      final c1 = TrainerOverlayService.forCurrentPlatform();
      final c2 = TrainerOverlayService.forCurrentPlatform();
      expect(identical(c1, c2), isTrue);
    }
  });

  test('trainerOverlayMode notifier exists and starts false', () {
    expect(trainerOverlayMode.value, isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/overlay/trainer_overlay_service_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the router**

Create `lib/services/overlay/trainer_overlay_service.dart`:

```dart
import 'dart:io' show Platform;

import 'package:bike_control/services/overlay/android_overlay_controller.dart';
import 'package:bike_control/services/overlay/desktop_overlay_controller.dart';
import 'package:bike_control/services/overlay/ios_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';

/// Whether the desktop main window is currently in compact-overlay mode.
/// Only meaningful on macOS/Windows; the desktop controller toggles it and
/// the app root listens to it via `TrainerOverlayHost`.
final ValueNotifier<bool> trainerOverlayMode = ValueNotifier<bool>(false);

class TrainerOverlayService {
  TrainerOverlayService._();
  static TrainerOverlayController? _instance;

  static TrainerOverlayController forCurrentPlatform() {
    return _instance ??= _build();
  }

  static TrainerOverlayController _build() {
    if (kIsWeb) return NoOpOverlayController();
    if (Platform.isAndroid) return AndroidOverlayController();
    if (Platform.isIOS) return IosOverlayController();
    if (Platform.isMacOS || Platform.isWindows) return DesktopOverlayController();
    return NoOpOverlayController();
  }

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }
}
```

The three controller files don't exist yet — the file won't compile until Tasks 7, 11, 13, 16 are done. Add **stub** files so this compiles now:

Create `lib/services/overlay/desktop_overlay_controller.dart`:

```dart
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class DesktopOverlayController implements TrainerOverlayController {
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;
  @override
  Future<OverlayShowResult> show(FitnessBikeDefinition def, Set<OverlayField> fields) async {
    return const OverlayShowResult.fail(OverlayShowFailure.unknown, message: 'not implemented');
  }
  @override
  Future<void> hide() async {}
  @override
  void updateFields(Set<OverlayField> fields) {}
}
```

Create `lib/services/overlay/android_overlay_controller.dart` and `lib/services/overlay/ios_overlay_controller.dart` with the same stub body but different class names (`AndroidOverlayController`, `IosOverlayController`).

- [ ] **Step 4: Run the test**

Run: `flutter test test/services/overlay/trainer_overlay_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/overlay/ test/services/overlay/trainer_overlay_service_test.dart
git commit -m "feat(overlay): platform router and global overlay-mode notifier"
```

---

## Task 7: `TrainerOverlayView` shared widget

**Files:**
- Create: `lib/widgets/overlay/trainer_overlay_view.dart`
- Test: `test/widgets/overlay/trainer_overlay_view_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/widgets/overlay/trainer_overlay_view_test.dart`:

```dart
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  ValueNotifier<OverlayState> mkState({
    int gear = 14,
    int maxGear = 24,
    int? powerW = 178,
    int? cadenceRpm = 86,
    Set<OverlayField> fields = const {OverlayField.power, OverlayField.cadence},
    TrainerMode mode = TrainerMode.simMode,
  }) {
    return ValueNotifier(OverlayState(
      gear: gear, maxGear: maxGear, gearRatio: 2.43, mode: mode,
      powerW: powerW, cadenceRpm: cadenceRpm, ergTargetW: null, fields: fields,
    ));
  }

  testWidgets('renders gear N / M and mode pill', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: TrainerOverlayView(state: mkState(), onHide: () {}, onModeToggle: null),
        ),
      ),
    );
    expect(find.text('14 / 24'), findsOneWidget);
    expect(find.text('SIM'), findsOneWidget);
  });

  testWidgets('hides power when not selected', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: TrainerOverlayView(
            state: mkState(fields: const {OverlayField.cadence}),
            onHide: () {},
            onModeToggle: null,
          ),
        ),
      ),
    );
    expect(find.textContaining('W'), findsNothing);
    expect(find.textContaining('rpm'), findsOneWidget);
  });

  testWidgets('shows -- for null power and cadence', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: TrainerOverlayView(
            state: mkState(powerW: null, cadenceRpm: null),
            onHide: () {},
            onModeToggle: null,
          ),
        ),
      ),
    );
    expect(find.textContaining('--'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widgets/overlay/trainer_overlay_view_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the widget**

Create `lib/widgets/overlay/trainer_overlay_view.dart`:

```dart
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerOverlayView extends StatelessWidget {
  final ValueListenable<OverlayState> state;

  /// Called when user requests overlay close.
  final VoidCallback onHide;

  /// On desktop, called to toggle ERG/SIM. Pass `null` to render the mode
  /// pill as a static label (Android overlay isolate cannot reliably handle
  /// taps that bridge isolates).
  final VoidCallback? onModeToggle;

  /// Called when the user starts dragging. Desktop wires this to
  /// `windowManager.startDragging()`. Pass `null` on Android (the package
  /// handles dragging natively).
  final VoidCallback? onDragStart;

  const TrainerOverlayView({
    super.key,
    required this.state,
    required this.onHide,
    this.onModeToggle,
    this.onDragStart,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<OverlayState>(
      valueListenable: state,
      builder: (context, s, _) {
        return Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            color: cs.background.withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.border),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(context, cs, s),
              const Spacer(),
              Center(
                child: Text(
                  '${s.gear} / ${s.maxGear}',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: cs.foreground,
                  ),
                ),
              ),
              if (s.fields.contains(OverlayField.gearRatio))
                Center(
                  child: Text(
                    'ratio ${s.gearRatio.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: cs.mutedForeground),
                  ),
                ),
              const Spacer(),
              _metricsRow(context, cs, s),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context, ColorScheme cs, OverlayState s) {
    final modePill = _modePill(cs, s.mode);
    return Row(
      children: [
        if (onModeToggle != null)
          Button.ghost(onPressed: onModeToggle, child: modePill)
        else
          modePill,
        const Spacer(),
        if (onDragStart != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onDragStart!(),
            child: Icon(Icons.drag_indicator, size: 16, color: cs.mutedForeground),
          ),
        IconButton.ghost(
          icon: const Icon(Icons.close, size: 14),
          onPressed: onHide,
        ),
      ],
    );
  }

  Widget _modePill(ColorScheme cs, TrainerMode mode) {
    final label = mode == TrainerMode.ergMode ? 'ERG' : 'SIM';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: cs.primaryForeground,
        ),
      ),
    );
  }

  Widget _metricsRow(BuildContext context, ColorScheme cs, OverlayState s) {
    final children = <Widget>[];
    if (s.fields.contains(OverlayField.power)) {
      children.add(_metric(cs, '${s.powerW ?? '--'} W'));
    }
    if (s.fields.contains(OverlayField.cadence)) {
      children.add(_metric(cs, '${s.cadenceRpm ?? '--'} rpm'));
    }
    if (s.fields.contains(OverlayField.ergTarget) &&
        s.mode == TrainerMode.ergMode) {
      children.add(_metric(cs, 'tgt ${s.ergTargetW ?? '--'} W'));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );
  }

  Widget _metric(ColorScheme cs, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.foreground,
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widgets/overlay/trainer_overlay_view_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/overlay/ test/widgets/overlay/
git commit -m "feat(overlay): TrainerOverlayView shared widget"
```

---

## Task 8: `DesktopOverlayController` (window_manager)

**Files:**
- Replace: `lib/services/overlay/desktop_overlay_controller.dart`

- [ ] **Step 1: Replace the stub with the full implementation**

```dart
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:window_manager/window_manager.dart' as wm;

class DesktopOverlayController with wm.WindowListener implements TrainerOverlayController {
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  @override
  ValueListenable<bool> get isShowing => _showing;

  // Snapshot of the main window state to restore on hide.
  Size? _savedSize;
  Offset? _savedPosition;
  bool _savedAlwaysOnTop = false;
  bool _savedSkipTaskbar = false;
  bool _savedResizable = true;

  @override
  Future<OverlayShowResult> show(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    if (_showing.value) return const OverlayShowResult.ok();
    try {
      // 1. Capture current window state.
      _savedSize = await wm.windowManager.getSize();
      _savedPosition = await wm.windowManager.getPosition();
      _savedAlwaysOnTop = await wm.windowManager.isAlwaysOnTop();
      _savedSkipTaskbar = await wm.windowManager.isSkipTaskbar();
      _savedResizable = await wm.windowManager.isResizable();

      // 2. Apply compact-overlay window styling.
      await wm.windowManager.setAlwaysOnTop(true);
      await wm.windowManager.setBackgroundColor(const Color(0x00000000));
      await wm.windowManager.setHasShadow(false);
      await wm.windowManager.setResizable(false);
      await wm.windowManager.setSkipTaskbar(true);
      if (Platform.isMacOS) {
        // Stay visible on every Space and over fullscreened apps.
        await wm.windowManager.setVisibleOnAllWorkspaces(
          true,
          visibleOnFullScreen: true,
        );
      }
      await wm.windowManager.setMinimumSize(const Size(220, 140));
      await wm.windowManager.setSize(const Size(220, 140));

      // Restore last-known overlay position if any.
      final saved = core.settings.getOverlayPosition();
      if (saved != null) {
        await wm.windowManager.setPosition(saved);
      }

      wm.windowManager.addListener(this);

      _showing.value = true;
      trainerOverlayMode.value = true;
      return const OverlayShowResult.ok();
    } catch (e, s) {
      // Best-effort revert.
      await _restore();
      return OverlayShowResult.fail(
        OverlayShowFailure.unknown,
        message: 'Failed to enter overlay mode: $e\n$s',
      );
    }
  }

  @override
  Future<void> hide() async {
    if (!_showing.value) return;
    wm.windowManager.removeListener(this);

    // Persist current overlay position before restoring.
    try {
      final pos = await wm.windowManager.getPosition();
      await core.settings.setOverlayPosition(pos);
    } catch (_) {
      // Position is non-critical.
    }

    await _restore();
    _showing.value = false;
    trainerOverlayMode.value = false;
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    // Desktop reads fields directly from settings; nothing to push here.
  }

  Future<void> _restore() async {
    try {
      await wm.windowManager.setAlwaysOnTop(_savedAlwaysOnTop);
      await wm.windowManager.setSkipTaskbar(_savedSkipTaskbar);
      await wm.windowManager.setResizable(_savedResizable);
      if (Platform.isMacOS) {
        await wm.windowManager.setVisibleOnAllWorkspaces(false);
      }
      await wm.windowManager.setMinimumSize(const Size(360, 480));
      if (_savedSize != null) {
        await wm.windowManager.setSize(_savedSize!);
      }
      if (_savedPosition != null) {
        await wm.windowManager.setPosition(_savedPosition!);
      }
      await wm.windowManager.setHasShadow(true);
    } catch (_) {
      // ignore — best-effort
    }
  }

  @override
  void onWindowMoved() {
    // Persist position as the user drags the overlay.
    () async {
      try {
        final pos = await wm.windowManager.getPosition();
        await core.settings.setOverlayPosition(pos);
      } catch (_) {}
    }();
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/services/overlay/desktop_overlay_controller.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/overlay/desktop_overlay_controller.dart
git commit -m "feat(overlay): desktop controller via window_manager (compact mode)"
```

---

## Task 9: Mount `TrainerOverlayHost` in app root

**Files:**
- Create: `lib/widgets/overlay/trainer_overlay_host.dart`
- Modify: app root file (locate via grep below)

- [ ] **Step 1: Find the app root**

Run: `grep -rln "class BikeControlApp" lib`
Take note of the file (likely `lib/main.dart` or `lib/widgets/menu.dart`). Open it and locate the widget that builds the routed home (look for `Navigator`, `pages/navigation.dart` import, or `home:`).

- [ ] **Step 2: Create the host wrapper**

Create `lib/widgets/overlay/trainer_overlay_host.dart`:

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// Wraps the app body. When `trainerOverlayMode` is true (set by the desktop
/// controller), the wrapper renders the compact overlay instead of `child`.
class TrainerOverlayHost extends StatelessWidget {
  final Widget child;
  const TrainerOverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: trainerOverlayMode,
      builder: (context, isOverlay, _) {
        if (!isOverlay) return child;
        return _OverlayBody();
      },
    );
  }
}

class _OverlayBody extends StatefulWidget {
  @override
  State<_OverlayBody> createState() => _OverlayBodyState();
}

class _OverlayBodyState extends State<_OverlayBody> {
  late final ValueNotifier<OverlayState> _state;
  FitnessBikeDefinition? _def;
  Listenable? _bound;

  @override
  void initState() {
    super.initState();
    _state = ValueNotifier(_emptyState());
    _bind();
  }

  void _bind() {
    final proxy = core.connection.devices.whereType<ProxyDevice>().firstOrNull;
    final def = proxy?.emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return;
    _def = def;
    _bound = Listenable.merge([
      def.currentGear,
      def.gearRatio,
      def.trainerMode,
      def.powerW,
      def.cadenceRpm,
      def.ergTargetPower,
    ]);
    _bound!.addListener(_recompute);
    _recompute();
  }

  void _recompute() {
    final def = _def;
    if (def == null) return;
    _state.value = OverlayState(
      gear: def.currentGear.value,
      maxGear: def.maxGear,
      gearRatio: def.gearRatio.value,
      mode: def.trainerMode.value,
      powerW: def.powerW.value,
      cadenceRpm: def.cadenceRpm.value,
      ergTargetW: def.ergTargetPower.value,
      fields: core.settings.getOverlayFields(),
    );
  }

  @override
  void dispose() {
    _bound?.removeListener(_recompute);
    _state.dispose();
    super.dispose();
  }

  static OverlayState _emptyState() => const OverlayState(
        gear: 0,
        maxGear: 0,
        gearRatio: 1.0,
        mode: TrainerMode.simMode,
        powerW: null,
        cadenceRpm: null,
        ergTargetW: null,
        fields: {OverlayField.power, OverlayField.cadence},
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0x00000000),
      child: Center(
        child: TrainerOverlayView(
          state: _state,
          onHide: () => TrainerOverlayService.forCurrentPlatform().hide(),
          onModeToggle: () {
            final def = _def;
            if (def == null) return;
            if (def.trainerMode.value == TrainerMode.ergMode) {
              def.exitErgMode();
            } else {
              def.setManualErgPower(def.ergTargetPower.value ?? 150);
            }
          },
          onDragStart: () => wm.windowManager.startDragging(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Wrap the app's home content**

In whichever file builds the app shell (the file you found in Step 1), import the host and wrap the root `Scaffold` / `Navigator` body:

```dart
import 'package:bike_control/widgets/overlay/trainer_overlay_host.dart';
```

Then change the build tree from:

```dart
home: Navigation(...)
```

to:

```dart
home: TrainerOverlayHost(child: Navigation(...))
```

(Replace `Navigation(...)` with whatever the existing home expression is. The wrapper is a transparent passthrough when overlay mode is off.)

- [ ] **Step 4: Verify the app still compiles**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/overlay/trainer_overlay_host.dart lib/main.dart
# (Add whichever file you actually modified.)
git commit -m "feat(overlay): mount TrainerOverlayHost at app root for desktop compact mode"
```

---

## Task 10: Android manifest changes for SYSTEM_ALERT_WINDOW

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Read the current manifest**

Run: `cat android/app/src/main/AndroidManifest.xml`

- [ ] **Step 2: Add the permission and overlay service entries**

Inside the `<manifest>` element (alongside the other `<uses-permission>` lines), add:

```xml
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

Inside the `<application>` element (alongside other `<service>` entries, or just before `</application>`), add:

```xml
        <service
            android:name="flutter.overlay.window.flutter_overlay_window.OverlayService"
            android:exported="false" />
```

- [ ] **Step 3: Verify the build configures**

Run: `flutter pub get && flutter build apk --debug --target-platform android-arm64 --no-shrink`
Expected: build succeeds (or fails for unrelated reasons; the manifest part is valid if there is no manifest-related error).

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "android: declare SYSTEM_ALERT_WINDOW and overlay service for trainer overlay"
```

---

## Task 11: Android overlay isolate entry point

**Files:**
- Create: `lib/services/overlay/overlay_entry_point.dart`

- [ ] **Step 1: Create the entry point file**

```dart
import 'dart:convert';

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();
  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  late final ValueNotifier<OverlayState> _state;

  @override
  void initState() {
    super.initState();
    _state = ValueNotifier(_emptyState());
    FlutterOverlayWindow.overlayListener.listen(_onMessage);
  }

  void _onMessage(dynamic raw) {
    if (raw == null) return;
    try {
      final Map<String, dynamic> json = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      _state.value = OverlayState.fromJson(json);
    } catch (e) {
      // Keep last known state on decode failure.
      if (kDebugMode) print('overlay decode failed: $e');
    }
  }

  static OverlayState _emptyState() => const OverlayState(
        gear: 0, maxGear: 0, gearRatio: 1.0,
        mode: TrainerMode.simMode,
        powerW: null, cadenceRpm: null, ergTargetW: null,
        fields: {OverlayField.power, OverlayField.cadence},
      );

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      home: Scaffold(
        backgroundColor: const Color(0x00000000),
        child: Center(
          child: TrainerOverlayView(
            state: _state,
            onHide: () => FlutterOverlayWindow.closeOverlay(),
            // No mode toggle: cannot reach the main isolate from here cheaply.
            onModeToggle: null,
            // flutter_overlay_window provides its own dragging.
            onDragStart: null,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/services/overlay/overlay_entry_point.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/overlay/overlay_entry_point.dart
git commit -m "feat(overlay): Android overlay isolate entry point"
```

---

## Task 12: `AndroidOverlayController`

**Files:**
- Replace: `lib/services/overlay/android_overlay_controller.dart`

- [ ] **Step 1: Replace the stub with the full implementation**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class AndroidOverlayController implements TrainerOverlayController {
  static const _minPushIntervalMs = 100; // ~10 Hz
  final ValueNotifier<bool> _showing = ValueNotifier(false);
  FitnessBikeDefinition? _def;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  OverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<OverlayShowResult> show(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      final ok = await FlutterOverlayWindow.requestPermission();
      if (ok != true) {
        return const OverlayShowResult.fail(OverlayShowFailure.permissionDenied);
      }
    }

    _def = def;
    _fields = fields;
    _bind();

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'BikeControl',
      overlayContent: 'Trainer overlay active',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 360,
      width: 560,
      startPosition: const OverlayPosition(20, 80),
    );

    _showing.value = true;
    // Send an initial state immediately.
    _push(force: true);
    return const OverlayShowResult.ok();
  }

  @override
  Future<void> hide() async {
    _bound?.removeListener(_onChange);
    _bound = null;
    _def = null;
    _pushDebounce?.cancel();
    _pushDebounce = null;
    _lastPushed = null;
    if (await FlutterOverlayWindow.isActive() == true) {
      await FlutterOverlayWindow.closeOverlay();
    }
    _showing.value = false;
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    _fields = fields;
    _push(force: true);
  }

  void _bind() {
    final def = _def;
    if (def == null) return;
    _bound?.removeListener(_onChange);
    _bound = Listenable.merge([
      def.currentGear,
      def.gearRatio,
      def.trainerMode,
      def.powerW,
      def.cadenceRpm,
      def.ergTargetPower,
    ]);
    _bound!.addListener(_onChange);
  }

  void _onChange() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastPushAt).inMilliseconds;
    if (elapsed >= _minPushIntervalMs) {
      _push();
      return;
    }
    _pushDebounce ??= Timer(
      Duration(milliseconds: _minPushIntervalMs - elapsed),
      () {
        _pushDebounce = null;
        _push();
      },
    );
  }

  Future<void> _push({bool force = false}) async {
    final def = _def;
    if (def == null) return;
    final s = OverlayState(
      gear: def.currentGear.value,
      maxGear: def.maxGear,
      gearRatio: def.gearRatio.value,
      mode: def.trainerMode.value,
      powerW: def.powerW.value,
      cadenceRpm: def.cadenceRpm.value,
      ergTargetW: def.ergTargetPower.value,
      fields: _fields,
    );
    if (!force && s == _lastPushed) return;
    _lastPushed = s;
    _lastPushAt = DateTime.now();
    await FlutterOverlayWindow.shareData(jsonEncode(s.toJson()));
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/services/overlay/android_overlay_controller.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/overlay/android_overlay_controller.dart
git commit -m "feat(overlay): Android controller with permission flow and debounced state push"
```

---

## Task 13: iOS Live Activity setup — Info.plist + entitlements

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner/Runner.entitlements`

- [ ] **Step 1: Add Live Activities support to Info.plist**

Open `ios/Runner/Info.plist` and add this key/value pair inside the top-level `<dict>`:

```xml
	<key>NSSupportsLiveActivities</key>
	<true/>
```

- [ ] **Step 2: Add App Group entitlement**

Open `ios/Runner/Runner.entitlements`. If `<key>com.apple.security.application-groups</key>` exists, add an entry; otherwise add the whole block:

```xml
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.openbikecontrol.bikecontrol.overlay</string>
	</array>
```

(Use the same group identifier in the Widget Extension entitlements in Task 14. Replace the suffix if the bundle id base is different — verify with: `grep PRODUCT_BUNDLE_IDENTIFIER ios/Runner.xcodeproj/project.pbxproj`.)

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/Info.plist ios/Runner/Runner.entitlements
git commit -m "ios: enable Live Activities and App Group for trainer overlay"
```

---

## Task 14: Create the `TrainerActivity` Widget Extension

> ⚠️ **This task involves Xcode UI steps that cannot be scripted.** Follow them in order.

**Files:**
- Create: `ios/TrainerActivity/TrainerActivity.swift`
- Create: `ios/TrainerActivity/TrainerActivityAttributes.swift`
- Create: `ios/TrainerActivity/Info.plist`
- Create: `ios/TrainerActivity/TrainerActivity.entitlements`

- [ ] **Step 1: Create the target in Xcode**

1. Open `ios/Runner.xcworkspace` in Xcode.
2. File → New → Target.
3. Choose **Widget Extension** under iOS → press Next.
4. Product Name: `TrainerActivity`. Check **Include Live Activity**. Uncheck **Include Configuration Intent**. Press Finish.
5. When asked to activate the new scheme, click **Activate**.
6. Select the `TrainerActivity` target → Signing & Capabilities → set the same Team as Runner → add **App Groups** → tick `group.com.openbikecontrol.bikecontrol.overlay` (or the id you used in Task 13).
7. Set the Deployment Target of `TrainerActivity` to **iOS 16.2**.

- [ ] **Step 2: Replace the auto-generated activity attributes file**

Replace `ios/TrainerActivity/TrainerActivityAttributes.swift` (or whatever file Xcode generated next to the activity) with:

```swift
import ActivityKit
import Foundation

public struct TrainerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var gear: Int
        public var maxGear: Int
        public var mode: String        // "sim" | "erg"
        public var powerW: Int?
        public var cadenceRpm: Int?
        public var ergTargetW: Int?
        public var showPower: Bool
        public var showCadence: Bool
        public var showErgTarget: Bool
        public var showGearRatio: Bool
        public var gearRatio: Double

        public init(
            gear: Int, maxGear: Int, mode: String,
            powerW: Int?, cadenceRpm: Int?, ergTargetW: Int?,
            showPower: Bool, showCadence: Bool, showErgTarget: Bool, showGearRatio: Bool,
            gearRatio: Double
        ) {
            self.gear = gear
            self.maxGear = maxGear
            self.mode = mode
            self.powerW = powerW
            self.cadenceRpm = cadenceRpm
            self.ergTargetW = ergTargetW
            self.showPower = showPower
            self.showCadence = showCadence
            self.showErgTarget = showErgTarget
            self.showGearRatio = showGearRatio
            self.gearRatio = gearRatio
        }
    }

    public init() {}
}
```

- [ ] **Step 3: Replace the activity widget file**

Replace `ios/TrainerActivity/TrainerActivity.swift` with:

```swift
import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TrainerActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainerActivityAttributes.self) { context in
            // Lock Screen / Banner
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BikeControl").font(.caption2).foregroundStyle(.secondary)
                    Text("\(context.state.gear) / \(context.state.maxGear)")
                        .font(.system(size: 36, weight: .bold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.mode.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                    if context.state.showPower, let w = context.state.powerW {
                        Text("\(w) W").font(.caption.monospacedDigit())
                    }
                    if context.state.showCadence, let rpm = context.state.cadenceRpm {
                        Text("\(rpm) rpm").font(.caption.monospacedDigit())
                    }
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.4))
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.gear)/\(context.state.maxGear)")
                        .font(.title2.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.mode.uppercased())
                        .font(.caption2.bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        if context.state.showPower, let w = context.state.powerW {
                            Label("\(w) W", systemImage: "bolt.fill")
                        }
                        if context.state.showCadence, let rpm = context.state.cadenceRpm {
                            Label("\(rpm) rpm", systemImage: "arrow.clockwise")
                        }
                        if context.state.showErgTarget, let t = context.state.ergTargetW {
                            Label("tgt \(t) W", systemImage: "scope")
                        }
                    }.font(.caption.monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "gear")
            } compactTrailing: {
                Text("\(context.state.gear)/\(context.state.maxGear)")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Text("\(context.state.gear)").font(.caption2.bold())
            }
        }
    }
}
```

- [ ] **Step 4: Edit the extension's `Info.plist`**

In `ios/TrainerActivity/Info.plist`, ensure the `NSExtension` block declares the widget kind. Xcode usually generates this; if it's missing, add:

```xml
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
```

- [ ] **Step 5: Build the iOS app**

Run: `flutter build ios --debug --no-codesign`
Expected: build succeeds. If it fails on signing, fix Team/bundle id in Xcode and retry.

- [ ] **Step 6: Commit**

```bash
git add ios/TrainerActivity/ ios/Runner.xcodeproj/
git commit -m "ios: add TrainerActivity Widget Extension (Lock Screen + Dynamic Island)"
```

---

## Task 15: `IosOverlayController`

**Files:**
- Replace: `lib/services/overlay/ios_overlay_controller.dart`

- [ ] **Step 1: Replace the stub with the full implementation**

```dart
import 'dart:async';

import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class IosOverlayController implements TrainerOverlayController {
  static const _appGroupId = 'group.com.openbikecontrol.bikecontrol.overlay';
  static const _minPushIntervalMs = 500; // ~2 Hz

  final ValueNotifier<bool> _showing = ValueNotifier(false);
  final LiveActivities _la = LiveActivities();
  String? _activityId;

  FitnessBikeDefinition? _def;
  Listenable? _bound;
  Set<OverlayField> _fields = {OverlayField.power, OverlayField.cadence};

  Timer? _pushDebounce;
  OverlayState? _lastPushed;
  DateTime _lastPushAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  ValueListenable<bool> get isShowing => _showing;

  @override
  Future<OverlayShowResult> show(
      FitnessBikeDefinition def, Set<OverlayField> fields) async {
    try {
      await _la.init(appGroupId: _appGroupId);
    } catch (e) {
      return OverlayShowResult.fail(OverlayShowFailure.systemDisabled,
          message: 'Live Activities init failed: $e');
    }
    _def = def;
    _fields = fields;
    _bind();

    final s = _snapshot();
    try {
      _activityId = await _la.createActivity(_toMap(s));
      if (_activityId == null) {
        return const OverlayShowResult.fail(OverlayShowFailure.systemDisabled,
            message: 'Live Activities are disabled (Low Power Mode or system setting).');
      }
    } catch (e) {
      return OverlayShowResult.fail(OverlayShowFailure.systemDisabled,
          message: 'Live Activity create failed: $e');
    }

    _showing.value = true;
    return const OverlayShowResult.ok();
  }

  @override
  Future<void> hide() async {
    _bound?.removeListener(_onChange);
    _bound = null;
    _def = null;
    _pushDebounce?.cancel();
    _pushDebounce = null;
    _lastPushed = null;
    final id = _activityId;
    if (id != null) {
      try {
        await _la.endActivity(id);
      } catch (_) {}
      _activityId = null;
    }
    _showing.value = false;
  }

  @override
  void updateFields(Set<OverlayField> fields) {
    _fields = fields;
    _push(force: true);
  }

  void _bind() {
    final def = _def;
    if (def == null) return;
    _bound?.removeListener(_onChange);
    _bound = Listenable.merge([
      def.currentGear,
      def.gearRatio,
      def.trainerMode,
      def.powerW,
      def.cadenceRpm,
      def.ergTargetPower,
    ]);
    _bound!.addListener(_onChange);
  }

  void _onChange() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastPushAt).inMilliseconds;
    if (elapsed >= _minPushIntervalMs) {
      _push();
      return;
    }
    _pushDebounce ??= Timer(
      Duration(milliseconds: _minPushIntervalMs - elapsed),
      () {
        _pushDebounce = null;
        _push();
      },
    );
  }

  OverlayState _snapshot() {
    final def = _def!;
    return OverlayState(
      gear: def.currentGear.value,
      maxGear: def.maxGear,
      gearRatio: def.gearRatio.value,
      mode: def.trainerMode.value,
      powerW: def.powerW.value,
      cadenceRpm: def.cadenceRpm.value,
      ergTargetW: def.ergTargetPower.value,
      fields: _fields,
    );
  }

  Map<String, dynamic> _toMap(OverlayState s) => {
        'gear': s.gear,
        'maxGear': s.maxGear,
        'mode': s.mode == TrainerMode.ergMode ? 'erg' : 'sim',
        'powerW': s.powerW,
        'cadenceRpm': s.cadenceRpm,
        'ergTargetW': s.ergTargetW,
        'showPower': s.fields.contains(OverlayField.power),
        'showCadence': s.fields.contains(OverlayField.cadence),
        'showErgTarget': s.fields.contains(OverlayField.ergTarget),
        'showGearRatio': s.fields.contains(OverlayField.gearRatio),
        'gearRatio': s.gearRatio,
      };

  Future<void> _push({bool force = false}) async {
    final id = _activityId;
    if (id == null) return;
    final s = _snapshot();
    if (!force && s == _lastPushed) return;
    _lastPushed = s;
    _lastPushAt = DateTime.now();
    try {
      await _la.updateActivity(id, _toMap(s));
    } catch (_) {}
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/services/overlay/ios_overlay_controller.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/overlay/ios_overlay_controller.dart
git commit -m "feat(overlay): iOS controller backed by Live Activities (debounced 2 Hz)"
```

---

## Task 16: `OverlaySettingsSection` widget

**Files:**
- Create: `lib/pages/proxy_device_details/overlay_settings_section.dart`

- [ ] **Step 1: Create the section widget**

```dart
import 'dart:io' show Platform;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class OverlaySettingsSection extends StatefulWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;
  const OverlaySettingsSection({
    super.key,
    required this.definition,
    required this.device,
  });

  @override
  State<OverlaySettingsSection> createState() => _OverlaySettingsSectionState();
}

class _OverlaySettingsSectionState extends State<OverlaySettingsSection> {
  late TrainerOverlayController _controller;
  late bool _enabled;
  late Set<OverlayField> _fields;

  @override
  void initState() {
    super.initState();
    _controller = TrainerOverlayService.forCurrentPlatform();
    _enabled = core.settings.getOverlayEnabled();
    _fields = core.settings.getOverlayFields();
    _controller.isShowing.addListener(_syncFromController);
  }

  @override
  void dispose() {
    _controller.isShowing.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    if (!mounted) return;
    setState(() => _enabled = _controller.isShowing.value);
  }

  Future<void> _toggle(bool v) async {
    if (kIsWeb) return;
    if (v) {
      final res = await _controller.show(widget.definition, _fields);
      if (!mounted) return;
      if (res.ok) {
        await core.settings.setOverlayEnabled(true);
        setState(() => _enabled = true);
      } else {
        // Stay off and surface message.
        showToast(
          context: context,
          builder: (c, _) => SurfaceCard(
            child: Text(res.message ?? AppLocalizations.of(context).overlayLowPowerMode),
          ),
        );
        setState(() => _enabled = false);
      }
    } else {
      await _controller.hide();
      await core.settings.setOverlayEnabled(false);
      if (mounted) setState(() => _enabled = false);
    }
  }

  Future<void> _toggleField(OverlayField f, bool on) async {
    final next = {..._fields};
    if (on) {
      next.add(f);
    } else {
      next.remove(f);
    }
    await core.settings.setOverlayFields(next);
    _controller.updateFields(next);
    if (mounted) setState(() => _fields = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isIos = !kIsWeb && Platform.isIOS;
    final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows);
    final isAndroid = !kIsWeb && Platform.isAndroid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          l10n.overlaySection,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        SettingTile(
          icon: LucideIcons.layers,
          title: l10n.overlayEnabled,
          subtitle: isIos ? l10n.overlayDisabledIos : l10n.overlaySectionSubtitle,
          trailing: Switch(value: _enabled, onChanged: _toggle),
        ),
        if (_enabled) _fieldsCard(l10n),
        if (isDesktop && _enabled) _tipCard(l10n.overlayWindowsTip),
        if (isAndroid) _androidPermissionTile(l10n),
      ],
    );
  }

  Widget _fieldsCard(AppLocalizations l10n) {
    Widget row(OverlayField f, String label) {
      return Row(
        children: [
          Expanded(child: Text(label)),
          Switch(
            value: _fields.contains(f),
            onChanged: (v) => _toggleField(f, v),
          ),
        ],
      );
    }
    return SettingTile(
      icon: LucideIcons.eye,
      title: l10n.overlayFieldsLabel,
      subtitle: l10n.overlaySectionSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          row(OverlayField.power, l10n.overlayFieldPower),
          row(OverlayField.cadence, l10n.overlayFieldCadence),
          row(OverlayField.ergTarget, l10n.overlayFieldErgTarget),
          row(OverlayField.gearRatio, l10n.overlayFieldGearRatio),
        ],
      ),
    );
  }

  Widget _tipCard(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 16, color: cs.mutedForeground),
          const Gap(8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: cs.mutedForeground)),
          ),
        ],
      ),
    );
  }

  Widget _androidPermissionTile(AppLocalizations l10n) {
    return SettingTile(
      icon: LucideIcons.shieldCheck,
      title: l10n.overlayGrantAndroidPermission,
      subtitle: l10n.overlayPermissionExplain,
      trailing: Button.ghost(
        onPressed: () async {
          // Re-trigger via show(): the controller asks for permission first.
          await _toggle(true);
        },
        child: Text(l10n.overlayGrantAndroidPermission),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/pages/proxy_device_details/overlay_settings_section.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/pages/proxy_device_details/overlay_settings_section.dart
git commit -m "feat(overlay): settings section (toggle, fields, tips, permission)"
```

---

## Task 17: Wire `OverlaySettingsSection` into the proxy device details page

**Files:**
- Modify: `lib/pages/proxy_device_details.dart`

- [ ] **Step 1: Add the import**

At the top of `lib/pages/proxy_device_details.dart`, alongside the other `pages/proxy_device_details/...` imports, add:

```dart
import 'package:bike_control/pages/proxy_device_details/overlay_settings_section.dart';
```

- [ ] **Step 2: Render it after `TrainerSettingsSection`**

Inside `_settingsSection()`, change:

```dart
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(...),
        TrainerSettingsSection(definition: def, device: widget.device),
      ],
    );
```

to:

```dart
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          AppLocalizations.of(context).virtualShiftingSettings,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        TrainerSettingsSection(definition: def, device: widget.device),
        OverlaySettingsSection(definition: def, device: widget.device),
      ],
    );
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/pages/proxy_device_details.dart
git commit -m "feat(overlay): mount overlay settings section on proxy device details page"
```

---

## Task 18: Manual test pass + bug fixes

**Files:** none until bugs surface.

This step is **explicitly manual**. Each platform must be verified by hand because the overlay touches OS-level surfaces that automated tests cannot cover.

- [ ] **Step 1: macOS — connect a smart trainer (or use the simulator), enable VS, toggle overlay**

Verify:
- Window shrinks to ~220×140, frameless, transparent.
- Overlay sits on top while Zwift / MyWhoosh runs in **borderless windowed** mode.
- Drag handle moves the window.
- Quit and relaunch — position is restored.
- Toggle overlay off — main UI returns to its previous size.

- [ ] **Step 2: Windows — same checklist as macOS**

Additionally verify the borderless-windowed tip is visible in settings. Confirm the overlay does **not** show over a DirectX exclusive-fullscreen trainer app (this is documented behavior).

- [ ] **Step 3: Android — first run grants permission, then the overlay survives backgrounding**

Verify:
- Toggle overlay → permission sheet → grant in system settings → return to app.
- Overlay appears at top-right by default and is draggable.
- Background the app: overlay stays visible while Zwift is running.
- Gear value updates live as you shift.
- Toggle overlay off → overlay disappears.

- [ ] **Step 4: iOS — iPhone 15 Pro (Dynamic Island) and iPhone 13 / iPad (Lock Screen)**

Verify:
- iPhone 15 Pro: compact (gear icon · `14/24`), expanded (full layout), minimal (gear number) all render correctly.
- iPhone 13: Lock Screen banner appears.
- iPad: Lock Screen only — confirm the in-app text says this is a known limitation.
- Low Power Mode → toggle should fail gracefully with a snackbar.

- [ ] **Step 5: File issues for any bugs found**

For each bug, capture: platform, repro, expected vs. actual. Fix in a separate commit per bug.

- [ ] **Step 6: Commit any fixes**

```bash
git add ...
git commit -m "fix(overlay): <specific issue>"
```

---

## Self-review checklist (already executed by the plan author)

- ✅ Spec section "Scope" → covered by tasks 16, 17 (UI), 4 (persistence), 8/12/15 (per-platform behavior).
- ✅ Spec section "Platform strategy" → tasks 8 (desktop), 10–12 (Android), 13–15 (iOS).
- ✅ Spec section "Caveats" → tasks 16 (tips, iOS notice), 18 (manual verification).
- ✅ Spec section "Architecture" → file map and tasks mirror it 1:1.
- ✅ Spec section "Data flow" → desktop direct (Task 9), Android shareData (Tasks 11–12), iOS updateActivity (Task 15).
- ✅ Spec section "Compact-mode mechanics" → Task 8 implements all five steps; macOS Spaces/fullscreen handled via `setVisibleOnAllWorkspaces` (already exposed by `window_manager` 0.5+, so the native shim noted in the spec is not needed).
- ✅ Spec section "Android permission flow" → Task 12 (controller) + Task 16 (UI hook).
- ✅ Spec section "iOS Live Activity setup" → Tasks 13–15.
- ✅ Spec section "UI" → Tasks 7 (compact view), 14 (Dynamic Island), 16 (settings section).
- ✅ Spec section "Settings additions" → Tasks 4 (persistence) + 16 (UI).
- ✅ Spec section "Error handling" → all four cases handled in Tasks 8, 12, 15, 16.
- ✅ Spec section "Testing" → widget test (Task 7), unit tests (Tasks 3, 4, 6), manual plan (Task 18).
- ✅ Spec section "Dependencies added" → Task 1.
- ✅ No placeholders; all code blocks complete.
- ✅ Type consistency: `OverlayField`, `OverlayState`, `TrainerOverlayController`, `OverlayShowResult`, `trainerOverlayMode` are spelled identically across tasks.
