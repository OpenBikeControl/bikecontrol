# Live Retrofit Mode Switch & Tap-to-Connect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping a proxy trainer in "Trainer & Accessories" auto-starts the emulator using the last-used retrofit mode for that trainer (defaulting to `proxy`); users can switch modes at any time while the emulator is running, and the switch stops the old transport/advertisement and starts the new one without tearing down the upstream BLE connection.

**Architecture:** Persist the chosen `RetrofitMode` per trainer key (scanResult name/id) in `Settings`. Extract the transport-start side of `DirconEmulator.startServer()` into `_startTransport()` and the tear-down of transports from `stop()` into `_teardownTransport()`. Add a new `switchRetrofitMode(mode)` that reuses those two helpers while leaving `isStarted`, `scanResult`, `services`, and unlock/vendor state intact. The proxy list tile auto-calls `startProxy()` with the saved mode before pushing details; the details-page `ConnectionCard` grows an always-visible mode picker that persists the choice and calls `switchRetrofitMode` while running.

**Tech Stack:** Flutter, Dart; `prop` submodule (`DirconEmulator`).

---

## File Structure

Modified:

- `lib/utils/settings/settings.dart` — add `getRetrofitMode(trainerKey)` / `setRetrofitMode(trainerKey, mode)` keyed on `retrofit_mode_<trainerKey>`.
- `prop/lib/emulators/dircon_emulator.dart` — extract `_teardownTransport()` + `_startTransport()`, add `switchRetrofitMode(RetrofitMode)`; `stop()` keeps calling the teardown helper + resets to `proxy`.
- `prop/test/emulators/dircon_emulator_test.dart` (new or extended, depending on existing content) — tests that `switchRetrofitMode` preserves `isStarted`/`scanResult` and flips `retrofitMode`.
- `lib/pages/proxy.dart` — on tap, if the emulator isn't started yet, read the saved mode and call `emulator.setRetrofitMode(saved)` + `device.startProxy()` before pushing the details page.
- `lib/pages/proxy_device_details/connection_card.dart` — always render the mode picker; on change, persist to settings and either `setRetrofitMode` (when not started) or `switchRetrofitMode` (when running).

---

## Task 1: Per-trainer retrofit-mode persistence in `Settings`

**Files:**
- Modify: `lib/utils/settings/settings.dart`
- Test: `test/utils/settings/settings_retrofit_mode_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `test/utils/settings/settings_retrofit_mode_test.dart`:

```dart
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    settings.prefs = await SharedPreferences.getInstance();
  });

  group('Settings retrofit mode persistence', () {
    test('defaults to proxy when nothing stored', () {
      expect(settings.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.proxy);
    });

    test('setRetrofitMode round-trips', () async {
      await settings.setRetrofitMode('KICKR BIKE 1234', RetrofitMode.wifi);
      expect(settings.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.wifi);

      await settings.setRetrofitMode('KICKR BIKE 1234', RetrofitMode.bluetooth);
      expect(settings.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.bluetooth);
    });

    test('distinct trainer keys store distinct modes', () async {
      await settings.setRetrofitMode('KICKR BIKE 1234', RetrofitMode.wifi);
      await settings.setRetrofitMode('Zwift Hub 9876', RetrofitMode.bluetooth);

      expect(settings.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.wifi);
      expect(settings.getRetrofitMode('Zwift Hub 9876'), RetrofitMode.bluetooth);
    });

    test('unknown stored value falls back to proxy', () async {
      SharedPreferences.setMockInitialValues({'retrofit_mode_KICKR BIKE 1234': 'garbage'});
      final fresh = Settings();
      fresh.prefs = await SharedPreferences.getInstance();
      expect(fresh.getRetrofitMode('KICKR BIKE 1234'), RetrofitMode.proxy);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify the failure**

Run: `flutter test test/utils/settings/settings_retrofit_mode_test.dart`
Expected: FAIL — `getRetrofitMode` / `setRetrofitMode` are undefined.

- [ ] **Step 3: Add the accessors**

In `lib/utils/settings/settings.dart`, add an import at the top (next to the existing `prop` imports):

```dart
import 'package:prop/emulators/dircon_emulator.dart';
```

Then, directly below the existing `getTrainerApp()` / `setTrainerApp()` pair (around line 117–127), add:

```dart
  static String _retrofitModeKey(String trainerKey) => 'retrofit_mode_$trainerKey';

  RetrofitMode getRetrofitMode(String trainerKey) {
    final raw = prefs.getString(_retrofitModeKey(trainerKey));
    if (raw == null) return RetrofitMode.proxy;
    return RetrofitMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => RetrofitMode.proxy,
    );
  }

  Future<void> setRetrofitMode(String trainerKey, RetrofitMode mode) async {
    await prefs.setString(_retrofitModeKey(trainerKey), mode.name);
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/utils/settings/settings_retrofit_mode_test.dart`
Expected: all 4 tests pass.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/utils/settings/settings.dart test/utils/settings/settings_retrofit_mode_test.dart`
Expected: No new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/utils/settings/settings.dart test/utils/settings/settings_retrofit_mode_test.dart
git commit -m "feat(settings): per-trainer retrofit-mode persistence"
```

---

## Task 2: `DirconEmulator.switchRetrofitMode` — live mode swap without reconnect

**Files:**
- Modify: `prop/lib/emulators/dircon_emulator.dart`
- Test: `prop/test/emulators/dircon_emulator_test.dart` (extend existing)

Submodule path: `/Users/boni/Developer/Flutter/swift_control/prop`. `cd` into it for tests and a dedicated commit, then bump the pointer from the outer repo.

- [ ] **Step 1: Inspect the current `startServer()` and `stop()` to plan the extraction**

Run: `grep -n "Future<void> startServer\|void stop\|_teardownTransport\|_startTransport\|setRetrofitMode\|switchRetrofitMode" prop/lib/emulators/dircon_emulator.dart`
Expected: matches for `startServer` (line ~97), `stop` (line ~181), and `setRetrofitMode` (line ~283). No pre-existing `_teardownTransport`, `_startTransport`, or `switchRetrofitMode`.

- [ ] **Step 2: Write the failing switch-mode test**

In `prop/test/emulators/dircon_emulator_test.dart`, append a new group immediately before the final closing `}` of `main()` (if no `main()` exists yet in the file, wrap the new code in a fresh `void main() { ... }` block — the test runner requires one):

```dart
  group('DirconEmulator.switchRetrofitMode', () {
    DirconEmulator makeStartedProxy() {
      final e = DirconEmulator();
      e.setScanResult(BleDevice(deviceId: 't', name: 'T'));
      // Minimal services so handleServices doesn't barf if/when invoked.
      e.services = const <BleService>[];
      // Use setRetrofitMode directly — we're not actually starting the transport
      // (which needs a live network / BLE peripheral), just flipping state.
      e.setRetrofitMode(RetrofitMode.proxy);
      // Fake a started emulator without touching the transport machinery.
      e.isStarted.value = true;
      return e;
    }

    test('no-op when the new mode matches the current one', () {
      final e = makeStartedProxy();
      final before = e.retrofitMode.value;
      e.switchRetrofitMode(RetrofitMode.proxy);
      expect(e.retrofitMode.value, before);
      expect(e.isStarted.value, isTrue);
    });

    test('flipping to a new mode updates the listenable without clearing isStarted', () {
      final e = makeStartedProxy();
      // We can't actually exercise transport start (no BLE/mDNS in unit test)
      // so we stub the test to only check the state transitions we can observe:
      // the retrofit mode must change, and isStarted must remain true while the
      // scanResult survives.
      // The real transport swap is covered by the manual smoke test in Task 5.
      e.switchRetrofitMode(RetrofitMode.bluetooth);
      expect(e.retrofitMode.value, RetrofitMode.bluetooth);
      expect(e.isStarted.value, isTrue);
      expect(e.scanResult, isNotNull);
    });

    test('stop() resets the mode back to proxy', () {
      final e = makeStartedProxy();
      e.switchRetrofitMode(RetrofitMode.wifi);
      e.stop();
      expect(e.retrofitMode.value, RetrofitMode.proxy);
      expect(e.isStarted.value, isFalse);
    });
  });
```

- [ ] **Step 3: Run the failing tests**

From `/Users/boni/Developer/Flutter/swift_control/prop`:

Run: `flutter test test/emulators/dircon_emulator_test.dart`
Expected: FAIL on the three new tests — `switchRetrofitMode` doesn't exist yet.

- [ ] **Step 4: Extract `_teardownTransport()` and `_startTransport()` helpers**

In `prop/lib/emulators/dircon_emulator.dart`, find the existing `startServer()` method (around line 97). Refactor it so its body (everything after `isStarted.value = true;` and `_localAddressN.value = null;`) moves into a new private method `_startTransport()`. The entry point `startServer()` becomes:

```dart
  Future<void> startServer() async {
    if (scanResult == null) {
      throw 'Scan result not set';
    }
    isStarted.value = true;
    _localAddressN.value = null;
    await _startTransport();
  }

  Future<void> _startTransport() async {
    if (_retrofitMode == RetrofitMode.bluetooth) {
      final definition = FitnessBikeDefinition(
        connectedDevice: scanResult!,
        connectedDeviceServices: services!,
        data: data,
      );
      _bluetoothTransporter = BluetoothTransporter(
        definition: definition,
        advertisementName: scanResult!.name == null ? 'BikeControl Virtual' : '${scanResult!.name} - Virtual',
      );
      await _bluetoothTransporter!.start();
      definition.subscribeToTrainer();
      isConnected.value = true;
      return;
    }
    if (kDebugMode) {
      print('Starting mDNS server...');
    }

    // Get local IP
    final interfaces = await NetworkInterface.list();
    InternetAddress? localIP;

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          localIP = addr;
          break;
        }
      }
      if (localIP != null) break;
    }

    if (localIP == null) {
      throw 'Could not find network interface';
    }
    _localAddressN.value = localIP.address;

    _createDefinitionAndTransporter();
    await _createTcpServer();

    if (kDebugMode) {
      enableLogging(LogTopic.calls);
      enableLogging(LogTopic.errors);
    }
    disableServiceTypeValidation(true);

    _mdnsRegistration = await register(
      Service(
        name: _isZwiftClick ? 'BikeControl' : ' ${scanResult!.name} - BikeControl',
        addresses: [localIP],
        port: _portNumber,
        type: '_wahoo-fitness-tnp._tcp',
        txt: {
          'ble-service-uuids': _isZwiftClick
              ? Uint8List.fromList('0x1818,0x1826,A026EE0D-0A7D-4AB3-97FA-F1500F9FEB8B,FC82'.codeUnits)
              : Uint8List.fromList(
                  [
                    ...scanResult!.services.map((service) {
                      return service.endsWith('-0000-1000-8000-00805f9b34fb')
                          ? '0x${service.substring(4, 8)}'
                          : service;
                    }),
                    if (_retrofitMode == RetrofitMode.wifi) FtmsMdnsConstants.ZWIFT_PLAY_SERVICE_UUID,
                  ].joinToString(separator: ',').codeUnits,
                ),
          'mac-address': Uint8List.fromList(scanResult!.deviceId.codeUnits),
          'serial-number': _isZwiftClick
              ? Uint8List.fromList('244700181'.codeUnits)
              : Uint8List.fromList(scanResult!.deviceId.replaceAll('-', '').substring(0, '244700181'.length).codeUnits),
        },
      ),
    );
    if (kDebugMode) {
      print('Server started - advertising service!');
    }
  }
```

Then find the existing `stop()` (around line 181) and refactor its transport teardown into a new `_teardownTransport()`:

```dart
  void stop() {
    _teardownTransport();
    isStarted.value = false;
    isConnected.value = false;
    _retrofitMode = RetrofitMode.proxy;
    if (kDebugMode) {
      print('Stopped FtmsMdnsEmulator');
    }
  }

  void _teardownTransport() {
    _localAddressN.value = null;
    _transporter?.dispose();
    _transporter = null;
    _bluetoothTransporter?.dispose();
    _bluetoothTransporter = null;
    _socket?.close();
    _tcpServer?.close();
    if (_mdnsRegistration != null) {
      unregister(_mdnsRegistration!);
    }
    _tcpServer = null;
    _mdnsRegistration = null;
    _socket = null;
  }
```

(Note: the `isConnected = false` and `isStarted = false` stay in `stop()` — they shouldn't fire during a mode switch.)

- [ ] **Step 5: Add `switchRetrofitMode`**

Immediately below the existing `setRetrofitMode` method (around line 283), add:

```dart
  /// Swap the retrofit transport without tearing down the upstream BLE
  /// connection. No-op when [mode] already matches [retrofitMode]. When the
  /// emulator isn't running, this is equivalent to [setRetrofitMode].
  Future<void> switchRetrofitMode(RetrofitMode mode) async {
    if (mode == _retrofitMode) return;
    if (!isStarted.value) {
      _retrofitMode = mode;
      return;
    }
    _teardownTransport();
    isConnected.value = false;
    _retrofitMode = mode;
    try {
      await _startTransport();
    } catch (e) {
      // If the new transport fails to come up, surface to the caller but
      // also drop isStarted so the UI shows the disconnected picker again.
      isStarted.value = false;
      rethrow;
    }
  }
```

- [ ] **Step 6: Run tests**

From `/Users/boni/Developer/Flutter/swift_control/prop`:

Run: `flutter test test/emulators/dircon_emulator_test.dart`
Expected: All tests pass (including the three new ones).

- [ ] **Step 7: Analyze inside the submodule**

Run: `flutter analyze lib/emulators/dircon_emulator.dart test/emulators/dircon_emulator_test.dart`
Expected: No new issues beyond pre-existing warnings in the submodule.

- [ ] **Step 8: Commit in the submodule**

```bash
cd /Users/boni/Developer/Flutter/swift_control/prop
git add lib/emulators/dircon_emulator.dart test/emulators/dircon_emulator_test.dart
git commit -m "feat(dircon): live switchRetrofitMode swaps transport without reconnect"
```

- [ ] **Step 9: Bump the submodule pointer**

```bash
cd /Users/boni/Developer/Flutter/swift_control
git add prop
git commit -m "chore(prop): bump submodule for switchRetrofitMode"
```

---

## Task 3: Tap-to-connect in `ProxyPage`

**Files:**
- Modify: `lib/pages/proxy.dart`

- [ ] **Step 1: Auto-start the emulator with the saved mode on tap**

In `lib/pages/proxy.dart`, the current tap handler pushes the details page. Replace the `onPressed:` body of the `Button.ghost` (around line 54–62) with:

Before:

```dart
              onPressed: () async {
                if (device is ProxyDevice) {
                  await context.push(ProxyDeviceDetailsPage(device: device));
                } else {
                  await context.push(ControllerSettingsPage(device: device));
                }
                widget.onUpdate();
              },
```

After:

```dart
              onPressed: () async {
                if (device is ProxyDevice) {
                  if (!device.emulator.isStarted.value) {
                    final savedMode = core.settings.getRetrofitMode(device.trainerKey);
                    device.emulator.setRetrofitMode(savedMode);
                    // Fire-and-wait for the initial connect; errors bubble as usual.
                    try {
                      await device.startProxy();
                    } catch (_) {
                      // Surface nothing special here — the details page shows the
                      // disconnected state and the user can retry via the mode picker.
                    }
                  }
                  await context.push(ProxyDeviceDetailsPage(device: device));
                } else {
                  await context.push(ControllerSettingsPage(device: device));
                }
                widget.onUpdate();
              },
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/pages/proxy.dart`
Expected: No new issues. (The file already imports `ProxyDevice` and `core`.)

- [ ] **Step 3: Commit**

```bash
git add lib/pages/proxy.dart
git commit -m "feat(proxy-list): tap auto-starts emulator with the saved retrofit mode"
```

---

## Task 4: Always-visible mode picker in `ConnectionCard` with live switch + persistence

**Files:**
- Modify: `lib/pages/proxy_device_details/connection_card.dart`

**Goal:**
- When the emulator isn't running: picker behaves as today (Connect button performs the initial start using the pending mode, and the chosen mode is persisted).
- When the emulator is running: show a compact picker above the connected-state banner; on change, persist the new mode AND call `emulator.switchRetrofitMode(mode)` for a live swap.

- [ ] **Step 1: Persist `_pendingMode` changes while disconnected**

Locate `setState(() => _pendingMode = m)` inside the `RadioGroup` in `_disconnectedCard` (around line 80). Replace with:

```dart
            onChanged: (m) async {
              setState(() => _pendingMode = m);
              await core.settings.setRetrofitMode(widget.device.trainerKey, m);
            },
```

Persist on the "Connect" tap too. Replace the existing `LoadingWidget.futureCallback` body (around line 113–117):

```dart
            futureCallback: () async {
              emulator.setRetrofitMode(_pendingMode);
              await core.settings.setRetrofitMode(widget.device.trainerKey, _pendingMode);
              await widget.device.startProxy();
            },
```

Add the required import at the top of the file:

```dart
import 'package:bike_control/utils/core.dart';
```

- [ ] **Step 2: Render a compact mode picker inside the connected card**

Find `_connectedCard(DirconEmulator emulator)` (around line 128). Wrap its existing returned `_card(...)` in a `Column` that adds a live picker row above the banner. Specifically, replace the return expression:

Before:

```dart
    return ValueListenableBuilder<RetrofitMode>(
      valueListenable: emulator.retrofitMode,
      builder: (context, mode, _) {
        final (bg, border, iconBg, iconColor, title) = switch (mode) {
          ...
        };
        final usesWifi = mode != RetrofitMode.bluetooth;
        return _card(
          bg: bg,
          border: border,
          child: Column(
            ...
          ),
        );
      },
    );
```

After:

```dart
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
            'Virtual Shifting (WiFi) — active',
          ),
          RetrofitMode.bluetooth => (
            const Color(0xFFFDF4FF),
            const Color(0xFFF5D0FE),
            const Color(0xFFFAE8FF),
            const Color(0xFFA21CAF),
            'Virtual Shifting (Bluetooth) — active',
          ),
        };
        final usesWifi = mode != RetrofitMode.bluetooth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            _modePickerCompact(mode),
            _card(
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
            ),
          ],
        );
      },
    );
```

(Note: the inner `_card(...)` plus its existing header row and optional `_bridgeRow` are moved verbatim from the original method into the `Column` above.)

- [ ] **Step 3: Implement `_modePickerCompact`**

Add the new builder just below `_connectedCard`:

```dart
  Widget _modePickerCompact(RetrofitMode active) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      bg: cs.card,
      border: cs.border,
      child: RadioGroup<RetrofitMode>(
        value: active,
        onChanged: (m) async {
          if (m == active) return;
          await core.settings.setRetrofitMode(widget.device.trainerKey, m);
          setState(() => _pendingMode = m);
          try {
            await widget.device.emulator.switchRetrofitMode(m);
          } catch (e) {
            // Surface the failure but let the UI update; the emulator's
            // isStarted listener will flip us back to the disconnected card.
            if (kDebugMode) print('switchRetrofitMode failed: $e');
          }
        },
        child: Row(
          spacing: 6,
          children: [
            for (final m in _allowedModes)
              Expanded(
                child: RadioCard<RetrofitMode>(
                  value: m,
                  child: Row(
                    spacing: 8,
                    children: [
                      Icon(_modeIcon(m), size: 16, color: cs.mutedForeground),
                      Expanded(
                        child: Text(
                          m.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
```

Add `import 'package:flutter/foundation.dart';` at the top of the file (for `kDebugMode`) if not already present.

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/pages/proxy_device_details/connection_card.dart`
Expected: No new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/proxy_device_details/connection_card.dart
git commit -m "feat(connection-card): always-visible mode picker with live switchRetrofitMode"
```

---

## Task 5: Final verification

- [ ] **Step 1: Run affected test suites**

Run: `flutter test test/utils/settings/settings_retrofit_mode_test.dart`
Expected: all tests pass.

From `/Users/boni/Developer/Flutter/swift_control/prop`:

Run: `flutter test test/emulators/dircon_emulator_test.dart`
Expected: all tests pass (including the three new `switchRetrofitMode` tests).

- [ ] **Step 2: Run the whole outer-repo suite**

Run: `flutter test`
Expected: no new failures relative to the pre-feature baseline. Known pre-existing failures (`screenshot_test.dart`, `cycplus_bc2_test.dart`) are unrelated.

- [ ] **Step 3: Analyze all touched files**

Run: `flutter analyze lib/utils/settings/settings.dart lib/pages/proxy.dart lib/pages/proxy_device_details/connection_card.dart`
Expected: only pre-existing info/warning messages in `settings.dart`; nothing new from this feature.

- [ ] **Step 4: Manual smoke test**

Run: `flutter run` on an available platform. With a proxy trainer available:

1. Kill the app so the emulator starts cold.
2. Trainer & Accessories shows the device. Tap it. Expect: emulator starts in `proxy` (default); details page opens and shows "Proxy active — mirroring via WiFi". No manual Connect click needed.
3. In the details page, tap the compact mode picker → `Virtual Shifting (Bluetooth)`. Expect: the banner flips to the bluetooth colours and title within ~1s, no BLE re-scan, the upstream trainer connection is preserved.
4. Tap back → Tap the device again. Expect: the emulator is already started in `bluetooth`; no Connect button; the device remembers `bluetooth` as the last mode after a full app restart (since `setRetrofitMode` was persisted on step 3).
5. Tap the picker → `Virtual Shifting (WiFi)`. Expect: the BLE advertisement goes down, the mDNS + TCP server comes up, and a WiFi IP appears in the bridge row.
6. Fully disconnect (or kill the app). Reopen. Tap the device. Expect: the saved mode from step 5 (`wifi`) is used automatically.

- [ ] **Step 5: Report results**

If everything passes, the feature is ready to merge. Note any divergence in the smoke test.

---

## Self-review

**Spec coverage**
- "connect to it with the last chosen connect mode (or Proxy by default)" → Task 1 (persistence + proxy default) + Task 3 (tap auto-starts with saved mode).
- "Allow the user to change the connect mode anytime" → Task 4 (picker always visible in `ConnectionCard`).
- "When connect mode is changed, do not reconnect, but stop the existing 'connect mode' and start the chosen one" → Task 2 (`switchRetrofitMode` calls `_teardownTransport` + `_startTransport`, leaving `scanResult`, `services`, and the upstream BLE link intact).

**Placeholder scan**
No TBDs. Every code step carries concrete code. The one "Similar to Task N" temptation — the connected-card rewrite — is spelled out in full to keep Task 4 Step 2 self-contained.

**Type consistency**
- `RetrofitMode` enum values used consistently (`proxy`, `wifi`, `bluetooth`).
- `Settings.getRetrofitMode(String)` / `Settings.setRetrofitMode(String, RetrofitMode)` consistent across Tasks 1, 3, 4.
- `DirconEmulator.switchRetrofitMode(RetrofitMode)` return type `Future<void>` matches the call sites.
- `ProxyDevice.trainerKey` getter (added in a prior feature) used consistently as the settings key in Tasks 3 and 4.
