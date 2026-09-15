import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/gamepad/gamepad_device.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/devices/hid/hid_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_sensor_device.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_climb.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/inactivity_disconnector.dart';
import 'package:bike_control/bluetooth/incline/incline_controller.dart';
import 'package:bike_control/bluetooth/incline/incline_sink.dart';
import 'package:bike_control/bluetooth/incline/manual_incline_device.dart';
import 'package:bike_control/bluetooth/support_log_buffer.dart';
import 'package:bike_control/bluetooth/wifi_trainer_scanner.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/models/remembered_device.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_bridge_binding.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/services/sensors/sensor_sink_controller.dart';
import 'package:bike_control/services/sensors/sensor_sink_sync.dart';
import 'package:bike_control/services/sensors/sensor_source.dart';
import 'package:bike_control/services/sensors/standalone_sensor_lifecycle.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/interpreter.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gamepads/gamepads.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/sensor_definition.dart';
import 'package:prop/prop.dart';
import 'package:universal_ble/universal_ble.dart';

import 'devices/base_device.dart';
import 'devices/zwift/constants.dart';
import 'messages/notification.dart';

class Connection {
  final devices = <BaseDevice>[];

  /// Apple Health as a heart-rate source. Non-null only on iOS with Health
  /// data available (see the SensorHub wiring in [initialize]); tests inject
  /// one over a fake channel. Its existence IS the "is HealthKit supported"
  /// signal the signals grid reads — there is deliberately no second flag.
  HealthKitSensorSource? healthKitSource;

  bool get isHealthKitConnected =>
      core.sensors.sources.any((s) => s.id == HealthKitSensorSource.sourceId);

  List<BluetoothDevice> get bluetoothDevices => devices.whereType<BluetoothDevice>().toList();
  List<ProxyDevice> get proxyDevices => devices.whereType<ProxyDevice>().toList();
  List<GamepadDevice> get gamepadDevices => devices.whereType<GamepadDevice>().toList();
  List<GyroscopeSteering> get gyroscopeDevices => devices.whereType<GyroscopeSteering>().toList();
  List<WahooKickrHeadwind> get accessories => devices.whereType<WahooKickrHeadwind>().toList();
  List<WahooKickrClimb> get climbAccessories => devices.whereType<WahooKickrClimb>().toList();
  List<ManualInclineDevice> get inclineDevices => devices.whereType<ManualInclineDevice>().toList();
  List<BaseDevice> get controllerDevices => [
    ...bluetoothDevices.where((d) => d is! Accessory && d is! ProxyDevice),
    ...gamepadDevices,
    ...gyroscopeDevices,
    ...devices.whereType<HidDevice>(),
  ];

  var _androidNotificationsSetup = false;

  final _connectionQueue = <BaseDevice>[];
  var _handlingConnectionQueue = false;

  final Map<BaseDevice, StreamSubscription<BaseNotification>> _streamSubscriptions = {};
  final StreamController<BaseNotification> _actionStreams = StreamController<BaseNotification>.broadcast();
  Stream<BaseNotification> get actionStream => _actionStreams.stream;
  /// High-level app events (shifts, ERG targets, mode changes, handled errors)
  /// — the "Logs:" section of the support bundle. Kept in its own buffer so the
  /// verbose wire trace can never evict it (see [lastTraceEntries]).
  final SupportLogBuffer _appLog = SupportLogBuffer(500);
  List<({DateTime date, String entry})> get lastLogEntries => _appLog.entries;

  /// Verbose DirCon/trainer wire trace (`IN>`/`OUT<`/`trainer>`/`trainer<`),
  /// recorded for everyone from [startLogCapture] on. Separate from
  /// [lastLogEntries] so a few dozen frames per second can't flush the
  /// high-level events a support bundle needs — a beta bundle used to arrive
  /// as pure wire trace with every shift/ERG/control line gone. Deliberately
  /// not gated on any entitlement: the beta gate this used to have only
  /// resolved once IAP/Supabase finished initialising — minutes into a session
  /// on a cold start — and silently dropped exactly the
  /// connect/handshake/first-ride window a support bundle exists to show.
  final SupportLogBuffer _traceLog = SupportLogBuffer(2000);
  List<({DateTime date, String entry})> get lastTraceEntries => _traceLog.entries;

  void _appendLogEntry(String entry) => _appLog.add(entry);

  bool _logCaptureStarted = false;

  /// Start buffering [LogNotification]s (and, for beta testers, the verbose
  /// trace) into [lastLogEntries] independently of the full [initialize], which
  /// only runs once the app content mounts. Called at startup so handled errors
  /// during the bootstrap — before [initialize] — still reach the support and
  /// startup-recovery log bundle. Idempotent.
  void startLogCapture() {
    if (_logCaptureStarted) return;
    _logCaptureStarted = true;

    actionStream.listen((log) => _appendLogEntry(log.toString()));

    // The verbose DirCon/trainer wire trace, in its OWN buffer ([_traceLog])
    // so a high-rate trace never evicts the high-level events in
    // [lastLogEntries]. A release build has no console to read
    // `IN>`/`OUT<`/`trainer<` from, so this is the only way that traffic
    // reaches a support bundle. The string is already built for every trace
    // call once this sink is set, so recording it costs nothing beyond the
    // bounded buffer.
    Logger.onTrace = _traceLog.add;
  }

  final Map<BaseDevice, StreamSubscription<bool>> _connectionSubscriptions = {};
  final StreamController<BaseDevice> _connectionStreams = StreamController<BaseDevice>.broadcast();
  Stream<BaseDevice> get connectionStream => _connectionStreams.stream;
  final StreamController<BluetoothDevice> _rssiConnectionStreams = StreamController<BluetoothDevice>.broadcast();
  Stream<BluetoothDevice> get rssiConnectionStream => _rssiConnectionStreams.stream;

  final _lastScanResult = <BleDevice>[];
  final ValueNotifier<bool> hasDevices = ValueNotifier(false);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);

  /// Parsed adverts of nearby SRAM controllers (shifters/blips/pods — NOT the RD),
  /// used to name and pre-register their buttons. Deduped by serial (last wins).
  Iterable<SramDeviceInfo> get sramShifterAdverts {
    final byserial = <int, SramDeviceInfo>{};
    for (final adv in _lastScanResult) {
      final record = _sramServiceDataRecord(adv.serviceData);
      if (record == null) continue;
      final info = SramAdvertisement.parse(record);
      if (info == null || info.isRearDerailleur) continue; // controllers only
      final t = info.effectiveType;
      // Only controllers that have buttons: drop/Reverb/Blipbox shifters (0..4) and blips/pods (96..125).
      // `effectiveType` falls back through the model→type map, so a shifter model
      // resolves to type 0 and a front derailleur (128) / dropper post (132) is excluded.
      final hasButtons = t != null && ((t >= 0 && t <= 4) || (t >= 96 && t <= 125));
      if (!hasButtons) continue;
      byserial[info.serial] = info;
    }
    return byserial.values;
  }

  /// Whether a Zwift Click V2 left puck is switched on within range.
  ///
  /// Read from the raw adverts, not from [devices], and deliberately so: what
  /// matters is a sibling being *nearby*, not paired. In right-side-only mode
  /// the left puck is on the ignored list and so never enters [devices] at
  /// all, yet it is still advertising and still counts.
  bool get hasNearbyClickV2LeftSide {
    if (_lastScanResult.any(isClickV2LeftSideAdvert)) return true;
    // A left puck that connected before the scan list was last cleared no
    // longer has an advert to find, but is plainly still there.
    return devices.whereType<ZwiftClickV2LeftSide>().any((d) => d.isConnected);
  }

  /// Whether an advert is a Click V2 left puck, by the Zwift manufacturer
  /// record's device-type byte. Split out from [hasNearbyClickV2LeftSide] so
  /// the identification can be tested without a radio.
  @visibleForTesting
  static bool isClickV2LeftSideAdvert(BleDevice adv) {
    final payload = adv.manufacturerDataList
        .firstOrNullWhere((e) => e.companyId == ZwiftConstants.ZWIFT_MANUFACTURER_ID)
        ?.payload;
    if (payload == null || payload.isEmpty) return false;
    return ZwiftDeviceType.fromManufacturerData(payload.first) == ZwiftDeviceType.clickV2Left;
  }

  static Uint8List? _sramServiceDataRecord(Map<String, Uint8List> serviceData) {
    for (final e in serviceData.entries) {
      if (e.key.toLowerCase().contains('fe51')) return e.value;
    }
    return null;
  }

  Timer? _gamePadSearchTimer;
  WifiTrainerScanner? _wifiTrainerScanner;

  /// Auto-disconnects idle BLE controllers to save battery (issue #329).
  /// Created in [initialize] once `core` is ready.
  InactivityDisconnector? _inactivityDisconnector;

  InclineController? _inclineController;
  _ClimbRelaySink? _relaySink;
  FitnessBikeDefinition? _relaySinkFbd;

  // ── Remembered devices ────────────────────────────────────────────────
  // A controller that is switched off or out of range used to vanish from the
  // app entirely. These three members keep it on screen instead: rebuilt from
  // the advertisement we stored the last time it connected, greyed out, and
  // still editable.

  /// Controllers known from a previous session, rebuilt from their stored
  /// advertisement. Kept deliberately OUT of [devices] and out of
  /// [_connectionQueue] so a remembered entry never triggers a connection
  /// attempt on its own — it is a picture of a device, not a device.
  final Map<String, BaseDevice> _offlineControllers = {};

  /// The last smart trainer that connected, as data. Unlike controllers this is
  /// never rebuilt into an object: the trainer card needs a name and a route
  /// into its settings page, not buttons or a contour, and constructing a
  /// [ProxyDevice] allocates an emulator we would never start.
  RememberedDevice? rememberedTrainer;

  /// Ids of devices that have connected at least once in this app session.
  ///
  /// This is what separates "lost connection" (red — it was working and broke)
  /// from "out of range" (amber — you just haven't switched it on yet). A fresh
  /// launch with the controller in a drawer must not paint the screen red.
  // Not annotated `Set<String>`: `prop` exports its own non-generic `Set`,
  // which shadows dart:core's here. The literal infers the right type.
  final _connectedThisSession = <String>{};

  bool wasConnectedThisSession(String uniqueId) => _connectedThisSession.contains(uniqueId);

  /// Remembered controllers that no live device has taken over yet. Once the
  /// real device is discovered and enters [devices], its offline stand-in drops
  /// out of this list so the rider never sees the same controller twice.
  List<BaseDevice> get offlineControllers {
    final liveIds = devices.map((d) => d.uniqueId).toSet();
    return _offlineControllers.values.where((d) => !liveIds.contains(d.uniqueId)).toList();
  }

  /// Rebuilds the remembered controllers and restores the remembered trainer.
  /// Safe to call more than once — entries already present are left alone.
  void loadRememberedDevices() {
    final ignoredIds = core.settings.getIgnoredDevices().map((d) => d.id).toSet();
    for (final remembered in core.rememberedDevices.load()) {
      if (ignoredIds.contains(remembered.deviceId)) continue;

      if (remembered.kind == RememberedDeviceKind.trainer) {
        rememberedTrainer ??= remembered;
        continue;
      }
      if (_offlineControllers.containsKey(remembered.deviceId)) continue;

      try {
        // The stored advert is exactly what the factory reads, so this yields a
        // real device of the right subclass — correct buttons, correct contour.
        final device = BluetoothDevice.fromScanResult(remembered.toScanResult());
        if (device != null) _offlineControllers[remembered.deviceId] = device;
      } catch (e, s) {
        recordError(e, s, context: 'Connection.loadRememberedDevices ${remembered.deviceId}');
      }
    }
  }

  /// Drops a remembered device and returns the index it sat at, so an Undo can
  /// put it back exactly where the rider saw it. Bindings in the keymap are
  /// left alone and the device is NOT ignored, so switching it on nearby still
  /// connects it normally.
  Future<int?> forgetRemembered(String deviceId) async {
    _offlineControllers.remove(deviceId);
    if (rememberedTrainer?.deviceId == deviceId) rememberedTrainer = null;
    final index = await core.rememberedDevices.forget(deviceId);
    hasDevices.value = devices.isNotEmpty || _offlineControllers.isNotEmpty;
    return index;
  }

  Future<void> restoreRemembered(RememberedDevice device, {int? atIndex}) async {
    await core.rememberedDevices.restore(device, atIndex: atIndex);
    loadRememberedDevices();
    hasDevices.value = devices.isNotEmpty || _offlineControllers.isNotEmpty;
  }

  /// Marks a device as genuinely connected in this session, and remembers it.
  ///
  /// Called from both the BLE connection-state listener and the post-connect
  /// path, since neither covers every device type on its own. Remembering is
  /// idempotent (the repository dedupes by id and refreshes the timestamp), so
  /// arriving twice for one connect is harmless.
  void _noteConnected(BaseDevice device) {
    _connectedThisSession.add(device.uniqueId);
    unawaited(_rememberConnectedDevice(device));
    _registerSensorSource(device);
  }

  /// Gives the hub a live [SensorSource] the moment a sensor actually reaches
  /// connected state — never at construction, since `fromScanResult` builds
  /// one object per scan result whether or not the rider ever connects it.
  ///
  /// Gated on [BleSensorDevice] rather than a concrete type: a strap, a
  /// cadence sensor and a power meter all own a [BleSensorSource] the same
  /// way, and dispatching on the shared interface means the NEXT sensor type
  /// only has to mix it in, not earn a third `is` check here.
  ///
  /// Called from [_noteConnected], so it inherits the same "arriving twice is
  /// harmless" contract: `SensorHub.register` re-keys a map entry and rebinds
  /// only the quantities that already point at this id, so registering the
  /// same instance again is a no-op in every observable way.
  void _registerSensorSource(BaseDevice device) {
    if (device is! BleSensorDevice) return;
    try {
      core.sensors.register(device.source);
      unawaited(device.source.start());
    } catch (e, s) {
      recordError(e, s, context: 'Connection._registerSensorSource ${device.source.id}');
    }
  }

  /// The disconnect-side counterpart of [_registerSensorSource]: drops the
  /// hub's registration and stops the source so its retained reading is
  /// cleared rather than left to be served stale past its TTL. A rediscovered
  /// sensor arrives as a brand new device and source object (see
  /// `SensorHub.register`'s doc comment), so there is nothing here worth
  /// keeping around once this one is gone.
  ///
  /// Gated on [BleSensorDevice] for the same reason as
  /// [_registerSensorSource] — see its doc comment. Delegates the actual
  /// teardown to [_unregisterSource], shared with [disconnectHealthKit].
  Future<void> _unregisterSensorSource(BaseDevice device, {required bool forget}) async {
    if (device is! BleSensorDevice) return;
    await _unregisterSource(device.source, forget: forget, context: 'Connection._unregisterSensorSource');
  }

  /// Shared by the BLE path above and [disconnectHealthKit]: drop the hub
  /// registration, optionally clear every selection pointing at this id, and
  /// stop the source so its retained reading is cleared rather than served
  /// stale past its TTL.
  ///
  /// `SensorHub.unregister` deliberately leaves the rider's selection
  /// pointing at this id (see its own doc comment) — it cannot tell a
  /// transient drop from the rider being done with the device, so it always
  /// assumes the former. Only [forget] means the latter: [Connection] is the
  /// one place that actually knows the rider forgot this source (as opposed
  /// to it merely dropping out — BLE range, or a transient HealthKit hiccup —
  /// to be rediscovered a moment later), so clearing the selection for good
  /// is done here, explicitly, and only then — a transient drop must leave it
  /// alone so `register`'s rebind loop still matches when the source
  /// reappears.
  Future<void> _unregisterSource(SensorSource source, {required bool forget, required String context}) async {
    try {
      core.sensors.unregister(source.id);
      if (forget) {
        for (final quantity in source.provides) {
          if (core.sensors.selectionFor(quantity) == source.id) {
            core.sensors.select(quantity, null);
          }
        }
      }
      await source.stop();
    } catch (e, s) {
      recordError(e, s, context: '$context ${source.id}');
    }
  }

  /// The HealthKit analogue of a strap connect: ask for Health permission
  /// (a no-op sheet-wise once granted), then register so `SensorHub` calls
  /// `start()` and the native session/query begins. `unknown` proceeds —
  /// HealthKit hides read denials, so refusing on anything but an explicit
  /// share denial would refuse riders who actually said yes.
  Future<void> connectHealthKit() async {
    final source = healthKitSource;
    if (source == null) return;
    final verdict = await source.authorize();
    if (verdict == HealthKitAuthorization.denied) throw HealthKitDeniedException();
    try {
      core.sensors.register(source);
      unawaited(source.start());
    } catch (e, s) {
      recordError(e, s, context: 'Connection.connectHealthKit');
      rethrow;
    }
  }

  /// Mirrors [_unregisterSensorSource]'s `forget` semantics exactly —
  /// `true` only when the rider is done with Apple Health, never for a
  /// transient failure.
  Future<void> disconnectHealthKit({required bool forget}) async {
    final source = healthKitSource;
    if (source == null || !isHealthKitConnected) return;
    await _unregisterSource(source, forget: forget, context: 'Connection.disconnectHealthKit');
  }

  /// Cold launch with Apple Health persisted as the heart-rate source:
  /// re-register without a tap. iOS remembers the authorization, so this
  /// shows no sheet. A denial here (the rider revoked access in Settings
  /// meanwhile) is swallowed on purpose: the tile then shows the persisted
  /// pick as "Connecting…" and a tap re-prompts.
  Future<void> restoreHealthKitSelection() async {
    if (healthKitSource == null) return;
    if (core.sensors.selectionFor(SensorQuantity.heartRate) != HealthKitSensorSource.sourceId) return;
    try {
      await connectHealthKit();
    } on HealthKitDeniedException {
      _appendLogEntry('HealthKit: persisted Apple Health selection not restored — permission denied');
    }
  }

  /// Builds the source only where it can work. `isAvailable` is a cheap
  /// synchronous check on the native side; keeping it async here keeps
  /// `initialize` free of a platform round-trip on the critical path.
  Future<void> _probeHealthKit() async {
    try {
      final channel = MethodChannelHealthKit();
      if (!await channel.isAvailable()) return;
      healthKitSource = HealthKitSensorSource(channel: channel);
      await restoreHealthKitSelection();
    } catch (e, s) {
      recordError(e, s, context: 'Connection._probeHealthKit');
    }
  }

  /// Records a device we just connected to. Accessories are skipped — they are
  /// not links in the setup chain and would only clutter the remembered list.
  Future<void> _rememberConnectedDevice(BaseDevice device) async {
    if (device is! BluetoothDevice) return;
    if (device is Accessory) return;

    final kind = device is ProxyDevice ? RememberedDeviceKind.trainer : RememberedDeviceKind.controller;
    final remembered = RememberedDevice.fromScanResult(
      device.device,
      kind: kind,
      lastConnected: DateTime.now(),
    );
    if (kind == RememberedDeviceKind.trainer) {
      rememberedTrainer = remembered;
    } else {
      // The live device supersedes its own stand-in.
      _offlineControllers.remove(device.uniqueId);
    }
    await core.rememberedDevices.remember(remembered);
  }

  /// Devices whose in-place ("No connection") disconnect is currently in
  /// flight. UniversalBle.disconnect resolves only after the platform's
  /// disconnect event has fired — while our connectionStream listener is
  /// still attached. Without this guard that listener re-enters [disconnect]
  /// WITHOUT keepInList and drops the device from the registry, orphaning the
  /// object the open details page still holds.
  final _inPlaceDisconnects = <BaseDevice>{};

  /// Devices whose [disconnect] is currently running its teardown. The same
  /// mid-teardown platform event re-enters [disconnect] from the drop listener
  /// with `dropped: true` — at that point the device still reads as connected
  /// (BaseDevice.disconnect clears the flag last), so without this guard the
  /// echo would start a second, concurrent teardown of the same device.
  final _disconnecting = <BaseDevice>{};

  /// BLE ids of controllers disconnected by the inactivity battery saver. They
  /// are deliberately NOT added to the ignore list (so the user can reconnect),
  /// but must not be auto-reconnected when rediscovered (via scan results,
  /// getSystemDevices or the disconnect listener's performScanning) — otherwise
  /// they reconnect right after the battery-saver disconnect. Cleared on an
  /// explicit reconnect, a successful (re)connect, or automatically once
  /// [inactivityReconnectCooldown] has elapsed — after that a rediscovered
  /// (woken) controller auto-reconnects normally again.
  final _suppressedAutoReconnect = <String>{};

  /// How long after the battery-saver disconnect a controller stays suppressed.
  /// Long enough for the controller to stop advertising and fall asleep;
  /// afterwards any advertisement means the rider woke it and wants it back.
  /// Mutable as a test seam (the integration tests shrink it to milliseconds).
  Duration inactivityReconnectCooldown = const Duration(seconds: 90);

  /// Whether [device] is currently sitting out a battery-saver or backoff
  /// suppression window (see [_suppressedAutoReconnect]). Read-only escape
  /// hatch for callers outside this class (e.g. [ClickV2Onboarding]) that
  /// enumerate devices themselves and must not force-reconnect one the
  /// battery saver deliberately put to sleep.
  bool isAutoReconnectSuppressed(BaseDevice device) =>
      device is BluetoothDevice && _suppressedAutoReconnect.contains(device.device.deviceId);

  /// Consecutive failed auto-connect attempts per BLE device id. Only devices
  /// with [BluetoothDevice.maxAutoConnectAttempts] > 0 ever suppress; reset by
  /// a successful connect.
  final _consecutiveConnectFailures = <String, int>{};

  /// Device ids whose give-up alert was already shown this session — later
  /// suppression rounds only log, so one stubborn device produces one alert.
  final _backoffAlerted = <String>{};

  /// How long a device that exhausted its attempts stays suppressed before
  /// rediscovery may try again (one quiet attempt per round). Mutable as a
  /// test seam.
  Duration autoConnectBackoffCooldown = const Duration(seconds: 90);

  /// Pending cooldown timers from [_recordConnectFailure], keyed by BLE device
  /// id. Backoff shares [_suppressedAutoReconnect] with the battery saver, so a
  /// stale timer left running past a Retry/reconnect could lift a later —
  /// possibly unrelated — suppression early; tracked here so it can be
  /// cancelled the moment the suppression it guards is lifted some other way.
  final _backoffCooldownTimers = <String, Timer>{};

  /// When each BLE device last became connected — used to spot a pod that
  /// connects but drops again within [quickDropThreshold] (e.g. a WHEELTOP TX
  /// pod whose keepalive we can't answer). Such a connect looks successful to
  /// the connect queue, so [_consecutiveConnectFailures] never catches it.
  final _connectedAt = <String, DateTime>{};

  /// Consecutive quick drops per BLE device id (a connect that dies within
  /// [quickDropThreshold]). Counted only for devices that do NOT opt out via
  /// [BluetoothDevice.keepsReconnectingWhileDropping]; drives the same backoff
  /// as [_consecutiveConnectFailures] once it reaches the device's limit.
  final _quickDropCounts = <String, int>{};

  /// A connection that dies within this window counts as a quick drop. Mutable
  /// as a test seam.
  Duration quickDropThreshold = const Duration(seconds: 5);

  /// True once [device] has exhausted its auto-connect attempts (failed
  /// connects or quick drops) — backoff rounds stay quiet: no
  /// connecting/disconnected toasts, no OS notification.
  bool _isInBackoff(BaseDevice device) {
    if (device is! BluetoothDevice || device.maxAutoConnectAttempts <= 0) return false;
    final id = device.device.deviceId;
    return (_consecutiveConnectFailures[id] ?? 0) >= device.maxAutoConnectAttempts ||
        (_quickDropCounts[id] ?? 0) >= device.maxAutoConnectAttempts;
  }

  void initialize() {
    // Show what the rider owns before any radio has said a word.
    loadRememberedDevices();

    startLogCapture();

    _inactivityDisconnector = InactivityDisconnector(
      isTrainerAppConnected: () => core.logic.connectedNonLocalTrainerConnections.isNotEmpty,
      isOnlyLocalActive: () => core.logic.enabledNonLocalTrainerConnections.isEmpty && core.settings.getLocalEnabled(),
      hasEligibleControllers: () => controllerDevices.whereType<BluetoothDevice>().any((d) => d.isConnected),
      onTimeout: _onInactivityTimeout,
    );

    _inclineController ??= InclineController(
      gradeProvider: () => ftmsEmulator.fitnessBike?.simGrade.value,
      sinkProvider: () {
        final direct = devices.whereType<InclineSink>().firstOrNullWhere(
          (d) => (d as BaseDevice).isConnected,
        );
        if (direct != null) return direct;
        final fbd = ftmsEmulator.fitnessBike;
        if (fbd != null && fbd.supportsClimbRelay) {
          if (!identical(_relaySinkFbd, fbd)) {
            _relaySinkFbd = fbd;
            _relaySink = _ClimbRelaySink(fbd);
          }
          return _relaySink;
        }
        _relaySink = null;
        _relaySinkFbd = null;
        return null;
      },
    )..start();

    // A trainer app attaching/leaving any non-Local connection method drives
    // the battery saver. These emulator singletons live for the app lifetime,
    // so the listeners never need removing.
    for (final connection in [
      core.zwiftEmulator,
      core.zwiftMdnsEmulator,
      core.rouvyMdnsEmulator,
      core.obpMdnsEmulator,
      core.obpBluetoothEmulator,
      core.di2Emulator,
      core.whooshLink,
      core.remotePairing,
      core.remoteKeyboardPairing,
    ]) {
      connection.isConnected.addListener(() => _inactivityDisconnector?.onTrainerConnectionChanged());
    }

    if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isIOS)) {
      core.mediaKeyHandler.initialize();
      // Load saved media key detection state
      core.mediaKeyHandler.isMediaKeyDetectionEnabled.value = core.settings.getMediaKeyDetectionEnabled();
    }

    ftmsEmulator.isTrial = () => !IAPManager.instance.isProEnabledForCurrentDevice;

    // Rider metrics BikeControl itself sourced (currently just heart rate) are
    // served through their own definition, which lives either on the bridge's
    // composite or on a standalone emulator — never both. Isolated in its own
    // try/catch so a failure here (e.g. a bad persisted sensor selection)
    // cannot take the rest of connection setup down with it.
    try {
      final sensorDefinition = SensorDefinition();
      final standaloneSensorEmulator = DirconEmulator();
      // Mirrors ftmsEmulator's own wiring above: without this, a lapsed
      // subscriber's standalone heart rate monitor keeps advertising forever,
      // untrialled and unlabelled — the bridge path already refuses to
      // advertise once the trial's spent (`shouldAdvertise`) and marks
      // itself while it still can (`isTrial`); the standalone path must too.
      standaloneSensorEmulator.isTrial = () => !IAPManager.instance.isProEnabledForCurrentDevice;
      standaloneSensorEmulator.shouldAdvertise = () => IAPManager.instance.isProEnabledForCurrentDevice;
      // Attach-before-start / stop-before-detach: DirconEmulator.startServer
      // advertises whatever is already on its composite, so calling it
      // before the definition is attached leaves nothing to serve. See
      // StandaloneSensorLifecycle's doc comment for exactly what that fails
      // with.
      final standaloneSensorLifecycle = StandaloneSensorLifecycle(
        attachDefinition: standaloneSensorEmulator.attachDefinition,
        startServer: () => standaloneSensorEmulator.startServer(mode: RetrofitMode.bluetooth),
        stopServer: standaloneSensorEmulator.stop,
        detachDefinition: standaloneSensorEmulator.detachDefinition,
      );
      final sensorSink = SensorSinkController(
        definition: sensorDefinition,
        // attachDefinition/detachDefinition (not composite.attach/detach
        // directly) so a mid-ride source selection restarts the live bridge
        // transport in place when it needs to — composite.attach alone only
        // updates the composite's bookkeeping.
        attach: ftmsEmulator.attachDefinition,
        detach: ftmsEmulator.detachDefinition,
        startStandalone: standaloneSensorLifecycle.start,
        stopStandalone: () => standaloneSensorLifecycle.stop(sensorDefinition),
      );

      // The buffer this attaches to lives on Connection, built after `core`,
      // which is why `log` is a settable field rather than a constructor arg.
      core.sensors.log = _appLog;
      // Runtime callback, not a one-shot: re-evaluated on every publish (see
      // SensorHub.isProEnabled's doc comment), so a subscription lapsing
      // mid-ride stops resolving on the next tick without the rider ever
      // reselecting anything.
      core.sensors.isProEnabled = () => IAPManager.instance.isProEnabledForCurrentDevice;
      core.sensors.loadSelections(core.settings);
      if (!kIsWeb && Platform.isIOS) {
        unawaited(_probeHealthKit());
      }
      Timer.periodic(const Duration(seconds: 1), (_) => core.sensors.tick());

      // Keeps the sink synced to both the bridge's isStarted AND whether the
      // rider has picked a heart rate source at all — a cold launch with
      // nothing selected must not stand up an empty "BikeControl" HRM
      // advertisement (see SensorSinkSync's doc comment). Also the retry path
      // for a standalone start that failed at launch: any later selection
      // change re-syncs, not just a bridge transition.
      SensorSinkSync(
        hub: core.sensors,
        isBridgeRunning: ftmsEmulator.isStarted,
        sink: sensorSink,
      ).start();

      SensorBridgeBinding(
        hub: core.sensors,
        onHeartRate: (bpm) {
          ftmsEmulator.fitnessBike?.setExternalHeartRate(bpm);
          sensorDefinition.setHeartRate(bpm);
        },
        // Cadence and power are NOT unconditionally forwarded to
        // sensorDefinition the way heart rate is. FTMS Indoor Bike Data
        // already carries both while a trainer is bridged
        // (setExternalCadence/setExternalPower feed that packet directly), so
        // the standalone-only definition must never be told about them while
        // bridged — doing so would newly expose CSC/Cycling Power on the
        // bridge's own GATT table. sensorDefinition advertises CSC/Cycling
        // Power unconditionally, the same as heart rate always has;
        // SensorSinkController is what keeps them off the bridge, by calling
        // sensorDefinition.retractCadenceAndPowerForBridge() before every
        // bridge attach (see that method's doc comment for the defect this
        // guards against).
        onCadence: (rpm) {
          ftmsEmulator.fitnessBike?.setExternalCadence(rpm);
          if (!ftmsEmulator.isStarted.value) sensorDefinition.setCadence(rpm);
        },
        onPower: (watts) {
          ftmsEmulator.fitnessBike?.setExternalPower(watts);
          if (!ftmsEmulator.isStarted.value) sensorDefinition.setPower(watts);
        },
      ).start();
    } catch (e, s) {
      recordError(e, s, context: 'SensorHub wiring');
    }

    // The advertised name depends on the selected trainer app (e.g. Rouvy →
    // "Zwift Hub"). Restart the transport on every change so the new name
    // shows up on the wire without the user reconnecting.
    core.settings.trainerAppListenable.addListener(() {
      // Reconcile each device's composite membership (a VS bridge takes its
      // ride-along controller on/off depending on the app, and a Click V2
      // rides on the bridge for some apps but not others) BEFORE the shared
      // emulator re-advertises, so the new advertisement reflects the change.
      for (final pd in proxyDevices) {
        unawaited(pd.onTrainerAppChanged());
      }
      for (final click in bluetoothDevices.whereType<ZwiftClickV2>()) {
        click.onTrainerAppChanged();
      }
      unawaited(ftmsEmulator.restart());
    });

    // Inform the user when ClickLogic restarts a device on purpose — its
    // entry greys out for a few seconds, so explain why.
    ClickLogic.onResetSent = (deviceId) {
      final device = bluetoothDevices.firstOrNullWhere((e) => e.device.deviceId == deviceId);
      if (device != null) {
        _actionStreams.add(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.deviceIsRestarting(device.toString())),
        );
      }
    };

    // Whether the right puck's lights will stay lit — only this side can see
    // what is in range. Never gates the keep-awake itself.
    ClickLogic.isLeftSideNearby = () => hasNearbyClickV2LeftSide;

    UniversalBle.onAvailabilityChange = (available) {
      _actionStreams.add(BluetoothAvailabilityNotification(available == AvailabilityState.poweredOn));
      if (available == AvailabilityState.poweredOn && !kIsWeb && !core.logic.deferLaunchPermissions) {
        core.permissions.getScanRequirements().then((perms) {
          if (perms.isEmpty) {
            performScanning();
          }
        });
      } else if (available == AvailabilityState.poweredOff) {
        disconnectAll();
        stop();
      }
    };
    UniversalBle.onScanResult = (result) {
      // Update RSSI for already connected devices
      final existingDevice = bluetoothDevices.firstOrNullWhere(
        (e) => e.device.deviceId == result.deviceId,
      );
      if (existingDevice != null && existingDevice.rssi != result.rssi) {
        existingDevice.rssi = result.rssi;
        _rssiConnectionStreams.add(existingDevice); // Notify UI of update
      }

      if (_lastScanResult.none((e) => e.deviceId == result.deviceId && e.services.contentEquals(result.services))) {
        _lastScanResult.add(result);

        // A left puck coming into range is what brings the right one's LEDs
        // back, so re-enter the mode now rather than waiting up to a tick for
        // it. An ignored left puck never gets further than this — it is
        // discovered and then dropped — so discovery is the only signal.
        // Deliberately narrowed to left pucks: this re-runs the sequence, and
        // every other advert would make that an erase for nothing.
        if (isClickV2LeftSideAdvert(result)) {
          ClickLogic.startKeepAwakeIfPending();
        }

        if (kDebugMode) {
          debugPrint('Scan result: ${result.name} - ${result.deviceId} - Services: ${result.services}');
        }

        try {
          final scanResult = BluetoothDevice.fromScanResult(result);

          if (scanResult != null) {
            _actionStreams.add(
              LogNotification('Found new device: ${scanResult.toString()}'),
            );
            addDevices([scanResult]);
          } else {
            final manufacturerData = result.manufacturerDataList;
            final data = manufacturerData
                .firstOrNullWhere((e) => e.companyId == ZwiftConstants.ZWIFT_MANUFACTURER_ID)
                ?.payload;
            if (data != null && kDebugMode) {
              _actionStreams.add(
                LogNotification('Found unknown device ${result.name} with identifier: ${data.firstOrNull}'),
              );
            }
          }
        } catch (e, backtrace) {
          _actionStreams.add(
            LogNotification("Error processing scan result for device ${result.deviceId}: $e\n$backtrace"),
          );
          if (kDebugMode) {
            print(e);
            print("backtrace: $backtrace");
          }
        }
      }
    };

    UniversalBle.onValueChange = (deviceId, characteristicUuid, value, timestamp) async {
      final device = bluetoothDevices.firstOrNullWhere((e) => e.device.deviceId == deviceId);
      if (device == null) {
        _actionStreams.add(LogNotification('Device not found: $deviceId'));
        UniversalBle.disconnect(deviceId);
        return;
      } else {
        if (kIsWeb) {
          // on web, log all characteristic changes for debugging
          _actionStreams.add(
            LogNotification(
              'Characteristic update for device ${device.toString()}, char: $characteristicUuid, value: ${bytesToReadableHex(value)}',
            ),
          );
        }
        try {
          await device.processCharacteristic(characteristicUuid, value);
        } catch (e, backtrace) {
          _actionStreams.add(
            LogNotification(
              "Error processing characteristic for device ${device.toString()} and char: $characteristicUuid: $e\n$backtrace",
            ),
          );
          if (kDebugMode) {
            print(e);
            print("backtrace: $backtrace");
          }
        }

        try {
          await _runCustomDeviceScript(
            device: device,
            characteristicUuid: characteristicUuid,
            value: value,
          );
        } catch (e, backtrace) {
          _actionStreams.add(
            LogNotification(
              "Error executing script for ${device.runtimeType} and char: $characteristicUuid: $e\n$backtrace",
            ),
          );
          if (e is FormatException) {
            final deviceType = device.runtimeType.toString();
            await DeviceScriptService.instance.deleteScript(deviceType);
            _actionStreams.add(
              LogNotification(
                "Deactivated custom script for ${device.runtimeType} due to invalid output format.",
              ),
            );
          }
          if (kDebugMode) {
            print(e);
            print("backtrace: $backtrace");
          }
        }
      }
    };

    UniversalBle.onConnectionChange = (String deviceId, bool isConnected, String? error) {
      final device = bluetoothDevices.firstOrNullWhere((e) => e.device.deviceId == deviceId);
      if (device != null && !isConnected) {
        // allow reconnection
        _lastScanResult.removeWhere((d) => d.deviceId == deviceId);
      }
    };

    if (!kIsWeb && !screenshotMode) {
      // Checking permissions means *asking* for them on Apple platforms, so a
      // fresh install with nothing configured must not reach this: the wizard
      // owns that conversation. Everyone else is checked at launch, so a
      // permission revoked in System Settings surfaces here rather than as a
      // silently dead connection.
      if (!core.logic.deferLaunchPermissions) {
        core.permissions.getScanRequirements().then((perms) {
          if (perms.isEmpty) {
            performScanning();
          }
        });
      }
      if (core.settings.getPhoneSteeringEnabled() && IAPManager.instance.isProEnabledForCurrentDeviceOrDidPurchaseOld) {
        toggleGyroscopeSteering(true);
      }
    }
  }

  Future<void> performScanning() async {
    if (isScanning.value) {
      return;
    }
    isScanning.value = true;
    _actionStreams.add(LogNotification(AppLocalizations.current.scanningForDevicesShort));

    if (screenshotMode) {
      return;
    }

    // does not work on web, may not work on Windows
    if (!kIsWeb && !Platform.isWindows) {
      UniversalBle.getSystemDevices(
        withServices: BluetoothDevice.servicesToScan,
      ).then((devices) async {
        // getSystemDevices reports OS-connected/bonded devices, not live
        // advertisements — isEligibleSystemDevice keeps that query from
        // grabbing another app's power meter as if it were a trainer (see
        // its doc comment; fix-wave-C).
        final baseDevices = devices
            .mapNotNull(BluetoothDevice.fromScanResult)
            .where(BluetoothDevice.isEligibleSystemDevice)
            .toList();
        if (baseDevices.isNotEmpty) {
          addDevices(baseDevices);
        }
      });
    }

    await UniversalBle.startScan(
      // allow all to enable Wahoo Kickr Bike Shift detection
      //scanFilter: kIsWeb ? ScanFilter(withServices: BluetoothDevice.servicesToScan) : null,
      platformConfig: PlatformConfig(web: WebOptions(optionalServices: BluetoothDevice.servicesToScan)),
    );

    if (!kIsWeb) {
      _startWifiTrainerDiscovery();
      _gamePadSearchTimer = Timer.periodic(Duration(seconds: 3), (_) {
        Gamepads.list().then((list) {
          final pads = list.map((pad) => GamepadDevice(pad.name.isEmpty ? 'Gamepad' : pad.name, id: pad.id)).toList();
          addDevices(pads);

          final removedDevices = gamepadDevices.where((device) => list.none((pad) => pad.id == device.id)).toList();
          for (var device in removedDevices) {
            devices.remove(device);
            _streamSubscriptions[device]?.cancel();
            _streamSubscriptions.remove(device);
            _connectionSubscriptions[device]?.cancel();
            _connectionSubscriptions.remove(device);
            signalChange(device);
          }
        });
      });
    } else {
      isScanning.value = false;
    }
  }

  /// Browse the LAN for DirCon trainers (always on while scanning; the
  /// scanner excludes BikeControl's own advertisements). Failures — e.g. the
  /// user denied the Local Network permission — are logged and never affect
  /// BLE scanning.
  void _startWifiTrainerDiscovery() {
    _wifiTrainerScanner ??= WifiTrainerScanner(
      onFound: (trainer) {
        _actionStreams.add(LogNotification('Found WiFi trainer: ${trainer.syntheticDevice.name}'));
        addDevices([ProxyDevice.wifi(trainer.syntheticDevice, host: trainer.host, port: trainer.port)]);
      },
      onLost: (deviceId) {
        final device = proxyDevices.firstOrNullWhere((d) => d.scanResult.deviceId == deviceId);
        // A connected device stays — the live TCP connection is the source
        // of truth; mDNS visibility can flap.
        if (device != null && !device.isConnected && !device.isStarting.value) {
          devices.remove(device);
          _streamSubscriptions[device]?.cancel();
          _streamSubscriptions.remove(device);
          _connectionSubscriptions[device]?.cancel();
          _connectionSubscriptions.remove(device);
          hasDevices.value = devices.isNotEmpty;
          signalChange(device);
        }
      },
    );
    _wifiTrainerScanner!.start().catchError((Object e, s) {
      _actionStreams.add(LogNotification('WiFi trainer discovery unavailable: $e'));
      recordError(e, s, context: 'Wifi Trainer Discovery');
    });
  }

  Future<void> _runCustomDeviceScript({
    required BluetoothDevice device,
    required String characteristicUuid,
    required Uint8List value,
  }) async {
    if (!IAPManager.instance.isPurchased.value && !IAPManager.instance.hasActiveSubscription) {
      return;
    }

    final scriptOutput = await DeviceScriptService.instance.runCustomScript(
      deviceType: device.runtimeType.toString(),
      characteristicUuid: characteristicUuid,
      data: value,
    );

    if (scriptOutput == null) {
      return;
    }

    final serviceUuid = device.serviceUuidForCharacteristic(scriptOutput.characteristicUuid);
    if (serviceUuid == null) {
      _actionStreams.add(
        LogNotification(
          'Script output characteristic ${scriptOutput.characteristicUuid} was not found on ${device.runtimeType}.',
        ),
      );
      return;
    }

    final characteristic = device.services
        ?.firstOrNullWhere((s) => s.uuid == serviceUuid)
        ?.characteristics
        .firstOrNullWhere((c) => c.uuid == scriptOutput.characteristicUuid);

    if (characteristic == null) {
      _actionStreams.add(
        LogNotification(
          'Script output characteristic ${scriptOutput.characteristicUuid} was not found on ${device.runtimeType}.',
        ),
      );
      return;
    } else if (!characteristic.properties.containsAny([
      CharacteristicProperty.write,
      CharacteristicProperty.writeWithoutResponse,
    ])) {
      _actionStreams.add(
        LogNotification(
          'Script output characteristic ${scriptOutput.characteristicUuid} on ${device.runtimeType} does not support writing.',
        ),
      );
      return;
    }

    await UniversalBle.write(
      device.device.deviceId,
      serviceUuid,
      scriptOutput.characteristicUuid,
      scriptOutput.data,
      withoutResponse: characteristic.properties.contains(CharacteristicProperty.writeWithoutResponse) == true,
    );
  }

  Future<void> startMyWhooshServer() {
    return core.whooshLink.startServer().catchError((e) {
      core.settings.setMyWhooshLinkEnabled(false);
      _actionStreams.add(LogNotification('Error starting MyWhoosh "Link" server: $e'));
      _actionStreams.add(
        AlertNotification(
          LogLevel.LOGLEVEL_ERROR,
          AppLocalizations.current.errorStartingMyWhooshLink,
        ),
      );
    });
  }

  void addDevices(List<BaseDevice> dev) {
    final ignoredDevices = core.settings.getIgnoredDevices();
    final ignoredDeviceIds = ignoredDevices.map((d) => d.id).toSet();
    final newDevices = dev.where((device) {
      if (devices.contains(device)) return false;

      // Check if device is in the ignored list
      if (device is BluetoothDevice) {
        if (ignoredDeviceIds.contains(device.device.deviceId)) {
          return false;
        }
        // A controller the battery saver disconnected must not silently
        // reconnect when rediscovered until the reconnect cooldown has passed
        // or the user explicitly reconnects it.
        if (_suppressedAutoReconnect.contains(device.device.deviceId)) {
          return false;
        }
      }

      return true;
    }).toList();
    devices.addAll(newDevices);
    _connectionQueue.addAll(newDevices);

    // A device kept in the list during an automatic reset cycle reappeared in
    // the scan: its fresh instance is filtered out above (same id), so queue
    // the existing instance for reconnection instead.
    final resetDevices = dev
        .mapNotNull((d) => devices.firstOrNullWhere((e) => e == d))
        .where((e) => e.isResetting && !e.isConnected && !_connectionQueue.contains(e))
        .toList();
    _connectionQueue.addAll(resetDevices);

    _handleConnectionQueue();

    hasDevices.value = devices.isNotEmpty;
  }

  void toggleGyroscopeSteering(bool enable) {
    final existing = gyroscopeDevices.firstOrNull;
    if (existing != null && !enable) {
      // Remove gyroscope steering
      disconnect(existing, forget: true, persistForget: false);
    } else if (enable) {
      // Add gyroscope steering
      final gyroDevice = GyroscopeSteering();
      addDevices([gyroDevice]);
    }
  }

  void _handleConnectionQueue() {
    // windows apparently has issues when connecting to multiple devices at once, so don't
    if (_connectionQueue.isNotEmpty && !_handlingConnectionQueue && !screenshotMode) {
      _handlingConnectionQueue = true;
      final device = _connectionQueue.removeAt(0);

      final willConnect = device.shouldAutoConnect;
      // Reconnections after an automatic reset happen every minute — keep
      // them silent. Captured here because the flag clears during handshake.
      // A device that already gave up (backoff) only gets quiet cooldown
      // rounds from here on — the guidance alert already said its piece.
      final notify = willConnect && !device.isResetting && !_isInBackoff(device);
      if (notify) {
        _actionStreams.add(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.connectingToDevice(device.toString())),
        );
      }
      _connect(device)
          .then((_) {
            _handlingConnectionQueue = false;

            if (notify) {
              _actionStreams.add(
                AlertNotification(
                  LogLevel.LOGLEVEL_INFO,
                  AppLocalizations.current.connectionSucceeded(device.toString()),
                ),
              );
            }
            if (_connectionQueue.isNotEmpty) {
              _handleConnectionQueue();
            }
          })
          .catchError((e) {
            device.isConnected = false;
            _handlingConnectionQueue = false;
            if (device is BluetoothDevice && device.keepsReconnectingWhileDropping) {
              // Keepalive probe: the reconnect churn is expected and is NOT
              // rear-derailleur contention, so the "claimed by the derailleur"
              // give-up guidance must not fire. Keep it to a quiet log.
              _actionStreams.add(LogNotification('${device.toString()}: connect attempt failed during probe ($e)'));
            } else if (_recordConnectFailure(device)) {
              // Backoff engaged — _recordConnectFailure emitted the guidance alert
              // (or the silent per-round log) in place of the generic toast.
            } else if (e is TimeoutException) {
              _actionStreams.add(
                AlertNotification(
                  LogLevel.LOGLEVEL_WARNING,
                  AppLocalizations.current.unableToConnectToDeviceTimeout(device.toString()),
                ),
              );
            } else {
              _actionStreams.add(
                AlertNotification(
                  LogLevel.LOGLEVEL_ERROR,
                  AppLocalizations.current.connectionFailed(device.toString(), e.toString()),
                ),
              );
            }
            if (_connectionQueue.isNotEmpty) {
              _handleConnectionQueue();
            }
          });
    }
  }

  /// Records a failed auto-connect attempt. Returns true when the device has
  /// exhausted [BluetoothDevice.maxAutoConnectAttempts] and backoff messaging
  /// (guidance alert on the first round, log-only afterwards) replaces the
  /// generic failure toast.
  bool _recordConnectFailure(BaseDevice device) {
    if (device is! BluetoothDevice) return false;
    final maxAttempts = device.maxAutoConnectAttempts;
    if (maxAttempts <= 0) return false;

    final id = device.device.deviceId;
    final failures = (_consecutiveConnectFailures[id] ?? 0) + 1;
    _consecutiveConnectFailures[id] = failures;
    if (failures < maxAttempts) return false;

    _engageBackoff(device);
    return true;
  }

  /// Records a quick drop — a connect that succeeded but died within
  /// [quickDropThreshold] (a WHEELTOP TX pod whose keepalive we can't answer
  /// yet does this in a tight loop). Skipped for devices that opt to keep
  /// cycling via [BluetoothDevice.keepsReconnectingWhileDropping] (the
  /// keepalive probe needs those reconnects). Engages the same backoff once
  /// the drop streak reaches the device's limit.
  void _recordQuickDrop(BluetoothDevice device) {
    final maxAttempts = device.maxAutoConnectAttempts;
    if (maxAttempts <= 0 || device.keepsReconnectingWhileDropping) return;

    final id = device.device.deviceId;
    final drops = (_quickDropCounts[id] ?? 0) + 1;
    _quickDropCounts[id] = drops;
    if (drops >= maxAttempts) _engageBackoff(device);
  }

  /// Suppresses auto-reconnect for [device] for [autoConnectBackoffCooldown],
  /// clears the stale scan-result entry when the cooldown lifts, and shows the
  /// give-up guidance alert once per session (log-only afterwards). Shared by
  /// the connect-failed and quick-drop backoff paths.
  void _engageBackoff(BluetoothDevice device) {
    final id = device.device.deviceId;
    _suppressedAutoReconnect.add(id);
    // Lift the suppression after the cooldown. The stale _lastScanResult entry
    // must go too — it would dedupe every future advertisement and block
    // rediscovery forever (same pitfall the battery-saver cooldown handles).
    // Cancel any earlier round's still-pending timer first — otherwise it
    // fires on its original schedule and can lift a later (even unrelated,
    // e.g. battery-saver) suppression on this id early.
    _backoffCooldownTimers.remove(id)?.cancel();
    _backoffCooldownTimers[id] = Timer(autoConnectBackoffCooldown, () {
      _backoffCooldownTimers.remove(id);
      _suppressedAutoReconnect.remove(id);
      _lastScanResult.removeWhere((d) => d.deviceId == id);
    });

    final guidance = device.connectionGuidance;
    final message = [
      AppLocalizations.current.connectionGaveUpAfterAttempts(device.toString()),
      if (guidance != null) guidance,
    ].join('\n');
    if (_backoffAlerted.add(id)) {
      _actionStreams.add(
        AlertNotification(
          LogLevel.LOGLEVEL_WARNING,
          message,
          buttonTitle: AppLocalizations.current.reconnect,
          onTap: () {
            _backoffCooldownTimers.remove(id)?.cancel();
            _suppressedAutoReconnect.remove(id);
            _consecutiveConnectFailures.remove(id);
            _quickDropCounts.remove(id);
            _lastScanResult.removeWhere((d) => d.deviceId == id);
            addDevices([device]);
          },
        ),
      );
    } else {
      _actionStreams.add(LogNotification(message));
    }
  }

  /// Connect a device that is already in the list — used by the in-place
  /// picker ("No connection" -> Virtual Shifting / Proxy on the same object).
  ///
  /// Routes through the same [_connect] path the auto-connect queue uses so the
  /// action / connection-state listeners are (re)attached. A bare
  /// [ProxyDevice.startProxy] would reconnect the BLE upstream but leave
  /// `isConnected` stuck — the listener that flips it is torn down on
  /// disconnect and only [_connect] re-establishes it.
  Future<void> connectDevice(BaseDevice device) {
    // An explicit reconnect (e.g. the device picker) clears any battery-saver
    // suppression so the controller auto-reconnects normally again afterwards.
    if (device is BluetoothDevice) _suppressedAutoReconnect.remove(device.device.deviceId);
    return _connect(device);
  }

  Future<void> _connect(BaseDevice device) async {
    // Cancel any stale subscriptions from a previous connect attempt so a retry
    // doesn't stack listeners on the same device's streams.
    await _streamSubscriptions.remove(device)?.cancel();
    await _connectionSubscriptions.remove(device)?.cancel();

    final actionSubscription = device.actionStream.listen((data) {
      _actionStreams.add(data);
      // Any button press — from a BLE controller or any other input device —
      // counts as rider activity and slides the inactivity timer. The timer only
      // arms while a BLE controller is connected (see hasEligibleControllers), so
      // non-BLE button activity simply keeps a co-connected controller alive.
      if (data is ButtonNotification) {
        _inactivityDisconnector?.onButtonActivity();
      }
    });
    _streamSubscriptions[device] = actionSubscription;

    if (device is BluetoothDevice) {
      final connectionStateSubscription = device.device.connectionStream.listen((state) {
        // A disconnected event for a device that is still marked connected is
        // a genuine drop; one arriving after a deliberate disconnect (which
        // already cleared the flag) is the platform's late echo of it.
        final wasConnected = device.isConnected;
        device.isConnected = state;
        if (state) _noteConnected(device);
        _connectionStreams.add(device);

        // Quick-drop tracking (Wheeltop TX pods connect then drop within
        // seconds because their keepalive is unanswered — a "successful"
        // connect the connect queue never counts as a failure). Only devices
        // that declare an attempt limit participate.
        if (device.maxAutoConnectAttempts > 0) {
          final id = device.device.deviceId;
          if (state) {
            _connectedAt[id] = DateTime.now();
          } else {
            final connectedAt = _connectedAt.remove(id);
            if (connectedAt != null) {
              if (DateTime.now().difference(connectedAt) >= quickDropThreshold) {
                // Survived long enough — a healthy connection clears the streak.
                _quickDropCounts.remove(id);
              } else {
                _recordQuickDrop(device);
              }
            }
          }
        }

        // An automatic reset cycle (ClickLogic) reboots the device every
        // minute — don't spam connect/disconnect notifications for it.
        final isSilentReset = device.isResetting;
        // A device that already gave up (backoff) delivers its failure as a
        // delayed disconnected event on this same listener — the guidance
        // alert already said its piece, so quiet cooldown rounds stay quiet
        // here too: no disconnected toast, no OS notification.
        final isSilentBackoff = !state && _isInBackoff(device);
        if (!state && !isSilentReset && !isSilentBackoff) {
          _actionStreams.add(
            AlertNotification(
              state ? LogLevel.LOGLEVEL_INFO : LogLevel.LOGLEVEL_WARNING,
              '${device.toString()} ${state ? AppLocalizations.current.connected.decapitalize() : AppLocalizations.current.disconnected.decapitalize()}',
            ),
          );
        }
        if (!isSilentReset && !isSilentBackoff) {
          core.flutterLocalNotificationsPlugin.show(
            id: 1338,
            title:
                '${device.toString()} ${state ? AppLocalizations.current.connected.decapitalize() : AppLocalizations.current.disconnected.decapitalize()}',
            body: !state ? AppLocalizations.current.tryingToConnectAgain : null,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails('Connection', 'Connection Status'),
              iOS: DarwinNotificationDetails(presentAlert: true, presentSound: false),
            ),
          );
        }
        if (!device.isConnected && !_inPlaceDisconnects.contains(device)) {
          disconnect(device, forget: false, persistForget: false, dropped: wasConnected);
          // try reconnect
          performScanning();
        }
      });
      _connectionSubscriptions[device] = connectionStateSubscription;
    }

    try {
      await device.connect();
      if (device is BluetoothDevice) {
        _consecutiveConnectFailures.remove(device.device.deviceId);
      }
      // Deliberately gated on isConnected, not on connect() returning:
      // ProxyDevice.connect() is a no-op unless the rider has actually asked
      // for that trainer, so an ungated add here marks a trainer that never
      // connected as "connected this session" — and the home screen then
      // reports a brand-new trainer as having lost its connection.
      if (device.isConnected) _noteConnected(device);
      signalChange(device);

      IAPManager.instance.setAttributes();

      core.actionHandler.supportedApp?.keymap.addNewButtons(device.availableButtons);

      // Let the battery saver re-evaluate now that a device connected.
      _inactivityDisconnector?.onDeviceConnectionChanged();

      if (devices.isNotEmpty && !_androidNotificationsSetup && !kIsWeb && Platform.isAndroid) {
        _androidNotificationsSetup = true;
        // start foreground service only when app is in foreground
        NotificationRequirement.addPersistentNotification().catchError((e) {
          _actionStreams.add(LogNotification(e.toString()));
        });
      }
    } catch (e, backtrace) {
      await _streamSubscriptions.remove(device)?.cancel();
      // Deliberately do NOT cancel _connectionSubscriptions here. Android
      // delivers a failed connect twice, and the ordering varies: on real
      // devices the disconnected event usually arrives BEFORE the exception
      // (the listener has already cleaned up — cancelling again is a no-op),
      // while other stacks and the fake platform deliver it after (then this
      // still-attached listener is the only thing that removes the device and
      // re-enables retry). Cancelling here would break the second ordering.
      _actionStreams.add(LogNotification("$e\n$backtrace"));
      if (kDebugMode) {
        print(e);
        print("backtrace: $backtrace");
      }
      rethrow;
    }
  }

  void signalNotification(BaseNotification notification) {
    _actionStreams.add(notification);
  }

  void signalChange(BaseDevice baseDevice) {
    _connectionStreams.add(baseDevice);
  }

  /// [dropped]: the link already went away on its own (peripheral-side BLE
  /// drop, DirCon socket closed). The drop listeners flip [BaseDevice.isConnected]
  /// before calling in, so without this flag the device's own teardown would be
  /// skipped — and a ProxyDevice would leave its definition attached to the
  /// shared emulator, still advertising and still being written to.
  Future<void> disconnect(
    BaseDevice device, {
    required bool persistForget,
    required bool forget,
    bool keepInList = false,
    bool dropped = false,
  }) async {
    if (keepInList) _inPlaceDisconnects.add(device);
    final tearingDown = _disconnecting.contains(device);
    if (!tearingDown) _disconnecting.add(device);
    try {
      if (!tearingDown && (device.isConnected || dropped)) {
        await device.disconnect();
      }
    } finally {
      if (keepInList) _inPlaceDisconnects.remove(device);
      if (!tearingDown) _disconnecting.remove(device);
    }

    if (device is BluetoothDevice) {
      await _unregisterSensorSource(device, forget: forget);

      if (persistForget) {
        // Add device to ignored list when forgetting
        await core.settings.addIgnoredDevice(device.device.deviceId, device.toString());
        _actionStreams.add(LogNotification('Device ignored: ${device.toString()}'));
      }
      // For an in-place disconnect (the "No connection" picker entry) keep the
      // scan result so the scanner doesn't churn a fresh duplicate while the
      // user stays on the details page — the same device object must remain
      // reconnectable.
      if (!forget && !keepInList) {
        // allow reconnection
        _lastScanResult.removeWhere((d) => d.deviceId == device.device.deviceId);
      }

      // Clean up subscriptions and scan results for reconnection
      _streamSubscriptions[device]?.cancel();
      _streamSubscriptions.remove(device);
      _connectionSubscriptions[device]?.cancel();
      _connectionSubscriptions.remove(device);

      // Forgetting an emulated device tears down its fake peripheral and clears
      // the scan-result dedupe cache so the same profile can be re-added later.
      if (forget && core.emulation.isEmulated(device.device.deviceId)) {
        core.emulation.stop(device.device.deviceId);
        _lastScanResult.removeWhere((d) => d.deviceId == device.device.deviceId);
      }

      // Remove device from the list — unless it is rebooting due to an
      // automatic reset and will be back in a few seconds, or this is an
      // in-place disconnect (keepInList) where the open details page still
      // holds this exact object and must be able to reconnect it. Dropping it
      // here would orphan that reference: rediscovery builds a *new* device,
      // and the page's stale one fails to reconnect ("Device not found").
      if (!keepInList && (forget || !device.isResetting)) {
        devices.remove(device);
        hasDevices.value = devices.isNotEmpty;
      }
    } else if (device is GyroscopeSteering || device is HidDevice) {
      // Clean up subscriptions
      _streamSubscriptions[device]?.cancel();
      _streamSubscriptions.remove(device);
      _connectionSubscriptions[device]?.cancel();
      _connectionSubscriptions.remove(device);

      // Remove device from the list
      devices.remove(device);
      hasDevices.value = devices.isNotEmpty;
    }

    signalChange(device);
    _inactivityDisconnector?.onDeviceConnectionChanged();
  }

  Future<void> disconnectAll() async {
    _actionStreams.add(LogNotification(AppLocalizations.current.disconnectingAllDevices));
    // Collected rather than awaited inline: this loop is otherwise fully
    // synchronous, and awaiting per-device here would open a re-entrancy
    // window between devices during a global teardown for no benefit —
    // `bluetoothDevices` is already a `.toList()` snapshot, so nothing else
    // needs the sensor-source teardown to have landed before the next
    // device's turn, only before disconnectAll() itself returns.
    final sensorSourceTeardowns = <Future<void>>[];
    for (var device in bluetoothDevices) {
      _streamSubscriptions[device]?.cancel();
      _streamSubscriptions.remove(device);
      _connectionSubscriptions[device]?.cancel();
      _connectionSubscriptions.remove(device);
      // Not a "forget": Bluetooth going away in bulk is a transient global
      // drop, not the rider individually forgetting every device, so the
      // selection is left alone the same way a single transient drop is.
      sensorSourceTeardowns.add(_unregisterSensorSource(device, forget: false));
      device.disconnect();
      signalChange(device);
      devices.remove(device);
    }
    await Future.wait(sensorSourceTeardowns);
    _gamePadSearchTimer?.cancel();
    _lastScanResult.clear();
    // Everything is gone, so the battery-saver suppression is moot — a later
    // rediscovery should auto-connect normally again.
    _suppressedAutoReconnect.clear();
    _consecutiveConnectFailures.clear();
    _quickDropCounts.clear();
    _connectedAt.clear();
    _backoffAlerted.clear();
    for (final timer in _backoffCooldownTimers.values) {
      timer.cancel();
    }
    _backoffCooldownTimers.clear();
    hasDevices.value = false;
    _inactivityDisconnector?.onDeviceConnectionChanged();
  }

  Future<void> stop() async {
    final isBtEnabled = (await UniversalBle.getBluetoothAvailabilityState()) == AvailabilityState.poweredOn;
    if (isBtEnabled) {
      UniversalBle.stopScan();
    }
    _wifiTrainerScanner?.stop();
    // Symmetric with [performScanning], which arms it: gamepad polling is part
    // of scanning, and stopping left it running. It also leaked — stop() clears
    // isScanning, so the next performScanning() sails past its guard and
    // assigns a second periodic timer over the top of the first, once per
    // stop/rescan cycle (unlock-mode switches do exactly that).
    _gamePadSearchTimer?.cancel();
    _gamePadSearchTimer = null;
    isScanning.value = false;
    _lastScanResult.clear();
    _androidNotificationsSetup = false;
  }

  // ── Inactivity / battery-saver disconnect (issue #329) ─────────────────────

  /// Test seam: run the inactivity battery-saver disconnect directly instead of
  /// waiting out the real idle timer.
  @visibleForTesting
  void debugTriggerInactivityTimeout([Duration timeout = const Duration(minutes: 60)]) => _onInactivityTimeout(timeout);

  /// Called by [_inactivityDisconnector] when the idle timeout elapses.
  /// Disconnects every connected BLE controller (battery-powered; ProxyDevice
  /// and accessories excluded), then surfaces an in-app alert with a Reconnect
  /// action and an OS push notification. [timeout] is the elapsed window, used
  /// for the human-readable message.
  void _onInactivityTimeout(Duration timeout) {
    final controllers = controllerDevices.whereType<BluetoothDevice>().where((d) => d.isConnected).toList();
    if (controllers.isEmpty) return;

    for (final device in controllers) {
      // Suppress auto-reconnect so the rediscovery that follows the disconnect
      // doesn't immediately bring the controller back (the whole point is to
      // let its battery rest). Lifted by the Reconnect action below or by the
      // cooldown timer once the controller had time to fall asleep.
      _suppressedAutoReconnect.add(device.device.deviceId);
      unawaited(
        disconnect(device, forget: true, persistForget: false).catchError((Object error, StackTrace stackTrace) {
          _actionStreams.add(
            LogNotification('Failed to disconnect ${device.toString()} after inactivity timeout: $error\n$stackTrace'),
          );
        }),
      );
    }

    // Lift the suppression once the controller had time to power down. The
    // stale _lastScanResult entry must go too: the controller's last
    // advertisement right after the disconnect re-entered the dedup list, and
    // it would block every future advertisement from reaching addDevices —
    // leaving a woken controller unconnectable until an app restart.
    final suppressedIds = controllers.map((d) => d.device.deviceId).toList();
    Timer(inactivityReconnectCooldown, () {
      for (final id in suppressedIds) {
        _suppressedAutoReconnect.remove(id);
        _lastScanResult.removeWhere((d) => d.deviceId == id);
      }
    });

    _actionStreams.add(
      AlertNotification(
        LogLevel.LOGLEVEL_WARNING,
        AppLocalizations.current.controllersDisconnectedInactivity(timeout.inMinutes),
        buttonTitle: AppLocalizations.current.reconnect,
        // Route reconnection through the connection queue so BLE connects are
        // serialized (Windows fails on parallel connects) and ignored-device
        // filtering applies. disconnect(persistForget: false) above did not add
        // these to the ignore list, so they are eligible to be re-added.
        onTap: () {
          for (final device in controllers) {
            _suppressedAutoReconnect.remove(device.device.deviceId);
          }
          addDevices(controllers);
        },
      ),
    );

    if (!kIsWeb) {
      core.flutterLocalNotificationsPlugin.show(
        id: 1339,
        title: AppLocalizations.current.batterySaverTitle,
        body: AppLocalizations.current.controllersDisconnectedInactivity(timeout.inMinutes),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails('BatterySaver', 'Battery Saver'),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: false),
        ),
      );
    }
  }
}

/// Relay sink that forwards incline writes upstream through the active
/// [FitnessBikeDefinition] (e.g. to a Wahoo app connected over DirCon).
/// Always reports [followsGrade] == true — the relay has no manual-hold state.
class _ClimbRelaySink implements InclineSink {
  _ClimbRelaySink(this._fbd);
  final FitnessBikeDefinition _fbd;
  @override
  bool get followsGrade => true;
  @override
  Future<bool> writeInclineRaw(int g) => _fbd.writeClimbInclineUpstream(g);
}
