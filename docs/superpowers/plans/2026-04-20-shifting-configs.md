# ShiftingConfig Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single global `proxy_*` virtual-shifting settings with a `ShiftingConfig` model. Each trainer device gets its own list of named configs with one active. The active config feeds the `FitnessBikeDefinition`, persists locally, and syncs via `UserSettings`.

**Architecture:** Introduce a plain Dart `ShiftingConfig` data class (name + trainer key + VS mode + weights + grade smoothing + optional 24-step gear ratios). All configs live in a single flat `List<ShiftingConfig>` owned by a new `ShiftingConfigsController` on `core`. Persistence: the full list is stored as one SharedPreferences JSON string and synced to Supabase via a new top-level `shifting_configs` jsonb column on the `user_settings` table. The ProxyDevice reads its active config from the controller via its `deviceName` key; the TrainerSettingsSection writes into the active config through the controller. UI adds a config picker to `ProxyDeviceDetailsPage` modelled after the keymap picker.

**External dependency:** Requires adding a `shifting_configs jsonb` column to the `user_settings` Supabase table before Task 10 lands in production.

**Tech Stack:** Flutter, `shadcn_flutter` (`Select`, `Dialog`), `shared_preferences`, `supabase_flutter` (existing sync infrastructure).

---

## Design Decisions (locked in — flag early if any are wrong)

| Question | Choice |
|---|---|
| One config or multiple per trainer? | **Multiple.** A flat `List<ShiftingConfig>`; each entry carries `trainerKey` and an `isActive` flag. Invariant: at most one `isActive == true` per `trainerKey`. |
| Trainer identity | **`device.name`** (e.g. `"KICKR BIKE 1234"`). Names are more portable across platforms than BLE device IDs, which iOS randomises. If a device has no name, fall back to `device.uniqueId`. |
| Storage surface | **Single SharedPreferences key `shifting_configs`** holding the JSON-encoded full list. Simpler than one key per trainer, round-trips easily to `UserSettings`. |
| Sync payload | **New top-level `shifting_configs` jsonb column** on `user_settings`. Schema migration owned outside this plan; Dart side reads/writes the column as a JSON array. |
| Migration | **None.** Legacy `proxy_*` SharedPreferences keys are dropped without porting their values — users start with an empty `ShiftingConfig` list and a synthesised default. |
| Active-config selection UI | Dropdown `Select<ShiftingConfig>` on `ProxyDeviceDetailsPage` above the gear card with "+ New" and "Manage" buttons, mirroring `customize.dart`'s app picker. |
| Removing legacy `getProxy*`/`setProxy*` | Yes, once all call sites migrate. |

If *any* of the above is wrong, stop and redirect before implementing.

---

## File Structure

Created:

- `lib/models/shifting_config.dart` — `ShiftingConfig` + JSON + defaults + `copyWith`.
- `lib/services/shifting_configs_controller.dart` — `ShiftingConfigsController` (list owner, getters/setters, active selection, migration).
- `lib/pages/proxy_device_details/shifting_config_picker.dart` — the dropdown + manage dialog widget.
- `test/models/shifting_config_test.dart` — JSON + copyWith tests.
- `test/services/shifting_configs_controller_test.dart` — list behaviour, active invariant, migration.

Modified:

- `lib/utils/core.dart` — expose `core.shiftingConfigs` (the controller).
- `lib/utils/settings/settings.dart` — remove `getProxy*`/`setProxy*` and clamp constants; keep the clamp constants exposed as static fields on `ShiftingConfig`.
- `lib/models/user_settings.dart` — add `shiftingConfigs: List<ShiftingConfig>?` field + JSON in/out.
- `lib/repositories/user_settings_repository.dart` — read/write the list through `keymaps['_shifting_configs']`.
- `lib/bluetooth/devices/proxy/proxy_device.dart` — `applyTrainerSettings()` reads from the active config.
- `lib/pages/proxy_device_details/trainer_settings_section.dart` — read/write through active config.
- `lib/pages/proxy_device_details/gear_ratios_editor_page.dart` — same.
- `lib/pages/proxy_device_details.dart` — mount `ShiftingConfigPicker` above `_gearSection()`.
- `lib/pages/trainer_feedback.dart` — use active config when building the diagnostic payload.

---

## Task 1: `ShiftingConfig` data class + JSON

**Files:**
- Create: `lib/models/shifting_config.dart`
- Test: `test/models/shifting_config_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/models/shifting_config_test.dart`:

```dart
import 'package:bike_control/models/shifting_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

void main() {
  group('ShiftingConfig', () {
    test('default() populates sensible values', () {
      final cfg = ShiftingConfig.defaults(trainerKey: 'KICKR');
      expect(cfg.name, 'Default');
      expect(cfg.trainerKey, 'KICKR');
      expect(cfg.isActive, true);
      expect(cfg.mode, VirtualShiftingMode.targetPower);
      expect(cfg.bikeWeightKg, 10.0);
      expect(cfg.riderWeightKg, 75.0);
      expect(cfg.gradeSmoothing, true);
      expect(cfg.gearRatios, isNull);
    });

    test('toJson/fromJson round-trips', () {
      final cfg = ShiftingConfig(
        name: 'Race',
        trainerKey: 'KICKR',
        isActive: true,
        mode: VirtualShiftingMode.trackResistance,
        bikeWeightKg: 8.2,
        riderWeightKg: 68.5,
        gradeSmoothing: false,
        gearRatios: [0.75, 1.0, 1.5],
      );
      final restored = ShiftingConfig.fromJson(cfg.toJson());
      expect(restored, cfg);
    });

    test('fromJson tolerates missing optional fields', () {
      final restored = ShiftingConfig.fromJson({
        'name': 'Minimal',
        'trainerKey': 'KICKR',
        'isActive': false,
        'mode': 'targetPower',
        'bikeWeightKg': 10.0,
        'riderWeightKg': 75.0,
        'gradeSmoothing': true,
      });
      expect(restored.gearRatios, isNull);
    });

    test('copyWith overrides specific fields', () {
      final base = ShiftingConfig.defaults(trainerKey: 'KICKR');
      final renamed = base.copyWith(name: 'Race');
      expect(renamed.name, 'Race');
      expect(renamed.trainerKey, base.trainerKey);
      expect(renamed.mode, base.mode);
    });

    test('values are clamped into legal ranges via fromJson', () {
      final cfg = ShiftingConfig.fromJson({
        'name': 'OutOfRange',
        'trainerKey': 'KICKR',
        'isActive': true,
        'mode': 'targetPower',
        'bikeWeightKg': 999.0,
        'riderWeightKg': 5.0,
        'gradeSmoothing': true,
      });
      expect(cfg.bikeWeightKg, lessThanOrEqualTo(ShiftingConfig.bikeWeightMaxKg));
      expect(cfg.riderWeightKg, greaterThanOrEqualTo(ShiftingConfig.riderWeightMinKg));
    });
  });
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `flutter test test/models/shifting_config_test.dart`
Expected: FAIL with "Target of URI doesn't exist" for `shifting_config.dart`.

- [ ] **Step 3: Create the model**

Create `lib/models/shifting_config.dart`:

```dart
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

class ShiftingConfig {
  static const double bikeWeightDefaultKg = 10.0;
  static const double bikeWeightMinKg = 1.0;
  static const double bikeWeightMaxKg = 50.0;
  static const double riderWeightDefaultKg = 75.0;
  static const double riderWeightMinKg = 20.0;
  static const double riderWeightMaxKg = 200.0;
  static const VirtualShiftingMode modeDefault = VirtualShiftingMode.targetPower;

  final String name;
  final String trainerKey;
  final bool isActive;
  final VirtualShiftingMode mode;
  final double bikeWeightKg;
  final double riderWeightKg;
  final bool gradeSmoothing;
  final List<double>? gearRatios;

  const ShiftingConfig({
    required this.name,
    required this.trainerKey,
    required this.isActive,
    required this.mode,
    required this.bikeWeightKg,
    required this.riderWeightKg,
    required this.gradeSmoothing,
    this.gearRatios,
  });

  factory ShiftingConfig.defaults({required String trainerKey, String name = 'Default', bool isActive = true}) {
    return ShiftingConfig(
      name: name,
      trainerKey: trainerKey,
      isActive: isActive,
      mode: modeDefault,
      bikeWeightKg: bikeWeightDefaultKg,
      riderWeightKg: riderWeightDefaultKg,
      gradeSmoothing: true,
    );
  }

  factory ShiftingConfig.fromJson(Map<String, dynamic> json) {
    final rawMode = json['mode'] as String?;
    final parsedMode = VirtualShiftingMode.values.firstWhere(
      (e) => e.name == rawMode,
      orElse: () => modeDefault,
    );
    final bike = (json['bikeWeightKg'] as num?)?.toDouble() ?? bikeWeightDefaultKg;
    final rider = (json['riderWeightKg'] as num?)?.toDouble() ?? riderWeightDefaultKg;
    final rawRatios = json['gearRatios'] as List?;
    final parsedRatios = rawRatios == null
        ? null
        : rawRatios.whereType<num>().map((e) => e.toDouble()).toList();
    return ShiftingConfig(
      name: (json['name'] as String?) ?? 'Default',
      trainerKey: (json['trainerKey'] as String?) ?? '__unknown__',
      isActive: (json['isActive'] as bool?) ?? false,
      mode: parsedMode,
      bikeWeightKg: bike.clamp(bikeWeightMinKg, bikeWeightMaxKg),
      riderWeightKg: rider.clamp(riderWeightMinKg, riderWeightMaxKg),
      gradeSmoothing: (json['gradeSmoothing'] as bool?) ?? true,
      gearRatios: (parsedRatios != null && parsedRatios.length == FitnessBikeDefinition.maxGear) ? parsedRatios : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'trainerKey': trainerKey,
    'isActive': isActive,
    'mode': mode.name,
    'bikeWeightKg': bikeWeightKg,
    'riderWeightKg': riderWeightKg,
    'gradeSmoothing': gradeSmoothing,
    if (gearRatios != null) 'gearRatios': gearRatios,
  };

  ShiftingConfig copyWith({
    String? name,
    String? trainerKey,
    bool? isActive,
    VirtualShiftingMode? mode,
    double? bikeWeightKg,
    double? riderWeightKg,
    bool? gradeSmoothing,
    List<double>? gearRatios,
    bool clearGearRatios = false,
  }) {
    return ShiftingConfig(
      name: name ?? this.name,
      trainerKey: trainerKey ?? this.trainerKey,
      isActive: isActive ?? this.isActive,
      mode: mode ?? this.mode,
      bikeWeightKg: bikeWeightKg ?? this.bikeWeightKg,
      riderWeightKg: riderWeightKg ?? this.riderWeightKg,
      gradeSmoothing: gradeSmoothing ?? this.gradeSmoothing,
      gearRatios: clearGearRatios ? null : (gearRatios ?? this.gearRatios),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShiftingConfig &&
          name == other.name &&
          trainerKey == other.trainerKey &&
          isActive == other.isActive &&
          mode == other.mode &&
          bikeWeightKg == other.bikeWeightKg &&
          riderWeightKg == other.riderWeightKg &&
          gradeSmoothing == other.gradeSmoothing &&
          _listEquals(gearRatios, other.gearRatios));

  @override
  int get hashCode => Object.hash(
    name,
    trainerKey,
    isActive,
    mode,
    bikeWeightKg,
    riderWeightKg,
    gradeSmoothing,
    gearRatios == null ? null : Object.hashAll(gearRatios!),
  );

  static bool _listEquals(List<double>? a, List<double>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `flutter test test/models/shifting_config_test.dart`
Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/models/shifting_config.dart test/models/shifting_config_test.dart
git commit -m "feat(shifting): add ShiftingConfig model with JSON round-trip"
```

---

## Task 2: `ShiftingConfigsController` — list owner, active invariant, persistence

**Files:**
- Create: `lib/services/shifting_configs_controller.dart`
- Test: `test/services/shifting_configs_controller_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/shifting_configs_controller_test.dart`:

```dart
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/services/shifting_configs_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ShiftingConfigsController> fresh() async {
    final prefs = await SharedPreferences.getInstance();
    final c = ShiftingConfigsController(prefs);
    await c.init();
    return c;
  }

  group('ShiftingConfigsController', () {
    test('starts empty when no storage is present', () async {
      final c = await fresh();
      expect(c.all, isEmpty);
    });

    test('activeFor returns a synthesised default when no config exists', () async {
      final c = await fresh();
      final active = c.activeFor('KICKR');
      expect(active.name, 'Default');
      expect(active.trainerKey, 'KICKR');
      expect(active.mode, VirtualShiftingMode.targetPower);
    });

    test('save persists and reload returns the saved config', () async {
      final c = await fresh();
      await c.upsert(
        ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(name: 'Race', bikeWeightKg: 8.2),
      );
      final prefs = await SharedPreferences.getInstance();
      final c2 = ShiftingConfigsController(prefs);
      await c2.init();
      final race = c2.configsFor('KICKR').firstWhere((e) => e.name == 'Race');
      expect(race.bikeWeightKg, 8.2);
    });

    test('setActive enforces at most one active per trainerKey', () async {
      final c = await fresh();
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(name: 'A'));
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR', isActive: false).copyWith(name: 'B'));
      await c.setActive(trainerKey: 'KICKR', name: 'B');
      final actives = c.configsFor('KICKR').where((e) => e.isActive).toList();
      expect(actives.length, 1);
      expect(actives.single.name, 'B');
    });

    test('remove prevents deleting the last config for a trainer', () async {
      final c = await fresh();
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR'));
      expect(() => c.remove(trainerKey: 'KICKR', name: 'Default'), throwsStateError);
    });

    test('remove re-elects a successor active when active is removed', () async {
      final c = await fresh();
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR').copyWith(name: 'A'));
      await c.upsert(ShiftingConfig.defaults(trainerKey: 'KICKR', isActive: false).copyWith(name: 'B'));
      await c.remove(trainerKey: 'KICKR', name: 'A');
      final remaining = c.configsFor('KICKR');
      expect(remaining.length, 1);
      expect(remaining.single.name, 'B');
      expect(remaining.single.isActive, true);
    });
  });
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `flutter test test/services/shifting_configs_controller_test.dart`
Expected: FAIL with "Target of URI doesn't exist" for `shifting_configs_controller.dart`.

*(Expected final count after step 4: 6 tests.)*

- [ ] **Step 3: Implement the controller**

Create `lib/services/shifting_configs_controller.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:bike_control/models/shifting_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShiftingConfigsController extends ChangeNotifier {
  static const String storageKey = 'shifting_configs';

  final SharedPreferences _prefs;
  final List<ShiftingConfig> _configs = [];

  ShiftingConfigsController(this._prefs);

  List<ShiftingConfig> get all => List.unmodifiable(_configs);

  List<ShiftingConfig> configsFor(String trainerKey) =>
      _configs.where((c) => c.trainerKey == trainerKey).toList(growable: false);

  ShiftingConfig activeFor(String trainerKey) {
    final forTrainer = configsFor(trainerKey);
    final active = forTrainer.where((c) => c.isActive);
    if (active.isNotEmpty) return active.first;
    if (forTrainer.isNotEmpty) return forTrainer.first;
    return ShiftingConfig.defaults(trainerKey: trainerKey);
  }

  Future<void> init() async {
    _configs
      ..clear()
      ..addAll(_readStored());
  }

  Future<void> upsert(ShiftingConfig config) async {
    final idx = _configs.indexWhere(
      (c) => c.trainerKey == config.trainerKey && c.name == config.name,
    );
    if (idx >= 0) {
      _configs[idx] = config;
    } else {
      _configs.add(config);
    }
    if (config.isActive) {
      _enforceSingleActive(config.trainerKey, config.name);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setActive({required String trainerKey, required String name}) async {
    for (var i = 0; i < _configs.length; i++) {
      final c = _configs[i];
      if (c.trainerKey != trainerKey) continue;
      _configs[i] = c.copyWith(isActive: c.name == name);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove({required String trainerKey, required String name}) async {
    final forTrainer = configsFor(trainerKey);
    if (forTrainer.length <= 1) {
      throw StateError('Cannot remove the last ShiftingConfig for trainer "$trainerKey"');
    }
    final removedWasActive = forTrainer.firstWhere((c) => c.name == name).isActive;
    _configs.removeWhere((c) => c.trainerKey == trainerKey && c.name == name);
    if (removedWasActive) {
      final survivors = configsFor(trainerKey);
      if (survivors.isNotEmpty) {
        final idx = _configs.indexOf(survivors.first);
        _configs[idx] = survivors.first.copyWith(isActive: true);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> rename({required String trainerKey, required String from, required String to}) async {
    final idx = _configs.indexWhere((c) => c.trainerKey == trainerKey && c.name == from);
    if (idx < 0) return;
    _configs[idx] = _configs[idx].copyWith(name: to);
    await _persist();
    notifyListeners();
  }

  Future<void> duplicate({required String trainerKey, required String sourceName, required String newName}) async {
    final source = _configs.firstWhere(
      (c) => c.trainerKey == trainerKey && c.name == sourceName,
      orElse: () => ShiftingConfig.defaults(trainerKey: trainerKey),
    );
    await upsert(source.copyWith(name: newName, isActive: false));
  }

  /// Replace the in-memory list from a synced payload and persist locally.
  Future<void> hydrateFromSync(List<ShiftingConfig> configs) async {
    _configs
      ..clear()
      ..addAll(configs);
    await _persist();
    notifyListeners();
  }

  /// Returns the current list as a JSON-encoded string, suitable for `UserSettings`.
  String toStoredJson() => jsonEncode(_configs.map((c) => c.toJson()).toList());

  /// Parses a JSON-encoded list produced by [toStoredJson].
  static List<ShiftingConfig> parseStoredJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ShiftingConfig.fromJson)
        .toList(growable: false);
  }

  void _enforceSingleActive(String trainerKey, String activeName) {
    for (var i = 0; i < _configs.length; i++) {
      final c = _configs[i];
      if (c.trainerKey != trainerKey) continue;
      final shouldBeActive = c.name == activeName;
      if (c.isActive != shouldBeActive) {
        _configs[i] = c.copyWith(isActive: shouldBeActive);
      }
    }
  }

  List<ShiftingConfig> _readStored() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return parseStoredJson(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(storageKey, toStoredJson());
  }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run: `flutter test test/services/shifting_configs_controller_test.dart`
Expected: All 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/services/shifting_configs_controller.dart test/services/shifting_configs_controller_test.dart
git commit -m "feat(shifting): add ShiftingConfigsController with active invariant"
```

---

## Task 3: Expose the controller on `core`

**Files:**
- Modify: `lib/utils/core.dart`

- [ ] **Step 1: Find where `core` exposes services**

Run: `grep -n "class Core\|  final\|SharedPreferences" lib/utils/core.dart`
Expected: Listing of existing fields to place `shiftingConfigs` next to, plus how `SharedPreferences` is obtained.

- [ ] **Step 2: Add the controller field and init it at startup**

In `lib/utils/core.dart`, add an import at the top:

```dart
import 'package:bike_control/services/shifting_configs_controller.dart';
```

Locate the `class Core` declaration and add a field next to the other services (e.g. alongside `settings`):

```dart
  late final ShiftingConfigsController shiftingConfigs;
```

Find the existing initialisation block (where `settings.init()` / `await prefs...` happen). Immediately after `await core.settings.init();` (which constructs SharedPreferences internally), add:

```dart
  shiftingConfigs = ShiftingConfigsController(core.settings.prefs);
  await shiftingConfigs.init();
```

(If `core.settings.prefs` is private, expose it via a getter `SharedPreferences get prefs => _prefs;` in `settings.dart` — the codebase already exposes `prefs` at the field level, see `settings.dart:204` reference in the repository.)

- [ ] **Step 3: Verify analyzer is clean**

Run: `flutter analyze lib/utils/core.dart lib/services/shifting_configs_controller.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/utils/core.dart
git commit -m "feat(shifting): mount ShiftingConfigsController on core"
```

---

## Task 4: Rewire `ProxyDevice.applyTrainerSettings()` onto the active config

**Files:**
- Modify: `lib/bluetooth/devices/proxy/proxy_device.dart`

- [ ] **Step 1: Read the current `applyTrainerSettings` + call sites**

Run: `grep -n "applyTrainerSettings\|getProxy\|rebindLegacyTrainerKey" lib/bluetooth/devices/proxy/proxy_device.dart`
Expected: shows the current implementation in `handleServices` that reads the legacy `core.settings.getProxy*` keys.

- [ ] **Step 2: Replace the body with active-config reads + legacy rebind**

In `lib/bluetooth/devices/proxy/proxy_device.dart`, locate the `applyTrainerSettings()` method:

```dart
  void applyTrainerSettings() {
    final def = emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return;
    def.setBicycleWeightKg(core.settings.getProxyBikeWeightKg());
    def.setRiderWeightKg(core.settings.getProxyRiderWeightKg());
    def.setGradeSmoothingEnabled(core.settings.getProxyGradeSmoothing());
    def.setVirtualShiftingMode(core.settings.getProxyVirtualShiftingMode());
    final persistedRatios = core.settings.getProxyGearRatios();
    if (persistedRatios != null) {
      def.setGearRatios(persistedRatios);
    }
  }
```

Replace with:

```dart
  String get trainerKey => scanResult.name ?? scanResult.deviceId;

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

(No new imports needed beyond the existing ones — `core.shiftingConfigs` is reached through the already-imported `utils/core.dart`.)

- [ ] **Step 3: Verify analyzer is clean**

Run: `flutter analyze lib/bluetooth/devices/proxy/proxy_device.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/bluetooth/devices/proxy/proxy_device.dart
git commit -m "feat(shifting): ProxyDevice reads VS settings from active ShiftingConfig"
```

---

## Task 5: Rewire `TrainerSettingsSection` onto the active config

**Files:**
- Modify: `lib/pages/proxy_device_details/trainer_settings_section.dart`

- [ ] **Step 1: Read the current section to identify call sites**

Run: `grep -n "getProxy\|setProxy" lib/pages/proxy_device_details/trainer_settings_section.dart`
Expected: Four getters (lines 25-28) and four setters (inside onChanged callbacks).

- [ ] **Step 2: Replace legacy calls with active-config reads and a mutation helper**

In `lib/pages/proxy_device_details/trainer_settings_section.dart`, replace the imports block at the top with:

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratios_editor_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:bike_control/widgets/ui/stepper_control.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
```

Change the `TrainerSettingsSection` widget's constructor to also take the owning `ProxyDevice`:

```dart
class TrainerSettingsSection extends StatefulWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;
  const TrainerSettingsSection({super.key, required this.definition, required this.device});

  @override
  State<TrainerSettingsSection> createState() => _TrainerSettingsSectionState();
}
```

Rewrite `initState()`:

```dart
  @override
  void initState() {
    super.initState();
    final cfg = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    def.setBicycleWeightKg(cfg.bikeWeightKg);
    def.setRiderWeightKg(cfg.riderWeightKg);
    def.setGradeSmoothingEnabled(cfg.gradeSmoothing);
    def.setVirtualShiftingMode(cfg.mode);
    core.shiftingConfigs.addListener(_onConfigsChanged);
  }

  @override
  void dispose() {
    core.shiftingConfigs.removeListener(_onConfigsChanged);
    super.dispose();
  }

  void _onConfigsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _updateActive(ShiftingConfig Function(ShiftingConfig) mutate) async {
    final current = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    await core.shiftingConfigs.upsert(mutate(current));
  }
```

Replace each `await core.settings.setProxy...(v)` line with the equivalent `_updateActive` call. For example:

```dart
  onChanged: (v) async {
    def.setVirtualShiftingMode(v);
    await _updateActive((c) => c.copyWith(mode: v));
  },
```

```dart
  onChanged: (v) async {
    def.setBicycleWeightKg(v);
    await _updateActive((c) => c.copyWith(bikeWeightKg: v));
  },
```

```dart
  onChanged: (v) async {
    def.setRiderWeightKg(v);
    await _updateActive((c) => c.copyWith(riderWeightKg: v));
  },
```

```dart
  onChanged: (v) async {
    def.setGradeSmoothingEnabled(v);
    await _updateActive((c) => c.copyWith(gradeSmoothing: v));
  },
```

- [ ] **Step 3: Update the one call site that constructs `TrainerSettingsSection`**

In `lib/pages/proxy_device_details.dart`, locate the line that reads `TrainerSettingsSection(definition: def)`:

```dart
    return TrainerSettingsSection(definition: def, device: widget.device);
```

- [ ] **Step 4: Verify analyzer is clean**

Run: `flutter analyze lib/pages/proxy_device_details/trainer_settings_section.dart lib/pages/proxy_device_details.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/proxy_device_details/trainer_settings_section.dart lib/pages/proxy_device_details.dart
git commit -m "feat(shifting): TrainerSettingsSection reads/writes active ShiftingConfig"
```

---

## Task 6: Rewire the gear-ratios editor onto the active config

**Files:**
- Modify: `lib/pages/proxy_device_details/gear_ratios_editor_page.dart`

- [ ] **Step 1: Read the current editor to locate the two setProxyGearRatios call sites**

Run: `grep -n "getProxy\|setProxy" lib/pages/proxy_device_details/gear_ratios_editor_page.dart`
Expected: two setter calls (one on "load preset", one on "save current").

- [ ] **Step 2: Thread the `ProxyDevice` through the editor**

At the top of `lib/pages/proxy_device_details/gear_ratios_editor_page.dart`, add:

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/models/shifting_config.dart';
```

Update the `GearRatiosEditorPage` constructor and the place that pushes the page to take a `ProxyDevice`:

```dart
class GearRatiosEditorPage extends StatefulWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;
  const GearRatiosEditorPage({super.key, required this.definition, required this.device});

  @override
  State<GearRatiosEditorPage> createState() => _GearRatiosEditorPageState();
}
```

Locate both `await core.settings.setProxyGearRatios(…)` call sites. Replace them with:

```dart
        final current = core.shiftingConfigs.activeFor(widget.device.trainerKey);
        await core.shiftingConfigs.upsert(current.copyWith(gearRatios: preset.values));
```

and:

```dart
        final current = core.shiftingConfigs.activeFor(widget.device.trainerKey);
        await core.shiftingConfigs.upsert(current.copyWith(gearRatios: def.gearRatios.value));
```

Find the single call site that pushes `GearRatiosEditorPage` (likely from `TrainerSettingsSection` or `gear_hero_card.dart`) and thread the device through:

Run: `grep -rn "GearRatiosEditorPage(" lib/`
At each call site, change `GearRatiosEditorPage(definition: def)` to `GearRatiosEditorPage(definition: def, device: <device-in-scope>)`. For `TrainerSettingsSection`, that's `widget.device`.

- [ ] **Step 3: Verify analyzer is clean**

Run: `flutter analyze lib/pages/proxy_device_details/gear_ratios_editor_page.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/proxy_device_details/gear_ratios_editor_page.dart lib/pages/proxy_device_details/
git commit -m "feat(shifting): gear-ratios editor writes to active ShiftingConfig"
```

---

## Task 7: Rewire `trainer_feedback.dart` onto the active config

**Files:**
- Modify: `lib/pages/trainer_feedback.dart`

- [ ] **Step 1: Locate the three getProxy* reads in the payload builder**

Run: `grep -n "getProxy" lib/pages/trainer_feedback.dart`
Expected: three lines in `_buildPayload` + `_vsMode`.

- [ ] **Step 2: Replace with a single lookup on the active config**

In `lib/pages/trainer_feedback.dart`'s `_buildPayload()` method, add at the top of the method:

```dart
    final cfg = core.shiftingConfigs.activeFor(widget.device.trainerKey);
```

Replace:

```dart
      gradeSmoothing: core.settings.getProxyGradeSmoothing(),
      gearRatios: core.settings.getProxyGearRatios() ?? FitnessBikeDefinition.defaultGearRatios,
```

with:

```dart
      gradeSmoothing: cfg.gradeSmoothing,
      gearRatios: cfg.gearRatios ?? FitnessBikeDefinition.defaultGearRatios,
```

And replace the `_vsMode()` implementation:

```dart
  String? _vsMode() {
    final cfg = core.shiftingConfigs.activeFor(widget.device.trainerKey);
    switch (cfg.mode) {
      case VirtualShiftingMode.targetPower:
        return 'target_power';
      case VirtualShiftingMode.trackResistance:
        return 'track_resistance';
      case VirtualShiftingMode.basicResistance:
        return 'basic';
    }
  }
```

- [ ] **Step 3: Verify analyzer is clean**

Run: `flutter analyze lib/pages/trainer_feedback.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/trainer_feedback.dart
git commit -m "feat(shifting): trainer feedback uses active ShiftingConfig"
```

---

## Task 8: Delete the legacy `proxy_*` accessors from `settings.dart`

**Files:**
- Modify: `lib/utils/settings/settings.dart`

- [ ] **Step 1: Confirm no remaining callers**

Run: `grep -rn "getProxyBikeWeightKg\|getProxyRiderWeightKg\|getProxyGradeSmoothing\|getProxyVirtualShiftingMode\|getProxyGearRatios\|setProxyBikeWeightKg\|setProxyRiderWeightKg\|setProxyGradeSmoothing\|setProxyVirtualShiftingMode\|setProxyGearRatios\|clearProxyGearRatios" lib/`
Expected: Only `lib/utils/settings/settings.dart` matches (the definitions themselves).

If any other match exists, the earlier tasks missed a call site — finish those before this task.

- [ ] **Step 2: Delete the "Proxy / retrofit bike settings" block**

Open `lib/utils/settings/settings.dart` and delete the entire block starting at the `// Proxy / retrofit bike settings` comment through the final `clearProxyGearRatios` method. That's lines 488–568 in the current file; all constants (`_proxyBikeWeightDefaultKg`, `_proxyBikeWeightMinKg`, etc.) and all `getProxy*`/`setProxy*`/`clearProxyGearRatios` methods go.

Also remove the now-unused `import 'package:prop/emulators/definitions/fitness_bike_definition.dart';` if it becomes orphan after the deletion (check with `grep -n "FitnessBikeDefinition" lib/utils/settings/settings.dart`).

- [ ] **Step 3: Verify analyzer is clean**

Run: `flutter analyze lib/utils/settings/settings.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/utils/settings/settings.dart
git commit -m "refactor(settings): drop legacy proxy_* accessors now that ShiftingConfig owns them"
```

---

## Task 9: `ShiftingConfigPicker` widget + Manage dialog

**Files:**
- Create: `lib/pages/proxy_device_details/shifting_config_picker.dart`

- [ ] **Step 1: Create the picker widget**

Create `lib/pages/proxy_device_details/shifting_config_picker.dart`:

```dart
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/utils/core.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ShiftingConfigPicker extends StatefulWidget {
  final String trainerKey;
  const ShiftingConfigPicker({super.key, required this.trainerKey});

  @override
  State<ShiftingConfigPicker> createState() => _ShiftingConfigPickerState();
}

class _ShiftingConfigPickerState extends State<ShiftingConfigPicker> {
  @override
  void initState() {
    super.initState();
    core.shiftingConfigs.addListener(_onChanged);
  }

  @override
  void dispose() {
    core.shiftingConfigs.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<String?> _promptName({required String title, String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, placeholder: const Text('Name')),
        actions: [
          Button.outline(
            onPressed: () => Navigator.of(c).pop(null),
            child: const Text('Cancel'),
          ),
          Button.primary(
            onPressed: () => Navigator.of(c).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNew() async {
    final name = await _promptName(title: 'New shifting config');
    if (name == null || name.isEmpty) return;
    final source = core.shiftingConfigs.activeFor(widget.trainerKey);
    await core.shiftingConfigs.upsert(source.copyWith(name: name, isActive: true));
  }

  Future<void> _manage() async {
    await showDialog<void>(
      context: context,
      builder: (c) {
        final configs = core.shiftingConfigs.configsFor(widget.trainerKey);
        return AlertDialog(
          title: const Text('Manage shifting configs'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final cfg in configs)
                  ListTile(
                    title: Text(cfg.name),
                    subtitle: cfg.isActive ? const Text('Active') : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        IconButton.ghost(
                          icon: const Icon(LucideIcons.copy, size: 16),
                          onPressed: () async {
                            final name = await _promptName(title: 'Duplicate', initial: '${cfg.name} copy');
                            if (name == null || name.isEmpty) return;
                            await core.shiftingConfigs.duplicate(
                              trainerKey: widget.trainerKey,
                              sourceName: cfg.name,
                              newName: name,
                            );
                          },
                        ),
                        IconButton.ghost(
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          onPressed: () async {
                            final name = await _promptName(title: 'Rename', initial: cfg.name);
                            if (name == null || name.isEmpty || name == cfg.name) return;
                            await core.shiftingConfigs.rename(
                              trainerKey: widget.trainerKey,
                              from: cfg.name,
                              to: name,
                            );
                          },
                        ),
                        if (configs.length > 1)
                          IconButton.ghost(
                            icon: const Icon(LucideIcons.trash2, size: 16),
                            onPressed: () async {
                              await core.shiftingConfigs.remove(
                                trainerKey: widget.trainerKey,
                                name: cfg.name,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            Button.outline(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final configs = core.shiftingConfigs.configsFor(widget.trainerKey);
    final active = core.shiftingConfigs.activeFor(widget.trainerKey);

    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: Select<ShiftingConfig>(
            value: configs.contains(active) ? active : null,
            popup: SelectPopup(
              items: SelectItemList(
                children: [
                  for (final cfg in configs)
                    SelectItemButton(
                      value: cfg,
                      child: Text(cfg.name),
                    ),
                ],
              ),
            ).call,
            itemBuilder: (c, cfg) => Text(cfg!.name),
            placeholder: const Text('Default'),
            onChanged: (cfg) async {
              if (cfg == null) return;
              await core.shiftingConfigs.setActive(trainerKey: widget.trainerKey, name: cfg.name);
            },
          ),
        ),
        Button.outline(
          onPressed: _createNew,
          leading: const Icon(LucideIcons.plus, size: 16),
          child: const Text('New'),
        ),
        Button.outline(
          onPressed: _manage,
          leading: const Icon(LucideIcons.settings, size: 16),
          child: const Text('Manage'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Mount the picker on ProxyDeviceDetailsPage**

In `lib/pages/proxy_device_details.dart`, add the import:

```dart
import 'package:bike_control/pages/proxy_device_details/shifting_config_picker.dart';
```

Insert it immediately before `_gearSection()` inside the main `Column(children: [...])`:

```dart
                _deviceCard(),
                ConnectionCard(device: device),
                ShiftingConfigPicker(trainerKey: device.trainerKey),
                _gearSection(),
```

- [ ] **Step 3: Verify analyzer is clean**

Run: `flutter analyze lib/pages/proxy_device_details.dart lib/pages/proxy_device_details/shifting_config_picker.dart`
Expected: No issues found.

- [ ] **Step 4: Manual smoke test**

Run: `flutter run` on any desktop platform. Open the ProxyDeviceDetailsPage, pick "New", name it, change a VS setting, pick "Manage" to rename/delete, confirm the active one is the one being used (bike weight stays after a restart).

- [ ] **Step 5: Commit**

```bash
git add lib/pages/proxy_device_details/shifting_config_picker.dart lib/pages/proxy_device_details.dart
git commit -m "feat(shifting): add ShiftingConfigPicker UI on ProxyDeviceDetailsPage"
```

---

## Task 10: Round-trip the list through `UserSettings` for sync

**Files:**
- Modify: `lib/models/user_settings.dart`
- Modify: `lib/repositories/user_settings_repository.dart`

- [ ] **Step 1: Add the field to UserSettings**

In `lib/models/user_settings.dart`:

Add the field next to the existing `keymaps`:

```dart
  final List<ShiftingConfig>? shiftingConfigs;
```

Add an import:

```dart
import 'package:bike_control/models/shifting_config.dart';
```

Pass the field through the constructor, `fromJson`, `toJson`, and `copyWith`. The full modified constructor:

```dart
  const UserSettings({
    this.userId,
    this.deviceId,
    this.keymaps,
    this.shiftingConfigs,
    this.ignoredDeviceIds,
    this.ignoredDeviceNames,
    this.version = 0,
    this.updatedAt,
    this.createdAt,
  });
```

In `fromJson`, parse `shiftingConfigs` from the new top-level `shifting_configs` column:

```dart
    List<ShiftingConfig>? parseShifting(dynamic raw) {
      if (raw is! List) return null;
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ShiftingConfig.fromJson)
          .toList(growable: false);
    }

    return UserSettings(
      userId: json['user_id'] as String?,
      deviceId: json['device_id'] as String?,
      keymaps: json['keymaps'] as Map<String, dynamic>?,
      shiftingConfigs: parseShifting(json['shifting_configs']),
      // …existing fields…
    );
```

In `toJson`, emit `shifting_configs` as a top-level JSON array (or omit when null):

```dart
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'device_id': deviceId,
      'keymaps': keymaps,
      if (shiftingConfigs != null)
        'shifting_configs': shiftingConfigs!.map((e) => e.toJson()).toList(),
      'ignored_device_ids': _stringifyList(ignoredDeviceIds),
      'ignored_device_names': _stringifyList(ignoredDeviceNames),
      'version': version,
    };
  }
```

Update `copyWith` to include the new field.

**Schema note:** The `user_settings` Supabase table needs a `shifting_configs jsonb` column added (nullable, no default). That migration is owned outside this plan — deploy it before the client-side changes reach production, otherwise the upsert in `saveSettings()` will fail with an unknown-column error.

- [ ] **Step 2: Wire the repository to read/write shifting configs**

In `lib/repositories/user_settings_repository.dart`:

In `saveSettings()`, after building `keymapsData`, include the controller's current list:

```dart
      final settings = UserSettings(
        userId: userId,
        deviceId: deviceId,
        keymaps: keymapsData,
        shiftingConfigs: core.shiftingConfigs.all,
        ignoredDeviceIds: ignoredIds,
        ignoredDeviceNames: ignoredNames,
        version: newVersion,
      );
```

In `loadAndApplySettings()`, after the existing `_applyKeymaps` + `_applyIgnoredDevices` calls, hydrate the shifting configs:

```dart
      if (settings.shiftingConfigs != null) {
        await core.shiftingConfigs.hydrateFromSync(settings.shiftingConfigs!);
      }
```

Add `import 'package:bike_control/utils/core.dart';` if not already imported.

- [ ] **Step 3: Verify analyzer is clean**

Run: `flutter analyze lib/models/user_settings.dart lib/repositories/user_settings_repository.dart`
Expected: No issues found.

- [ ] **Step 4: Add a round-trip test**

Create `test/models/user_settings_shifting_test.dart`:

```dart
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/models/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

void main() {
  test('UserSettings round-trips shiftingConfigs via the top-level column', () {
    final settings = UserSettings(
      userId: 'u1',
      deviceId: 'd1',
      keymaps: {'Zwift': []},
      shiftingConfigs: [
        ShiftingConfig(
          name: 'Race',
          trainerKey: 'KICKR',
          isActive: true,
          mode: VirtualShiftingMode.trackResistance,
          bikeWeightKg: 8.2,
          riderWeightKg: 68.5,
          gradeSmoothing: false,
        ),
      ],
    );

    final json = settings.toJson();
    expect(json['shifting_configs'], isA<List>());
    expect(json['keymaps'], isNot(contains('_shifting_configs')));

    final restored = UserSettings.fromJson(json);
    expect(restored.shiftingConfigs, isNotNull);
    expect(restored.shiftingConfigs!.single.name, 'Race');
    expect(restored.shiftingConfigs!.single.bikeWeightKg, 8.2);
  });
}
```

Run: `flutter test test/models/user_settings_shifting_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/user_settings.dart lib/repositories/user_settings_repository.dart test/models/user_settings_shifting_test.dart
git commit -m "feat(shifting): round-trip ShiftingConfigs through UserSettings sync"
```

---

## Self-review

- **Spec coverage**
  - "new ShiftingConfig that holds the settings" → Task 1.
  - "part of the UserSettings class" → Task 10, top-level `shifting_configs` column.
  - "User should be able to change their active ShiftingConfig" → Task 9 picker.
  - "Each Trainer device gets its own ShiftingConfigs" → flat list with `trainerKey`, controller scopes by that key (Tasks 1–2).
  - Existing call sites rewired → Tasks 4–7.
  - Legacy `proxy_*` accessors removed (no data migration) → Task 8.

- **Placeholder scan:** every step has concrete code, exact file paths, and exact commands. No TBD / TODO / "add appropriate error handling".

- **Type consistency:** `ShiftingConfig`, `ShiftingConfigsController`, `core.shiftingConfigs`, `trainerKey`, `VirtualShiftingMode` (from `prop`) are referenced identically across every task. Constructor additions (`ProxyDevice device` on `TrainerSettingsSection` and `GearRatiosEditorPage`) are introduced in the same task that starts consuming them; Task 5 Step 3 and Task 6 Step 2 also update all call sites that construct those widgets.
