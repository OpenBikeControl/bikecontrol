import 'dart:async';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:bike_control/utils/gear_readout.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart' show SupportedApp, TrainerConnectionType;
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart' show Target;
import 'package:bike_control/utils/units.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prop/dircon/dircon_trainer_transport.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:prop/prop.dart' hide TrainerMode;
import 'package:prop/transports/ble_trainer_transport.dart';
import 'package:prop/transports/trainer_transport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class ProxyDevice extends BluetoothDevice {
  static final List<String> proxyServiceUUIDs = [
    FitnessBikeDefinition.HEART_RATE_MEASUREMENT_UUID, // Heart Rate
    FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID, // Heart Rate
    FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, // Fitness Machine
  ];

  /// Per-instance emulator used exclusively in proxy mode. Each proxy-mode
  /// trainer needs its own mDNS identity / peripheral so they are independent.
  // Serve DirCon on the standard Wahoo port so clients that hard-dial it
  // (ignoring the mDNS SRV port) can connect — TrainerRoad's desktop app is the
  // motivating case. Reasoning in `prop` ([kWahooDirconStandardPort]).
  final DirconEmulator _proxyEmulator = DirconEmulator(preferredPort: kWahooDirconStandardPort);

  /// Active emulator for this device. In proxy mode → own per-instance
  /// emulator; in VS modes → shared global [ftmsEmulator].
  DirconEmulator get emulator => _retrofitModeN.value == RetrofitMode.proxy ? _proxyEmulator : ftmsEmulator;

  final ValueChangeNotifier<String> onChange = ValueChangeNotifier('');

  /// True while the initial BLE connect + service discovery for this proxy is
  /// in flight. The emulator's `isStarted` only flips once startServer runs
  /// (after services are discovered); UI that needs to render a "Connecting…"
  /// state between tap and first successful start should watch this instead.
  final ValueNotifier<bool> isStarting = ValueNotifier(false);

  // ── Stable state wrappers ─────────────────────────────────────────────────
  // These mirror whichever emulator is currently active. Because the active
  // emulator can change on a mode swap, the UI should bind to these
  // ProxyDevice-level listenables instead of directly to emulator.X, so
  // bindings survive mode transitions.

  final ValueNotifier<RetrofitMode> _retrofitModeN = ValueNotifier(RetrofitMode.proxy);

  /// The current retrofit mode. Stays stable across emulator swaps.
  ValueListenable<RetrofitMode> get retrofitMode => _retrofitModeN;

  final ValueNotifier<bool> _isStartedN = ValueNotifier(false);

  /// Whether the active emulator has started. Stable across mode swaps.
  ValueListenable<bool> get isStartedListenable => _isStartedN;

  final ValueNotifier<bool> _isConnectedN = ValueNotifier(false);

  /// Whether a trainer app is connected via the active emulator. Stable across
  /// mode swaps.
  ValueListenable<bool> get isConnectedListenable => _isConnectedN;

  /// Whether BikeControl is bridging this trainer: the emulator is running, or
  /// a trainer app is already holding the virtual trainer.
  ///
  /// This — not [isConnected], which only says the Bluetooth link to the
  /// trainer is up — is what "connected" means for a trainer everywhere in the
  /// app. A trainer BikeControl can talk to but isn't bridging does nothing for
  /// the rider, and calling that "connected" is technically true and useless.
  /// Onboarding has always drawn the line here; this getter is that line, in
  /// one place, so onboarding and the home screen cannot drift apart.
  bool get isBridged => _isStartedN.value || _isConnectedN.value;

  /// A compact, plain-text readout of what the trainer is reporting right now
  /// — "250 W · 90 rpm · gear 12/24" — for places that want one line rather
  /// than the full metric row [showMetaInformation] builds.
  ///
  /// Deliberately gated on [isConnected], not [isBridged]: these numbers come
  /// off the trainer itself, so they are just as real, and just as worth
  /// showing, before BikeControl starts bridging it.
  String? get liveReadout {
    if (!isConnected) return null;
    if (screenshotMode) return '250 W · 90 rpm';

    final proxyDef = emulator.composite.firstOfType<ProxyBikeDefinition>();
    final fitnessDef = emulator.fitnessBike;
    final int? power = proxyDef?.powerW.value ?? fitnessDef?.powerW.value;
    final int? cadence = proxyDef?.cadenceRpm.value ?? fitnessDef?.cadenceRpm.value;

    final parts = <String>[
      if ((power ?? 0) > 0) '$power W',
      if ((cadence ?? 0) > 0) '$cadence rpm',
    ];

    // The gear only exists while BikeControl is computing it, so it appears
    // alongside the trainer's own numbers rather than instead of them.
    if (fitnessDef != null && proxyDef == null) {
      if (fitnessDef.trainerMode.value == TrainerMode.ergMode) {
        final watts = fitnessDef.ergTargetPower.value;
        if (watts != null) parts.add('ERG $watts W');
      } else {
        parts.add(
          'Gear ${formatGearReadout(
            currentGear: fitnessDef.currentGear.value,
            maxGear: fitnessDef.maxGear,
            frontShiftEnabled: fitnessDef.frontShiftEnabled,
            largeRing: fitnessDef.frontRing.value == FrontRing.large,
          )}',
        );
      }
    }

    return parts.isEmpty ? null : parts.join(' · ');
  }

  final ValueNotifier<String?> _localAddressN = ValueNotifier(null);

  /// Local IPv4 address currently advertised, if any. Stable across mode swaps.
  ValueListenable<String?> get localAddress => _localAddressN;

  /// The [FitnessBikeDefinition] for this trainer while in VS mode. Attached
  /// to [ftmsEmulator]'s composite while VS is active; null in proxy mode.
  FitnessBikeDefinition? _fbd;
  FitnessBikeDefinition? get fitnessBike => _fbd;

  /// Test-only: attach [fbd] as the active virtual-shifting definition without
  /// starting any emulator/server. Lets the screenshot harness render the
  /// virtual-shifting gear UI instead of the "trainer doesn't advertise FTMS"
  /// warning (which shows whenever [fitnessBike] is null). Pass null to detach
  /// again, so a scene that needs the gears can leave the next one without.
  @visibleForTesting
  void debugAttachFitnessBike(FitnessBikeDefinition? fbd) {
    _fbd = fbd;
    _currentFbd = fbd;
  }

  // Note: the base class [BluetoothDevice.services] field holds the discovered
  // BLE services and is used directly when rebuilding definitions on mode switch.

  /// ProxyBikeDefinition built during [handleServices] for proxy mode.
  ProxyBikeDefinition? _proxyDef;

  /// Which emulator we currently have listeners registered on. Used by
  /// [_bindToActiveEmulator] to remove stale listeners.
  DirconEmulator? _currentlyListening;

  StreamSubscription<void>? _bridgeBudgetSub;

  /// Latest [FitnessBikeDefinition] created during [_buildDefinitions]. In VS
  /// mode this is the same as [_fbd]. Kept separate so the bridge-usage
  /// tracker can read live trainer activity via [_isTrainerActive].
  FitnessBikeDefinition? _currentFbd;

  ZwiftEmulatorDefinition? _zwiftControllerEmulator;

  /// Upstream transport to the real trainer — BLE by default, DirCon for
  /// WiFi-discovered trainers.
  final TrainerTransport transport;

  bool get isWifiUpstream => transport is DirconTrainerTransport;

  StreamSubscription<({String characteristic, Uint8List value})>? _transportNotificationSub;

  ProxyDevice(super.scanResult)
    : transport = BleTrainerTransport(scanResult.deviceId),
      super(
        availableButtons: const [],
        icon: _iconFor(scanResult),
        isBeta: true,
      ) {
    _initEmulator();
  }

  /// A trainer discovered over mDNS/DirCon. [scanResult] is the synthetic
  /// BleDevice built by WifiTrainerScanner (deviceId `dircon://<name>`,
  /// services from the ad's TXT record).
  ProxyDevice.wifi(super.scanResult, {required String host, required int port})
    : transport = DirconTrainerTransport(id: scanResult.deviceId, host: host, port: port),
      super(
        availableButtons: const [],
        icon: _iconFor(scanResult),
        isBeta: true,
      ) {
    _initEmulator();
  }

  void _initEmulator() {
    _proxyEmulator.shouldAdvertise = () => !_isBridgeTrialOver;
    _proxyEmulator.deviceName = () => scanResult.name;
    _rebindEmulatorState();
  }

  /// Test-only: drive the device-level "trainer app connected" wrapper
  /// directly, without running the active emulator's connect machinery (whose
  /// real BLE/transport futures race the widget-test fake clock).
  @visibleForTesting
  void debugSetTrainerAppConnected(bool connected) => _isConnectedN.value = connected;

  /// (Re)establish the retrofit-mode listener and the active-emulator state
  /// mirrors into our stable wrappers. Run on construction and on every
  /// (re)connect: an in-place disconnect ("No connection") detaches these (see
  /// [disconnect]) and the same ProxyDevice instance is reused on reconnect, so
  /// without re-binding here the UI wrappers (isStartedListenable /
  /// isConnectedListenable) would never track the new session — the emulator
  /// connects but the card stays stuck on "connecting".
  void _rebindEmulatorState() {
    // removeListener first so re-running this never double-subscribes (the
    // first connect already added it in the constructor).
    _retrofitModeN.removeListener(_bindToActiveEmulator);
    _retrofitModeN.addListener(_bindToActiveEmulator);
    _bindToActiveEmulator();
  }

  /// Test seam for [_rebindEmulatorState] — [startProxy] performs a real BLE
  /// connect, so unit tests exercise the reconnect rebinding through this.
  @visibleForTesting
  void debugRebindEmulatorState() => _rebindEmulatorState();

  /// Await [detach], recording (not rethrowing) any failure so a teardown or
  /// mode switch keeps going. [context] names the operation in the report.
  Future<void> _detachLogged(Future<void> detach, String context) {
    return detach.catchError((Object e, StackTrace s) {
      recordError(e, s, context: 'ProxyDevice: $context');
    });
  }

  /// Stop the shared FTMS emulator once this device's definitions are detached
  /// and nothing else is using it.
  ///
  /// Checks [DirconEmulator.hasNothingToServe] rather than
  /// `composite.children.isEmpty` directly: a `SensorDefinition` (rider
  /// metrics BikeControl sourced itself) can still be riding along after the
  /// trainer it shared the bridge with is gone, and nothing this feature owns
  /// may ever be the reason the shared composite looks in use.
  Future<void> _stopFtmsEmulatorIfUnused() async {
    if (ftmsEmulator.hasNothingToServe && ftmsEmulator.isStarted.value) {
      await ftmsEmulator.stop();
    }
  }

  /// Restart the per-instance proxy emulator if it's running. Called when
  /// something the advertisement depends on (the selected trainer app)
  /// changes. No-op when not running or when this device is currently in a
  /// VS mode — ftmsEmulator handles itself in that case.
  Future<void> restartProxyEmulator() async {
    if (_retrofitModeN.value != RetrofitMode.proxy) return;
    await _proxyEmulator.restart();
  }

  /// React to a trainer-app change while this device is connected.
  ///
  /// Proxy mode re-advertises its own emulator (the advertised name depends on
  /// the app). A VS-mode device reconciles its ride-along controller: the
  /// controller belongs on the bridge only for apps that take their controller
  /// over it ([_attachesZwiftController]). Switching to an app that doesn't must
  /// take it back off, or the bridge keeps advertising a controller the app
  /// can't use — and it stays there until the trainer is reconnected. The
  /// composite is only mutated here; the shared emulator's re-advertise is
  /// driven by the caller.
  Future<void> onTrainerAppChanged() async {
    if (_retrofitModeN.value == RetrofitMode.proxy) {
      await restartProxyEmulator();
      return;
    }
    final controller = _zwiftControllerEmulator;
    if (controller == null) return;
    final attached = ftmsEmulator.composite.children.contains(controller);
    if (_attachesZwiftController && !attached) {
      ftmsEmulator.composite.attach(controller);
    } else if (!_attachesZwiftController && attached) {
      ftmsEmulator.composite.detach(controller);
    }
  }

  /// Mirror the active emulator's state notifiers into our stable wrappers.
  /// Removes listeners from the previous emulator (if any) before re-binding.
  void _bindToActiveEmulator() {
    final prev = _currentlyListening;
    if (prev != null) {
      prev.isStarted.removeListener(_mirrorIsStarted);
      prev.isConnected.removeListener(_mirrorIsConnected);
      prev.localAddress.removeListener(_mirrorLocalAddress);
      prev.isConnected.removeListener(_syncBridgeTracking);
    }

    final active = emulator;
    _currentlyListening = active;
    active.isStarted.addListener(_mirrorIsStarted);
    active.isConnected.addListener(_mirrorIsConnected);
    active.localAddress.addListener(_mirrorLocalAddress);
    active.isConnected.addListener(_syncBridgeTracking);

    // Immediately mirror current values.
    _mirrorIsStarted();
    _mirrorIsConnected();
    _mirrorLocalAddress();
  }

  void _mirrorIsStarted() => _isStartedN.value = emulator.isStarted.value;
  void _mirrorIsConnected() => _isConnectedN.value = emulator.isConnected.value;
  void _mirrorLocalAddress() => _localAddressN.value = emulator.localAddress.value;

  void _syncBridgeTracking() {
    final isBridgeSession = _isConnectedN.value && _retrofitModeN.value != RetrofitMode.proxy;
    final isPro = IAPManager.instance.isProEnabledForCurrentDevice;
    if (isBridgeSession && !isPro) {
      if (core.bridgeUsageTracker.isExhausted) {
        // Already at the daily limit — pause advertising so no new clients can
        // discover us, but keep the transport pipeline + upstream BLE alive.
        scheduleMicrotask(() => unawaited(emulator.pauseAdvertising()));
        return;
      }
      core.bridgeUsageTracker.startSession(isActive: _isTrainerActive);
      _bridgeBudgetSub ??= core.bridgeUsageTracker.onBudgetExhausted.listen((_) {
        scheduleMicrotask(() => unawaited(emulator.pauseAdvertising()));
        _announceBridgeTrialOver();
      });
    } else {
      core.bridgeUsageTracker.stopSession();
    }
  }

  /// True when the current retrofit mode needs a Bridge transport (wifi /
  /// bluetooth) but the non-Pro user has already burned today's 20-minute
  /// budget. Proxy mode is unaffected.
  bool get _isBridgeTrialOver {
    if (_retrofitModeN.value == RetrofitMode.proxy) return false;
    if (IAPManager.instance.isProEnabledForCurrentDevice) return false;
    return core.bridgeUsageTracker.isExhausted;
  }

  void _announceBridgeTrialOver() {
    final title = AppLocalizations.current.bridgeTrialTimeOverTitle;
    final body = AppLocalizations.current.bridgeTrialTimeOverBody;
    core.connection.signalNotification(
      AlertNotification(LogLevel.LOGLEVEL_WARNING, '$title — $body'),
    );
    core.flutterLocalNotificationsPlugin.show(
      id: 1340,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('BridgeTrial', 'Bridge Trial Status'),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  /// Build [_proxyDef] and an internal FBD from the freshly-discovered BLE
  /// services. [_fbd] is only assigned (and [_currentFbd] updated) once the
  /// FBD is actually attached to ftmsEmulator — don't set [_fbd] here so
  /// [disconnect] doesn't try to detach a definition that was never attached.
  FitnessBikeDefinition _buildDefinitions(List<BleService> services) {
    final shouldAdvertiseZwift = _shouldAdvertiseZwift;
    _proxyDef = ProxyBikeDefinition(
      services: services,
      device: scanResult,
      data: _proxyEmulator.data,
      transport: transport,
    );

    _zwiftControllerEmulator = ZwiftEmulatorDefinition(device: device);

    final fbd = FitnessBikeDefinition(
      connectedDevice: scanResult,
      connectedDeviceServices: services,
      data: ftmsEmulator.data,
      shouldAdvertiseZwift: shouldAdvertiseZwift,
      transport: transport,
    );
    _seedFitnessBikeDefinition(fbd);
    return fbd;
  }

  bool get _shouldAdvertiseZwift {
    final trainerApp = core.settings.getTrainerApp();
    return trainerApp is Rouvy || trainerApp is Zwift;
  }

  /// True when [_zwiftControllerEmulator] rides along in the composite next to
  /// the FBD, adding the Zwift *Ride* service (`0000fc82-…`).
  ///
  /// Zwift only; Rouvy would lose Virtual Shifting over it and gets its
  /// controller from the standalone endpoint instead. Reasoning in `prop`.
  bool get _attachesZwiftController {
    if (_zwiftControllerEmulator == null) return false;
    return core.settings.getTrainerApp() is Zwift;
  }

  /// The name Rouvy needs the bridge to advertise under; null for every other
  /// app, leaving the usual name in place. Reasoning in `prop`
  /// ([DirconEmulator.advertisementNameOverride]).
  @visibleForTesting
  String? rouvyAdvertisementName() {
    if (core.settings.getTrainerApp() is! Rouvy) return null;
    final name = scanResult.name;
    final composed = name == null || name.isEmpty ? _bridgeSuffix : '$name - $_bridgeSuffix';
    return composed.toLowerCase().contains('bikecontrol') ? _bridgeSuffix : composed;
  }

  static const _bridgeSuffix = 'Bridge';

  /// Rouvy needs an IPv4-only listener; the controller endpoint has bound one
  /// for it for a while. Reasoning in `prop` ([DirconEmulator.forceIPv4]).
  @visibleForTesting
  bool rouvyNeedsIPv4() => needsIPv4For(core.settings.getTrainerApp());

  /// The app-keyed half of [rouvyNeedsIPv4], shared with the standalone
  /// sensor advertisement (`Connection.initialize`) so both DIRCON listeners
  /// bind the same way for the same app.
  static bool needsIPv4For(SupportedApp? app) => app is Rouvy;

  /// Mirrors `emulator.advertisementName`. Exposed on ProxyDevice for the UI
  /// so it doesn't have to dereference through the contextual `emulator`
  /// getter.
  String get advertisementName => emulator.advertisementName;

  Map<String, Uint8List> _trainerMdnsTxt() => trainerMdnsTxtFor(
    core.settings.getTrainerApp(),
    serialNumber: mdnsSerialNumber(scanResult.deviceId),
  );

  /// Whether the bridge advertises 16-bit services bare (`1826`) or in the
  /// `0x1826` form. Rouvy (and Zwift, MyWhoosh, TPV) parse the `0x` form and
  /// silently drop a bare one; Tacx Training does the opposite. So it follows
  /// the selected trainer app, re-evaluated on every advertisement. Shared
  /// with the standalone sensor advertisement (`Connection.initialize`).
  static bool bareShortServiceUuidsFor(SupportedApp? app) => app is Tacx;

  bool _bareShortServiceUuids() => bareShortServiceUuidsFor(core.settings.getTrainerApp());

  /// TXT record for the Bridge's `_wahoo-fitness-tnp._tcp` advertisement.
  ///
  /// [SupportedApp.trainerMdnsTxt] contributes whatever fields the selected app
  /// needs on top of these. It is applied last so an app can also correct one
  /// of the defaults if it ever has to.
  static Map<String, Uint8List> trainerMdnsTxtFor(SupportedApp? app, {required String serialNumber}) => {
    'mac-address': Uint8List.fromList(BikeControlMdnsMarkers.macAddress.codeUnits),
    'serial-number': Uint8List.fromList(serialNumber.codeUnits),
    for (final e in (app?.trainerMdnsTxt ?? const <String, String>{}).entries)
      e.key: Uint8List.fromList(e.value.codeUnits),
  };

  void _seedFitnessBikeDefinition(FitnessBikeDefinition def) {
    final stored = core.shiftingConfigs.storedActiveFor(trainerKey);
    final cfg = stored ?? core.shiftingConfigs.activeFor(trainerKey);
    def.setMaxGear(cfg.maxGear);
    def.setBicycleWeightKg(cfg.bikeWeightKg);
    def.setRiderWeightKg(cfg.riderWeightKg);
    def.setGradeSmoothingEnabled(cfg.gradeSmoothing);
    def.setCadenceFilterEnabled(cfg.cadenceFilterEnabled);
    // A rider who saved a config chose their mode; honour it. With no saved
    // config, let the definition manage the capability-based default (Track
    // Resistance on a grade-capable trainer) rather than the generic Target
    // Power, which runs virtual shifting like ERG and reads as "shifting does
    // nothing"; it re-derives once the FTMS feature probe lands.
    if (stored != null) {
      def.setVirtualShiftingMode(stored.mode);
    } else {
      def.useDefaultVirtualShiftingMode();
    }
    def.setChainringTeeth(cfg.smallChainringTeeth, cfg.largeChainringTeeth);
    def.setFrontShiftEnabled(cfg.frontShiftEnabled);
    if (cfg.gearRatios != null) {
      def.setGearRatios(cfg.gearRatios!);
    }

    // Seed whatever external heart rate is already resolved right now — this
    // is the single funnel every fresh FBD goes through (initial connect,
    // proxy→VS switch, and applyTrainerSettings re-seeding the current one),
    // so a trainer that connects mid-ride, after the rider already picked a
    // steady external source, doesn't sit with no heart rate on the wire
    // until SensorBridgeBinding's next change-driven push happens to fire.
    // Harmless no-op (re-sets the same value) on the applyTrainerSettings
    // path, which re-seeds an already-live FBD rather than a fresh one.
    def.setExternalHeartRate(core.sensors.resolved(SensorQuantity.heartRate).value);
    // Cadence and power get the same treatment — same funnel, same gap
    // (Phase 1 fixed it for heart rate above; this closes it for the other
    // two) — but GUARDED on a non-null value rather than passed through
    // unconditionally like heart rate is. Unlike _relayedHeartRateBpm
    // (nullable), FitnessBikeDefinition's trainer-side cadence/power fields
    // are non-nullable ints defaulting to 0, so an unconditional
    // setExternalCadence(null)/setExternalPower(null) here would latch the
    // resolved cadenceRpm/powerW notifiers at 0 for EVERY rider on every
    // connect — including one with no external source selected at all —
    // which would both regress the "nothing selected → byte-identical
    // behaviour" guarantee and silently disable
    // FitnessBikeDefinition.trainerReportsNoCadence's cadence-less-trainer
    // fallback (see that getter's doc comment for the full mechanism).
    // Calling this only when there is an actual reading to seed leaves a
    // no-external-source rider's fresh FBD completely untouched, while still
    // fixing the same drop as heart rate: an already-flowing external
    // cadence/power source no longer sits unseeded on a fresh FBD until the
    // hub's resolved value next happens to change.
    final resolvedCadence = core.sensors.resolved(SensorQuantity.cadence).value;
    if (resolvedCadence != null) def.setExternalCadence(resolvedCadence);
    final resolvedPower = core.sensors.resolved(SensorQuantity.power).value;
    if (resolvedPower != null) def.setExternalPower(resolvedPower);
    // The control-protocol override lives on the definition, and every
    // connect (and every proxy→VS switch) builds a fresh one — so re-applying
    // it belongs here, in the single funnel all three rebuild paths share,
    // rather than in [applyTrainerSettings] alone: switchRetrofitMode rebuilds
    // the FBD without ever calling that. Without this the rider's choice
    // silently reverts to auto on the next reconnect, on the very trainer they
    // had to override because auto talks to it over the wrong wire.
    //
    // An unrecognised stored name parses to null (auto), and
    // setControlProtocolOverride ignores anything this trainer can't carry, so
    // a stale pref can never strand the trainer on a dead write path.
    final storedProtocol = core.settings.getControlProtocolOverride(trainerKey);
    def.setControlProtocolOverride(TrainerControlProtocol.values.asNameMap()[storedProtocol]);

    _wireGearEchoLog(def);
    _wireSimRefusalLog(def);
  }

  /// The definition [_gearEchoLogListener] is attached to, and the listener
  /// itself — so re-seeding can't stack a second one on the same notifier.
  FitnessBikeDefinition? _gearEchoLoggedDef;
  VoidCallback? _gearEchoLogListener;

  /// Puts the gear-echo verdict in the support log for every rider: the
  /// definition's own logging only reaches debug consoles and beta traces, and
  /// "why is proto=ftms on a native trainer" is the first question on any
  /// shifting report.
  ///
  /// Idempotent per definition. [_seedFitnessBikeDefinition] is not only a
  /// connect-time path — [applyTrainerSettings] re-seeds the *existing*
  /// definition on every settings change — so a plain `addListener` there
  /// accumulated one listener per seed, and a single verdict then fanned out
  /// into that many identical notifications. A real bundle showed five.
  void _wireGearEchoLog(FitnessBikeDefinition def) {
    if (identical(_gearEchoLoggedDef, def)) return;
    final previous = _gearEchoLogListener;
    if (previous != null) {
      // Safe on a disposed notifier by contract, and the definition we are
      // moving off may well have been disposed with the last connection.
      _gearEchoLoggedDef?.gearEchoVerdict.removeListener(previous);
    }
    void onVerdict() {
      final verdict = def.gearEchoVerdict.value;
      if (verdict == null) return;
      core.connection.signalNotification(
        LogNotification(switch (verdict) {
          ZwiftGearEchoVerdict.fellBackToFtms =>
            '${scanResult.name}: trainer did not acknowledge gear changes — virtual shifting now delivered over FTMS',
          ZwiftGearEchoVerdict.noFtmsToFallBackTo =>
            '${scanResult.name}: trainer did not acknowledge gear changes and has no FTMS control point to fall back to',
          ZwiftGearEchoVerdict.riderOverrideKept =>
            '${scanResult.name}: trainer did not acknowledge gear changes — keeping the manually chosen control protocol',
        }),
      );
    }

    def.gearEchoVerdict.addListener(onVerdict);
    _gearEchoLoggedDef = def;
    _gearEchoLogListener = onVerdict;
  }

  /// Same idempotency contract as [_wireGearEchoLog], for the SIM-grade
  /// refusal verdict: a trainer that spends the whole handshake retry budget
  /// refusing Start/Resume ACKs every grade write and applies none, so the
  /// definition switches itself to Target Power — and the support log has to
  /// say so, or "vsMode says power but I picked Track Resistance" becomes the
  /// next unanswerable report.
  FitnessBikeDefinition? _simRefusalLoggedDef;
  VoidCallback? _simRefusalLogListener;

  void _wireSimRefusalLog(FitnessBikeDefinition def) {
    if (identical(_simRefusalLoggedDef, def)) return;
    final previous = _simRefusalLogListener;
    if (previous != null) {
      _simRefusalLoggedDef?.trackResistanceRefused.removeListener(previous);
    }
    void onRefused() {
      if (!def.trackResistanceRefused.value) return;
      core.connection.signalNotification(
        LogNotification(
          '${scanResult.name}: trainer refuses to start grade simulation — '
          'virtual shifting switched to Target Power',
        ),
      );
    }

    def.trackResistanceRefused.addListener(onRefused);
    _simRefusalLoggedDef = def;
    _simRefusalLogListener = onRefused;
  }

  /// Is the connected trainer reporting any sign of riding right now? Used to
  /// gate the bridge-usage tracker so coast / paused minutes don't burn the
  /// non-Pro daily budget. Any of cadence, speed or power being non-zero is
  /// enough; null values (no trainer notification yet) count as idle.
  bool _isTrainerActive() {
    final fbd = _currentFbd;
    if (fbd == null) return false;
    if ((fbd.cadenceRpm.value ?? 0) > 0) return true;
    if ((fbd.speedKph.value ?? 0) > 0) return true;
    if ((fbd.powerW.value ?? 0) > 0) return true;
    return false;
  }

  static IconData _iconFor(BleDevice scanResult) {
    final services = scanResult.services.map((s) => s.toLowerCase()).toSet();

    if (services.contains(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase())) {
      return LucideIcons.bike;
    }
    if (services.contains(FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID.toLowerCase())) {
      return LucideIcons.zap;
    }
    if (services.contains(FitnessBikeDefinition.HEART_RATE_MEASUREMENT_UUID.toLowerCase())) {
      return LucideIcons.heart;
    }
    return LucideIcons.bike;
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    final fbd = _buildDefinitions(services);

    final mode = _retrofitModeN.value;

    try {
      if (mode == RetrofitMode.proxy) {
        await _proxyEmulator.attachDefinition(_proxyDef!);
        _proxyEmulator.bareShortServiceUuids = _bareShortServiceUuids;
        await _proxyEmulator.startServer(
          mode: RetrofitMode.proxy,
          mdnsTxt: _trainerMdnsTxt(),
        );
      } else {
        // VS modes (wifi / bluetooth): the FBD lives in the shared ftmsEmulator.
        ftmsEmulator.shouldAdvertise = () => !_isBridgeTrialOver;
        ftmsEmulator.deviceName = () => scanResult.name;
        ftmsEmulator.advertisementNameOverride = rouvyAdvertisementName;
        ftmsEmulator.forceIPv4 = rouvyNeedsIPv4;
      ftmsEmulator.bareShortServiceUuids = _bareShortServiceUuids;
        _fbd = fbd;
        _currentFbd = fbd;
        await ftmsEmulator.attachDefinition(_fbd!);
        if (_attachesZwiftController) {
          await ftmsEmulator.attachDefinition(_zwiftControllerEmulator!);
        }
        await ftmsEmulator.startServer(
          mode: mode,
          mdnsTxt: _trainerMdnsTxt(),
        );
      }

      applyTrainerSettings();
      // Read the trainer's FTMS Feature map proactively so the UI can gate
      // virtual-shifting options and the feedback payload can report it. Runs
      // off the critical path — failures just leave trainerFeature null.
      final def = emulator.fitnessBike;
      if (def != null) unawaited(def.probeTrainerFeatures());
      onChange.value = 'Connected to ${scanResult.name}';

      if (_isBridgeTrialOver) {
        _announceBridgeTrialOver();
      }
    } catch (e, s) {
      recordError(e, s, context: 'Emulator start');
      core.connection.signalNotification(
        AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Failed to start emulator: $e'),
      );
      onChange.value = 'Failed to start emulator: $e';
      if (mode == RetrofitMode.proxy) {
        if (_proxyDef != null) {
          await _detachLogged(_proxyEmulator.detachDefinition(_proxyDef!), 'detach proxy def after start failure');
        }
        await _proxyEmulator.stop();
      } else if (_fbd != null) {
        await _detachLogged(ftmsEmulator.detachDefinition(_fbd!), 'detach FBD after start failure');
        _fbd = null;
        await _stopFtmsEmulatorIfUnused();
      }
      disconnect();
    }
  }

  /// Push persisted user settings (bike/rider weight, grade smoothing, VS mode)
  /// onto the active FitnessBikeDefinition so the physics calc uses them even
  /// when the user never opens the details page. No-op for ProxyBikeDefinition
  /// (those settings don't apply) and for WiFi modes whose definition is
  /// created lazily per TCP client — the details page rehydrates on mount.
  String get trainerKey => scanResult.name ?? scanResult.deviceId;

  /// Whether the underlying device looks like a smart trainer (FTMS-capable
  /// or FE-C-over-BLE). Power-meter-only or HR-only devices have no trainer
  /// commands to drive, so Virtual Shifting is meaningless for them — they
  /// stay on Proxy.
  bool get isSmartTrainer => scanResult.services.any((s) {
    final lower = s.toLowerCase();
    return lower == FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase() ||
        lower == FitnessBikeDefinition.FEC_BLE_SERVICE_UUID.toLowerCase();
  });

  /// Default connect mode when the user hasn't explicitly picked one. Smart
  /// trainers default to Virtual Shifting (transport resolved from the
  /// active Trainer Connection Settings); other devices fall back to Proxy.
  /// When VS is the conceptual default but no transport is enabled in
  /// Connection Settings, falls through to Proxy so the device still works.
  RetrofitMode get defaultRetrofitMode {
    if (!isSmartTrainer) return RetrofitMode.proxy;
    final transport = core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections);
    return switch (transport) {
      TrainerConnectionType.bluetooth => RetrofitMode.bluetooth,
      TrainerConnectionType.wifi => RetrofitMode.wifi,
      null => RetrofitMode.wifi,
    };
  }

  /// The mode a fresh connect starts in: the rider's saved choice for this
  /// trainer, else [defaultRetrofitMode] — with Bluetooth folded into WiFi
  /// while the trainer app runs on this same device ([Target.thisDevice]).
  ///
  /// A Bluetooth bridge can never be found from the device advertising it: a
  /// BLE peripheral is invisible to a central on the same adapter. The choice
  /// itself is left in the settings so it comes back when the rider moves the
  /// app to another device again. Shared by the auto-connect path and the
  /// connection card so neither can start a transport the other would not
  /// offer.
  RetrofitMode get savedRetrofitMode {
    final saved = core.settings.getRetrofitMode(trainerKey, fallback: defaultRetrofitMode);
    if (saved == RetrofitMode.bluetooth && core.settings.getLastTarget() == Target.thisDevice) {
      return RetrofitMode.wifi;
    }
    return saved;
  }

  void applyTrainerSettings() {
    // This device's own FBD first, for the same reason describeProxyDevice
    // prefers it: [emulator] is contextual (proxy vs. the *shared* global
    // ftmsEmulator) so `emulator.fitnessBike` is `firstOfType` across every
    // VS trainer in the composite — with two trainers bridged it can hand back
    // the other one's definition and seed it with this trainer's settings.
    // [fitnessBike] is null in proxy mode, which keeps the documented no-op.
    final def = fitnessBike ?? emulator.fitnessBike;
    if (def == null) return;
    _seedFitnessBikeDefinition(def);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    emulator.processCharacteristic(characteristic, bytes);
  }

  @override
  Widget? nameBadge(BuildContext context) {
    // The same physical trainer can be discovered over both WiFi (DirCon) and
    // Bluetooth, producing two entries for one trainer. Their names are only
    // *nearly* identical (BLE advertisement name vs DirCon service name), so
    // gating this on an exact-name duplicate missed the confusing case it was
    // meant to solve — every smart trainer carries its transport instead.
    if (!isSmartTrainer) return null;
    return Icon(
      isWifiUpstream ? LucideIcons.wifi : LucideIcons.bluetooth,
      size: 14,
      color: Theme.of(context).colorScheme.mutedForeground,
    );
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    if (isConnected) {
      final units = unitSystemOf(context);
      if (screenshotMode) {
        final parts = <Widget>[];
        _addMetric(parts, context, 250, 'W', LucideIcons.zap);
        _addMetric(parts, context, 133, 'bpm', LucideIcons.heart);
        _addMetric(parts, context, 90, 'rpm', LucideIcons.rotateCw);
        _addMetric(parts, context, units.fromKph(40).round(), units.speedSymbol, LucideIcons.gauge);
        return parts;
      }
      return [
        ValueListenableBuilder<String>(
          valueListenable: emulator.data,
          builder: (context, value, _) {
            if (value.isEmpty) return Text('Waiting for connection...').xSmall.muted;
            final proxyDef = emulator.composite.firstOfType<ProxyBikeDefinition>();
            final fitnessDef = emulator.fitnessBike;
            final parts = <Widget>[];
            if (proxyDef != null) {
              if (isWifiUpstream) {
                _addTextMetric(parts, context, AppLocalizations.of(context).connectionWifi, LucideIcons.wifi);
              }
              _addMetric(parts, context, proxyDef.powerW.value, 'W', LucideIcons.zap);
              _addMetric(parts, context, proxyDef.heartRateBpm.value, 'bpm', LucideIcons.heart);
              _addMetric(parts, context, proxyDef.cadenceRpm.value, 'rpm', LucideIcons.rotateCw);
              final speed = proxyDef.speedKph.value;
              if (speed != null) {
                _addMetric(parts, context, units.fromKph(speed).round(), units.speedSymbol, LucideIcons.gauge);
              }
            } else if (fitnessDef != null) {
              if (isWifiUpstream) {
                _addTextMetric(parts, context, AppLocalizations.of(context).connectionWifi, LucideIcons.wifi);
              }
              _addMetric(parts, context, fitnessDef.powerW.value, 'W', LucideIcons.zap);
              _addMetric(parts, context, fitnessDef.heartRateBpm.value, 'bpm', LucideIcons.heart);
              _addMetric(parts, context, fitnessDef.cadenceRpm.value, 'rpm', LucideIcons.rotateCw);
              final speed = fitnessDef.speedKph.value;
              if (speed != null) {
                _addMetric(parts, context, units.fromKph(speed).round(), units.speedSymbol, LucideIcons.gauge);
              }
              // Gear (sim / VS mode) or ERG target wattage (erg mode).
              if (fitnessDef.trainerMode.value == TrainerMode.ergMode) {
                final watts = fitnessDef.ergTargetPower.value;
                if (watts != null) {
                  _addTextMetric(parts, context, 'ERG $watts W', LucideIcons.target);
                }
              } else {
                _addTextMetric(
                  parts,
                  context,
                  'Gear ${formatGearReadout(currentGear: fitnessDef.currentGear.value, maxGear: fitnessDef.maxGear, frontShiftEnabled: fitnessDef.frontShiftEnabled, largeRing: fitnessDef.frontRing.value == FrontRing.large)}',
                  LucideIcons.settings2,
                );
              }
            }
            if (parts.isEmpty) return const SizedBox.shrink();
            return Wrap(
              spacing: 12,
              runSpacing: 4,
              children: parts,
            );
          },
        ),
      ];
    }
    // The other-transport entry of a trainer that is already held: the pitch
    // below would sell features the live sibling is delivering right now.
    // Say what this entry is instead, and what a tap does.
    final twin = twinSubtitle(AppLocalizations.of(context));
    if (twin != null) {
      return [Text(twin, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.mutedForeground))];
    }
    return [buildFeatureList(context)];
  }

  /// What bridging this trainer would buy the rider — virtual shifting, gear
  /// tuning, control from their own controller. Public because the home
  /// chain shows it too: a trainer that has never been connected is exactly
  /// the rider who has not seen any of this yet.
  Widget buildFeatureList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 11, color: cs.mutedForeground);

    final services = scanResult.services.map((s) => s.toLowerCase()).toSet();
    final hasZwiftAdv = services.contains(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase());
    final controller = core.connection.controllerDevices.firstOrNull;
    final supportsWifiProxy = services.contains(FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID.toLowerCase());

    final l10n = AppLocalizations.of(context);
    final features = <(IconData, String)>[
      if (!hasZwiftAdv) (LucideIcons.sparkles, l10n.proxyFeatureAddVirtualShifting),
      (LucideIcons.slidersHorizontal, l10n.proxyFeatureAdjustGears),
      if (controller != null) (LucideIcons.gamepad2, l10n.proxyFeatureDirectControl(controller.name)),
      (LucideIcons.dumbbell, l10n.proxyFeatureMiniWorkout),
      if (supportsWifiProxy) (LucideIcons.wifi, l10n.proxyFeatureWifiProxy),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.proxyConnectFor(name), style: muted),
        const Gap(2),
        for (final (icon, label) in features)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(4),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 11, color: cs.mutedForeground),
                ),
                const Gap(6),
                Flexible(child: Text(label, style: muted)),
              ],
            ),
          ),
      ],
    );
  }

  void _addMetric(List<Widget> parts, BuildContext context, int? value, String unit, IconData icon) {
    if (value == null) return;
    _addTextMetric(parts, context, '$value $unit', icon);
  }

  void _addTextMetric(List<Widget> parts, BuildContext context, String text, IconData icon) {
    parts.add(
      Container(
        constraints: const BoxConstraints(minWidth: 42),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(icon, size: 12, color: Theme.of(context).colorScheme.mutedForeground),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Steps the ERG target via [ErgPowerStepping]: an unchanged target (unknown
  /// baseline or manual-range boundary) is Ignored — handled internally, shows
  /// what happened, never forwarded to the app — and never yanks a >500 W
  /// game-set target down.
  ActionResult _stepErg(FitnessBikeDefinition def, AppLocalizations l10n, ControllerButton button, {required bool up}) {
    final next = def.stepManualErgPower(up: up);
    _reportShift(up: up, didChange: next != null);
    if (next != null) {
      return Success(l10n.trainerErgTarget(next), button: button);
    }
    final current = def.ergTargetPower.value;
    return current == null
        ? Ignored(l10n.trainerErgTargetGameControlled, button: button)
        : Ignored(l10n.trainerErgTarget(current), button: button);
  }

  /// Phone feedback for a shifter press handled here. This is the only place
  /// that knows whether the drivetrain actually moved — the result type
  /// doesn't (a successful VS shift is `Ignored`), so the outcome is reported
  /// explicitly rather than derived by the caller.
  void _reportShift({required bool up, required bool didChange}) {
    unawaited(didChange ? core.shiftFeedback.shifted(up: up) : core.shiftFeedback.atLimit());
  }

  ActionResult handleTrainerAction(ControllerButton button, InGameAction action) {
    final l10n = AppLocalizations.current;
    final def = emulator.fitnessBike;
    if (def == null) {
      // Internal-only diagnostic; not user-visible toast copy.
      return NotHandled('No active FitnessBikeDefinition', button: button);
    }
    switch (action) {
      case InGameAction.shiftUp:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          return _stepErg(def, l10n, button, up: true);
        } else {
          final didChange = def.shiftUp();
          _reportShift(up: true, didChange: didChange);
          return didChange
              ? Ignored(l10n.trainerShiftedUp(def.currentGear.value), button: button)
              : Ignored(l10n.trainerAlreadyHighestGear, button: button);
        }
      case InGameAction.shiftDown:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          return _stepErg(def, l10n, button, up: false);
        } else {
          final didChange = def.shiftDown();
          _reportShift(up: false, didChange: didChange);
          return didChange
              ? Ignored(l10n.trainerShiftedDown(def.currentGear.value), button: button)
              : Ignored(l10n.trainerAlreadyLowestGear, button: button);
        }
      case InGameAction.trainerSwitchMode:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          def.exitErgMode();
          return Success(l10n.trainerSwitchedToSim, button: button);
        } else {
          final current = def.ergTargetPower.value ?? 150;
          def.setManualErgPower(current);
          return Success(l10n.trainerSwitchedToErg(current), button: button);
        }
      case InGameAction.trainerIntensityUp:
        def.adjustIntensity(0.05);
        return Success(l10n.trainerIntensityIncreased, button: button);
      case InGameAction.trainerIntensityDown:
        def.adjustIntensity(-0.05);
        return Success(l10n.trainerIntensityDecreased, button: button);
      case InGameAction.frontShift:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          return Ignored(l10n.trainerFrontShiftUnavailable, button: button);
        }
        if (!def.frontShiftEnabled) {
          return Ignored(l10n.trainerFrontShiftNotEnabled, button: button);
        }
        final didToggle = def.toggleFrontChainring();
        if (!didToggle) {
          return Ignored(l10n.trainerFrontShiftUnavailable, button: button);
        }
        return Success(
          def.frontRing.value == FrontRing.large ? l10n.trainerFrontShiftedLarge : l10n.trainerFrontShiftedSmall,
          button: button,
        );
      default:
        return NotHandled('', button: button);
    }
  }

  /// Whether the auto-connect path is allowed to start this device on its own
  /// (scan-time / app-launch). Requires an explicit prior connect intent
  /// (`getAutoConnect`) — tapping Connect once is the whole consent story now
  /// that the virtual-shifting takeover dialog is gone.
  ///
  /// Never while the trainer's other-transport entry ([Connection.twinOf])
  /// holds it: the consent is stored under the shared [trainerKey], so it
  /// covers both entries, and honouring it twice opened two upstream paths to
  /// one trainer that fought over resistance. Read live rather than parked in
  /// a cooldown — the twin may hold the trainer for the whole ride.
  @override
  bool get shouldAutoConnect => core.settings.getAutoConnect(trainerKey) && !twinHoldsTrainer;

  /// True while this entry holds the trainer: the upstream link is up, the
  /// bridge is running for it, or a connect is in flight.
  bool get isConnectedOrConnecting => isConnected || isStarting.value || isBridged;

  /// Whether the same trainer is currently held through its other-transport
  /// entry (see [Connection.twinOf]).
  bool get twinHoldsTrainer => core.connection.twinOf(this)?.isConnectedOrConnecting ?? false;

  /// The list subtitle for this entry while its twin holds the trainer: this
  /// is not a second trainer, and connecting here switches paths (see
  /// [Connection.connectDevice]). Names the transport currently in use — the
  /// one the rider would be switching away from. Null when the trainer is not
  /// held through its twin, or this entry holds it itself.
  String? twinSubtitle(AppLocalizations l10n) {
    if (isConnectedOrConnecting) return null;
    final twin = core.connection.twinOf(this);
    if (twin == null || !twin.isConnectedOrConnecting) return null;
    return l10n.trainerTwinSubtitle(twin.isWifiUpstream ? l10n.connectionWifi : l10n.connectionBluetooth);
  }

  @override
  Future<void> connect() async {
    // ProxyDevice intentionally skips the upstream auto-connect — BLE is only
    // opened once the user explicitly starts the emulator via startProxy().
    // If they connected previously and haven't since tapped Disconnect,
    // honour that intent by kicking off startProxy() here (fire-and-forget).
    if (isStarting.value || _proxyEmulator.isStarted.value) return;
    if (!shouldAutoConnect) return;
    setRetrofitMode(savedRetrofitMode);
    await startProxy();
  }

  // ── Upstream seams: route through the TrainerTransport ──────────────────
  // For BLE, BleTrainerTransport performs verbatim the calls BluetoothDevice
  // used to make inline, so behavior is unchanged. For WiFi, the same connect
  // flow (services discovery, device-info reads, handleServices) runs over
  // DirCon.

  @override
  Future<void> connectUpstream() async {
    if (isWifiUpstream) {
      transport.onDisconnected = _onWifiDisconnected;
    }
    await transport.connect();
    _transportNotificationSub?.cancel();
    _transportNotificationSub = transport.notifications.listen((n) {
      processCharacteristic(n.characteristic, n.value).catchError((Object e) {
        core.connection.signalNotification(LogNotification('Error processing DirCon data: $e'));
      });
    });
    if (isWifiUpstream) {
      // No UniversalBle.onConnectionChange for WiFi — flip state ourselves.
      isConnected = true;
      core.connection.signalChange(this);
    }
  }

  @override
  Future<List<BleService>> discoverUpstreamServices() => transport.discoverServices();

  @override
  Future<Uint8List> readUpstream(String serviceUuid, String characteristicUuid) =>
      transport.read(serviceUuid, characteristicUuid);

  @override
  Future<void> disconnectUpstream() => transport.disconnect();

  /// Tears the upstream trainer connection down and brings it back up — the
  /// programmatic twin of picking "No connection" and then the bridge mode
  /// again in the ConnectionCard. A control-protocol change only takes real
  /// effect on a fresh connection: trainers latch their control session to
  /// the protocol that was live at connect time, so the cycle re-runs
  /// discovery, reseeds the definition (re-applying the persisted override)
  /// and performs the new protocol's handshakes from scratch.
  Future<void> reconnectUpstream() async {
    if (!isConnected && !isStartedListenable.value) return;
    await core.connection.disconnect(this, forget: false, persistForget: false, keepInList: true);
    await core.connection.connectDevice(this);
    // connectDevice resolves before discovery finishes on some transports —
    // wait for the rebuilt definition so callers can start using it.
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while ((!isConnected || fitnessBike == null) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  void _onWifiDisconnected() {
    if (!isConnected) return;
    isConnected = false;
    core.connection.signalNotification(
      AlertNotification(
        LogLevel.LOGLEVEL_WARNING,
        '$this ${AppLocalizations.current.disconnected.decapitalize()}',
      ),
    );
    unawaited(core.connection.disconnect(this, forget: false, persistForget: false, dropped: true));
    // Mirrors the BLE connectionStream listener: rediscovery re-adds us.
    core.connection.performScanning();
  }

  Future<void> startProxy() async {
    if (IAPManager.instance.isTrialExpired) {
      // 5-day trial over, user hasn't purchased — silently refuse the connect.
      // The UI Connect buttons surface a Go Pro dialog before ever reaching
      // here; this branch exists as a defensive funnel for the auto-connect
      // path. Clear auto-connect so the scanner doesn't keep re-firing.
      await core.settings.setAutoConnect(trainerKey, false);
      return;
    }
    // A prior in-place disconnect ("No connection") detached the emulator-state
    // bindings; re-establish them before connecting so isStartedListenable /
    // isConnectedListenable mirror this new session. No-op binding refresh on a
    // first connect.
    _rebindEmulatorState();
    isStarting.value = true;
    try {
      await super.connect();
    } finally {
      isStarting.value = false;
    }
  }

  /// Set the retrofit mode for this device. Updates the internal mode notifier,
  /// but does NOT start the emulator — call [startProxy] or [handleServices]
  /// to do that.
  ///
  /// For mode switches on an already-running emulator (e.g. swapping proxy ↔ VS
  /// while connected) use [switchRetrofitMode] instead.
  void setRetrofitMode(RetrofitMode mode) {
    _retrofitModeN.value = mode;
  }

  /// Swap the retrofit transport without tearing down the upstream BLE
  /// connection. For proxy ↔ VS transitions, migrates the definitions between
  /// emulators.
  Future<void> switchRetrofitMode(RetrofitMode next) async {
    final old = _retrofitModeN.value;
    if (old == next) return;

    if (old == RetrofitMode.proxy && next != RetrofitMode.proxy) {
      // proxy → VS: stop per-instance emulator, attach FBD to shared
      if (_proxyDef != null) {
        await _detachLogged(_proxyEmulator.detachDefinition(_proxyDef!), 'detach proxy def on proxy→VS switch');
      }
      await _proxyEmulator.stop();

      // Rebuild FBD for VS mode if services have been discovered.
      if (services != null) {
        _fbd = FitnessBikeDefinition(
          connectedDevice: scanResult,
          connectedDeviceServices: services!,
          data: ftmsEmulator.data,
          shouldAdvertiseZwift: _shouldAdvertiseZwift,
          transport: transport,
        );
        _currentFbd = _fbd;
        _seedFitnessBikeDefinition(_fbd!);
      }

      _retrofitModeN.value = next;
      ftmsEmulator.shouldAdvertise = () => !_isBridgeTrialOver;
      ftmsEmulator.deviceName = () => scanResult.name;
      ftmsEmulator.advertisementNameOverride = rouvyAdvertisementName;
      ftmsEmulator.forceIPv4 = rouvyNeedsIPv4;
      ftmsEmulator.bareShortServiceUuids = _bareShortServiceUuids;
      _bindToActiveEmulator();

      if (_fbd != null) {
        await ftmsEmulator.attachDefinition(_fbd!);
      }

      if (_attachesZwiftController) {
        await ftmsEmulator.attachDefinition(_zwiftControllerEmulator!);
      }

      await ftmsEmulator.startServer(
        mode: next,
        mdnsTxt: _trainerMdnsTxt(),
      );
    } else if (old != RetrofitMode.proxy && next == RetrofitMode.proxy) {
      // VS → proxy: detach from shared, start per-instance
      if (_fbd != null) {
        await _detachLogged(ftmsEmulator.detachDefinition(_fbd!), 'detach FBD on VS→proxy switch');
        _fbd = null;
      }
      await _stopFtmsEmulatorIfUnused();

      // Rebuild proxy def if services have been discovered.
      if (services != null) {
        _proxyDef = ProxyBikeDefinition(
          services: services!,
          device: scanResult,
          data: _proxyEmulator.data,
          transport: transport,
        );
      }

      _retrofitModeN.value = next;
      _bindToActiveEmulator();

      if (_proxyDef != null) {
        await _proxyEmulator.attachDefinition(_proxyDef!);
      }
      _proxyEmulator.bareShortServiceUuids = _bareShortServiceUuids;
      await _proxyEmulator.startServer(
        mode: RetrofitMode.proxy,
        mdnsTxt: _trainerMdnsTxt(),
      );
    } else {
      // VS wifi ↔ VS bluetooth: restart the shared emulator with the new mode
      _retrofitModeN.value = next;
      await ftmsEmulator.startServer(
        mode: next,
        mdnsTxt: _trainerMdnsTxt(),
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _transportNotificationSub?.cancel();
    _transportNotificationSub = null;
    transport.onDisconnected = null;
    // Remove listeners from the active emulator before teardown.
    _retrofitModeN.removeListener(_bindToActiveEmulator);
    final active = _currentlyListening;
    if (active != null) {
      active.isStarted.removeListener(_mirrorIsStarted);
      active.isConnected.removeListener(_mirrorIsConnected);
      active.localAddress.removeListener(_mirrorLocalAddress);
      active.isConnected.removeListener(_syncBridgeTracking);
      _currentlyListening = null;
    }

    _bridgeBudgetSub?.cancel();
    _bridgeBudgetSub = null;
    core.bridgeUsageTracker.stopSession();

    // Detach FBD from shared emulator if we contributed one.
    if (_fbd != null) {
      await _detachLogged(ftmsEmulator.detachDefinition(_fbd!), 'detach FBD on disconnect');
      _fbd = null;
    }

    if (_zwiftControllerEmulator != null) {
      await _detachLogged(
        ftmsEmulator.detachDefinition(_zwiftControllerEmulator!),
        'detach Zwift controller on disconnect',
      );
      _zwiftControllerEmulator = null;
    }

    // Await the stop so the shared emulator's mDNS/TCP advertising is fully torn
    // down before we report the device disconnected — otherwise a Virtual
    // Shifting → No connection switch can leave BikeControl advertising.
    await _stopFtmsEmulatorIfUnused();

    if (_proxyDef != null) {
      await _detachLogged(_proxyEmulator.detachDefinition(_proxyDef!), 'detach proxy definition on disconnect');
    }

    await _proxyEmulator.stop();

    // The stable wrappers are normally driven by the active emulator's
    // listeners, which we just detached above — so the emulator stops won't
    // propagate. Reset them explicitly so isStartedListenable /
    // isConnectedListenable report the disconnected state. The in-card
    // "No connection" entry disconnects in place (without popping the details
    // page) and relies on this to fall back to the disconnected picker.
    _isStartedN.value = false;
    _isConnectedN.value = false;

    return super.disconnect();
  }
}
