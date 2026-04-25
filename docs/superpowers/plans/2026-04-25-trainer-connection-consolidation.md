# Trainer Connection Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the proxy/virtual-shifting UI into a single Virtual Shifting mode (with the WiFi-vs-Bluetooth transport derived from active Trainer Connections), surface the Bridge status in the OverviewPage trainer card, and delete the bicycle→logo→trainer flow visualization along with its supporting assets.

**Architecture:** Keep the underlying `RetrofitMode` enum (proxy/wifi/bluetooth) in the `prop` package as-is — `DirconEmulator` still needs three transports. At the UI layer collapse the picker to two options (proxy / virtual shifting); when the user picks virtual shifting, resolve the actual transport dynamically from the enabled `TrainerConnection` list via a new `preferredBridgeTransport` helper. The OverviewPage trainer card grows a per-`ProxyDevice` "Bridge" row that mirrors `_buildTrainerConnectionRow`, the per-`BaseDevice` connection chrome moves into `StatusIcon`, and `_buildFlowRow` (with `HorizontalFlowPainter`, `BubblePointerPainter`, the bicycle/logo Lottie assets, and the per-device flow chip animation state) is deleted wholesale.

**Tech Stack:** Flutter, shadcn_flutter, prop (in-repo emulator package), shared_preferences for persisted retrofit mode, intl_utils for ARB-driven l10n.

---

## File Structure

Files modified:
- `lib/bluetooth/devices/trainer_connection.dart` — add `TrainerConnectionType? get virtualShiftingTransport`.
- `lib/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart` — override transport getter to `bluetooth`.
- `lib/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart` — override transport getter to `wifi`.
- `lib/utils/core.dart` — add `CoreLogic.preferredBridgeTransport` resolver.
- `lib/pages/proxy_device_details/connection_card.dart` — replace 3-radio picker with proxy + virtualShifting; resolve transport via `preferredBridgeTransport`; show l10n hint when no transport is available.
- `lib/pages/overview.dart` — add `_buildBridgeConnectionRow`; delete `_buildFlowRow`, flow chip animation, position measurement, `_logoController`, flow keys, `_onErrorBannerTick`; simplify `_buildErrorBanner` to a centered card without pointer.
- `lib/bluetooth/devices/proxy/proxy_device.dart` — drop the `connected ? 'Bridge live' : 'Waiting for connection...'` row from `showMetaInformation`.
- `lib/bluetooth/devices/base_device.dart` — replace the leading 48×48 icon container + green-dot row with `StatusIcon`; drop the Connected/Disconnected text.
- `pubspec.yaml` — remove `assets/bicycle.json`, `assets/openbikecontrol_logo.json`, `assets/openbikecontrol_logo_inverted.json` from the asset list.

> **L10n note:** This plan hard-codes the two new English strings (Bridge row label and missing-transport hint) inline at their call sites. ARB additions and `intl_utils:generate` are deferred to a follow-up pass.
- `test/pages/proxy_device_details/connection_card_trainer_support_test.dart` — adjust to the consolidated picker (one VS row, hint shown when MyWhoosh has no VS support).

Files deleted:
- `lib/widgets/ui/horizontal_flow_painter.dart`
- `lib/widgets/ui/bubble_pointer_painter.dart`
- `assets/bicycle.json`
- `assets/openbikecontrol_logo.json`
- `assets/openbikecontrol_logo_inverted.json`

Files to leave alone (used elsewhere):
- `lib/widgets/ui/trainer_label.dart` — still used by `lib/pages/controller_settings.dart:121`.
- `lib/widgets/ui/openbikecontrol_logo.dart` — still used by `StatusIcon`, `configuration.dart`, `customize.dart`.

---

### Task 1: Add `virtualShiftingTransport` to `TrainerConnection`

**Files:**
- Modify: `lib/bluetooth/devices/trainer_connection.dart`

- [ ] **Step 1: Open the file**

Confirm the current state:

```dart
abstract class TrainerConnection {
  final String title;
  final ConnectionMethodType type;
  ...
}
```

- [ ] **Step 2: Add the getter**

Edit `lib/bluetooth/devices/trainer_connection.dart` so the class becomes:

```dart
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/ui/connection_method.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

export 'package:bike_control/widgets/ui/connection_method.dart' show ConnectionMethodTypee;

abstract class TrainerConnection {
  final String title;
  final ConnectionMethodType type;
  List<InGameAction> supportedActions;

  final ValueNotifier<bool> isStarted = ValueNotifier(false);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  TrainerConnection({required this.title, required this.type, required this.supportedActions});

  /// Which Bridge (Virtual Shifting) transport this connection actually rides on.
  /// Used by [CoreLogic.preferredBridgeTransport] to decide whether a Virtual
  /// Shifting session over this app should advertise via WiFi (FTMS/mDNS) or
  /// Bluetooth (BLE peripheral). `null` for connection methods that don't carry
  /// trainer telemetry (e.g. [ConnectionMethodType.local]).
  TrainerConnectionType? get virtualShiftingTransport => switch (type) {
        ConnectionMethodType.bluetooth => TrainerConnectionType.bluetooth,
        ConnectionMethodType.network => TrainerConnectionType.wifi,
        ConnectionMethodType.openBikeControl => null,
        ConnectionMethodType.local => null,
      };

  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp});

  Widget getTile();
}
```

`TrainerConnectionType` is already declared in `lib/utils/keymap/apps/supported_app.dart` and that file is imported transitively via the existing buttons/keymap imports — confirm by reading `supported_app.dart` once if needed. If it isn't already importable from `trainer_connection.dart`, add `import 'package:bike_control/utils/keymap/apps/supported_app.dart' show TrainerConnectionType;` to the top of the file.

- [ ] **Step 3: Run static analysis**

```bash
flutter analyze lib/bluetooth/devices/trainer_connection.dart
```

Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add lib/bluetooth/devices/trainer_connection.dart
git commit -m "feat: declare TrainerConnection.virtualShiftingTransport"
```

---

### Task 2: Override `virtualShiftingTransport` for OBC connections

`ConnectionMethodType.openBikeControl` doesn't tell us BT vs WiFi — the BLE and mDNS OBC emulators both share that type. Override per subclass.

**Files:**
- Modify: `lib/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart`
- Modify: `lib/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart`

- [ ] **Step 1: Read both files** to find the existing constructor and class body so the override slot is clear:

```bash
sed -n '1,60p' lib/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart
sed -n '1,60p' lib/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart
```

- [ ] **Step 2: Override on the BLE emulator**

In `lib/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart`, add an import for `TrainerConnectionType` if it isn't already in scope, then add the override inside the class body:

```dart
@override
TrainerConnectionType? get virtualShiftingTransport => TrainerConnectionType.bluetooth;
```

- [ ] **Step 3: Override on the mDNS emulator**

In `lib/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart`, mirror the override:

```dart
@override
TrainerConnectionType? get virtualShiftingTransport => TrainerConnectionType.wifi;
```

- [ ] **Step 4: Run analyze**

```bash
flutter analyze lib/bluetooth/devices/openbikecontrol
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart lib/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart
git commit -m "feat: declare OBC emulator transports for VS resolution"
```

---

### Task 3: Add `preferredBridgeTransport` to `CoreLogic`

**Files:**
- Modify: `lib/utils/core.dart`

- [ ] **Step 1: Write the failing test**

Create `test/utils/core_logic_preferred_bridge_transport_test.dart`:

```dart
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnection extends TrainerConnection {
  final TrainerConnectionType? _transport;
  _FakeConnection({
    required super.title,
    required super.type,
    TrainerConnectionType? transport,
  })  : _transport = transport,
        super(supportedActions: const []);

  @override
  TrainerConnectionType? get virtualShiftingTransport => _transport;

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async =>
      NotHandled('');

  @override
  Widget getTile() => const SizedBox.shrink();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  test('returns null when no enabled connections expose a transport', () {
    expect(core.logic.preferredBridgeTransport([]), isNull);
  });

  test('prefers bluetooth when any enabled connection rides BLE', () {
    final list = <TrainerConnection>[
      _FakeConnection(title: 'mdns', type: ConnectionMethodType.network, transport: TrainerConnectionType.wifi),
      _FakeConnection(title: 'ble', type: ConnectionMethodType.bluetooth, transport: TrainerConnectionType.bluetooth),
    ];
    expect(core.logic.preferredBridgeTransport(list), TrainerConnectionType.bluetooth);
  });

  test('falls back to wifi when only network connections are enabled', () {
    final list = <TrainerConnection>[
      _FakeConnection(title: 'mdns', type: ConnectionMethodType.network, transport: TrainerConnectionType.wifi),
    ];
    expect(core.logic.preferredBridgeTransport(list), TrainerConnectionType.wifi);
  });

  test('ignores connections with null transport (local, etc.)', () {
    final list = <TrainerConnection>[
      _FakeConnection(title: 'local', type: ConnectionMethodType.local, transport: null),
    ];
    expect(core.logic.preferredBridgeTransport(list), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/utils/core_logic_preferred_bridge_transport_test.dart
```

Expected: FAIL — `preferredBridgeTransport` is undefined.

- [ ] **Step 3: Implement the helper**

In `lib/utils/core.dart`, locate `class CoreLogic` and add the method near the existing `enabledTrainerConnections` getter:

```dart
/// Resolves the Bridge (Virtual Shifting) transport — Bluetooth or WiFi —
/// from the user's currently enabled Trainer Connections. Bluetooth wins
/// over WiFi when both are enabled because it survives backgrounding on
/// iOS and avoids LAN reachability issues; the Connection Settings card
/// is the user's authoritative input. Returns `null` when no enabled
/// connection carries trainer telemetry (e.g. only `local` is on).
TrainerConnectionType? preferredBridgeTransport(List<TrainerConnection> enabled) {
  for (final conn in enabled) {
    if (conn.virtualShiftingTransport == TrainerConnectionType.bluetooth) {
      return TrainerConnectionType.bluetooth;
    }
  }
  for (final conn in enabled) {
    if (conn.virtualShiftingTransport == TrainerConnectionType.wifi) {
      return TrainerConnectionType.wifi;
    }
  }
  return null;
}
```

Add `import 'package:bike_control/utils/keymap/apps/supported_app.dart' show TrainerConnectionType;` at the top of the file if `TrainerConnectionType` isn't already in scope.

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/utils/core_logic_preferred_bridge_transport_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/core.dart test/utils/core_logic_preferred_bridge_transport_test.dart
git commit -m "feat: add CoreLogic.preferredBridgeTransport resolver"
```

---

### Task 4: Collapse `ConnectionCard` picker to proxy + virtual shifting

**Files:**
- Modify: `lib/pages/proxy_device_details/connection_card.dart`

The picker currently shows three radios: `proxy`, `wifi`, `bluetooth`. Replace with two: `proxy`, `virtualShifting`. When the user picks `virtualShifting`, resolve to a concrete `RetrofitMode` (`wifi` or `bluetooth`) via `core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections)`. Persist the resolved concrete mode (existing `setRetrofitMode` writes the prop enum). When no transport is available, disable the VS radio and show the `noBridgeTransportAvailable` hint.

- [ ] **Step 1: Add a UI-level enum and selection helper**

At the top of `lib/pages/proxy_device_details/connection_card.dart` (under the imports, before `class ConnectionCard`), add:

```dart
enum _ConnectMode { proxy, virtualShifting }

_ConnectMode _connectModeOf(RetrofitMode mode) =>
    mode == RetrofitMode.proxy ? _ConnectMode.proxy : _ConnectMode.virtualShifting;
```

- [ ] **Step 2: Replace `_allowedModes` with a `_connectModes` list**

Replace the existing `_allowedModes` getter with:

```dart
List<_ConnectMode> get _connectModes => const [
      _ConnectMode.proxy,
      _ConnectMode.virtualShifting,
    ];

/// Resolves which concrete [RetrofitMode] the Virtual Shifting radio will
/// switch into when picked. Mirrors the active Trainer Connections — BT wins
/// over WiFi. Returns `null` when neither transport is enabled, in which
/// case the VS radio renders disabled and the missing-transport hint shows.
RetrofitMode? get _resolvedVirtualShiftingMode {
  final transport = core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections);
  return switch (transport) {
    TrainerConnectionType.bluetooth => RetrofitMode.bluetooth,
    TrainerConnectionType.wifi => RetrofitMode.wifi,
    null => null,
  };
}
```

Add the imports needed at the top of the file:

```dart
import 'package:bike_control/utils/keymap/apps/supported_app.dart' show TrainerConnectionType;
```

- [ ] **Step 3: Adjust `initState` to seed `_pendingMode` from the resolved VS mode**

Replace the body of `initState` with:

```dart
@override
void initState() {
  super.initState();
  final saved = widget.device.emulator.retrofitMode.value;
  if (saved == RetrofitMode.proxy) {
    _pendingMode = RetrofitMode.proxy;
  } else {
    _pendingMode = _resolvedVirtualShiftingMode ?? RetrofitMode.wifi;
  }
  _useAccordion = saved != RetrofitMode.proxy;
}
```

- [ ] **Step 4: Rewrite `_radioCard` to take a `_ConnectMode`**

Replace the existing `_radioCard` method body so the radio renders one entry for VS that pulls its icon from the resolved concrete mode (falling back to `LucideIcons.cog` when nothing is enabled):

```dart
Widget _radioCard(_ConnectMode m, ColorScheme cs) {
  final RetrofitMode? resolved = m == _ConnectMode.proxy
      ? RetrofitMode.proxy
      : _resolvedVirtualShiftingMode;
  final IconData iconData = resolved == null
      ? LucideIcons.cog
      : _modeIcon(resolved);
  final bool disabled = m == _ConnectMode.virtualShifting && resolved == null;

  return RadioCard<_ConnectMode>(
    value: m,
    enabled: !disabled,
    child: Row(
      spacing: 12,
      children: [
        Icon(iconData, size: 20, color: cs.mutedForeground),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                _connectModeLabel(m),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                _connectModeHint(m),
                style: TextStyle(fontSize: 11, color: cs.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _connectModeLabel(_ConnectMode m) => switch (m) {
      _ConnectMode.proxy => 'Proxy',
      _ConnectMode.virtualShifting => 'Virtual Shifting',
    };

String _connectModeHint(_ConnectMode m) => switch (m) {
      _ConnectMode.proxy => 'Mirrors your trainer over WiFi without touching gear logic.',
      _ConnectMode.virtualShifting => switch (_resolvedVirtualShiftingMode) {
          RetrofitMode.bluetooth =>
            'Adds or adjusts virtual shifting and creates a Bluetooth-advertised trainer.',
          RetrofitMode.wifi =>
            'Adds or adjusts virtual shifting and creates a WiFi-advertised trainer.',
          _ => 'Enable a Bluetooth or WiFi Trainer Connection to use Virtual Shifting.',
          RetrofitMode.proxy => '',
        },
    };
```

- [ ] **Step 5: Rewrite `_disconnectedCard` and `_modePickerCompact` to use `_ConnectMode`**

In `_disconnectedCard`, change the `RadioGroup<RetrofitMode>` block to:

```dart
RadioGroup<_ConnectMode>(
  value: _connectModeOf(_pendingMode),
  onChanged: (m) async {
    final RetrofitMode? next = m == _ConnectMode.proxy
        ? RetrofitMode.proxy
        : _resolvedVirtualShiftingMode;
    if (next == null) return;
    setState(() => _pendingMode = next);
    await core.settings.setRetrofitMode(widget.device.trainerKey, next);
  },
  child: Column(
    spacing: 8,
    children: [
      for (final m in _connectModes) _radioCard(m, cs),
    ],
  ),
),
```

In `_modePickerCompact`, swap the `RadioGroup<RetrofitMode>` for:

```dart
RadioGroup<_ConnectMode>(
  value: _connectModeOf(active),
  onChanged: (m) async {
    final RetrofitMode? next = m == _ConnectMode.proxy
        ? RetrofitMode.proxy
        : _resolvedVirtualShiftingMode;
    if (next == null) return;
    if (next == active) return;
    if (next == RetrofitMode.bluetooth) {
      final ok = await _ensureBluetoothAdvertisePermissions();
      if (!ok) return;
    }
    await core.settings.setRetrofitMode(widget.device.trainerKey, next);
    setState(() => _pendingMode = next);
    try {
      await widget.device.emulator.switchRetrofitMode(next);
    } catch (e) {
      if (kDebugMode) print('switchRetrofitMode failed: $e');
    }
  },
  child: Column(
    spacing: 8,
    children: [
      for (final m in _connectModes) _radioCard(m, cs),
    ],
  ),
),
```

`_modePickerAccordion` already calls `_modePickerCompact(mode)` for its content — leave it as-is.

- [ ] **Step 6: Adjust the disconnected-card Connect button so it uses the resolved mode**

Inside the `LoadingWidget.futureCallback` of `_disconnectedCard`, replace the body with:

```dart
() async {
  if (IAPManager.instance.isTrialExpired) {
    await showGoProDialog(context);
    return;
  }
  final connectMode = _connectModeOf(_pendingMode);
  final RetrofitMode? next = connectMode == _ConnectMode.proxy
      ? RetrofitMode.proxy
      : _resolvedVirtualShiftingMode;
  if (next == null) return;
  if (next == RetrofitMode.bluetooth) {
    final ok = await _ensureBluetoothAdvertisePermissions();
    if (!ok) return;
  }
  emulator.setRetrofitMode(next);
  await core.settings.setRetrofitMode(widget.device.trainerKey, next);
  await core.settings.setAutoConnect(widget.device.trainerKey, true);
  await widget.device.startProxy();
}
```

- [ ] **Step 7: Run analyze**

```bash
flutter analyze lib/pages/proxy_device_details/connection_card.dart
```

Expected: no errors. Fix any leftover references to the old `_allowedModes` getter or the deleted `_modeHint(RetrofitMode)` helper.

- [ ] **Step 8: Commit**

```bash
git add lib/pages/proxy_device_details/connection_card.dart
git commit -m "feat: collapse VS picker to proxy + virtual shifting"
```

---

### Task 5: Update the trainer-support widget test for the consolidated picker

`test/pages/proxy_device_details/connection_card_trainer_support_test.dart` currently expects a separate WiFi card. With one VS radio, the missing-transport case should surface the inline missing-transport hint. Assert on the visible row labels rather than on the long hint sentence to keep the test resilient to copy edits.

**Files:**
- Modify: `test/pages/proxy_device_details/connection_card_trainer_support_test.dart`

- [ ] **Step 1: Read the existing test** to confirm scope:

```bash
sed -n '1,60p' test/pages/proxy_device_details/connection_card_trainer_support_test.dart
```

- [ ] **Step 2: Rewrite the test to assert the consolidated UI**

Replace the file contents with:

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details/connection_card.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({'trainer_app': 'MyWhoosh'});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
  });

  testWidgets('renders both Proxy and Virtual Shifting rows', (tester) async {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'x',
        name: 'Wahoo KICKR',
        services: const [FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID],
      ),
    );

    await tester.pumpWidget(
      ShadcnApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        home: Scaffold(child: ConnectionCard(device: device)),
      ),
    );
    await tester.pump();

    expect(find.text('Proxy'), findsOneWidget);
    expect(find.text('Virtual Shifting'), findsOneWidget);
    // No transport is enabled in this test (no TrainerConnection switched on),
    // so the missing-transport hint must surface on the VS row.
    expect(
      find.textContaining('Enable a Bluetooth or WiFi Trainer Connection'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 3: Run the test**

```bash
flutter test test/pages/proxy_device_details/connection_card_trainer_support_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add test/pages/proxy_device_details/connection_card_trainer_support_test.dart
git commit -m "test: cover consolidated proxy/VS connection picker"
```

---

### Task 6: Strip the Connected/Bridge meta row from `ProxyDevice`

The "Bridge live" / "Waiting for connection..." row inside `showMetaInformation` is what the OverviewPage currently surfaces; it duplicates info we'll add to the trainer card and lives on a row that's about to be deleted from `BaseDevice`.

**Files:**
- Modify: `lib/bluetooth/devices/proxy/proxy_device.dart`

- [ ] **Step 1: Delete the connected branch**

In `lib/bluetooth/devices/proxy/proxy_device.dart`, locate `showMetaInformation` (lines 188–237 currently). Replace the entire method with:

```dart
@override
List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
  if (!isConnected) {
    return [
      Text(
        'Connect to enable / adjust Virtual Shifting, or to proxy the device via WiFi',
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.mutedForeground,
        ),
      ),
    ];
  }
  return const [];
}
```

- [ ] **Step 2: Drop now-unused imports**

If after the edit nothing else in `proxy_device.dart` references `RetrofitMode` from the meta row (the live shifter row in `showAdditionalInformation` still does), leave imports. Run analyze to find any unused-import warnings:

```bash
flutter analyze lib/bluetooth/devices/proxy/proxy_device.dart
```

Expected: no new warnings. If `BikeControl` is no longer referenced, remove its import.

- [ ] **Step 3: Commit**

```bash
git add lib/bluetooth/devices/proxy/proxy_device.dart
git commit -m "refactor: drop bridge-status meta row from ProxyDevice"
```

---

### Task 7: Replace `BaseDevice` icon container + Connected row with `StatusIcon`

**Files:**
- Modify: `lib/bluetooth/devices/base_device.dart`

The existing 48×48 icon container plus the wrap row showing a green dot + "Connected"/"Disconnected" + meta widgets becomes a single `StatusIcon` (38×38, status dot included), followed by the same name + meta wrap minus the connection text.

- [ ] **Step 1: Edit `showInformation`**

Locate `Widget showInformation(BuildContext context, {required bool showFull})` near line 483 of `lib/bluetooth/devices/base_device.dart`. Replace its body with:

```dart
Widget showInformation(BuildContext context, {required bool showFull}) {
  final meta = showMetaInformation(context, showFull: showFull);
  return Row(
    spacing: 12,
    children: [
      StatusIcon(
        icon: icon,
        status: isConnected,
        started: false,
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 4,
          children: [
            Row(
              spacing: 6,
              children: [
                Text(
                  toString(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                ),
                if (isBeta) BetaPill(),
              ],
            ),
            if (meta.isNotEmpty)
              Wrap(
                runSpacing: 6,
                spacing: 6,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                runAlignment: WrapAlignment.start,
                children: meta,
              ),
          ],
        ),
      ),
    ],
  );
}
```

- [ ] **Step 2: Add the `StatusIcon` import**

Near the existing imports at the top of `lib/bluetooth/devices/base_device.dart`, add:

```dart
import 'package:bike_control/widgets/status_icon.dart';
```

- [ ] **Step 3: Drop now-unused l10n strings**

`AppLocalizations.of(context).connected` / `.disconnected` were only used in this file's deleted row. If no other file uses them, leave them in `intl_en.arb` (a separate cleanup pass owns dead-string deletion). Confirm via:

```bash
grep -rn "AppLocalizations.of(context).connected\b\|AppLocalizations.of(context).disconnected\b" lib test
```

Expected: only matches in `lib/gen/`. Do not edit generated files.

- [ ] **Step 4: Verify `flutter analyze` is clean**

```bash
flutter analyze lib/bluetooth/devices/base_device.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/bluetooth/devices/base_device.dart
git commit -m "refactor: render BaseDevice connection state via StatusIcon"
```

---

### Task 8: Add the Bridge connection row to the trainer card

**Files:**
- Modify: `lib/pages/overview.dart`

The trainer card already iterates `enabledTrainers` and emits `_buildTrainerConnectionRow` for each. Append a row per connected `ProxyDevice` whose icon mirrors the active `RetrofitMode` and whose status follows the emulator.

- [ ] **Step 1: Add a `_buildBridgeConnectionRow` method on `_OverviewPageState`**

After the existing `_buildTrainerConnectionRow` method (currently lines 1084–1101), add:

```dart
Widget _buildBridgeConnectionRow(ProxyDevice device) {
  return ValueListenableBuilder<RetrofitMode>(
    valueListenable: device.emulator.retrofitMode,
    builder: (context, mode, _) {
      // Proxy mode mirrors raw FTMS over WiFi — surface a wifi icon, not the
      // bridge-specific bluetooth/cog visuals.
      final IconData icon = switch (mode) {
        RetrofitMode.bluetooth => Icons.bluetooth,
        RetrofitMode.wifi => Icons.wifi,
        RetrofitMode.proxy => Icons.wifi,
      };
      return ValueListenableBuilder<bool>(
        valueListenable: device.emulator.isConnected,
        builder: (context, connected, _) {
          return ValueListenableBuilder<bool>(
            valueListenable: device.isStarting,
            builder: (context, starting, _) {
              final title = 'Bridge (${device.toString()})';
              return Row(
                children: [
                  StatusIcon(icon: icon, status: connected, started: starting),
                  const Gap(8),
                  Expanded(
                    child: connected
                        ? Text(title).small.semiBold
                        : Text(title).small.muted,
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}
```

Add the import at the top of `lib/pages/overview.dart` if it isn't already there:

```dart
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
```

- [ ] **Step 2: Wire the row into `_buildTrainerCard`**

Inside `_buildTrainerCard`, locate the block (currently lines 1059–1072) that iterates `enabledTrainers`. Replace it with:

```dart
final proxies = core.connection.proxyDevices.where((p) => p.isConnected).toList();

if (enabledTrainers.isNotEmpty || proxies.isNotEmpty) ...[
  const Gap(12),
  for (final enabledTrainer in enabledTrainers) ...[
    _buildTrainerConnectionRow(enabledTrainer),
    if (enabledTrainer != enabledTrainers.last || proxies.isNotEmpty) const Gap(8),
  ],
  for (final proxy in proxies) ...[
    _buildBridgeConnectionRow(proxy),
    if (proxy != proxies.last) const Gap(8),
  ],
  const Gap(12),
] else ...[
  const Gap(12),
  if (trainerApp is! BikeControl) ...[
    Text(context.i18n.noConnectionMethodIsConnectedOrActive).small.muted,
    const Gap(12),
  ],
],
```

- [ ] **Step 3: Subscribe to proxy emulator notifiers so the row repaints**

`_connectionListener` already triggers `setState` on connection changes, but the emulator's `retrofitMode` / `isConnected` / `isStarting` notifiers fire independently. The `ValueListenableBuilder` wrappers handle the leaf row, but the parent card's "are there any connected proxies?" question hinges on `device.isConnected` (a plain field). Subscribe to each proxy's `isStarting` and `emulator.isConnected` notifiers in `initState` so the trainer card rebuilds when a bridge comes online. Inside `_OverviewPageState.initState`, add after the existing `_connectionListener`:

```dart
for (final proxy in core.connection.proxyDevices) {
  proxy.isStarting.addListener(_onProxyStateChanged);
  proxy.emulator.isConnected.addListener(_onProxyStateChanged);
}
```

Add a paired teardown helper next to `_onErrorBannerTick`:

```dart
void _onProxyStateChanged() {
  if (mounted) setState(() {});
}
```

And in `dispose`, before the `_connectionListener.cancel()` call:

```dart
for (final proxy in core.connection.proxyDevices) {
  proxy.isStarting.removeListener(_onProxyStateChanged);
  proxy.emulator.isConnected.removeListener(_onProxyStateChanged);
}
```

(Newly-discovered proxies are already covered because `connectionStream` fires `setState` on each appearance, after which the next build sees them.)

- [ ] **Step 4: Run analyze**

```bash
flutter analyze lib/pages/overview.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/overview.dart
git commit -m "feat: surface Bridge status in OverviewPage trainer card"
```

---

### Task 9: Delete `_buildFlowRow` and supporting state

**Files:**
- Modify: `lib/pages/overview.dart`

This is the bulk deletion. The existing `_buildFlowRow` orchestrates the bicycle-Lottie → logo-Lottie → trainer flow with an animated chip overlay; tearing it out also kills `_buildAnimatedFlowChip`, `_buildFlowChip`, `_measurePositions`, the position state, the per-device flow-chip controllers, and the inline error banner pointer that targets the logo's measured X.

- [ ] **Step 1: Remove the call site**

In `_OverviewPageState.build`, line 478 currently reads `_buildFlowRow(trainerApp, enabledTrainers),`. Delete that line entirely from the `leftColumn` children list.

- [ ] **Step 2: Delete the flow-row methods**

Delete the entire range from the `// ── Flow row ──` banner comment (currently around line 742) through the end of `_buildFlowChip` (currently line 967). That removes:

- `static const _chipSize = 26.0;`
- `_buildFlowRow`
- `_buildAnimatedFlowChip`
- `_buildFlowChip`

Keep `late final PageController _horizontalScrollController = PageController();` — it's reused by the mobile tab strip. Move it just below the activity-log section, so the file no longer carries the `// ── Flow row ──` banner.

- [ ] **Step 3: Delete the position-measurement state and helpers**

Delete:

- The `_buildAnimatedActivityItem` is unrelated; do **not** touch it.
- The keys `_flowRowKey`, `_bicycleKey`, `_logoKey`, `_trainerLabelKey` (declared near the top of the state class).
- The position fields `_bicycleCenterX`, `_bicycleCenterY`, `_logoCenterX`, `_logoCenterY`, `_logoLeftX`, `_logoRightX`, `_trainerLabelCenterX`, `_trainerCenterY`, `_hasMeasured`.
- The `_measurePositions()` method.
- The `_onErrorBannerTick` method (and the `addListener(_onErrorBannerTick)` on `_errorBannerController`).
- The `WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _measurePositions(); });` block inside `build`.

- [ ] **Step 4: Delete the per-device flow chip animation state**

Delete the field declarations and any usages of:

- `_flowControllers` (the `Map<String, AnimationController>`)
- `_flowButton`
- `_flowIsError`
- `_flowResult`
- `_flowGeneration`
- `_controllerFor`
- `_onDeviceFlowDone`

In `dispose`, remove the loop:

```dart
for (final c in _flowControllers.values) {
  c.dispose();
}
```

- [ ] **Step 5: Trim `_onActionResult`**

`_onActionResult` currently ends with a flow-chip animation kickoff. Replace its body with:

```dart
void _onActionResult(ActionResult result, ControllerButton button) {
  final entry = _ActivityEntry(button: button, time: DateTime.now(), result: result);
  _insertActivityEntry(entry);

  if (entry.isError) {
    final alreadyShown = _latestError != null && _errorBannerController.value > 0;
    _latestError = entry;
    if (alreadyShown) {
      _errorShakeController.forward(from: 0);
    } else {
      _errorBannerController.forward(from: 0);
    }
    setState(() {});
  } else if (_latestError != null) {
    _errorBannerController.reverse().then((_) {
      if (mounted) setState(() => _latestError = null);
    });
  } else {
    setState(() {});
  }
}
```

- [ ] **Step 6: Delete `_logoController`**

`_logoController` only animated the OBC logo Lottie inside `_buildFlowRow`. Remove its declaration:

```dart
late final AnimationController _logoController = AnimationController(vsync: this);
```

Remove the `_logoController.dispose();` line in `dispose`. In `_onButtonPressed`, delete the trailing block:

```dart
if (_logoController.duration != null) {
  _logoController.forward(from: 0);
}
```

- [ ] **Step 7: Drop the now-unused imports**

After the deletions, run:

```bash
flutter analyze lib/pages/overview.dart
```

Expected complaints: unused imports for `package:lottie/lottie.dart`, `bubble_pointer_painter.dart`, `horizontal_flow_painter.dart`, `trainer_label.dart`. Delete those imports from the file. Also delete `import 'dart:math';` if `min`/`max`/`sin` are no longer referenced (the error banner shake still uses `sin` — keep `dart:math` if so).

- [ ] **Step 8: Re-run analyze**

```bash
flutter analyze lib/pages/overview.dart
```

Expected: no errors, no unused-import warnings.

- [ ] **Step 9: Commit**

```bash
git add lib/pages/overview.dart
git commit -m "refactor: remove flow-row visualization from OverviewPage"
```

---

### Task 10: Simplify the error banner to a centered card

**Files:**
- Modify: `lib/pages/overview.dart`

`_buildErrorBanner` currently positions a `BubblePointerPainter` over the logo's measured X. With `_buildFlowRow` gone there is no logo to anchor against. Render the error card centered, no pointer.

- [ ] **Step 1: Replace `_buildErrorBanner` body**

Locate `_buildErrorBanner` (currently around line 1314). Replace the entire method with:

```dart
Widget _buildErrorBanner({bool useAbsolutePointer = false}) {
  final entry = _latestError;
  if (entry == null && _errorBannerController.value == 0) {
    return const SizedBox.shrink();
  }

  Widget buildCard() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            padding: const EdgeInsets.all(2),
            borderRadius: BorderRadius.circular(22),
            child: _buildActivityRow(entry!, isLatest: true),
          ),
        ),
      );

  return KeyedSubtree(
    key: _errorBannerKey,
    child: SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _errorBannerController,
        curve: Curves.easeOutCubic,
      ),
      axisAlignment: -1.0,
      child: entry != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AnimatedBuilder(
                animation: _errorShakeController,
                builder: (context, child) {
                  final t = _errorShakeController.value;
                  final scale = 1.0 + 0.03 * sin(t * pi);
                  return Transform.scale(scale: scale, child: child);
                },
                child: buildCard(),
              ),
            )
          : const SizedBox.shrink(),
    ),
  );
}
```

The `useAbsolutePointer` parameter no longer affects rendering — the signature stays so the existing call sites in `_buildFlowRow`'s replacement path don't need changes; both call sites are gone after Task 9 anyway. If no caller remains, drop the parameter.

- [ ] **Step 2: Re-attach the error banner to the left column**

In `build`, the left column previously rendered `_buildFlowRow(trainerApp, enabledTrainers)` which embedded the error banner. After Task 9 it's gone; insert a single error-banner placeholder so latest errors stay visible. Find the `leftColumn` declaration (currently starting around line 470) and slot it just before the controllers card:

```dart
final leftColumn = Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Gap(8),
    ValueListenableBuilder(
      valueListenable: IAPManager.instance.isPurchased,
      builder: (context, value, child) => value ? const SizedBox(height: 12) : IAPStatusWidget(small: false),
    ),
    _buildErrorBanner(),
    const Gap(22),
    Card(
      // ... existing controllers card unchanged ...
    ),
    // ...
  ],
);
```

- [ ] **Step 3: Run analyze**

```bash
flutter analyze lib/pages/overview.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/overview.dart
git commit -m "refactor: render error banner as centered card without pointer"
```

---

### Task 11: Delete unused painters and asset files

**Files:**
- Delete: `lib/widgets/ui/horizontal_flow_painter.dart`
- Delete: `lib/widgets/ui/bubble_pointer_painter.dart`
- Delete: `assets/bicycle.json`
- Delete: `assets/openbikecontrol_logo.json`
- Delete: `assets/openbikecontrol_logo_inverted.json`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Verify nothing else imports them**

```bash
grep -rn "horizontal_flow_painter\|bubble_pointer_painter\|HorizontalFlowPainter\|BubblePointerPainter\|quadBezier\|assets/bicycle\.json\|assets/openbikecontrol_logo" lib test integration_test 2>/dev/null
```

Expected: zero matches in `lib/` and `test/` (the only non-empty hits should be in `pubspec.yaml`, which we'll fix next).

- [ ] **Step 2: Delete the files**

```bash
rm lib/widgets/ui/horizontal_flow_painter.dart
rm lib/widgets/ui/bubble_pointer_painter.dart
rm assets/bicycle.json
rm assets/openbikecontrol_logo.json
rm assets/openbikecontrol_logo_inverted.json
```

- [ ] **Step 3: Drop the asset entries from `pubspec.yaml`**

Remove these three lines (currently lines 123, 127, 128) from the `assets:` block in `pubspec.yaml`:

```yaml
    - assets/bicycle.json
    - assets/openbikecontrol_logo.json
    - assets/openbikecontrol_logo_inverted.json
```

Leave `assets/silence.mp3`, `assets/mywhoosh.png`, `assets/rouvy.png`, `assets/trainingpeaks.png`, and `assets/contours/` untouched.

- [ ] **Step 4: Run flutter pub get**

```bash
flutter pub get
```

Expected: clean exit, no errors about missing assets.

- [ ] **Step 5: Run analyze**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/ui/horizontal_flow_painter.dart lib/widgets/ui/bubble_pointer_painter.dart assets/bicycle.json assets/openbikecontrol_logo.json assets/openbikecontrol_logo_inverted.json pubspec.yaml
git commit -m "chore: drop flow-row painters and Lottie assets"
```

(`git add` for deleted paths records the deletions; `git rm` would also work.)

---

### Task 12: Full test sweep + manual UI verification

- [ ] **Step 1: Run the full test suite**

```bash
flutter test
```

Expected: all suites pass. Investigate any new failures referencing `_buildFlowRow`, `RetrofitMode`, `Connected`/`Disconnected` text, or the deleted painters; surgically update the offending tests before continuing.

- [ ] **Step 2: Manually drive the UI**

Start a dev build on a desktop or simulator target you can iterate on:

```bash
flutter run -d macos
```

Walk through:

1. **Connection settings empty** — open proxy details on a fresh device. Expect the VS radio to render disabled with the missing-transport hint.
2. **Enable a BLE trainer connection** (e.g. ZwiftEmulator BLE) — re-open proxy details, expect the VS radio to now render enabled with the Bluetooth icon and BT hint.
3. **Enable a WiFi trainer connection only** (e.g. ZwiftMdns) — same flow, expect the WiFi icon and WiFi hint.
4. **Connect a proxy device** — the OverviewPage trainer card should grow a "Bridge (<TrainerName>)" row whose icon matches the active retrofit mode and whose status follows the emulator.
5. **Trigger an action error** — the centered error banner should slide in (no pointer arrow) and shake on repeat errors.
6. **Confirm the bicycle/logo Lottie animation is gone** and the page still scrolls/lays out cleanly on desktop and mobile widths.

- [ ] **Step 3: Final commit (only if any tests/UI required tweaks)**

If the manual sweep revealed regressions, fix them and commit:

```bash
git add -p
git commit -m "fix: <specific regression>"
```

Otherwise nothing further to commit.

---

## Self-review (already done while drafting)

- **Spec coverage:**
  - Single VS connect mode ✓ Tasks 1–4 (transport getter → resolver → picker collapse).
  - Bridge row in trainer card ✓ Task 8.
  - Remove "Connected | Bridge Status" from `ProxyDevice` ✓ Task 6.
  - Replace `BaseDevice` icon + connection text with `StatusIcon` ✓ Task 7.
  - Remove `_buildFlowRow` and all its glue/assets ✓ Tasks 9–11.
- **Type consistency:** `_ConnectMode` enum is introduced and used uniformly in Task 4; `preferredBridgeTransport` returns `TrainerConnectionType?` and is consumed in Task 4 with a `switch` covering all three cases (`bluetooth`, `wifi`, `null`). `RetrofitMode` references are unchanged in the prop layer.
- **No placeholders:** every step has its concrete code or command. The `if no other file uses them` check in Task 7 step 3 is a defensive verification, not a placeholder.
