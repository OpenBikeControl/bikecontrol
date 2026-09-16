import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_sensor_device.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/models/remembered_device.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/utils/click_v2_onboarding.dart';
import 'package:bike_control/pages/unlock.dart';
import 'package:intl/intl.dart';
import 'package:bike_control/pages/home/chain_builder.dart';
import 'package:bike_control/pages/home/chain_inputs.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/pages/home/home_extras.dart';
import 'package:bike_control/pages/home/home_sheets.dart';
import 'package:bike_control/pages/home/pro_unregistered_banner.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/sensors/sensors_page.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/services/local_network_access.dart';
import 'package:bike_control/services/network_self_test/probes/passive_probes.dart' show advertisedAddressWarning;
import 'package:bike_control/utils/requirements/local_network.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/controller/controller_canvas.dart';
import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart';
import 'package:bike_control/widgets/home/accessory_card.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_card.dart';
import 'package:bike_control/widgets/home/chain_labels.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:bike_control/widgets/home/trial_card.dart';
import 'package:bike_control/widgets/zwift_ride_firmware_notice.dart';
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show enableLocalControl, ensureLocalNetworkAccess;
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:prop/mdns/service_advertiser.dart' show ServiceAdvertiser;
import 'package:prop/prop.dart' show ClickKeepAwakeStatus, ClickLogic, LogLevel;
import 'package:prop/utils/network_address.dart' show AdvertisedAddressPicker;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// How much the chain card wants to talk about a given trainer. Lower wins.
///
/// One physical trainer is regularly discovered twice — once over BLE, once
/// over mDNS/DirCon — and the two entries are separate [ProxyDevice]s. Ranking
/// only on `isBridged` left the two idle duplicates tied, so the chain card
/// could pick the twin the rider isn't using. Falling back through "the BLE /
/// DirCon link is up" and "we're connecting right now" keeps the live entry in
/// front of its idle double.
@visibleForTesting
int proxyChainRank(ProxyDevice p) {
  if (p.isBridged) return 0;
  if (p.isConnected) return 1;
  if (p.isStarting.value) return 2;
  return 3;
}

/// The trainer the chain card speaks for: the liveliest of the discovered
/// proxies. See [proxyChainRank].
@visibleForTesting
ProxyDevice? chainProxy() => core.connection.proxyDevices.sortedBy(proxyChainRank).firstOrNull;

/// The app card's active step is "waiting for the app to connect" and the
/// Network method is the enabled path — the moment troubleshooting helps.
bool appCardOffersTroubleshooting(ChainLink link) =>
    link.key == ChainLinkKey.app &&
    link.activeStep?.id == SetupStepId.appConnected &&
    core.logic.isObpMdnsEnabled &&
    core.obpMdnsEmulator.isStarted.value;

/// The Main tab: the setup chain.
///
/// One card per link, in signal-path order — your controllers, then the gears
/// BikeControl computes from them, then the app that receives them. Each card
/// states its own status and its own remaining steps, so a rider who opens the
/// app can answer "am I ready?" without tapping anything, and a rider whose
/// ride just broke can see *which* link failed instead of a screen of green
/// widgets that are all technically telling the truth.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.isMobile,
    required this.onUpdate,
    this.showHelpRow = true,
    this.onHelp,
  });

  final bool isMobile;

  /// Lets the host clear its error banner when the rider acts on a card.
  final VoidCallback onUpdate;

  /// Hidden on wide desktop, where the activity rail already carries a Help
  /// button and a second one would be redundant.
  final bool showHelpRow;
  final VoidCallback? onHelp;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final StreamSubscription<BaseDevice> _connectionListener;
  late final StreamSubscription<BaseNotification> _actionListener;
  Timer? _metricsTicker;

  /// Assumed available until proven otherwise, so the step doesn't flash as
  /// pending on every cold start before the platform has answered.
  bool _bluetoothReady = true;

  final Map<String, ControllerButton> _pressedButton = {};
  final Map<String, int> _pressGeneration = {};

  /// Last measured Local Network status, kept here rather than read off
  /// [LocalNetworkAccess.cached]: that cache expires after 30s, and a step that
  /// silently disappeared half a minute after the rider looked at it would be
  /// worse than no step at all.
  LocalNetworkStatus? _localNetwork;

  /// Null when the permission is not the rider's problem: nothing that rides on
  /// the LAN is switched on, this platform has no such permission, or it has
  /// never been measured.
  bool? get _localNetworkGranted {
    if (!core.logic.hasNetworkMethodEnabled || localNetworkRequirements().isEmpty) return null;
    final status = _localNetwork;
    // Same rule as everywhere else: unknown is not a denial, so the step must
    // not sit there red because the probe could not tell.
    return status == null ? null : LocalNetworkAccess.usable(status);
  }

  Future<void> _refreshLocalNetwork() async {
    if (!core.logic.hasNetworkMethodEnabled || localNetworkRequirements().isEmpty) return;
    try {
      final status = await LocalNetworkAccess.status();
      if (mounted && status != _localNetwork) setState(() => _localNetwork = status);
    } catch (e, s) {
      recordError(e, s, context: 'home local network status');
    }
  }

  /// The advertised address when it is one the trainer app is unlikely to
  /// reach, else null — see [AppInput.advertisedAddressWarning]. Read off the
  /// same picker the self-test's "advertised address" row runs, so the card
  /// never says something that page would not.
  String? _advertisedAddressWarning;

  Future<void> _refreshAdvertisedAddress() async {
    // The store board sells a finished setup, and a VPN on the screenshot
    // machine must not end up in a listing. The web has no interfaces to
    // list, and without a network method nothing is advertised at all.
    final applies = !kIsWeb && !screenshotMode && core.logic.hasNetworkMethodEnabled;
    try {
      final warning = applies ? advertisedAddressWarning(await AdvertisedAddressPicker.report()) : null;
      if (mounted && warning != _advertisedAddressWarning) setState(() => _advertisedAddressWarning = warning);
    } catch (e, s) {
      recordError(e, s, context: 'home advertised address');
    }
  }

  /// What can move the advertised address, or make it matter: the responder
  /// backend re-picking when the machine changes networks (the only place the
  /// address is actually tracked), and a network method starting, stopping,
  /// connecting or dropping — a drop is most often the moment a VPN came up.
  /// None of these is a connection-stream event, so each is watched here.
  late final List<Listenable> _advertisedAddressListenables = [
    ServiceAdvertiser.instance.advertisedAddress,
    for (final connection in [
      core.obpMdnsEmulator,
      core.zwiftMdnsEmulator,
      core.rouvyMdnsEmulator,
      core.whooshLink,
    ]) ...[
      connection.isStarted,
      connection.isConnected,
    ],
  ];

  void _onAdvertisedAddressChanged() {
    unawaited(_refreshAdvertisedAddress());
  }

  @override
  void initState() {
    super.initState();

    unawaited(_refreshLocalNetwork());
    unawaited(_refreshAdvertisedAddress());
    for (final listenable in _advertisedAddressListenables) {
      listenable.addListener(_onAdvertisedAddressChanged);
    }
    // A VPN is switched on in the system settings, not in BikeControl — the
    // rider comes back to the app afterwards, and the card has to be current
    // when they do.
    WidgetsBinding.instance.addObserver(this);

    _connectionListener = core.connection.connectionStream.listen((_) {
      _syncProxyListeners();
      if (mounted) setState(() {});
      _maybeShowRideFirmwareDialog();
    });
    _syncProxyListeners();
    _actionListener = core.connection.actionStream.listen((notification) {
      if (notification is ButtonNotification && notification.buttonsClicked.isNotEmpty) {
        final id = notification.device.uniqueId;
        _pressGeneration[id] = (_pressGeneration[id] ?? 0) + 1;
        if (mounted) setState(() => _pressedButton[id] = notification.buttonsClicked.first);
      }
    });

    // Live trainer telemetry lives behind several notifiers that swap when the
    // trainer changes mode. A slow tick is cheaper to reason about than
    // re-subscribing on every transition, and it only runs while a trainer is
    // actually connected.
    // Not started under the screenshot harness: a periodic timer never lets a
    // widget test's frame loop go quiet, and the captured metrics are fixtures
    // there anyway.
    if (!screenshotMode) {
      _metricsTicker = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted && core.connection.proxyDevices.any((p) => p.isConnected)) setState(() {});
      });
    }

    _refreshBluetoothState();
    IAPManager.instance.isPurchased.addListener(_onPurchaseChanged);
    // The keep-awake resolves a few seconds after a left puck turns up, which
    // is not a connection event — without this the offer would linger on the
    // card after it had already been taken up.
    ClickLogic.keepAwakeStatus.addListener(_onKeepAwakeChanged);
    // The Sensors card's status is the Broadcast switch and whoever is
    // subscribed to the standalone peripheral — neither is a connection
    // event, so without these the card would sit on "Off" after the rider
    // switched Broadcast on from its own page.
    _broadcastListenables = [
      if (core.connection.broadcast case final broadcast?) ...[broadcast.isOn, broadcast.transport],
      core.connection.standaloneClientConnected,
    ];
    for (final listenable in _broadcastListenables) {
      listenable.addListener(_onBroadcastChanged);
    }

    _maybeShowRideFirmwareDialog();
  }

  List<Listenable> _broadcastListenables = const [];

  void _onBroadcastChanged() {
    if (mounted) setState(() {});
  }

  void _onKeepAwakeChanged() {
    if (mounted) setState(() {});
  }

  /// Once per install, when a Zwift Ride first shows up on server-locked
  /// firmware (>1.2.0), surface a one-time dialog pointing the rider at support.
  /// The persistent card notice in controller settings is the standing fallback.
  bool _rideFirmwareDialogHandled = false;

  void _maybeShowRideFirmwareDialog() {
    if (screenshotMode || _rideFirmwareDialogHandled) return;
    if (core.settings.getRideFirmwareLockDialogShown()) {
      _rideFirmwareDialogHandled = true;
      return;
    }
    final affected = core.connection.controllerDevices.firstOrNullWhere(ZwiftRide.hasUnsupportedFirmware);
    if (affected == null) return;
    _rideFirmwareDialogHandled = true;
    unawaited(core.settings.setRideFirmwareLockDialogShown(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showZwiftRideFirmwareDialog(context, affected as ZwiftRide);
      }
    });
  }

  /// Whether the bridge is running and whether the trainer app holds it are
  /// ValueNotifiers on each ProxyDevice, not events on the connection stream —
  /// so without these listeners the trainer card would sit on a stale status
  /// until something else happened to rebuild the page.
  final Set<ProxyDevice> _watchedProxies = {};

  void _syncProxyListeners() {
    for (final proxy in core.connection.proxyDevices) {
      if (!_watchedProxies.add(proxy)) continue;
      proxy.isStarting.addListener(_onProxyChanged);
      proxy.isStartedListenable.addListener(_onProxyChanged);
      proxy.isConnectedListenable.addListener(_onProxyChanged);
    }
  }

  void _onProxyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final proxy in _watchedProxies) {
      proxy.isStarting.removeListener(_onProxyChanged);
      proxy.isStartedListenable.removeListener(_onProxyChanged);
      proxy.isConnectedListenable.removeListener(_onProxyChanged);
    }
    _connectionListener.cancel();
    _actionListener.cancel();
    _metricsTicker?.cancel();
    IAPManager.instance.isPurchased.removeListener(_onPurchaseChanged);
    ClickLogic.keepAwakeStatus.removeListener(_onKeepAwakeChanged);
    for (final listenable in _broadcastListenables) {
      listenable.removeListener(_onBroadcastChanged);
    }
    for (final listenable in _advertisedAddressListenables) {
      listenable.removeListener(_onAdvertisedAddressChanged);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshAdvertisedAddress());
  }

  void _onPurchaseChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshBluetoothState() async {
    try {
      final ready = await BluetoothTurnedOn().getStatus();
      if (mounted && ready != _bluetoothReady) setState(() => _bluetoothReady = ready);
    } catch (e, s) {
      recordError(e, s, context: 'HomePage bluetooth availability');
    }
  }

  // ── Reading the world ─────────────────────────────────────────────────

  /// Every controller the app knows about: the live ones first, then the
  /// remembered stand-ins for devices that aren't here right now.
  List<BaseDevice> get _knownControllers => [
    ...core.connection.controllerDevices,
    ...core.connection.offlineControllers,
  ];

  BaseDevice? _controllerById(String? uniqueId) =>
      uniqueId == null ? null : _knownControllers.firstOrNullWhere((d) => d.uniqueId == uniqueId);

  /// Whether [device] is unlocked, or null when unlocking does not apply.
  ///
  /// Only the Zwift Click V2 needs it, and only in the modes that actually use
  /// Zwift to unlock: the legacy unified controller (which has no other way)
  /// and the left puck when the rider chose unlock-with-Zwift. The left puck on
  /// the restart workaround never unlocks — it reboots itself instead — so a
  /// step telling the rider to open Zwift would be wrong there, and the right
  /// puck was never locked at all.
  bool? _unlockState(BaseDevice device) {
    if (device is! ZwiftClickV2) return null;
    if (device is ZwiftClickV2LeftSide && !core.settings.getUnlockWithZwift()) return null;
    return device.isPersistedUnlocked;
  }

  /// When this controller's unlock runs out, or null if it isn't unlocked.
  /// Formatted here, next to the other display concerns — the chain model
  /// itself stays free of locales and date formats.
  String? _unlockedUntil(BaseDevice device) {
    if (device is! ZwiftClickV2) return null;
    final until = device.unlockedUntil;
    return until == null ? null : DateFormat('EEEE, HH:mm').format(until);
  }

  DevicePresence _presenceOf(BaseDevice device, {required bool isStandIn}) {
    if (device.isConnected) return DevicePresence.connected;
    if (device.isResetting) return DevicePresence.resetting;
    // The distinction that keeps a fresh launch calm: only a device that was
    // working in *this* session counts as broken.
    if (core.connection.wasConnectedThisSession(device.uniqueId)) return DevicePresence.lost;
    // A stand-in comes from the remembered list, so we know the rider owns it
    // and it is merely out of range. Anything else is something the scanner
    // just found and we have never connected to — "not set up", not "broken".
    return isStandIn ? DevicePresence.remembered : DevicePresence.discovered;
  }

  bool _hasMappedButtons(BaseDevice device) {
    final keymap = core.actionHandler.supportedApp?.keymap;
    if (keymap == null) return false;
    return device.availableButtons.any(keymap.hasAnyMappedAction);
  }

  ChainInputs _readInputs() {
    final controllers = _knownControllers;
    final standInIds = core.connection.offlineControllers.map((d) => d.uniqueId).toSet();
    final trainerApp = core.settings.getTrainerApp();
    final proxy = chainProxy();
    final remembered = core.connection.rememberedTrainer;

    TrainerInput? trainer;
    if (proxy != null) {
      // "Connected" for a trainer means *bridged*, exactly as onboarding
      // defines it (onboardingTrainerBridged): the bridge is running for this
      // trainer. A trainer whose Bluetooth link is up but which isn't bridging
      // anything does nothing for the rider, and saying "connected" about it
      // is the kind of technically-true status this redesign exists to remove.
      final bridged = proxy.isBridged;
      // Picking "No connection" — letting the trainer app handle shifting — is
      // a deliberate resting state. Whatever happened earlier in the session,
      // a trainer the rider has switched off is not a trainer that broke.
      final wanted = core.settings.getAutoConnect(proxy.trainerKey);
      final DevicePresence presence;
      if (bridged) {
        presence = DevicePresence.connected;
      } else if (!wanted) {
        presence = DevicePresence.discovered;
      } else if (core.connection.wasConnectedThisSession(proxy.uniqueId)) {
        presence = DevicePresence.lost;
      } else {
        presence = DevicePresence.discovered;
      }
      // The trainer's own advertised name — not [name], which falls back to
      // the class name when there is none. An empty one counts as none too,
      // or the hint would warn against picking “”.
      final rawName = proxy.scanResult.name;
      trainer = TrainerInput(
        deviceId: proxy.uniqueId,
        name: proxy.toString(),
        presence: presence,
        // isConnectedListenable mirrors emulator.isConnected — the trainer app
        // actually holds the virtual trainer, not just "the bridge is running".
        appHoldsBridge: proxy.isConnectedListenable.value,
        // The exact entry to look for in the trainer app's device list.
        bridgeName: proxy.advertisementName,
        // And the one beside it not to pick: the trainer under its own name.
        rawTrainerName: rawName == null || rawName.isEmpty ? null : rawName,
        metrics: proxy.liveReadout,
        overlayOffered: _overlayOffered(proxy),
        overlayEnabled: core.settings.getOverlayEnabled(),
        overlayAnswered: core.settings.getOverlayAnswered(),
        overlayDeclined: core.settings.getOverlayDeclined(),
      );
    } else if (remembered != null) {
      trainer = TrainerInput(
        deviceId: remembered.deviceId,
        name: remembered.name ?? context.i18n.chainTrainerTitle,
        presence: DevicePresence.remembered,
        appHoldsBridge: false,
      );
    }

    // A connected trainer always wins. Sensors-only mode is the answer to "I
    // have no smart trainer", so the moment one is actually bridged — a
    // remembered one auto-connecting, or a new one the rider paired — that
    // answer is stale and the chain goes back to the trainer, quietly:
    // nothing to announce, the card itself is the news. Only *connected*: a
    // trainer the scanner merely sees may be the neighbour's, and one
    // remembered from before is exactly what a rider who now rides on
    // sensors alone has put away — neither may throw them out of the mode.
    final trainerConnected = trainer?.presence == DevicePresence.connected;
    if (trainerConnected && core.settings.getSensorsOnlyMode()) {
      unawaited(
        core.settings
            .setSensorsOnlyMode(false)
            .catchError((Object e, StackTrace s) => recordError(e, s, context: 'HomePage.sensorsOnlyExit')),
      );
    }
    final sensorsOnly = core.settings.getSensorsOnlyMode() && !trainerConnected;

    return ChainInputs(
      bluetoothReady: _bluetoothReady,
      controllers: [
        for (final device in controllers)
          ControllerInput(
            deviceId: device.uniqueId,
            // displayName, not toString: the Click V2 pucks carry a
            // translatable left/right suffix, and toString stays English.
            name: device.displayName(context),
            presence: _presenceOf(device, isStandIn: standInIds.contains(device.uniqueId)),
            hasMappedButtons: _hasMappedButtons(device),
            // A derailleur learns its paddles from the presses they send, so
            // before its guided setup has run there is nothing on the keymap
            // to map — see [ControllerInput.hasKnownButtons].
            hasKnownButtons: device.availableButtons.isNotEmpty,
            requiresBluetooth: device is BluetoothDevice,
            unlocked: _unlockState(device),
            unlockedUntil: _unlockedUntil(device),
            unlockUncertain: device is ZwiftClickV2 && device.isLikelyUnlocked,
            sramSetupDone: device is SramAxs ? !device.needsGuidedSetup : null,
            sramCanRestore: device is SramAxs && device.canRestoreShifting,
            needsUnlockModeChoice:
                (device is ZwiftClickV2 || device is ZwiftClickV2RightSide) && ClickV2Onboarding.isPending,
            clickV2NeedsLeftSide:
                device is ZwiftClickV2RightSide &&
                ClickLogic.keepAwakeStatus.value == ClickKeepAwakeStatus.waitingForLeftSide,
          ),
      ],
      // The chain builder lets a trainer win over sensors, so in sensors-only
      // mode the merely-seen or remembered trainer is withheld from it.
      trainer: sensorsOnly ? null : trainer,
      sensors: sensorsOnly ? _readSensors() : null,
      app: AppInput(
        name: trainerApp?.name,
        selfHosted: trainerApp is BikeControl,
        hasEnabledConnection: core.logic.enabledTrainerConnections.isNotEmpty,
        isConnected: core.logic.appFacingConnections.isNotEmpty,
        wasConnectedThisSession: _appConnectedThisSession,
        connectionSummary: core.logic.appFacingConnections.firstOrNull?.title,
        // showLocalControl is already "the rider's target is this device, and
        // this platform can drive it" — see CoreLogic.
        localControlOffered: core.logic.showLocalControl,
        localControlEnabled: core.settings.getLocalEnabled(),
        localNetworkGranted: _localNetworkGranted,
        // The trainer link's own answer, so the two cards can never disagree
        // about whether the app has picked the trainer up.
        trainerBridgedByApp: trainer?.appHoldsBridge ?? false,
        // Only Bluetooth mode serves the bridge as a BLE peripheral; proxy and
        // WiFi mode both serve DirCon from the advertised address. The trainer
        // input is the same proxy's, so the two answers cannot disagree.
        trainerBridgedOverNetwork:
            (trainer?.appHoldsBridge ?? false) && proxy != null && proxy.retrofitMode.value != RetrofitMode.bluetooth,
        advertisedAddressWarning: _advertisedAddressWarning,
      ),
    );
  }

  /// The sensors-only slot: which sources the rider picked, whether the
  /// broadcast is live, and over what.
  ///
  /// `broadcast` is built in `Connection.initialize`, so it is only ever null
  /// in a test that did not assign one; the fallbacks then read the same
  /// selection and persisted transport the controller itself would.
  SensorsInput _readSensors() {
    final broadcast = core.connection.broadcast;
    final ids =
        broadcast?.selectedSourceIds ??
        {
          for (final q in SensorQuantity.values)
            if (core.sensors.selectionFor(q) case final id?) id,
        };
    return SensorsInput(
      sourceNames: [
        for (final id in ids)
          if (_sensorSourceName(id) case final name?) name,
      ].distinct().toList(),
      broadcasting: broadcast?.isOn.value ?? false,
      transport: broadcast?.transport.value ?? core.settings.getSensorsTransport(),
      clientName: core.connection.standaloneClientName,
    );
  }

  /// A selected source's display name, wherever it currently lives: registered
  /// with the hub (connected), merely nearby (a strap the scanner has seen but
  /// Broadcast has not connected yet), or Apple Health. Null for a persisted
  /// id nothing answers to any more — a source the rider carried off — which
  /// the card then simply does not name.
  String? _sensorSourceName(String id) {
    final registered = core.sensors.sources.firstOrNullWhere((s) => s.id == id);
    if (registered != null) return registered.displayName;
    final nearby = core.connection.devices.whereType<BleSensorDevice>().firstOrNullWhere((d) => d.source.id == id);
    if (nearby != null) return nearby.source.displayName;
    final healthKit = core.connection.healthKitSource;
    if (healthKit != null && healthKit.id == id) return healthKit.displayName;
    return null;
  }

  /// Whether the trainer card should offer the gear overlay.
  ///
  /// The overlay answers one question — "why does my trainer app show a
  /// different gear than my shifter?" — and it can only answer it when the
  /// trainer app is on this very screen. Riding from another device puts the
  /// app somewhere BikeControl cannot draw, and a Virtual Shifting session is
  /// what produces a gear to draw in the first place: without one the trainer
  /// app's gear is the only gear, and there is nothing to reconcile.
  bool _overlayOffered(ProxyDevice proxy) {
    // The store board sells a finished setup; an outstanding offer, optional or
    // not, is the one thing on that card still asking for something.
    if (screenshotMode) return false;
    if (!TrainerOverlayService.isSupportedPlatform) return false;
    if (core.settings.getLastTarget() != Target.thisDevice) return false;
    return proxy.fitnessBike != null;
  }

  bool _appConnectedThisSession = false;

  /// The bridged trainer's own name, which the pairing instructions use to
  /// spell out the entry to look for ("KICKR CORE - BikeControl").
  String? get _bridgedTrainerName => core.connection.proxyDevices.firstOrNullWhere((p) => p.isBridged)?.name;

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inputs = _readInputs();
    // Latch once connected: the app card can then say "lost connection" rather
    // than falling back to "never set up" the moment the app quits.
    if (inputs.app.isConnected) _appConnectedThisSession = true;

    final links = buildChain(inputs);
    final banner = deriveBanner(links);
    final devicesById = {for (final d in _knownControllers) d.uniqueId: d};
    final trial = _trialState();

    return Padding(
      // No horizontal inset on mobile: the shell's scroll view already pads the
      // chain by 12 (Overview's hPad), and adding another 12 here cost 24px a
      // side — a sixth of a phone's width spent on nothing, and it stacks again
      // with each card's own padding. Desktop keeps it: there the chain sits in
      // a centred max-width box with no padding of its own.
      padding: EdgeInsets.fromLTRB(widget.isMobile ? 0 : 12, 12, widget.isMobile ? 0 : 12, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReadyBanner(
            banner: banner,
            appName: inputs.app.name,
            brokenLinkName: _linkName(links, banner.targetLinkId),
            onAction: banner.hasAction
                ? () => _openInstructions(links.firstWhere((l) => l.id == banner.targetLinkId))
                : null,
          ),
          if (trial != null) ...[
            TrialCard(
              state: trial,
              onUpgrade: () => IAPManager.instance.purchaseFullVersion(context),
              onRestore: () => IAPManager.instance.restorePurchases(),
            ),
            const Gap(10),
          ],
          // Pro on the account, not on this device: carries its own gap.
          const ProUnregisteredBanner(),
          for (final link in links) ...[
            _card(link, devicesById[link.deviceId], inputs),
            const Gap(10),
          ],
          ..._accessorySection(),
          HomeExtras(isMobile: widget.isMobile, onUpdate: _update),
          if (widget.showHelpRow) ...[
            const Gap(12),
            Button.outline(
              onPressed: widget.onHelp ?? () => openControllerHelpSheet(context),
              child: Row(
                children: [
                  Icon(LucideIcons.lifeBuoy, size: 17, color: Theme.of(context).colorScheme.primary),
                  const Gap(9),
                  Expanded(
                    child: Text(
                      context.i18n.chainSomethingNotWorking,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 15, color: Theme.of(context).colorScheme.mutedForeground),
                ],
              ),
            ),
          ],
          if (widget.isMobile) Gap(MediaQuery.viewPaddingOf(context).bottom + 32),
        ],
      ),
    );
  }

  void _update() {
    widget.onUpdate();
    unawaited(_refreshLocalNetwork());
    unawaited(_refreshAdvertisedAddress());
    if (mounted) setState(() {});
  }

  String? _linkName(List<ChainLink> links, String? id) {
    if (id == null) return null;
    final link = links.firstOrNullWhere((l) => l.id == id);
    if (link == null) return null;
    return link.title.isNotEmpty ? link.title : chainLinkName(context, link.key);
  }

  TrialCardState? _trialState() {
    final iap = IAPManager.instance;
    // The reward for paying is one less thing on screen.
    if (iap.isPurchased.value || iap.isProEnabledForCurrentDevice) return null;

    final trainerConnected = core.connection.proxyDevices.any((p) => p.isBridged);
    final bridge = core.bridgeUsageTracker;
    return TrialCardState(
      daysRemaining: iap.trialDaysRemaining,
      daysTotal: _trialDaysTotal,
      expired: iap.isTrialExpired,
      commandsRemaining: iap.commandsRemainingToday,
      commandsTotal: IAPManager.dailyCommandLimit,
      bridgeMinutesRemaining: trainerConnected ? bridge.remainingToday.inMinutes : null,
      bridgeMinutesTotal: trainerConnected ? bridge.dailyLimit.inMinutes : null,
    );
  }

  /// The trial's full length, inferred from the largest remaining count we have
  /// seen, so the meter never shows a value above its own ceiling.
  int get _trialDaysTotal {
    final remaining = IAPManager.instance.trialDaysRemaining;
    return remaining > _knownTrialDays ? remaining : _knownTrialDays;
  }

  static const int _knownTrialDays = 5;

  // ── Cards ─────────────────────────────────────────────────────────────

  Widget _card(ChainLink link, BaseDevice? device, ChainInputs inputs) {
    final card = switch (link.key) {
      ChainLinkKey.controller => _controllerCard(link, device, inputs),
      ChainLinkKey.trainer => _trainerCard(link, inputs),
      ChainLinkKey.sensors => _sensorsCard(link, inputs),
      ChainLinkKey.app => _appCard(link, inputs),
    };

    if (!link.dismissible) return card;

    // Only a device that isn't here can be swiped away, so this gesture can
    // never drop a working controller off the screen.
    return Dismissible(
      key: ValueKey('dismiss-${link.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: AmpelStyle.of(context, LinkStatus.problem).wash,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(LucideIcons.trash2, size: 20, color: AmpelStyle.of(context, LinkStatus.problem).color),
      ),
      onDismissed: (_) => _forget(link),
      child: card,
    );
  }

  Widget _controllerCard(ChainLink link, BaseDevice? device, ChainInputs inputs) {
    final placeholder = device == null;
    final status = link.status;

    return ChainCard(
      link: link,
      appName: inputs.app.name,
      tile: Icon(
        placeholder ? LucideIcons.gamepad : device.icon,
        size: 22,
        color: status == LinkStatus.off
            ? Theme.of(context).colorScheme.mutedForeground
            : Theme.of(context).colorScheme.foreground,
      ),
      title: placeholder ? context.i18n.chainControllerTitle : link.title,
      statusLabel: _controllerStatusLabel(link, device),
      statusBadges: placeholder ? const [] : _controllerBadges(device),
      editLabel: placeholder ? context.i18n.chainSetUp : context.i18n.chainEdit,
      onEdit: () => _openController(device),
      onTap: () => _openController(device),
      onInstructions: () => _openInstructions(link),
      instructionsLabel: placeholder || link.activeStep?.id == SetupStepId.controllerClickV2Setup
          ? context.i18n.chainSetUp
          : null,
      body: placeholder ? null : _controllerBody(device, connected: device.isConnected),
    );
  }

  /// This controller's own page — or the setup sheet, when the card is still an
  /// empty slot and there is no page yet.
  Future<void> _openController(BaseDevice? device) async {
    if (device == null) {
      await openControllerSetupSheet(context);
    } else {
      await context.push(ControllerSettingsPage(device: device));
    }
    _update();
  }

  String _controllerStatusLabel(ChainLink link, BaseDevice? device) {
    // A device that is actually here is never described by a presence status.
    // "Out of range" is what LinkStatus.attention means for a controller that
    // is away — but attention is also what an unfinished checklist produces for
    // one sitting right there connected, and calling that "out of range" is
    // simply false.
    if (device != null && device.isConnected) {
      return _unlockStatusLabel(device) ?? context.i18n.connected;
    }
    return switch (link.status) {
      LinkStatus.ready => context.i18n.connected,
      LinkStatus.problem => context.i18n.chainStatusLostConnection,
      LinkStatus.attention => context.i18n.chainStatusOutOfRange,
      LinkStatus.off => context.i18n.chainStatusNotSetUp,
    };
  }

  /// The things that qualify "Connected": a battery about to die, a firmware
  /// update waiting, a signal on the edge of dropping. Shown only when they are
  /// actually a problem — a healthy device carries no glyphs, so one appearing
  /// means something, and the detail lives one tap away on the device page.
  List<Widget> _controllerBadges(BaseDevice device) {
    if (!device.isConnected || device is! BluetoothDevice) return const [];
    final scheme = Theme.of(context).colorScheme;
    final battery = device.batteryLevel;
    final rssi = device.rssi;
    return [
      // Same threshold the device page already paints red at.
      if (battery != null && battery < 20) Icon(LucideIcons.batteryWarning, size: 14, color: scheme.destructive),
      if (device is ZwiftDevice && (device as ZwiftDevice).hasNewerFirmwareVersion)
        Icon(LucideIcons.circleArrowUp, size: 13, color: scheme.mutedForeground),
      // -70 dBm is where the device page stops calling the link "Good".
      if (rssi != null && rssi < -70) Icon(LucideIcons.signalLow, size: 13, color: scheme.mutedForeground),
    ];
  }

  /// For an unlocked Click V2, when its unlock runs out — which is worth more
  /// than "Connected", because that is the fact about to stop being true.
  /// Null for anything else, including a Click that is currently locked: the
  /// checklist step carries that, and a stale deadline would contradict it.
  String? _unlockStatusLabel(BaseDevice device) {
    if (_unlockState(device) != true) return null;
    final until = _unlockedUntil(device);
    if (until == null) return null;
    return device is ZwiftClickV2 && device.isLikelyUnlocked
        ? context.i18n.chainStepUnlockedLikelyUntil(until)
        : context.i18n.chainStepUnlockedUntil(until);
  }

  /// The controller's real contour with its real buttons — so the card doubles
  /// as the button map. Rendered for disconnected devices too, faded: mapping a
  /// button is a keymap edit, not a radio operation, so there is no reason to
  /// make a rider wait until they are back on the bike to do it.
  Widget? _controllerBody(BaseDevice device, {required bool connected}) {
    // Nothing to draw is not the same as an empty box to draw it in. A device
    // with no contour and no buttons discovered yet — a SRAM derailleur before
    // its guided setup runs — otherwise rendered as a blank grey panel that
    // looked like a failed render.
    if (device is! SteeringDevice && device.controllerLayout == null && device.availableButtons.isEmpty) {
      return null;
    }

    final keymap = core.actionHandler.supportedApp?.keymap;
    final size = 56 / Theme.of(context).scaling;

    Widget buttonFor(ControllerButton button) {
      final pressed = _pressedButton[device.uniqueId];
      return AnimatedButtonWidget(
        key: ValueKey(button.name),
        button: button,
        pressGeneration: pressed?.name == button.name ? (_pressGeneration[device.uniqueId] ?? 0) : 0,
        keymap: keymap,
        device: device,
        size: size,
        onUpdate: _update,
      );
    }

    final Widget content;
    if (device is SteeringDevice) {
      final steering = device as SteeringDevice;
      content = SteeringGauge(
        angle: steering.steeringAngle,
        calibrated: steering.steeringCalibrated,
        threshold: steering.steeringThreshold,
        device: device,
        leftButton: steering.steerLeftButton,
        rightButton: steering.steerRightButton,
        keymap: keymap,
        onUpdate: _update,
      );
    } else {
      final layout = device.controllerLayout;
      content = layout != null
          ? ControllerCanvas(
              layout: layout,
              availableButtons: device.availableButtons,
              buttonBuilder: buttonFor,
              buttonSize: size,
            )
          : Wrap(spacing: 9, runSpacing: 9, children: device.availableButtons.map(buttonFor).toList());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            opacity: connected ? 1 : 0.55,
            duration: const Duration(milliseconds: 250),
            child: content,
          ),
          if (!connected) ...[
            const Gap(8),
            Text(context.i18n.chainOfflineEditNotice).xSmall.muted,
          ],
        ],
      ),
    );
  }

  Widget _trainerCard(ChainLink link, ChainInputs inputs) {
    final proxy = chainProxy();
    // Straight from the device, in onboarding's sense — not inferred back out
    // of the card's own status, which is how a remembered trainer that isn't
    // even here ended up presenting itself as bridged.
    final bridged = proxy?.isBridged ?? false;
    final appReady = inputs.app.isConnected;
    final appName = inputs.app.name ?? context.i18n.chainAppTitle;
    final appHoldsBridge = inputs.trainer?.appHoldsBridge ?? false;

    // Onboarding's answers for a bridged trainer, plus the honest one for a
    // trainer that is talking to BikeControl without being bridged. That last
    // case matters now that live watts are shown whenever the trainer reports
    // them: "Not connected" beside a cadence reading is a contradiction the
    // rider has to resolve, so a connected-but-unbridged trainer says so.
    final String statusLabel;
    if (link.status == LinkStatus.problem) {
      statusLabel = context.i18n.chainStatusLostConnection;
    } else if (bridged) {
      statusLabel = appHoldsBridge
          ? context.i18n.chainStatusBridged
          // "Waiting for the app" is wrong once the app is already here over
          // the controller link: it has connected, it just hasn't picked the
          // trainer entry up — the other half of its pairing screen.
          : appReady
          ? context.i18n.chainStatusWaitingForPickup(appName)
          : context.i18n.onboardingSummaryWaitingFor(appName);
    } else if (appReady && inputs.app.name != null) {
      // Only vouch for the app handling shifting when the app is actually
      // working — otherwise this card would excuse a broken link.
      statusLabel = context.i18n.chainStatusHandledByApp(appName);
    } else if (proxy?.isConnected ?? false) {
      statusLabel = context.i18n.connected;
    } else {
      statusLabel = context.i18n.notConnected;
    }

    final activeStep = link.activeStep;
    final offersOverlay = activeStep?.id == SetupStepId.trainerGearOverlay;
    // "Not now" belongs to the step while it is required — the one time it
    // asks for an answer. Once answered and switched off again it is an
    // optional offer, and an offer has nothing to decline.
    final overlayAsksForAnswer = offersOverlay && !activeStep!.optional;

    return ChainCard(
      link: link,
      // Nullable on purpose: the step wording falls back to "Trainer app"
      // itself, and the overlay step has a sentence of its own for that case.
      appName: inputs.app.name,
      tile: Icon(
        LucideIcons.bike,
        size: 22,
        color: link.status == LinkStatus.ready
            ? Theme.of(context).colorScheme.foreground
            : Theme.of(context).colorScheme.mutedForeground,
      ),
      title: link.title.isEmpty ? context.i18n.chainTrainerTitle : link.title,
      statusLabel: statusLabel,
      // Until a trainer is actually bridged there is nothing to edit — the
      // useful offer is to connect it, the same way onboarding does.
      editLabel: bridged ? context.i18n.chainEdit : context.i18n.connect,
      onEdit: () => _openTrainer(proxy, bridged: bridged),
      onTap: () => _openTrainer(proxy, bridged: bridged),
      onInstructions: () => _openInstructions(link),
      // The overlay step is an offer, not a puzzle: its button turns the thing
      // on rather than explaining how it works. And while the step is
      // required, the offer needs a second answer — "Not now" — or a rider who
      // doesn't want the overlay is stuck with an amber card forever.
      instructionsLabel: offersOverlay ? context.i18n.chainStepOverlayAction : null,
      secondaryActionLabel: overlayAsksForAnswer ? context.i18n.chainStepOverlayDecline : null,
      onSecondaryAction: overlayAsksForAnswer ? _declineOverlay : null,
      body: _trainerBody(proxy),
      // The way out for a rider with no smart trainer: the slot stays useful —
      // it becomes their sensors — instead of sitting there OPTIONAL forever.
      // Offered whenever nothing is actually bridged: a trainer the scanner
      // merely sees, or one remembered from before, is not a trainer the
      // rider is on right now.
      footer: inputs.trainer?.presence != DevicePresence.connected
          ? ChainCardFooterRow(
              question: inputs.app.name != null
                  ? context.i18n.sensorsUseSensorsOnlyQuestionApp(inputs.app.name!)
                  : context.i18n.sensorsUseSensorsOnlyQuestion,
              action: context.i18n.sensorsUseSensorsOnly,
              onPressed: _enterSensorsOnlyMode,
            )
          : null,
    );
  }

  Future<void> _enterSensorsOnlyMode() async {
    await core.settings.setSensorsOnlyMode(true);
    _update();
  }

  /// Sensors-only mode's card in the trainer's slot: what is being broadcast,
  /// to whom, and — while it is live — the readings themselves.
  Widget _sensorsCard(ChainLink link, ChainInputs inputs) {
    final sensors = inputs.sensors!;
    final broadcasting = sensors.broadcasting;

    final String statusLabel;
    if (broadcasting) {
      statusLabel = context.i18n.sensorsStatusBroadcasting;
    } else if (sensors.sourceNames.isEmpty) {
      statusLabel = context.i18n.sensorsStatusOffSetup;
    } else {
      statusLabel = context.i18n.sensorsStatusOff;
    }

    // The first source is the title, the rest ride a sub line ("with Assioma
    // DUO"); the status meta carries the wire: "Bluetooth · MyWhoosh
    // connected". The transport only matters once the broadcast is on — an
    // idle card naming "Network" would be describing a wire nothing is on.
    final rest = sensors.sourceNames.skip(1).toList();
    final meta = [
      if (broadcasting)
        sensors.transport == RetrofitMode.wifi
            ? context.i18n.sensorsTransportNetwork
            : context.i18n.sensorsTransportBluetooth,
      if (broadcasting)
        if (sensors.clientName case final client?) context.i18n.sensorsClientConnected(client),
    ].join(' · ');

    return ChainCard(
      link: link.copyWith(subtitleArg: meta),
      appName: inputs.app.name,
      tile: Icon(
        LucideIcons.heartPulse,
        size: 22,
        color: link.status == LinkStatus.ready
            ? Theme.of(context).colorScheme.foreground
            : Theme.of(context).colorScheme.mutedForeground,
      ),
      title: link.title.isEmpty ? context.i18n.sensorsNoSensorsYet : link.title,
      statusLabel: statusLabel,
      subtitle: rest.isEmpty ? null : context.i18n.sensorsWith(rest.join(', ')),
      editLabel: context.i18n.sensorsOpen,
      onEdit: _openSensors,
      onTap: _openSensors,
      body: broadcasting ? _sensorsBody() : null,
      // The way back: sensors-only mode hid the trainer card, and short of a
      // trainer auto-connecting there was no other way to reach it — see
      // _enterSensorsOnlyMode for the entry this mirrors. Broadcast itself is
      // untouched by leaving the mode (Decision 6): the sink keeps standalone
      // until a trainer actually bridges.
      footer: ChainCardFooterRow(
        question: context.i18n.sensorsConnectTrainerQuestion,
        action: context.i18n.sensorsConnectTrainer,
        onPressed: _leaveSensorsOnlyMode,
      ),
    );
  }

  Future<void> _leaveSensorsOnlyMode() async {
    await core.settings.setSensorsOnlyMode(false);
    if (!mounted) return;
    _update();
    await openTrainerConnectSheet(context);
  }

  Future<void> _openSensors() async {
    await context.push(const SensorsPage());
    _update();
  }

  /// The live readings, one chip per quantity the rider has a source for.
  /// Only what is actually selected: a "--" chip for a quantity nobody feeds
  /// would be the empty grid the design kit keeps off the home page.
  Widget _sensorsBody() {
    final selected = core.connection.broadcast?.selectedQuantities ?? const <SensorQuantity>{};
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (selected.contains(SensorQuantity.heartRate))
          _MetricChip(
            quantity: SensorQuantity.heartRate,
            icon: LucideIcons.heart,
            color: const Color(0xFFEF4444),
            unit: 'bpm',
          ),
        if (selected.contains(SensorQuantity.cadence))
          _MetricChip(
            quantity: SensorQuantity.cadence,
            icon: LucideIcons.rotateCw,
            color: const Color(0xFF8B5CF6),
            unit: 'rpm',
          ),
        if (selected.contains(SensorQuantity.power))
          _MetricChip(quantity: SensorQuantity.power, icon: LucideIcons.zap, color: const Color(0xFFF59E0B), unit: 'W'),
      ],
    );
  }

  /// The trainer's own page — or the connect sheet, while there is nothing
  /// bridged for a page to be about.
  Future<void> _openTrainer(ProxyDevice? proxy, {required bool bridged}) async {
    if (bridged && proxy != null) {
      await context.push(ProxyDeviceDetailsPage(device: proxy));
    } else {
      await openTrainerConnectSheet(context);
    }
    _update();
  }

  /// What the trainer card shows about itself, in the order the rider earns it.
  ///
  /// Once virtual shifting is running, the live drivetrain: the rider can watch
  /// a shift land without opening the trainer. Before that, a trainer that has
  /// never been connected gets the bridging pitch instead — that rider has
  /// never seen what bridging one does, so the card makes the case rather than
  /// sitting empty. In between, nothing.
  ///
  /// A rider's connected, selected external sensors used to be echoed here
  /// too (a compact read-only grid). `LiveMetricsSection` — mounted on a
  /// trainer's own `ProxyDeviceDetailsPage`, not here — supersedes it: that
  /// grid also owns picking a source, which this card never did, so echoing
  /// a second, read-only copy of the same data on Home would just be noise.
  Widget? _trainerBody(ProxyDevice? proxy) {
    final definition = proxy?.fitnessBike;
    // Paired and shifting, but the trainer app is not on the bridge yet — the
    // gears are real, they are just not carrying anything. The buttons come
    // with it: a rider on the home screen can shift without opening the page.
    return proxy != null && definition != null
        ? DrivetrainControls(definition: definition, compact: true, dim: !proxy.isConnected)
        : _trainerFeatureList(proxy);
  }

  /// The bridging pitch, but only for a trainer that is here and has never
  /// been connected. Null once it has been — including a trainer that broke
  /// mid-session, where a feature list would read as if nothing were wrong.
  Widget? _trainerFeatureList(ProxyDevice? proxy) {
    if (proxy == null || proxy.isConnected || proxy.isBridged) return null;
    if (core.connection.wasConnectedThisSession(proxy.uniqueId)) return null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: proxy.buildFeatureList(context),
    );
  }

  Widget _appCard(ChainLink link, ChainInputs inputs) {
    final app = core.settings.getTrainerApp();
    final logo = app?.logoAsset;

    final String statusLabel;
    if (link.status == LinkStatus.ready) {
      statusLabel = context.i18n.chainStatusReceivingCommands;
    } else if (link.status == LinkStatus.problem) {
      statusLabel = context.i18n.notConnected;
    } else if (app != null) {
      // Name what is actually outstanding. Reporting "waiting for the app"
      // while a permission is missing points the rider at the wrong device.
      statusLabel = appStatusFollowsActiveStep(link)
          ? chainStepText(context, link.activeStep!, appName: app.name).label
          : context.i18n.chainStatusWaitingForApp(app.name);
    } else {
      statusLabel = context.i18n.chainStatusNotSetUp;
    }

    return ChainCard(
      link: link,
      appName: inputs.app.name,
      tile: logo != null
          ? ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.asset(logo, width: 30, height: 30))
          : Icon(LucideIcons.monitor, size: 22, color: Theme.of(context).colorScheme.mutedForeground),
      title: link.title.isEmpty ? context.i18n.chainAppTitle : link.title,
      statusLabel: statusLabel,
      onEdit: () async {
        await context.push(const TrainerConnectionSettingsPage());
        _update();
      },
      onInstructions: () => _openInstructions(link),
      // Both of this card's buttons act rather than explain, so both say what
      // they do: opening Trainer Connections is an action, and so is switching
      // Local on.
      instructionsLabel: link.activeStep?.id == SetupStepId.appLocalControl
          ? context.i18n.chainStepLocalControlAction
          : link.activeStep?.id == SetupStepId.appNetworkAddress
          ? context.i18n.chainStepNetworkAddressAction
          : appLinkOpensConnectionSettings(link)
          ? context.i18n.chainSetUp
          : appCardOffersTroubleshooting(link)
          ? context.i18n.networkTroubleshootTroubleshoot
          : null,
    );
  }

  /// Accessories BikeControl has picked up — a Headwind fan, a KICKR Climb.
  ///
  /// They are not links in the chain (nothing about a fan decides whether the
  /// rider can shift), so they sit under it, quieter. They are on the screen at
  /// all because every accessory the scanner finds is connected automatically,
  /// including one that isn't the rider's — a Headwind through a neighbour's
  /// wall — and the only way onto the ignore list runs through a device's own
  /// settings page. Without this section such a device has no route to it.
  List<Widget> _accessorySection() {
    final accessories = <BluetoothDevice>[
      ...core.connection.accessories,
      ...core.connection.climbAccessories,
    ];
    if (accessories.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
        child: Text(context.i18n.accessories).xSmall.muted,
      ),
      for (final device in accessories) ...[
        AccessoryCard(
          title: device.displayName(context),
          icon: device.icon,
          connected: device.isConnected,
          onOpen: () async {
            await context.push(ControllerSettingsPage(device: device));
            _update();
          },
        ),
        const Gap(10),
      ],
    ];
  }

  // ── Actions ───────────────────────────────────────────────────────────

  /// Instruction sheets are routed on the card and its state, never on the
  /// wording of the active step — so a never-paired controller gets the pairing
  /// flow while a paired-then-dropped one gets the reconnect checklist.
  Future<void> _openInstructions(ChainLink link) async {
    switch (link.key) {
      case ChainLinkKey.controller:
        // A locked Click V2 has one specific answer, and it is not the generic
        // "can't find your controller" help: send the rider straight into the
        // unlock flow for this exact device.
        final active = link.activeStep?.id;
        final device = _controllerById(link.deviceId);
        if (active == SetupStepId.controllerUnlocked && device is ZwiftClickV2) {
          await openDrawer(
            context: context,
            position: OverlayPosition.bottom,
            builder: (_) => UnlockPage(device: device),
          );
        } else if (active == SetupStepId.controllerClickV2Setup) {
          // The explainer itself — the choice is what releases the controller
          // into the connect queue, so there is nothing else to offer here.
          await context.push(const ClickV2OnboardingPage());
        } else if (active == SetupStepId.controllerSramSetup && device is SramAxs) {
          // The same guided sheet the device card and the onboarding wizard
          // run — the derailleur cannot send anything until it has.
          await device.showGuidedSetup(context);
        } else if (active == SetupStepId.controllerSramRestore && device is SramAxs) {
          // The optional "restore original shifting" offer runs the same guided
          // restore sheet the device page does.
          await device.showGuidedRestore(context);
        } else if (link.status == LinkStatus.off) {
          await openControllerSetupSheet(context);
        } else {
          await openControllerHelpSheet(context);
        }
      case ChainLinkKey.trainer:
        // Three different problems, three different answers — routed on the
        // card's state, never on the wording of the active step.
        final activeStep = link.activeStep?.id;
        if (activeStep == SetupStepId.trainerGearOverlay) {
          await _enableOverlay();
        } else if (activeStep == SetupStepId.trainerAppBridged) {
          // The bridge is up and the app hasn't picked it up: show how to pair
          // BikeControl as the trainer, not how to connect a trainer.
          await openPairAsTrainerSheet(context, trainerName: _bridgedTrainerName);
        } else if (link.status == LinkStatus.ready) {
          await openTrainerHelpSheet(context);
        } else {
          await openTrainerConnectSheet(context);
        }
      case ChainLinkKey.app:
        if (link.activeStep?.id == SetupStepId.appLocalNetwork) {
          // Runs the permission sheet and, on a grant, brings the enabled
          // network methods up — the bridge has to actually start, not just
          // stop complaining.
          await ensureLocalNetworkAccess(context);
          await _refreshLocalNetwork();
        } else if (link.activeStep?.id == SetupStepId.appNetworkAddress) {
          // The card has already said what looks wrong; the self-test is
          // where the rider sees every interface, the verdict, and the fixes.
          await context.push(const NetworkTroubleshootingPage());
        } else if (link.activeStep?.id == SetupStepId.appLocalControl) {
          // enableLocalControl runs the permission sheet itself when the
          // accessibility service or the keyboard grant is still missing, and
          // only reports success once the grant actually landed.
          await enableLocalControl(context);
        } else if (appLinkOpensConnectionSettings(link)) {
          // "Activate a connection method" is something the rider does HERE, in
          // Trainer Connections. The app guide answers the step after it — what
          // to do inside the trainer app — and handing that over instead leaves
          // the rider reading pairing instructions for a bridge that isn't
          // running yet.
          await context.push(const TrainerConnectionSettingsPage());
        } else if (appCardOffersTroubleshooting(link)) {
          // The app is up and just hasn't been told about this device yet —
          // that's the network troubleshooter's exact job, not the generic
          // "how do I pair this app" guide.
          await context.push(const NetworkTroubleshootingPage());
        } else {
          await openAppGuideSheet(context);
        }
      case ChainLinkKey.sensors:
        // No checklist to explain: everything about the sensors lives on
        // their page, so any "show me" lands there.
        await context.push(const SensorsPage());
    }
    _update();
  }

  /// Turns the gear overlay on, then opens the Overlay section.
  ///
  /// The button says "Enable overlay", so it enables the overlay — a button
  /// that only navigates somewhere with another switch on it is the toast
  /// problem again, one tap further along. The page still opens afterwards:
  /// the rider has just turned on something they have never seen, and that is
  /// where the fields, the Picture-in-Picture choice and — when the platform
  /// refused — Android's draw-over permission live.
  Future<void> _enableOverlay() async {
    final proxy = chainProxy();
    if (proxy == null) return;

    final result = await enableTrainerOverlay(proxy);
    if (!mounted) return;
    if (!result.ok) {
      // Say why here rather than leaving the rider to work it out from a
      // switch that sprang back to off.
      buildToast(
        level: LogLevel.LOGLEVEL_WARNING,
        title: result.message ?? context.i18n.overlayLowPowerMode,
      );
    }
    await context.push(ProxyDeviceDetailsPage(device: proxy, revealOverlaySection: true));
  }

  /// "Not now" on the overlay step: the rider has answered, so the step leaves
  /// the card and stays away. There is no undo here on purpose — the trainer
  /// page's Overlay switch is the way back, and turning the overlay on there
  /// (or anywhere) clears the decline again; see `Settings.setOverlayEnabled`.
  /// The decline also records the answer, so the step is never required again.
  Future<void> _declineOverlay() async {
    await core.settings.setOverlayDeclined(true);
    _update();
  }

  Future<void> _forget(ChainLink link) async {
    final deviceId = link.deviceId;
    if (deviceId == null) return;

    // Capture the entry and its copy before anything awaits, so Undo puts back
    // exactly what was removed rather than a reconstruction of it.
    final entry = core.rememberedDevices.load().firstOrNullWhere((d) => d.deviceId == deviceId);
    final toastTitle = context.i18n.chainForgotten(
      link.title.isNotEmpty ? link.title : chainLinkName(context, link.key),
    );
    final undoLabel = context.i18n.chainUndo;

    final index = await core.connection.forgetRemembered(deviceId);
    if (mounted) setState(() {});

    if (entry == null) return;
    buildToast(
      level: LogLevel.LOGLEVEL_INFO,
      title: toastTitle,
      closeTitle: undoLabel,
      onClose: () => _restore(entry, index),
    );
  }

  Future<void> _restore(RememberedDevice device, int? index) async {
    await core.connection.restoreRemembered(device, atIndex: index);
    if (mounted) setState(() {});
  }
}

/// One live reading on the Sensors card: icon, the number in bold, its unit
/// muted — the same icon and colour the signals grid uses for that quantity,
/// so a rider recognises the tile this chip is a summary of.
class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.quantity, required this.icon, required this.color, required this.unit});

  final SensorQuantity quantity;
  final IconData icon;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<int?>(
      valueListenable: core.sensors.resolved(quantity),
      builder: (context, value, _) => Container(
        key: Key('sensors-chip-${quantity.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const Gap(6),
            Text(
              value?.toString() ?? '--',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const Gap(4),
            Text(unit, style: TextStyle(fontSize: 11.5, color: theme.colorScheme.mutedForeground)),
          ],
        ),
      ),
    );
  }
}
