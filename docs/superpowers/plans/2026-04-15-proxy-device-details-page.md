# Proxy Device Details Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dedicated details page for `ProxyDevice` that shows live stats (power, HR, cadence, speed, optionally current gear) and user-adjustable settings (gear ratio, bike/rider weight, grade smoothing, virtual shifting mode, retrofit mode), mirroring the layout defined in the `bikecontrol.pen` design (node `sInQI`).

**Architecture:**
- Expose individual live metrics from `ProxyBikeDefinition` via `ValueNotifier`s (in addition to the existing aggregated `data: ValueNotifier<String>`), and expose current gear / gear ratio / retrofit mode / weights from the `DirconEmulator` wrapper so the UI can bind to them with `ValueListenableBuilder`.
- Build a new Flutter page `ProxyDeviceDetailsPage` structured as sections (device card, retrofit banner, live metrics grid, VS mode segmented control, gear ratio slider, weight steppers, grade smoothing toggle, actions), using the existing shadcn_flutter widgets already in use in `ControllerSettingsPage`.
- Persist user-adjustable defaults via `core.settings` (SharedPreferences) — new keys `proxy_bike_weight_kg`, `proxy_rider_weight_kg`, `proxy_grade_smoothing`, `proxy_vs_mode`.
- Route proxy list taps from `ProxyPage` to the new page instead of the generic `ControllerSettingsPage`.

**Tech Stack:** Flutter, shadcn_flutter, `prop` package (`DirconEmulator`, `ProxyBikeDefinition`, `FitnessBikeDefinition`), SharedPreferences via `core.settings`, `universal_ble`, `flutter_test`.

---

## File Structure

**New files:**
- `lib/pages/proxy_device_details.dart` — new page widget (page root + state class)
- `lib/pages/proxy_device_details/connection_card.dart` — retrofit mode picker + Connect CTA when disconnected; status + BT→WiFi bridge visualisation when connected
- `lib/pages/proxy_device_details/live_metrics_section.dart` — 2×2 grid of power / HR / cadence / speed
- `lib/pages/proxy_device_details/gear_hero_card.dart` — big gear display + shift buttons (only when retrofit Bluetooth mode with FitnessBikeDefinition)
- `lib/pages/proxy_device_details/trainer_settings_section.dart` — VS mode, gear ratio, weights, grade smoothing
- `lib/pages/proxy_device_details/metric_card.dart` — single reusable live metric card (label + value + unit + icon)
- `lib/widgets/ui/stepper_control.dart` — reusable ± numeric stepper (bike / rider weight)
- `test/pages/proxy_device_details_test.dart` — widget tests
- `test/widgets/ui/stepper_control_test.dart` — widget test

**Modified files:**
- `prop/lib/emulators/definitions/proxy_bike_definition.dart` — expose `powerW`, `heartRateBpm`, `cadenceRpm`, `speedKph`, `resistance` as `ValueNotifier`s.
- `prop/lib/emulators/definitions/fitness_bike_definition.dart` — expose `currentGear` (ValueListenable<int>), `gearRatio` (ValueListenable<double>), `virtualShiftingMode` (ValueListenable<VirtualShiftingMode>), `bicycleWeightKg` / `riderWeightKg` setters + listenables, `gradeSmoothingEnabled` listenable + setter, `trainerMode` listenable. `shiftUp()` / `shiftDown()` / `setTargetGear()` are already public.
- `prop/lib/emulators/dircon_emulator.dart` — expose `retrofitMode` listenable, `localAddress` listenable (set by `startServer`), and a `BleDefinition? get activeDefinition` getter returning `_transporter?.definition ?? _bluetoothTransporter?.definition`.
- `lib/utils/settings/settings.dart` — add 4 getter/setter pairs for proxy defaults.
- `lib/bluetooth/devices/proxy/proxy_device.dart` — strip the retrofit-mode `Select` + "Connect" button + debug button + status icon out of `showInformation`; leave only the base `super.showInformation(...)` row so the device list is clean. The mode picker and Connect CTA live in the new details page.
- `lib/pages/proxy.dart:54` — change navigation target from `ControllerSettingsPage` to `ProxyDeviceDetailsPage`.

---

## Context: Pre-flight Rules

- **Do not create a worktree.** Work on the current `next` branch in-place; the user runs this plan from within their active session.
- **Line endings:** LF. No trailing whitespace.
- **Formatting:** Always run `dart format .` before committing in the top-level repo and the `prop/` subrepo.
- **Testing:** Flutter widget tests with `flutter_test`, unit tests with plain `test` package (see existing tests under `test/`). Do not use mocks for `SharedPreferences` beyond `SharedPreferences.setMockInitialValues({})` — this is the existing pattern.
- **Commit cadence:** After each task's tests pass, commit with a conventional-commit style message. Do NOT combine tasks into a single commit.
- **Submodule note:** `prop/` is a git submodule. After modifying files inside `prop/`, commit inside `prop/` first, then in the outer repo bump the submodule pointer.

---

## Task 1: Expose live metrics on `ProxyBikeDefinition`

**Files:**
- Modify: `prop/lib/emulators/definitions/proxy_bike_definition.dart`
- Test: `prop/test/emulators/proxy_bike_definition_test.dart` (create if missing)

- [ ] **Step 1: Write the failing test**

Create `prop/test/emulators/proxy_bike_definition_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  group('ProxyBikeDefinition live metrics', () {
    late ProxyBikeDefinition def;

    setUp(() {
      def = ProxyBikeDefinition(
        services: const <BleService>[],
        device: BleDevice(deviceId: 'test', name: 'Test'),
        data: ValueNotifier<String>(''),
      );
    });

    test('exposes ValueNotifier fields that start unset', () {
      expect(def.powerW.value, isNull);
      expect(def.heartRateBpm.value, isNull);
      expect(def.cadenceRpm.value, isNull);
      expect(def.speedKph.value, isNull);
      expect(def.resistance.value, isNull);
    });

    test('parseHeartRateMeasurement updates heartRateBpm', () {
      def.onNotification(
        FitnessBikeDefinition.HEART_RATE_MEASUREMENT_UUID,
        Uint8List.fromList([0x00, 142]),
      );
      expect(def.heartRateBpm.value, 142);
    });

    test('parseCyclingPowerMeasurement updates powerW', () {
      // flags=0,0 ; power=248 little endian
      def.onNotification(
        FitnessBikeDefinition.CYCLING_POWER_MEASUREMENT_UUID,
        Uint8List.fromList([0x00, 0x00, 248, 0x00]),
      );
      expect(def.powerW.value, 248);
    });

    test('parseIndoorBikeData updates speed, cadence, power', () {
      // flags lo=0x44 (bit2 cadence + bit6 power), hi=0x00
      // speed present (bit0=0): 3460 (34.60 km/h in 0.01 units)
      // cadence: 184 -> 92 rpm
      // power: 250
      def.onNotification(
        FitnessBikeDefinition.INDOOR_BIKE_DATA_UUID,
        Uint8List.fromList([
          0x44, 0x00,
          0x84, 0x0D, // 3460
          0xB8, 0x00, // 184
          0xFA, 0x00, // 250
        ]),
      );
      expect(def.speedKph.value, closeTo(34.6, 0.01));
      expect(def.cadenceRpm.value, 92);
      expect(def.powerW.value, 250);
    });
  });
}
```

- [ ] **Step 2: Run test — verify failure**

```bash
cd prop && flutter test test/emulators/proxy_bike_definition_test.dart
```

Expected: compilation errors on `def.powerW`, `def.heartRateBpm`, etc.

- [ ] **Step 3: Add ValueNotifiers and wire parsers**

In `prop/lib/emulators/definitions/proxy_bike_definition.dart` replace the existing private fields and `_updateDataString` section (currently lines ~162–244) with:

```dart
  // Parsed data fields — exposed for UI listeners.
  final ValueNotifier<int?> heartRateBpm = ValueNotifier<int?>(null);
  final ValueNotifier<int?> powerW = ValueNotifier<int?>(null);
  final ValueNotifier<int?> cadenceRpm = ValueNotifier<int?>(null);
  final ValueNotifier<double?> speedKph = ValueNotifier<double?>(null);
  final ValueNotifier<int?> resistance = ValueNotifier<int?>(null);

  void _updateDataString() {
    final parts = <String>[];
    final hr = heartRateBpm.value;
    final p = powerW.value;
    final c = cadenceRpm.value;
    final s = speedKph.value;
    final r = resistance.value;
    if (hr != null) parts.add('Heart Rate: $hr bpm');
    if (p != null) parts.add('Power: $p W');
    if (c != null) parts.add('Cadence: $c U/min');
    if (s != null) parts.add('Speed: ${s.toStringAsFixed(1)} km/h');
    if (r != null) parts.add('Resistance: $r');
    data.value = parts.join('\n');
  }

  void _parseHeartRateMeasurement(List<int> bytes) {
    if (bytes.length < 2) return;
    final flags = bytes[0];
    final is16Bit = (flags & 0x01) != 0;
    heartRateBpm.value = is16Bit && bytes.length >= 3
        ? (bytes[1] | (bytes[2] << 8))
        : bytes[1];
  }

  void _parseCyclingPowerMeasurement(List<int> bytes) {
    if (bytes.length < 4) return;
    final raw = bytes[2] | (bytes[3] << 8);
    powerW.value = raw > 32767 ? raw - 65536 : raw;
  }

  void _parseIndoorBikeData(List<int> bytes) {
    if (bytes.length < 2) return;
    final flags = bytes[0] | (bytes[1] << 8);
    var offset = 2;

    if ((flags & 0x01) == 0 && offset + 2 <= bytes.length) {
      final raw = bytes[offset] | (bytes[offset + 1] << 8);
      speedKph.value = raw / 100.0;
      offset += 2;
    }
    if ((flags & 0x02) != 0) offset += 2;
    if ((flags & 0x04) != 0 && offset + 2 <= bytes.length) {
      final raw = bytes[offset] | (bytes[offset + 1] << 8);
      cadenceRpm.value = raw ~/ 2;
      offset += 2;
    }
    if ((flags & 0x08) != 0) offset += 2;
    if ((flags & 0x10) != 0) offset += 3;
    if ((flags & 0x20) != 0 && offset + 2 <= bytes.length) {
      final raw = bytes[offset] | (bytes[offset + 1] << 8);
      resistance.value = raw > 32767 ? raw - 65536 : raw;
      offset += 2;
    }
    if ((flags & 0x40) != 0 && offset + 2 <= bytes.length) {
      final raw = bytes[offset] | (bytes[offset + 1] << 8);
      powerW.value = raw > 32767 ? raw - 65536 : raw;
      offset += 2;
    }
    if ((flags & 0x80) != 0) offset += 2;
    if ((flags & 0x100) != 0) offset += 6;
    if ((flags & 0x200) != 0 && offset < bytes.length) {
      heartRateBpm.value = bytes[offset];
    }
  }
```

Leave `onNotification` and `onWriteRequest` unchanged. Remove the now-unused private `_heartRate`, `_power`, `_cadence`, `_speed`, `_resistance` fields (they are replaced by the ValueNotifiers above).

- [ ] **Step 4: Run test — verify pass**

```bash
cd prop && flutter test test/emulators/proxy_bike_definition_test.dart
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Commit (inside `prop/`)**

```bash
cd prop
git add lib/emulators/definitions/proxy_bike_definition.dart test/emulators/proxy_bike_definition_test.dart
git commit -m "feat(proxy): expose live metric ValueNotifiers on ProxyBikeDefinition"
```

---

## Task 2: Expose VS state + gear on `FitnessBikeDefinition`

**Files:**
- Modify: `prop/lib/emulators/definitions/fitness_bike_definition.dart`
- Test: `prop/test/emulators/fitness_bike_definition_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `prop/test/emulators/fitness_bike_definition_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  FitnessBikeDefinition make() => FitnessBikeDefinition(
        connectedDevice: BleDevice(deviceId: 't', name: 'T'),
        connectedDeviceServices: const <BleService>[],
        data: ValueNotifier<String>(''),
      );

  test('currentGear ValueListenable starts at 12 (neutral)', () {
    final def = make();
    expect(def.currentGear.value, 12);
  });

  test('shiftUp and shiftDown update currentGear listenable', () {
    final def = make();
    def.shiftUp();
    expect(def.currentGear.value, 13);
    def.shiftDown();
    def.shiftDown();
    expect(def.currentGear.value, 11);
  });

  test('setBicycleWeightKg / setRiderWeightKg update listenables', () {
    final def = make();
    def.setBicycleWeightKg(8.5);
    def.setRiderWeightKg(72.0);
    expect(def.bicycleWeightKg.value, closeTo(8.5, 0.01));
    expect(def.riderWeightKg.value, closeTo(72.0, 0.01));
  });

  test('setGradeSmoothingEnabled toggles', () {
    final def = make();
    expect(def.gradeSmoothingEnabled.value, isTrue);
    def.setGradeSmoothingEnabled(false);
    expect(def.gradeSmoothingEnabled.value, isFalse);
  });

  test('setVirtualShiftingMode updates listenable', () {
    final def = make();
    def.setVirtualShiftingMode(VirtualShiftingMode.trackResistance);
    expect(def.virtualShiftingMode.value, VirtualShiftingMode.trackResistance);
  });

  test('gear ratio listenable reflects selected gear', () {
    final def = make();
    def.setTargetGear(14);
    expect(def.gearRatio.value, closeTo(3.24, 0.001));
  });
}
```

- [ ] **Step 2: Run test — verify failure**

```bash
cd prop && flutter test test/emulators/fitness_bike_definition_test.dart
```

Expected: compile errors — missing `currentGear`, `bicycleWeightKg`, etc.

- [ ] **Step 3: Add listenables and setters**

In `prop/lib/emulators/definitions/fitness_bike_definition.dart`, replace the existing state block around line 91–155 with listenables. Concretely:

Replace:
```dart
  TrainerMode _zwiftTrainerMode = TrainerMode.simMode;
  VirtualShiftingMode _virtualShiftingMode = VirtualShiftingMode.targetPower;
```
with:
```dart
  final ValueNotifier<TrainerMode> _trainerModeN = ValueNotifier(TrainerMode.simMode);
  ValueListenable<TrainerMode> get trainerMode => _trainerModeN;
  TrainerMode get _zwiftTrainerMode => _trainerModeN.value;
  set _zwiftTrainerMode(TrainerMode v) => _trainerModeN.value = v;

  final ValueNotifier<VirtualShiftingMode> _vsModeN =
      ValueNotifier(VirtualShiftingMode.targetPower);
  ValueListenable<VirtualShiftingMode> get virtualShiftingMode => _vsModeN;
  VirtualShiftingMode get _virtualShiftingMode => _vsModeN.value;
  set _virtualShiftingMode(VirtualShiftingMode v) => _vsModeN.value = v;

  void setVirtualShiftingMode(VirtualShiftingMode mode) {
    _vsModeN.value = mode;
    _updateSimModeResistance();
  }
```

Replace:
```dart
  bool _gradeSmoothingEnabled = true;
```
with:
```dart
  final ValueNotifier<bool> _gradeSmoothingN = ValueNotifier(true);
  ValueListenable<bool> get gradeSmoothingEnabled => _gradeSmoothingN;
  bool get _gradeSmoothingEnabled => _gradeSmoothingN.value;

  void setGradeSmoothingEnabled(bool enabled) {
    _gradeSmoothingN.value = enabled;
    _updateSimModeResistance();
  }
```

Replace the raw weight fields:
```dart
  int _zwiftBicycleWeight = 1000;
  int _zwiftUserWeight = 7500;
```
with:
```dart
  // Stored in Zwift units (bike: 0.005 kg; rider: 0.01 kg).
  final ValueNotifier<int> _bicycleWeightZU = ValueNotifier(1000);
  final ValueNotifier<int> _riderWeightZU = ValueNotifier(7500);
  int get _zwiftBicycleWeight => _bicycleWeightZU.value;
  set _zwiftBicycleWeight(int v) => _bicycleWeightZU.value = v;
  int get _zwiftUserWeight => _riderWeightZU.value;
  set _zwiftUserWeight(int v) => _riderWeightZU.value = v;

  late final ValueNotifier<double> bicycleWeightKg = ValueNotifier(
    _zwiftBicycleWeight / 200.0,
  );
  late final ValueNotifier<double> riderWeightKg = ValueNotifier(
    _zwiftUserWeight / 100.0,
  );

  void setBicycleWeightKg(double kg) {
    final clamped = kg.clamp(1.0, 50.0);
    bicycleWeightKg.value = clamped;
    _bicycleWeightZU.value = (clamped * 200).round();
    _updateSimModeResistance();
  }

  void setRiderWeightKg(double kg) {
    final clamped = kg.clamp(20.0, 200.0);
    riderWeightKg.value = clamped;
    _riderWeightZU.value = (clamped * 100).round();
    _updateSimModeResistance();
  }
```

Replace:
```dart
  int _currentGear = _neutralGear;
```
with:
```dart
  final ValueNotifier<int> _currentGearN = ValueNotifier(_neutralGear);
  ValueListenable<int> get currentGear => _currentGearN;
  int get _currentGear => _currentGearN.value;
  set _currentGear(int v) => _currentGearN.value = v;

  late final ValueNotifier<double> _gearRatioN = ValueNotifier(
    _gearRatios[_currentGear - 1],
  );
  ValueListenable<double> get gearRatio => _gearRatioN;
```

In `setTargetGear`, after `_currentGear = newGear;` add:
```dart
    _gearRatioN.value = _gearRatios[newGear - 1];
```

At the top of the file, ensure `import 'package:flutter/foundation.dart';` covers `ValueListenable` (it already does — keep).

- [ ] **Step 4: Run test — verify pass**

```bash
cd prop && flutter test test/emulators/fitness_bike_definition_test.dart
```

Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd prop
git add lib/emulators/definitions/fitness_bike_definition.dart test/emulators/fitness_bike_definition_test.dart
git commit -m "feat(fitness): expose trainer mode/gear/weight/VS listenables"
```

---

## Task 3: Expose `activeDefinition`, `retrofitMode`, and `localAddress` on `DirconEmulator`

**Files:**
- Modify: `prop/lib/emulators/dircon_emulator.dart`
- Test: `prop/test/emulators/dircon_emulator_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `prop/test/emulators/dircon_emulator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';

void main() {
  test('retrofitMode listenable starts as proxy', () {
    final e = DirconEmulator();
    expect(e.retrofitMode.value, RetrofitMode.proxy);
  });

  test('setRetrofitMode updates listenable', () {
    final e = DirconEmulator();
    e.setRetrofitMode(RetrofitMode.wifi);
    expect(e.retrofitMode.value, RetrofitMode.wifi);
  });

  test('activeDefinition is null before startServer', () {
    final e = DirconEmulator();
    expect(e.activeDefinition, isNull);
  });

  test('localAddress listenable starts as null', () {
    final e = DirconEmulator();
    expect(e.localAddress.value, isNull);
  });
}
```

- [ ] **Step 2: Run test — verify failure**

```bash
cd prop && flutter test test/emulators/dircon_emulator_test.dart
```

Expected: compile errors on `retrofitMode`, `activeDefinition`, `localAddress`.

- [ ] **Step 3: Add listenables and getter**

In `prop/lib/emulators/dircon_emulator.dart`:

Replace:
```dart
  RetrofitMode _retrofitMode = RetrofitMode.proxy;
```
with:
```dart
  final ValueNotifier<RetrofitMode> _retrofitModeN = ValueNotifier(RetrofitMode.proxy);
  ValueListenable<RetrofitMode> get retrofitMode => _retrofitModeN;
  RetrofitMode get _retrofitMode => _retrofitModeN.value;
  set _retrofitMode(RetrofitMode v) => _retrofitModeN.value = v;
```

Add next to the other `ValueNotifier` fields (after `data`):
```dart
  /// Local IPv4 address announced via mDNS. Populated by [startServer]
  /// whenever the emulator is running in a WiFi retrofit/proxy mode.
  final ValueNotifier<String?> localAddress = ValueNotifier<String?>(null);
```

Inside `startServer()`, right after the line `if (localIP == null) { throw ...; }` (~line 128), add:
```dart
    localAddress.value = localIP.address;
```

Inside `stop()`, right after `isConnected.value = false;` (~line 171), add:
```dart
    localAddress.value = null;
```

Add at the bottom of the class (before the closing `}`):
```dart
  BleDefinition? get activeDefinition =>
      _transporter?.definition ?? _bluetoothTransporter?.definition;
```

At the top of the file, add:
```dart
import 'package:prop/emulators/ble_definition.dart';
```
(if not already imported).

- [ ] **Step 4: Run test — verify pass**

```bash
cd prop && flutter test test/emulators/dircon_emulator_test.dart
```

Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd prop
git add lib/emulators/dircon_emulator.dart test/emulators/dircon_emulator_test.dart
git commit -m "feat(emulator): expose retrofitMode, localAddress, activeDefinition"
```

---

## Task 4: Bump submodule pointer in the outer repo

**Files:**
- Modify: `prop` submodule pointer (auto via `git add prop`)

- [ ] **Step 1: Stage submodule update**

```bash
cd /Users/boni/Developer/Flutter/swift_control
git add prop
git status
```

Expected: `modified: prop (new commits)` shown.

- [ ] **Step 2: Commit**

```bash
git commit -m "chore(prop): bump submodule for ProxyBike/FitnessBike listenable exposure"
```

---

## Task 5: Add Proxy settings to `core.settings`

**Files:**
- Modify: `lib/utils/settings/settings.dart`
- Test: `test/utils/settings/settings_proxy_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/utils/settings/settings_proxy_test.dart`:

```dart
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
  });

  test('bike weight defaults to 10.0 kg', () {
    expect(settings.getProxyBikeWeightKg(), 10.0);
  });

  test('rider weight defaults to 75.0 kg', () {
    expect(settings.getProxyRiderWeightKg(), 75.0);
  });

  test('grade smoothing defaults to true', () {
    expect(settings.getProxyGradeSmoothing(), true);
  });

  test('virtual shifting mode defaults to targetPower', () {
    expect(settings.getProxyVirtualShiftingMode(), VirtualShiftingMode.targetPower);
  });

  test('setters persist values', () async {
    await settings.setProxyBikeWeightKg(8.5);
    await settings.setProxyRiderWeightKg(72.0);
    await settings.setProxyGradeSmoothing(false);
    await settings.setProxyVirtualShiftingMode(VirtualShiftingMode.trackResistance);

    expect(settings.getProxyBikeWeightKg(), closeTo(8.5, 0.01));
    expect(settings.getProxyRiderWeightKg(), closeTo(72.0, 0.01));
    expect(settings.getProxyGradeSmoothing(), isFalse);
    expect(settings.getProxyVirtualShiftingMode(), VirtualShiftingMode.trackResistance);
  });
}
```

- [ ] **Step 2: Run test — verify failure**

```bash
flutter test test/utils/settings/settings_proxy_test.dart
```

Expected: compile errors on `getProxyBikeWeightKg`, etc.

- [ ] **Step 3: Add setters/getters**

Append inside the `Settings` class in `lib/utils/settings/settings.dart`, just above the final closing `}`:

```dart
  // Proxy / retrofit bike settings
  double getProxyBikeWeightKg() =>
      (prefs.getDouble('proxy_bike_weight_kg') ?? 10.0).clamp(1.0, 50.0);

  Future<void> setProxyBikeWeightKg(double kg) async {
    await prefs.setDouble('proxy_bike_weight_kg', kg.clamp(1.0, 50.0));
  }

  double getProxyRiderWeightKg() =>
      (prefs.getDouble('proxy_rider_weight_kg') ?? 75.0).clamp(20.0, 200.0);

  Future<void> setProxyRiderWeightKg(double kg) async {
    await prefs.setDouble('proxy_rider_weight_kg', kg.clamp(20.0, 200.0));
  }

  bool getProxyGradeSmoothing() =>
      prefs.getBool('proxy_grade_smoothing') ?? true;

  Future<void> setProxyGradeSmoothing(bool enabled) async {
    await prefs.setBool('proxy_grade_smoothing', enabled);
  }

  VirtualShiftingMode getProxyVirtualShiftingMode() {
    final s = prefs.getString('proxy_vs_mode');
    return VirtualShiftingMode.values
            .firstOrNullWhere((e) => e.name == s) ??
        VirtualShiftingMode.targetPower;
  }

  Future<void> setProxyVirtualShiftingMode(VirtualShiftingMode mode) async {
    await prefs.setString('proxy_vs_mode', mode.name);
  }
```

Add this import at the top:
```dart
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
```

- [ ] **Step 4: Run test — verify pass**

```bash
flutter test test/utils/settings/settings_proxy_test.dart
```

Expected: 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/settings/settings.dart test/utils/settings/settings_proxy_test.dart
git commit -m "feat(settings): add proxy bike/rider weight, grade smoothing, VS mode"
```

---

## Task 6: Build `StepperControl` reusable widget

**Files:**
- Create: `lib/widgets/ui/stepper_control.dart`
- Test: `test/widgets/ui/stepper_control_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/ui/stepper_control_test.dart`:

```dart
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('StepperControl renders value label and + / - buttons', (tester) async {
    double current = 10.0;
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: StatefulBuilder(
            builder: (context, setState) => StepperControl(
              value: current,
              step: 0.5,
              min: 5.0,
              max: 20.0,
              format: (v) => '${v.toStringAsFixed(1)} kg',
              onChanged: (v) => setState(() => current = v),
            ),
          ),
        ),
      ),
    );

    expect(find.text('10.0 kg'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stepper-plus')));
    await tester.pumpAndSettle();
    expect(find.text('10.5 kg'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stepper-minus')));
    await tester.tap(find.byKey(const ValueKey('stepper-minus')));
    await tester.pumpAndSettle();
    expect(find.text('9.5 kg'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test — verify failure**

```bash
flutter test test/widgets/ui/stepper_control_test.dart
```

Expected: file not found / import error.

- [ ] **Step 3: Implement widget**

Create `lib/widgets/ui/stepper_control.dart`:

```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

class StepperControl extends StatelessWidget {
  final double value;
  final double step;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const StepperControl({
    super.key,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  double _clamp(double v) => v < min ? min : (v > max ? max : v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.ghost(
            key: const ValueKey('stepper-minus'),
            icon: const Icon(LucideIcons.minus, size: 14),
            onPressed: value > min ? () => onChanged(_clamp(value - step)) : null,
          ),
          SizedBox(
            width: 64,
            child: Center(
              child: Text(
                format(value),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton.ghost(
            key: const ValueKey('stepper-plus'),
            icon: const Icon(LucideIcons.plus, size: 14),
            onPressed: value < max ? () => onChanged(_clamp(value + step)) : null,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test — verify pass**

```bash
flutter test test/widgets/ui/stepper_control_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/ui/stepper_control.dart test/widgets/ui/stepper_control_test.dart
git commit -m "feat(ui): add StepperControl reusable widget"
```

---

## Task 7: Build `MetricCard` reusable widget

**Files:**
- Create: `lib/pages/proxy_device_details/metric_card.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value; // null → "--"
  final String unit;

  const MetricCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 6,
              children: [
                Icon(icon, size: 14, color: iconColor),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: cs.mutedForeground,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 4,
              children: [
                Text(
                  value ?? '--',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/proxy_device_details/metric_card.dart
git commit -m "feat(ui): add MetricCard widget"
```

(No test needed — purely presentational; exercised via the page widget test in Task 13.)

---

## Task 8: Build `LiveMetricsSection`

**Files:**
- Create: `lib/pages/proxy_device_details/live_metrics_section.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class LiveMetricsSection extends StatelessWidget {
  final ProxyDevice device;
  const LiveMetricsSection({super.key, required this.device});

  ProxyBikeDefinition? get _def =>
      device.emulator.activeDefinition is ProxyBikeDefinition
          ? device.emulator.activeDefinition as ProxyBikeDefinition
          : null;

  @override
  Widget build(BuildContext context) {
    final def = _def;
    if (def == null) {
      return const SizedBox.shrink();
    }
    return Column(
      spacing: 10,
      children: [
        Row(
          spacing: 10,
          children: [
            _bind<int?>(def.powerW, (v) => MetricCard(
                  icon: LucideIcons.zap,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'POWER',
                  value: v?.toString(),
                  unit: 'W',
                )),
            _bind<int?>(def.heartRateBpm, (v) => MetricCard(
                  icon: LucideIcons.heart,
                  iconColor: const Color(0xFFEF4444),
                  label: 'HEART',
                  value: v?.toString(),
                  unit: 'bpm',
                )),
          ],
        ),
        Row(
          spacing: 10,
          children: [
            _bind<int?>(def.cadenceRpm, (v) => MetricCard(
                  icon: LucideIcons.rotateCw,
                  iconColor: const Color(0xFF8B5CF6),
                  label: 'CADENCE',
                  value: v?.toString(),
                  unit: 'rpm',
                )),
            _bind<double?>(def.speedKph, (v) => MetricCard(
                  icon: LucideIcons.gauge,
                  iconColor: const Color(0xFF0EA5E9),
                  label: 'SPEED',
                  value: v?.toStringAsFixed(1),
                  unit: 'km/h',
                )),
          ],
        ),
      ],
    );
  }

  Widget _bind<T>(ValueListenable<T> ln, Widget Function(T) build) {
    return ValueListenableBuilder<T>(
      valueListenable: ln,
      builder: (_, v, __) => build(v),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/proxy_device_details/live_metrics_section.dart
git commit -m "feat(proxy-details): add LiveMetricsSection"
```

---

## Task 9: Build `ConnectionCard` (mode picker + bridge viz)

**Files:**
- Create: `lib/pages/proxy_device_details/connection_card.dart`

This card replaces both the "RetrofitBanner" and the inline mode picker that used to live in `ProxyDevice.showInformation`. When disconnected it shows the `Select<RetrofitMode>` + Connect button. When connected it shows the BT → WiFi bridge visualisation.

- [ ] **Step 1: Create the widget**

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ConnectionCard extends StatefulWidget {
  final ProxyDevice device;
  const ConnectionCard({super.key, required this.device});

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  RetrofitMode _pendingMode = RetrofitMode.proxy;

  List<RetrofitMode> get _allowedModes => [
        RetrofitMode.proxy,
        if (widget.device.scanResult.services
            .any((s) => s == FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID))
          RetrofitMode.wifi,
        RetrofitMode.bluetooth,
      ];

  @override
  Widget build(BuildContext context) {
    final emulator = widget.device.emulator;
    return ValueListenableBuilder<bool>(
      valueListenable: emulator.isStarted,
      builder: (context, started, _) {
        if (!widget.device.isConnected && !started) {
          return _disconnectedCard(emulator);
        }
        return _connectedCard(emulator);
      },
    );
  }

  Widget _card({required Color bg, required Color border, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _disconnectedCard(DirconEmulator emulator) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      bg: cs.card,
      border: cs.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            'Retrofit mode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: cs.mutedForeground,
            ),
          ),
          Select<RetrofitMode>(
            value: _pendingMode,
            itemBuilder: (context, value) => Text(value.label),
            constraints: const BoxConstraints(minWidth: 220),
            popup: SelectPopup(
              items: SelectItemList(
                children: [
                  for (final m in _allowedModes)
                    SelectItemButton(value: m, child: Text(m.label)),
                ],
              ),
            ).call,
            onChanged: (m) {
              if (m == null) return;
              setState(() => _pendingMode = m);
            },
          ),
          Text(
            _modeHint(_pendingMode),
            style: TextStyle(fontSize: 12, color: cs.mutedForeground),
          ),
          Button.primary(
            onPressed: () {
              emulator.setRetrofitMode(_pendingMode);
              widget.device.connect();
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Widget _connectedCard(DirconEmulator emulator) {
    return ValueListenableBuilder<RetrofitMode>(
      valueListenable: emulator.retrofitMode,
      builder: (context, mode, _) {
        final (bg, border, iconBg, iconColor, title) = switch (mode) {
          RetrofitMode.proxy => (
            const Color(0xFFF0FDF4),
            const Color(0xFFBBF7D0),
            const Color(0xFFDCFCE7),
            const Color(0xFF059669),
            'Proxy active — mirroring via WiFi',
          ),
          RetrofitMode.wifi => (
            const Color(0xFFEFF6FF),
            const Color(0xFFBFDBFE),
            const Color(0xFFDBEAFE),
            const Color(0xFF1D4ED8),
            'Retrofit (WiFi) — virtual shifting enabled',
          ),
          RetrofitMode.bluetooth => (
            const Color(0xFFFDF4FF),
            const Color(0xFFF5D0FE),
            const Color(0xFFFAE8FF),
            const Color(0xFFA21CAF),
            'Retrofit (Bluetooth) — virtual shifting enabled',
          ),
        };
        final usesWifi = mode != RetrofitMode.bluetooth;
        return _card(
          bg: bg,
          border: border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Row(
                spacing: 12,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.radioTower, size: 18, color: iconColor),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (usesWifi) _bridgeRow(emulator, iconColor),
            ],
          ),
        );
      },
    );
  }

  Widget _bridgeRow(DirconEmulator emulator, Color accent) {
    final deviceName = widget.device.scanResult.name ?? 'Device';
    return ValueListenableBuilder<String?>(
      valueListenable: emulator.localAddress,
      builder: (context, ip, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            spacing: 10,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(LucideIcons.bluetooth, size: 16, color: accent),
                  Flexible(
                    child: Text(
                      deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 4,
                  children: [
                    _dot(accent),
                    _dot(accent),
                    _dot(accent),
                    Icon(LucideIcons.arrowRight, size: 14, color: accent),
                    _dot(accent),
                    _dot(accent),
                    _dot(accent),
                  ],
                ),
              ),
              Row(
                spacing: 6,
                children: [
                  Icon(LucideIcons.wifi, size: 16, color: accent),
                  Text(
                    ip ?? '—',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot(Color color) => Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
      );

  String _modeHint(RetrofitMode mode) => switch (mode) {
        RetrofitMode.proxy => 'Mirrors your trainer over WiFi without touching gear logic.',
        RetrofitMode.wifi => 'Adds virtual shifting to a WiFi-advertised trainer.',
        RetrofitMode.bluetooth =>
          'Advertises a virtual FTMS device with a 24-step gear table.',
      };
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/proxy_device_details/connection_card.dart
git commit -m "feat(proxy-details): add ConnectionCard with mode picker and WiFi bridge viz"
```

---

## Task 9B: Strip retrofit mode / Connect UI from `ProxyDevice.showInformation`

The mode picker + Connect button + debug button + WiFi status icon currently rendered by `showInformation` now live in `ConnectionCard` inside the details page. The device list (ProxyPage) should only show the base device info row so the tappable list item stays clean.

**Files:**
- Modify: `lib/bluetooth/devices/proxy/proxy_device.dart`

- [ ] **Step 1: Replace the `showInformation` override**

In `lib/bluetooth/devices/proxy/proxy_device.dart`, replace the entire `showInformation` method (currently lines 38–116) with:

```dart
  @override
  Widget showInformation(BuildContext context, {required bool showFull}) {
    return super.showInformation(context, showFull: showFull);
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    if (!isConnected) return const [];
    return [
      ValueListenableBuilder<bool>(
        valueListenable: emulator.isConnected,
        builder: (context, connected, _) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(
              Icons.wifi,
              size: 12,
              color: connected
                  ? const Color(0xFF22C55E)
                  : Theme.of(context).colorScheme.mutedForeground,
            ),
            Text(
              connected ? 'Bridge live' : 'Bridge idle',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    ];
  }
```

Remove now-unused imports from the top of the file (`status_icon.dart`, `foundation.dart` if no other use, `universal_ble`, `shadcn_flutter`'s `Select`/`Button` etc.). Keep:
```dart
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:flutter/material.dart' show Icon, Icons, Row, Text;
import 'package:flutter/widgets.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
```

Also delete the now-unused `RetrofitMode _pendingMode = RetrofitMode.proxy;` field (it's no longer referenced here — `ConnectionCard` owns that local state).

The `processCharacteristic`, `handleServices`, `connect`, and `disconnect` overrides are unchanged.

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/bluetooth/devices/proxy/proxy_device.dart
```

Expected: no errors. Fix any unused-import warnings inline.

- [ ] **Step 3: Commit**

```bash
git add lib/bluetooth/devices/proxy/proxy_device.dart
git commit -m "refactor(proxy): move retrofit mode picker out of showInformation"
```

---

## Task 10: Build `GearHeroCard` (retrofit only)

**Files:**
- Create: `lib/pages/proxy_device_details/gear_hero_card.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GearHeroCard extends StatelessWidget {
  final FitnessBikeDefinition definition;
  const GearHeroCard({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        spacing: 12,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(LucideIcons.cog, size: 14, color: const Color(0xFF94A3B8)),
                  Text(
                    'CURRENT GEAR',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<TrainerMode>(
                valueListenable: definition.trainerMode,
                builder: (_, mode, __) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E40AF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _modeLabel(mode),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDBEAFE),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 28,
            children: [
              _shiftButton(
                icon: LucideIcons.minus,
                filled: false,
                onTap: () => definition.shiftDown(),
              ),
              ValueListenableBuilder<int>(
                valueListenable: definition.currentGear,
                builder: (_, gear, __) => Column(
                  spacing: 2,
                  children: [
                    Text(
                      '$gear',
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -2,
                        color: Colors.white,
                      ),
                    ),
                    ValueListenableBuilder<double>(
                      valueListenable: definition.gearRatio,
                      builder: (_, ratio, __) => Text(
                        'of 24  ·  ratio ${ratio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _shiftButton(
                icon: LucideIcons.plus,
                filled: true,
                onTap: () => definition.shiftUp(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shiftButton({
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          shape: BoxShape.circle,
          border: filled
              ? null
              : Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Icon(icon, size: 22, color: filled ? Colors.white : const Color(0xFFE2E8F0)),
      ),
    );
  }

  String _modeLabel(TrainerMode mode) => switch (mode) {
        TrainerMode.ergMode => 'ERG',
        TrainerMode.simMode => 'SIM',
        TrainerMode.simModeVirtualShifting => 'Virtual Shifting',
      };
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/proxy_device_details/gear_hero_card.dart
git commit -m "feat(proxy-details): add GearHeroCard"
```

---

## Task 11: Build `TrainerSettingsSection`

**Files:**
- Create: `lib/pages/proxy_device_details/trainer_settings_section.dart`

- [ ] **Step 1: Create the widget**

```dart
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TrainerSettingsSection extends StatefulWidget {
  final FitnessBikeDefinition definition;
  const TrainerSettingsSection({super.key, required this.definition});

  @override
  State<TrainerSettingsSection> createState() => _TrainerSettingsSectionState();
}

class _TrainerSettingsSectionState extends State<TrainerSettingsSection> {
  FitnessBikeDefinition get def => widget.definition;

  @override
  void initState() {
    super.initState();
    // Hydrate definition defaults from persisted settings.
    def.setBicycleWeightKg(core.settings.getProxyBikeWeightKg());
    def.setRiderWeightKg(core.settings.getProxyRiderWeightKg());
    def.setGradeSmoothingEnabled(core.settings.getProxyGradeSmoothing());
    def.setVirtualShiftingMode(core.settings.getProxyVirtualShiftingMode());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _vsModeCard(),
        _bikeWeightCard(),
        _riderWeightCard(),
        _gradeSmoothingCard(),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.border),
        ),
        child: child,
      );

  Widget _vsModeCard() {
    return ValueListenableBuilder<VirtualShiftingMode>(
      valueListenable: def.virtualShiftingMode,
      builder: (context, mode, _) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            _labelBlock(
              title: 'Virtual Shifting Mode',
              subtitle: 'How resistance is computed per gear',
            ),
            Row(
              spacing: 2,
              children: [
                _seg('Target Power', VirtualShiftingMode.targetPower, mode),
                _seg('Track Resist.', VirtualShiftingMode.trackResistance, mode),
                _seg('Basic', VirtualShiftingMode.basicResistance, mode),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, VirtualShiftingMode value, VirtualShiftingMode current) {
    final active = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          def.setVirtualShiftingMode(value);
          await core.settings.setProxyVirtualShiftingMode(value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.card
                : Theme.of(context).colorScheme.muted,
            borderRadius: BorderRadius.circular(6),
            border: active
                ? Border.all(color: Theme.of(context).colorScheme.border)
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active
                    ? Theme.of(context).colorScheme.foreground
                    : Theme.of(context).colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bikeWeightCard() {
    return ValueListenableBuilder<double>(
      valueListenable: def.bicycleWeightKg,
      builder: (context, kg, _) => _card(
        child: Row(
          children: [
            Icon(LucideIcons.bike, size: 18),
            const Gap(12),
            Expanded(
              child: _labelBlock(
                title: 'Bike Weight',
                subtitle: 'Used for virtual shifting physics',
              ),
            ),
            StepperControl(
              value: kg,
              step: 0.5,
              min: 1.0,
              max: 50.0,
              format: (v) => '${v.toStringAsFixed(1)} kg',
              onChanged: (v) async {
                def.setBicycleWeightKg(v);
                await core.settings.setProxyBikeWeightKg(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _riderWeightCard() {
    return ValueListenableBuilder<double>(
      valueListenable: def.riderWeightKg,
      builder: (context, kg, _) => _card(
        child: Row(
          children: [
            Icon(LucideIcons.user, size: 18),
            const Gap(12),
            Expanded(
              child: _labelBlock(
                title: 'Rider Weight',
                subtitle: 'Used for virtual shifting physics',
              ),
            ),
            StepperControl(
              value: kg,
              step: 1.0,
              min: 20.0,
              max: 200.0,
              format: (v) => '${v.toStringAsFixed(0)} kg',
              onChanged: (v) async {
                def.setRiderWeightKg(v);
                await core.settings.setProxyRiderWeightKg(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradeSmoothingCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: def.gradeSmoothingEnabled,
      builder: (context, enabled, _) => _card(
        child: Row(
          children: [
            Icon(LucideIcons.waves, size: 18),
            const Gap(12),
            Expanded(
              child: _labelBlock(
                title: 'Grade Smoothing',
                subtitle: 'Averages sudden slope changes',
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (v) async {
                def.setGradeSmoothingEnabled(v);
                await core.settings.setProxyGradeSmoothing(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelBlock({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/proxy_device_details/trainer_settings_section.dart
git commit -m "feat(proxy-details): add TrainerSettingsSection"
```

---

## Task 12: Build `ProxyDeviceDetailsPage` root

**Files:**
- Create: `lib/pages/proxy_device_details.dart`

- [ ] **Step 1: Create the page**

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/pages/proxy_device_details/gear_hero_card.dart';
import 'package:bike_control/pages/proxy_device_details/live_metrics_section.dart';
import 'package:bike_control/pages/proxy_device_details/trainer_settings_section.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ProxyDeviceDetailsPage extends StatefulWidget {
  final ProxyDevice device;
  const ProxyDeviceDetailsPage({super.key, required this.device});

  @override
  State<ProxyDeviceDetailsPage> createState() => _ProxyDeviceDetailsPageState();
}

class _ProxyDeviceDetailsPageState extends State<ProxyDeviceDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: const Text(
            'Smart Trainer',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          trailing: [
            IconButton.ghost(
              icon: Icon(LucideIcons.x, size: 22, color: Theme.of(context).colorScheme.mutedForeground),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          backgroundColor: Theme.of(context).colorScheme.background,
        ),
        const Divider(),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                _deviceCard(),
                ConnectionCard(device: device),
                _gearSection(),
                LiveMetricsSection(device: device),
                _settingsSection(),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deviceCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.border),
      ),
      child: widget.device.showInformation(context, showFull: true),
    );
  }

  Widget _gearSection() {
    final def = widget.device.emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return const SizedBox.shrink();
    return GearHeroCard(definition: def);
  }

  Widget _settingsSection() {
    final def = widget.device.emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        const Text(
          'Trainer Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        TrainerSettingsSection(definition: def),
      ],
    );
  }

  Widget _actions() {
    final device = widget.device;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        LoadingWidget(
          futureCallback: () async {
            await core.connection.disconnect(device, forget: true, persistForget: false);
            if (mounted) Navigator.of(context).pop();
          },
          renderChild: (isLoading, tap) => Button(
            style: ButtonStyle.outline(),
            onPressed: tap,
            leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.bluetoothOff, size: 18),
            child: const Text('Disconnect'),
          ),
        ),
        LoadingWidget(
          futureCallback: () async {
            await core.connection.disconnect(device, forget: true, persistForget: true);
            if (mounted) Navigator.of(context).pop();
          },
          renderChild: (isLoading, tap) => Button(
            style: ButtonStyle.destructive(),
            onPressed: tap,
            leading: isLoading ? const SmallProgressIndicator() : const Icon(LucideIcons.trash2, size: 18),
            child: const Text('Disconnect & forget'),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify compile**

```bash
flutter analyze lib/pages/proxy_device_details.dart
```

Expected: no errors (warnings about unused imports etc. OK to fix inline).

- [ ] **Step 3: Commit**

```bash
git add lib/pages/proxy_device_details.dart
git commit -m "feat(proxy-details): add ProxyDeviceDetailsPage root"
```

---

## Task 13: Widget test for `ProxyDeviceDetailsPage`

**Files:**
- Create: `test/pages/proxy_device_details_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders header with Smart Trainer title', (tester) async {
    final device = ProxyDevice(BleDevice(deviceId: 'x', name: 'Wahoo KICKR'));

    await tester.pumpWidget(
      ShadcnApp(home: ProxyDeviceDetailsPage(device: device)),
    );
    await tester.pump();

    expect(find.text('Smart Trainer'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Disconnect & forget'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test**

```bash
flutter test test/pages/proxy_device_details_test.dart
```

Expected: PASS. If the test fails because `core.settings` / `core.connection` aren't initialized, wrap the offending calls with null-safe guards in the page and rerun. The disconnect buttons need `core.connection`, but the widget only touches it on tap, so pure render should pass.

- [ ] **Step 3: Commit**

```bash
git add test/pages/proxy_device_details_test.dart
git commit -m "test(proxy-details): add smoke widget test"
```

---

## Task 14: Route `ProxyPage` to new details page

**Files:**
- Modify: `lib/pages/proxy.dart`

- [ ] **Step 1: Update import and navigation**

Replace line 3:
```dart
import 'package:bike_control/pages/controller_settings.dart';
```
with:
```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
```

Replace line 54:
```dart
      await context.push(ControllerSettingsPage(device: device));
```
with:
```dart
      if (device is ProxyDevice) {
        await context.push(ProxyDeviceDetailsPage(device: device));
      } else {
        await context.push(ControllerSettingsPage(device: device));
      }
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/pages/proxy.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/proxy.dart
git commit -m "feat(proxy): route proxy device taps to new details page"
```

---

## Task 15: End-to-end verification

- [ ] **Step 1: Run full analyzer**

```bash
flutter analyze
```

Expected: no new errors in modified/created files.

- [ ] **Step 2: Run full test suite**

```bash
flutter test
cd prop && flutter test && cd ..
```

Expected: all tests PASS.

- [ ] **Step 3: Manual smoke test**

Launch the app on one platform (macOS or a connected device/simulator):
```bash
flutter run -d macos
```

Connect a Proxy device in the app, open it from the Proxy list, confirm:
- Header shows "Smart Trainer"
- Device card shows name/connected/signal
- Retrofit banner shows the correct mode
- Live metrics render with "--" when no data; values when data arrives
- If in retrofit Bluetooth mode: gear hero shows gear number and responds to tapping ± buttons; trainer settings section shows VS mode / weights / grade smoothing
- Disconnect buttons pop the page after disconnect

Note in your handoff whether each bullet above was verified.

- [ ] **Step 4: Final commit (only if manual adjustments were needed)**

Only commit if you made follow-up tweaks during smoke testing:
```bash
git add -p
git commit -m "fix(proxy-details): post-smoke-test adjustments"
```

---

## Self-Review Checklist Outcome

- ✅ Spec coverage: design sections (device card, connection card w/ mode picker + bridge viz, gear hero, 4 live metrics, VS mode segmented, weights, grade smoothing, disconnect actions) all map to Tasks 7–12.
- ✅ Retrofit mode picker + Connect button moved from `ProxyDevice.showInformation` into `ConnectionCard` (Task 9B strips the old UI so the device list stays clean).
- ✅ BT → WiFi bridge visualisation renders when connected in a WiFi-based retrofit mode (`proxy` or `wifi`) using the new `DirconEmulator.localAddress` listenable.
- ✅ Type consistency: `FitnessBikeDefinition`, `ProxyBikeDefinition`, `VirtualShiftingMode`, `TrainerMode`, `RetrofitMode` names used consistently across tasks.
- ✅ No placeholders: every code block is complete; no "TBD" / "add appropriate X" phrasing.
- ⚠️ The Gear Ratio slider shown in the Pencil design is intentionally **not** implemented — the gear is controlled by the shift buttons in `GearHeroCard`, and an arbitrary slider would conflict with the 24-step gear table. If a raw-ratio override is desired later, it is a separate follow-up.
