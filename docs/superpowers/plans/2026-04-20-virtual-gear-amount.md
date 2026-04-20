# `virtualGearAmount` per Trainer App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the virtual-shifting gear count follow the active trainer app (24 for Zwift and everyone else, 30 for MyWhoosh) by exposing a `virtualGearAmount` on `SupportedApp` and plumbing it into `FitnessBikeDefinition`.

**Architecture:** `SupportedApp` gains a `virtualGearAmount` getter (default 24, MyWhoosh overrides to 30). `FitnessBikeDefinition` promotes `maxGear` from `static const 24` to a mutable instance field with a `setMaxGear(int)` method that regenerates default ratios (by interpolating the 24-entry Zwift baseline), recomputes `neutralGear`, clamps `currentGear`, and re-seeds `gearRatios`. `ProxyDevice.applyTrainerSettings` and `TrainerSettingsSection._applyActiveConfigToDefinition` call `setMaxGear(core.settings.getTrainerApp()?.virtualGearAmount ?? 24)` on every apply, so switching the trainer app live re-sizes the shifter. `ShiftingConfig.fromJson` drops its hard 24-entry guard in favour of accepting any 1–30 entry list; downstream consumers that actually need the right length keep validating.

**Tech Stack:** Flutter, Dart; `prop` submodule (`FitnessBikeDefinition`).

---

## File Structure

Modified:
- `lib/utils/keymap/apps/supported_app.dart` — add `int get virtualGearAmount => 24;` on the abstract class.
- `lib/utils/keymap/apps/my_whoosh.dart` — override the getter to return 30.
- `prop/lib/emulators/definitions/fitness_bike_definition.dart` — make `maxGear`/`neutralGear` instance fields; add `setMaxGear`; generalise `defaultGearRatios` into a `static List<double> defaultGearRatiosFor(int count)` helper with a 24-entry baseline; update `mapMyWhooshGradeToGear` to accept `maxGear`.
- `lib/models/shifting_config.dart` — relax the 24-entry `gearRatios` guard in `fromJson` to accept any 1–30 entry list.
- `test/models/shifting_config_test.dart` — replace the "wrong-length drop" test with a bounds test (0 and 31 entries drop; 24 and 30 are both accepted).
- `prop/test/emulators/fitness_bike_definition_test.dart` — update `mapMyWhooshGradeToGear` tests to pass an explicit `maxGear`; add a `setMaxGear` test group.
- `lib/bluetooth/devices/proxy/proxy_device.dart` — in `applyTrainerSettings`, call `def.setMaxGear(app.virtualGearAmount)` before reading `gearRatios`.
- `lib/pages/proxy_device_details/trainer_settings_section.dart` — in `_applyActiveConfigToDefinition`, do the same; re-apply when the trainer app changes.
- `lib/pages/proxy_device_details/gear_ratios_editor_page.dart` — scale presets to the current `maxGear`.

Not touched (intentionally):
- `ShiftingConfig` schema: no new field; the stored `gearRatios` list can legally have any length and the consumer clamps/re-seeds on apply.
- Supabase schema: unchanged.
- The Zwift-Sync path: unaffected (its gear-ratio arithmetic already works on arbitrary values).

---

## Task 1: `virtualGearAmount` on `SupportedApp`, overridden in MyWhoosh

**Files:**
- Modify: `lib/utils/keymap/apps/supported_app.dart`
- Modify: `lib/utils/keymap/apps/my_whoosh.dart`
- Test: `test/utils/keymap/supported_app_virtual_gear_amount_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `test/utils/keymap/supported_app_virtual_gear_amount_test.dart`:

```dart
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportedApp.virtualGearAmount', () {
    test('defaults to 24 for every app except MyWhoosh', () {
      expect(Zwift().virtualGearAmount, 24);
      expect(Rouvy().virtualGearAmount, 24);
      expect(TrainingPeaks().virtualGearAmount, 24);
      expect(OpenBikeControl().virtualGearAmount, 24);
    });

    test('MyWhoosh reports 30 virtual gears', () {
      expect(MyWhoosh().virtualGearAmount, 30);
    });
  });
}
```

- [ ] **Step 2: Run the failing test**

Run: `flutter test test/utils/keymap/supported_app_virtual_gear_amount_test.dart`
Expected: FAIL with `NoSuchMethodError` or "The getter 'virtualGearAmount' isn't defined".

- [ ] **Step 3: Add the getter to the abstract class**

In `lib/utils/keymap/apps/supported_app.dart`, immediately below the existing `inGameActionsMapping` getter (around line 55), add:

```dart
  /// How many virtual gears this trainer app exposes in its shifter. Drives
  /// [FitnessBikeDefinition.maxGear] when this app is active. Default 24
  /// (Zwift's virtual shifting). Override on apps that use a different count
  /// (e.g. MyWhoosh → 30).
  int get virtualGearAmount => 24;
```

- [ ] **Step 4: Override in MyWhoosh**

In `lib/utils/keymap/apps/my_whoosh.dart`, immediately after the existing `@override String? get logoAsset => 'assets/mywhoosh.png';` block (around line 16), add:

```dart
  @override
  int get virtualGearAmount => 30;
```

- [ ] **Step 5: Run the tests and verify they pass**

Run: `flutter test test/utils/keymap/supported_app_virtual_gear_amount_test.dart`
Expected: All 2 tests pass.

- [ ] **Step 6: Run analyzer**

Run: `flutter analyze lib/utils/keymap/apps/supported_app.dart lib/utils/keymap/apps/my_whoosh.dart test/utils/keymap/supported_app_virtual_gear_amount_test.dart`
Expected: No new issues.

- [ ] **Step 7: Commit**

```bash
git add lib/utils/keymap/apps/supported_app.dart lib/utils/keymap/apps/my_whoosh.dart test/utils/keymap/supported_app_virtual_gear_amount_test.dart
git commit -m "feat(keymap): add virtualGearAmount on SupportedApp (MyWhoosh=30, default=24)"
```

---

## Task 2: `FitnessBikeDefinition.setMaxGear` + scalable default ratios

**Files:**
- Modify: `prop/lib/emulators/definitions/fitness_bike_definition.dart`
- Test: `prop/test/emulators/fitness_bike_definition_test.dart`

Work happens inside the `prop` submodule. The submodule path is `/Users/boni/Developer/Flutter/swift_control/prop` — `cd` into it for its tests and a dedicated commit, then bump the pointer from the outer repo.

- [ ] **Step 1: Write the failing tests for `defaultGearRatiosFor`**

In `prop/test/emulators/fitness_bike_definition_test.dart`, append a new group immediately before the final closing `}` of `main()`:

```dart
  group('FitnessBikeDefinition.defaultGearRatiosFor', () {
    test('returns the historical 24-entry table unchanged', () {
      expect(
        FitnessBikeDefinition.defaultGearRatiosFor(24),
        FitnessBikeDefinition.defaultGearRatios,
      );
    });

    test('interpolates smoothly for a different count', () {
      final thirty = FitnessBikeDefinition.defaultGearRatiosFor(30);
      expect(thirty.length, 30);
      expect(thirty.first, closeTo(FitnessBikeDefinition.defaultGearRatios.first, 1e-9));
      expect(thirty.last, closeTo(FitnessBikeDefinition.defaultGearRatios.last, 1e-9));
      for (var i = 1; i < thirty.length; i++) {
        expect(thirty[i], greaterThanOrEqualTo(thirty[i - 1]));
      }
    });

    test('throws on non-positive count', () {
      expect(() => FitnessBikeDefinition.defaultGearRatiosFor(0), throwsArgumentError);
      expect(() => FitnessBikeDefinition.defaultGearRatiosFor(-1), throwsArgumentError);
    });

    test('returns a single mid-range ratio for count = 1', () {
      final one = FitnessBikeDefinition.defaultGearRatiosFor(1);
      expect(one.length, 1);
      expect(one.single, FitnessBikeDefinition.defaultGearRatios.first);
    });
  });

  group('FitnessBikeDefinition.setMaxGear', () {
    FitnessBikeDefinition make() => FitnessBikeDefinition(
      connectedDevice: BleDevice(deviceId: 't', name: 'T'),
      connectedDeviceServices: const <BleService>[],
      data: ValueNotifier<String>(''),
    );

    test('starts at 24 with neutral at 12', () {
      final def = make();
      expect(def.maxGear, 24);
      expect(def.neutralGear, 12);
      expect(def.currentGear.value, 12);
      expect(def.gearRatios.value.length, 24);
    });

    test('grows to 30 and resizes the gear table + neutral gear', () {
      final def = make();
      def.setMaxGear(30);
      expect(def.maxGear, 30);
      expect(def.neutralGear, 15);
      expect(def.gearRatios.value.length, 30);
      expect(def.currentGear.value, 15);
    });

    test('clamps currentGear when shrinking below it', () {
      final def = make();
      def.setMaxGear(30);
      def.setTargetGear(28);
      expect(def.currentGear.value, 28);
      def.setMaxGear(24);
      expect(def.maxGear, 24);
      expect(def.currentGear.value, 24);
    });

    test('keeps currentGear when it still fits after shrink', () {
      final def = make();
      def.setMaxGear(30);
      def.setTargetGear(10);
      def.setMaxGear(24);
      expect(def.currentGear.value, 10);
    });

    test('no-ops when the new count matches the current one', () {
      final def = make();
      final before = def.gearRatios.value;
      def.setMaxGear(24);
      expect(identical(def.gearRatios.value, before), isTrue);
    });

    test('rejects counts outside [1, 30]', () {
      final def = make();
      expect(() => def.setMaxGear(0), throwsArgumentError);
      expect(() => def.setMaxGear(31), throwsArgumentError);
    });
  });
```

- [ ] **Step 2: Update existing `mapMyWhooshGradeToGear` tests to pass `maxGear`**

Within `prop/test/emulators/fitness_bike_definition_test.dart`, find the existing group `MyWhoosh FTMS grade → gear mapping`. Replace all five of its `expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(...))` calls so the function now takes a `maxGear` second argument. Use 30 for every call (MyWhoosh's natural count) except the "clamps to [1, maxGear]" case where we explicitly vary maxGear.

The full replacement for the group:

```dart
  group('MyWhoosh FTMS grade → gear mapping', () {
    test('captured MyWhoosh samples round to the reported gears (30-gear MyWhoosh)', () {
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(302, 30), 17);
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(404, 30), 18);
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(496, 30), 19);
    });

    test('gear 14 sits at 0 % grade regardless of maxGear', () {
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(0, 24), 14);
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(0, 30), 14);
    });

    test('negative grades map to lower gears', () {
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(-100, 30), 13);
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(-1300, 30), 1);
    });

    test('grades beyond the table clamp to [1, maxGear]', () {
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(-10000, 30), 1);
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(10000, 30), 30);
      // When the app has a smaller shifter (e.g. Zwift), clamp respects it.
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(10000, 24), 24);
    });

    test('rounds to the nearest gear step', () {
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(50, 30), 15);
      expect(FitnessBikeDefinition.mapMyWhooshGradeToGear(49, 30), 14);
    });
  });
```

- [ ] **Step 3: Run the failing tests**

From `/Users/boni/Developer/Flutter/swift_control/prop`:

Run: `flutter test test/emulators/fitness_bike_definition_test.dart`
Expected: FAILs on the new `defaultGearRatiosFor`, `setMaxGear`, and updated `mapMyWhooshGradeToGear` tests (either compile errors for the new getters/functions, or assertion failures).

- [ ] **Step 4: Modify `FitnessBikeDefinition` — promote `maxGear`/`neutralGear` to instance fields**

In `prop/lib/emulators/definitions/fitness_bike_definition.dart`, find the block:

```dart
  static const int minGear = 1;
  static const int maxGear = 24;
  static const int neutralGear = 12;

  // Backwards-compatible aliases for legacy internal references.
  static const int _minGear = minGear;
  static const int _maxGear = maxGear;
  static const int _neutralGear = neutralGear;
```

Replace with:

```dart
  static const int minGear = 1;
  static const int _minGear = minGear;

  /// Default virtual-shifter size when no trainer app has been selected.
  /// Overridden at runtime via [setMaxGear] when the active app reports a
  /// different `virtualGearAmount`.
  static const int defaultMaxGear = 24;
  static const int defaultNeutralGear = 12;

  /// Inclusive upper bound for [maxGear]. Guards against obviously wrong
  /// values from configs or app definitions. MyWhoosh uses 30 (our highest
  /// supported app); the cap matches so unknown apps that report more gears
  /// than we know how to handle are rejected loudly rather than silently.
  static const int _absoluteMaxGear = 30;

  int _maxGear = defaultMaxGear;
  int _neutralGear = defaultNeutralGear;
  int get maxGear => _maxGear;
  int get neutralGear => _neutralGear;
```

- [ ] **Step 5: Replace the static `defaultGearRatios` usage with a baseline-plus-helper**

In the same file, immediately after the existing `static const List<double> defaultGearRatios = [ 0.75, ..., 5.49 ];` block, add:

```dart
  /// Generate a default gear-ratio table of the requested [count], interpolating
  /// linearly from the 24-entry Zwift baseline. Returns [defaultGearRatios]
  /// unchanged when `count == 24`.
  static List<double> defaultGearRatiosFor(int count) {
    if (count <= 0) {
      throw ArgumentError('gear count must be positive, got $count');
    }
    if (count == defaultGearRatios.length) return defaultGearRatios;
    if (count == 1) return [defaultGearRatios.first];
    final last = defaultGearRatios.length - 1;
    return List<double>.generate(count, (i) {
      final t = i / (count - 1) * last;
      final lo = t.floor();
      final hi = (lo + 1).clamp(0, last);
      final frac = t - lo;
      return defaultGearRatios[lo] + (defaultGearRatios[hi] - defaultGearRatios[lo]) * frac;
    });
  }
```

- [ ] **Step 6: Adjust `_gearRatiosN` / `_currentGearN` initializers and `setGearRatios` length check**

Find the fields around line 252:

```dart
  final ValueNotifier<List<double>> _gearRatiosN = ValueNotifier<List<double>>(
    List<double>.unmodifiable(defaultGearRatios),
  );
  ValueListenable<List<double>> get gearRatios => _gearRatiosN;
  List<double> get _gearRatios => _gearRatiosN.value;

  final ValueNotifier<int> _currentGearN = ValueNotifier(_neutralGear);
  ValueListenable<int> get currentGear => _currentGearN;
  int get _currentGear => _currentGearN.value;
  set _currentGear(int v) => _currentGearN.value = v;

  late final ValueNotifier<double> _gearRatioN = ValueNotifier(_gearRatios[_currentGear - 1]);
  ValueListenable<double> get gearRatio => _gearRatioN;
```

Replace with:

```dart
  final ValueNotifier<List<double>> _gearRatiosN = ValueNotifier<List<double>>(
    List<double>.unmodifiable(defaultGearRatios),
  );
  ValueListenable<List<double>> get gearRatios => _gearRatiosN;
  List<double> get _gearRatios => _gearRatiosN.value;

  final ValueNotifier<int> _currentGearN = ValueNotifier(defaultNeutralGear);
  ValueListenable<int> get currentGear => _currentGearN;
  int get _currentGear => _currentGearN.value;
  set _currentGear(int v) => _currentGearN.value = v;

  late final ValueNotifier<double> _gearRatioN = ValueNotifier(_gearRatios[_currentGear - 1]);
  ValueListenable<double> get gearRatio => _gearRatioN;
```

(`_neutralGear` → `defaultNeutralGear` so the initializer uses a true constant rather than an instance field, which Dart doesn't allow at declaration time.)

- [ ] **Step 7: Add `setMaxGear`**

Find the existing `setTargetGear` method (around line 1050) and immediately above it, add:

```dart
  /// Resize the virtual shifter to [count] gears. Regenerates the default
  /// ratio table when the current table's length no longer matches, and
  /// clamps [currentGear] into the new range. Called when the active
  /// trainer app changes (Zwift = 24, MyWhoosh = 30).
  void setMaxGear(int count) {
    if (count < _minGear || count > _absoluteMaxGear) {
      throw ArgumentError('maxGear must be in [$_minGear, $_absoluteMaxGear], got $count');
    }
    if (count == _maxGear) return;
    _maxGear = count;
    _neutralGear = (count / 2).ceil();
    if (_gearRatiosN.value.length != count) {
      _gearRatiosN.value = List<double>.unmodifiable(defaultGearRatiosFor(count));
    }
    final clampedCurrent = _currentGear.clamp(_minGear, _maxGear);
    if (clampedCurrent != _currentGear) {
      _currentGearN.value = clampedCurrent;
    }
    _gearRatioN.value = _gearRatios[_currentGear - 1];
    _updateSimModeResistance();
  }
```

- [ ] **Step 8: Update `setGearRatios` length validation**

Find the existing `setGearRatios` method:

```dart
  void setGearRatios(List<double> ratios) {
    if (ratios.length != _maxGear) {
      throw ArgumentError('gear ratios must have exactly $_maxGear entries; got ${ratios.length}');
    }
    ...
```

No body change needed — `_maxGear` is now an instance field, so the existing check naturally uses the current `maxGear`. Verify no code relies on `_maxGear` being a compile-time constant.

- [ ] **Step 9: Update `mapMyWhooshGradeToGear` to accept `maxGear` as a second argument**

Find the existing static method (around line 545):

```dart
  static int mapMyWhooshGradeToGear(int grade001Pct) {
    const gradePerGear = 100;
    const neutralGear = 14;
    final raw = (grade001Pct / gradePerGear).round() + neutralGear;
    return raw.clamp(_minGear, _maxGear);
  }
```

Replace with:

```dart
  static int mapMyWhooshGradeToGear(int grade001Pct, int maxGear) {
    const gradePerGear = 100;
    const myWhooshNeutralGear = 14;
    final raw = (grade001Pct / gradePerGear).round() + myWhooshNeutralGear;
    return raw.clamp(_minGear, maxGear);
  }
```

Find the only call site (in `_processFtmsWrite`, around line 482):

```dart
_applyInferredGear(mapMyWhooshGradeToGear(_ftmsGrade));
```

Change to:

```dart
_applyInferredGear(mapMyWhooshGradeToGear(_ftmsGrade, _maxGear));
```

- [ ] **Step 10: Resolve any remaining `_maxGear` / `_neutralGear` constant references**

Search the file: `grep -n "_maxGear\|_neutralGear" prop/lib/emulators/definitions/fitness_bike_definition.dart`.

Every match should now resolve to the instance field (which is fine). The most common uses:
- `getGearOffset() => _currentGear - _neutralGear;` — unchanged, uses the instance field.
- `setTargetGear(...)`, `setGearRatio(...)`, `scaleGearRatios(...)` — all correctly read the instance field.

The only exception is the initializer of `_currentGearN` itself, which Step 6 already changed to `defaultNeutralGear`.

- [ ] **Step 11: Run the tests**

From `/Users/boni/Developer/Flutter/swift_control/prop`:

Run: `flutter test test/emulators/fitness_bike_definition_test.dart`
Expected: All tests (new + updated + pre-existing) pass.

- [ ] **Step 12: Run analyzer inside the submodule**

Run: `flutter analyze lib/emulators/definitions/fitness_bike_definition.dart test/emulators/fitness_bike_definition_test.dart`
Expected: No new issues beyond the pre-existing `constant_identifier_names` / unused-helper warnings the submodule already has.

- [ ] **Step 13: Commit inside the submodule**

```bash
cd /Users/boni/Developer/Flutter/swift_control/prop
git add lib/emulators/definitions/fitness_bike_definition.dart test/emulators/fitness_bike_definition_test.dart
git commit -m "feat(fitness-bike): make maxGear configurable via setMaxGear"
```

- [ ] **Step 14: Bump the submodule pointer in the outer repo**

```bash
cd /Users/boni/Developer/Flutter/swift_control
git add prop
git commit -m "chore(prop): bump submodule for configurable maxGear"
```

---

## Task 3: Relax `ShiftingConfig.fromJson` gearRatios length guard

**Files:**
- Modify: `lib/models/shifting_config.dart`
- Test: `test/models/shifting_config_test.dart`

- [ ] **Step 1: Rewrite the existing wrong-length test to assert the new bounds**

In `test/models/shifting_config_test.dart`, replace the test:

```dart
    test('fromJson drops wrong-length gearRatios lists', () {
      final restored = ShiftingConfig.fromJson({
        'name': 'Partial',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': [0.75, 1.0, 1.5],
      });
      expect(restored.gearRatios, isNull);
    });
```

with:

```dart
    test('fromJson accepts any 1..30 entry gearRatios list', () {
      final restored24 = ShiftingConfig.fromJson({
        'name': '24g',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': List<double>.filled(24, 1.0),
      });
      expect(restored24.gearRatios?.length, 24);

      final restored30 = ShiftingConfig.fromJson({
        'name': '30g',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': List<double>.filled(30, 1.0),
      });
      expect(restored30.gearRatios?.length, 30);

      final restored3 = ShiftingConfig.fromJson({
        'name': '3g',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': [0.75, 1.0, 1.5],
      });
      expect(restored3.gearRatios?.length, 3);
    });

    test('fromJson drops empty and out-of-bounds gearRatios lists', () {
      ShiftingConfig call(List raw) => ShiftingConfig.fromJson({
        'name': 'x',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
        'gearRatios': raw,
      });
      expect(call([]).gearRatios, isNull);
      expect(call(List<double>.filled(31, 1.0)).gearRatios, isNull);
    });
```

- [ ] **Step 2: Run the failing tests**

Run: `flutter test test/models/shifting_config_test.dart`
Expected: The new tests fail (the model still enforces `length == FitnessBikeDefinition.maxGear`).

- [ ] **Step 3: Relax the `fromJson` guard**

In `lib/models/shifting_config.dart`, find:

```dart
      gearRatios: (parsedRatios != null && parsedRatios.length == FitnessBikeDefinition.maxGear) ? parsedRatios : null,
```

Replace with:

```dart
      gearRatios: (parsedRatios != null && parsedRatios.isNotEmpty && parsedRatios.length <= _gearRatiosMaxLength) ? parsedRatios : null,
```

Near the top of the `ShiftingConfig` class (alongside the other `static const` limits), add:

```dart
  static const int _gearRatiosMaxLength = 30;
```

Because `FitnessBikeDefinition.maxGear` is no longer a compile-time constant, also drop the now-unused reference if no other line in the file uses it. Verify with `grep -n "FitnessBikeDefinition" lib/models/shifting_config.dart` — the import on line 1 can stay (we still need `VirtualShiftingMode`), but the `FitnessBikeDefinition.maxGear` expression should be gone.

- [ ] **Step 4: Run tests**

Run: `flutter test test/models/shifting_config_test.dart`
Expected: All tests pass (the existing 7, plus the two replacement tests).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/models/shifting_config.dart test/models/shifting_config_test.dart`
Expected: No new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/models/shifting_config.dart test/models/shifting_config_test.dart
git commit -m "refactor(shifting): accept any 1..30 gear-ratios list per config"
```

---

## Task 4: Wire `virtualGearAmount` into `ProxyDevice.applyTrainerSettings`

**Files:**
- Modify: `lib/bluetooth/devices/proxy/proxy_device.dart`

- [ ] **Step 1: Update `applyTrainerSettings` to resize the shifter first**

In `lib/bluetooth/devices/proxy/proxy_device.dart`, replace the existing `applyTrainerSettings`:

```dart
  void applyTrainerSettings() {
    final def = emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return;
    final cfg = core.shiftingConfigs.activeFor(trainerKey);
    def.setBicycleWeightKg(cfg.bikeWeightKg);
    def.setRiderWeightKg(cfg.riderWeightKg);
    def.setGradeSmoothingEnabled(cfg.gradeSmoothing);
    def.setVirtualShiftingMode(cfg.mode);
    if (cfg.gearRatios != null) {
      def.setGearRatios(cfg.gearRatios!);
    }
  }
```

with:

```dart
  void applyTrainerSettings() {
    final def = emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return;
    final app = core.settings.getTrainerApp();
    def.setMaxGear(app?.virtualGearAmount ?? FitnessBikeDefinition.defaultMaxGear);
    final cfg = core.shiftingConfigs.activeFor(trainerKey);
    def.setBicycleWeightKg(cfg.bikeWeightKg);
    def.setRiderWeightKg(cfg.riderWeightKg);
    def.setGradeSmoothingEnabled(cfg.gradeSmoothing);
    def.setVirtualShiftingMode(cfg.mode);
    if (cfg.gearRatios != null && cfg.gearRatios!.length == def.maxGear) {
      def.setGearRatios(cfg.gearRatios!);
    }
  }
```

(The `length == def.maxGear` guard silently ignores mismatched gear-ratio lists — the definition keeps its freshly-regenerated `defaultGearRatiosFor(maxGear)` table. This avoids a throw when a user saves a 24-entry config under Zwift and then switches the active trainer app to MyWhoosh.)

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze lib/bluetooth/devices/proxy/proxy_device.dart`
Expected: No new issues.

- [ ] **Step 3: Commit**

```bash
git add lib/bluetooth/devices/proxy/proxy_device.dart
git commit -m "feat(proxy): resize virtual shifter to trainer app's virtualGearAmount on apply"
```

---

## Task 5: Keep the live UI in sync via `TrainerSettingsSection._applyActiveConfigToDefinition`

**Files:**
- Modify: `lib/pages/proxy_device_details/trainer_settings_section.dart`

- [ ] **Step 1: Update `_applyActiveConfigToDefinition` to resize before seeding**

In `lib/pages/proxy_device_details/trainer_settings_section.dart`, find:

```dart
  void _applyActiveConfigToDefinition() {
    final cfg = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    def.setBicycleWeightKg(cfg.bikeWeightKg);
    def.setRiderWeightKg(cfg.riderWeightKg);
    def.setGradeSmoothingEnabled(cfg.gradeSmoothing);
    def.setVirtualShiftingMode(cfg.mode);
    def.setGearRatios(cfg.gearRatios ?? FitnessBikeDefinition.defaultGearRatios);
  }
```

Replace with:

```dart
  void _applyActiveConfigToDefinition() {
    final app = core.settings.getTrainerApp();
    def.setMaxGear(app?.virtualGearAmount ?? FitnessBikeDefinition.defaultMaxGear);
    final cfg = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    def.setBicycleWeightKg(cfg.bikeWeightKg);
    def.setRiderWeightKg(cfg.riderWeightKg);
    def.setGradeSmoothingEnabled(cfg.gradeSmoothing);
    def.setVirtualShiftingMode(cfg.mode);
    final ratios = cfg.gearRatios;
    def.setGearRatios(
      ratios != null && ratios.length == def.maxGear
          ? ratios
          : FitnessBikeDefinition.defaultGearRatiosFor(def.maxGear),
    );
  }
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/pages/proxy_device_details/trainer_settings_section.dart`
Expected: No new issues.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/proxy_device_details/trainer_settings_section.dart
git commit -m "feat(trainer-settings): resize shifter to active app's virtualGearAmount"
```

---

## Task 6: Scale the gear-ratios editor presets to the current `maxGear`

**Files:**
- Modify: `lib/pages/proxy_device_details/gear_ratios_editor_page.dart`

- [ ] **Step 1: Parameterise `_evenSteps` and rebuild presets against `def.maxGear`**

In `lib/pages/proxy_device_details/gear_ratios_editor_page.dart`, find:

```dart
  // ---------- Presets ----------

  static List<double> _evenSteps(double lo, double hi) =>
      List<double>.generate(24, (i) => lerpDouble(lo, hi, i / 23)!);
```

Replace with:

```dart
  // ---------- Presets ----------

  static List<double> _evenSteps(double lo, double hi, int count) =>
      List<double>.generate(count, (i) => lerpDouble(lo, hi, count == 1 ? 0.0 : i / (count - 1))!);
```

Find:

```dart
  static final List<_Preset> _presetList = [
    _Preset(
      label: 'Default',
      range: '0.75–5.49',
      values: List<double>.unmodifiable(FitnessBikeDefinition.defaultGearRatios),
    ),
    _Preset(
      label: 'Compact',
      range: '1.00–4.00',
      values: List<double>.unmodifiable(_evenSteps(1.00, 4.00)),
    ),
    _Preset(
      label: 'Wide',
      range: '0.50–6.50',
      values: List<double>.unmodifiable(_evenSteps(0.50, 6.50)),
    ),
    _Preset(
      label: '1\u00D7',
      range: '2.20–4.20',
      values: List<double>.unmodifiable(_evenSteps(2.20, 4.20)),
    ),
  ];
```

Replace with:

```dart
  List<_Preset> _presetsForCount(int count) => [
    _Preset(
      label: 'Default',
      range: '0.75–5.49',
      values: List<double>.unmodifiable(FitnessBikeDefinition.defaultGearRatiosFor(count)),
    ),
    _Preset(
      label: 'Compact',
      range: '1.00–4.00',
      values: List<double>.unmodifiable(_evenSteps(1.00, 4.00, count)),
    ),
    _Preset(
      label: 'Wide',
      range: '0.50–6.50',
      values: List<double>.unmodifiable(_evenSteps(0.50, 6.50, count)),
    ),
    _Preset(
      label: '1\u00D7',
      range: '2.20–4.20',
      values: List<double>.unmodifiable(_evenSteps(2.20, 4.20, count)),
    ),
  ];
```

(Note: the field changed from `static final` to an instance method; presets are now recomputed each build.)

Then find the `_presets(BuildContext context)` method and the preset-rendering `Row`. Replace the reference `_presetList` with `_presetsForCount(def.maxGear)`:

Before:
```dart
        ValueListenableBuilder<List<double>>(
          valueListenable: def.gearRatios,
          builder: (context, current, _) {
            return Row(
              spacing: 8,
              children: _presetList
                  .map((p) => Expanded(child: _presetButton(context, p, current)))
                  .toList(),
            );
          },
        ),
```

After:
```dart
        ValueListenableBuilder<List<double>>(
          valueListenable: def.gearRatios,
          builder: (context, current, _) {
            return Row(
              spacing: 8,
              children: _presetsForCount(def.maxGear)
                  .map((p) => Expanded(child: _presetButton(context, p, current)))
                  .toList(),
            );
          },
        ),
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/pages/proxy_device_details/gear_ratios_editor_page.dart`
Expected: No new issues.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/proxy_device_details/gear_ratios_editor_page.dart
git commit -m "feat(gear-editor): scale presets to the current virtualGearAmount"
```

---

## Task 7: Re-apply settings when the trainer app changes mid-session

**Files:**
- Modify: `lib/utils/settings/settings.dart`
- Modify: `lib/bluetooth/devices/proxy/proxy_device.dart`

**Goal:** When the user picks a different trainer app in the keymap screen, every currently connected `ProxyDevice` should resize its shifter immediately, not wait for the next reconnect.

- [ ] **Step 1: Confirm where `setKeyMap` lives**

Search the file: `grep -n "setKeyMap" lib/utils/settings/settings.dart`.

Expected: the method is defined around line 129 and persists the active app.

- [ ] **Step 2: Extend `setKeyMap` to re-apply trainer settings on every connected proxy**

Locate the existing method:

```dart
  Future<void> setKeyMap(SupportedApp app) async {
    if (app is CustomApp) {
      await prefs.setStringList('customapp_${app.profileName}', app.encodeKeymap());
    }
    await prefs.setString('app', app.name);
    _triggerAutoSync();
  }
```

Replace with:

```dart
  Future<void> setKeyMap(SupportedApp app) async {
    if (app is CustomApp) {
      await prefs.setStringList('customapp_${app.profileName}', app.encodeKeymap());
    }
    await prefs.setString('app', app.name);
    for (final device in core.connection.devices.whereType<ProxyDevice>()) {
      device.applyTrainerSettings();
    }
    _triggerAutoSync();
  }
```

Add the required import at the top of `lib/utils/settings/settings.dart`:

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
```

- [ ] **Step 3: Manual sanity check via analyzer**

Run: `flutter analyze lib/utils/settings/settings.dart`
Expected: No new issues. (If there's an import cycle warning — Settings imports ProxyDevice which imports Core which imports Settings — Dart allows cycles and the analyzer does not flag them; continue.)

- [ ] **Step 4: Commit**

```bash
git add lib/utils/settings/settings.dart
git commit -m "feat(settings): re-apply trainer settings on connected proxies when keymap changes"
```

---

## Task 8: Final verification

- [ ] **Step 1: Run the whole test suite**

Run: `flutter test`
Expected: All previously-passing tests still pass. The pre-existing `screenshot_test.dart` and `cycplus_bc2_test.dart` failures (unrelated) remain; nothing else should regress.

- [ ] **Step 2: Run the submodule's test suite**

From `/Users/boni/Developer/Flutter/swift_control/prop`:

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 3: Run analyzer on the whole project**

Run: `flutter analyze`
Expected: Only pre-existing info / warning messages remain. No new issues.

- [ ] **Step 4: Manual smoke test (mobile / desktop as available)**

Run the app. With a proxy trainer connected:

1. Select Zwift as the trainer app → open the proxy device details page → open the gear-ratios editor → confirm 24 rows are shown and the presets produce 24-entry tables.
2. Switch to MyWhoosh → immediately (no reconnect required) the editor rebuilds to 30 rows; current gear clamps to ≤30; `setTargetGear(30)` works; `setTargetGear(31)` clamps to 30.
3. Switch back to Zwift → editor rebuilds to 24 rows; `currentGear` clamps if it was >24.

Report observed behaviour; no code change required here unless something diverges from the above.

---

## Self-review

**Spec coverage**
- "field called virtualGearAmount to SupportedApp, default 24" → Task 1 (abstract class getter with default 24).
- "Zwift → 24" → Task 1 (Zwift inherits the default; test pins it).
- "MyWhoosh has 30" → Task 1 (override).
- "depending on the selected trainer app adjust the amount of available gears in the virtual shifting logic accordingly" → Tasks 2 (setMaxGear + scalable ratios), 4 (ProxyDevice apply), 5 (TrainerSettingsSection), 6 (editor presets), 7 (live switch).

**Placeholder scan**
No TBDs, no "add appropriate error handling", no "Similar to Task N". Every code-producing step carries the full code.

**Type consistency**
- `int get virtualGearAmount` consistent across SupportedApp and its override.
- `FitnessBikeDefinition.setMaxGear(int)` consistent in Task 2 (definition), Task 4 (ProxyDevice), Task 5 (TrainerSettingsSection), Task 7 (via `applyTrainerSettings`).
- `FitnessBikeDefinition.defaultGearRatiosFor(int)` consistent in Task 2 (definition), Task 5 (fallback), Task 6 (editor preset "Default").
- `mapMyWhooshGradeToGear(int grade, int maxGear)` consistent in Task 2 (definition + tests) and the in-file call site.
- `ShiftingConfig.fromJson` bound is `[1, 30]` in both model (Task 3) and `FitnessBikeDefinition._absoluteMaxGear` (Task 2).
