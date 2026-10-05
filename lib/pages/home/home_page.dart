import 'dart:async';

import 'package:bike_control/pages/settings/overlay_settings_page.dart' show overlaySettingsDestination;
import 'package:bike_control/utils/trainer_connect.dart';
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_sensor_device.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_unlock.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/models/remembered_device.dart';
import 'package:bike_control/pages/controller_settings.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/utils/click_v2_onboarding.dart';
import 'package:bike_control/pages/unlock.dart';
import 'package:bike_control/widgets/ui/bk_motion.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart';
import 'package:bike_control/pages/home/chain_builder.dart';
import 'package:bike_control/pages/home/chain_inputs.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/pages/home/home_sheets.dart';
import 'package:bike_control/pages/home/pro_unregistered_banner.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/settings/virtual_shifting_settings_page.dart';
import 'package:bike_control/pages/sensors/sensors_page.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/services/local_network_access.dart';
import 'package:bike_control/services/network_self_test/probes/passive_probes.dart' show advertisedAddressWarning;
import 'package:bike_control/utils/requirements/local_network.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_controls.dart';
import 'package:bike_control/widgets/home/ampel.dart';
import 'package:bike_control/widgets/home/chain_card.dart';
import 'package:bike_control/widgets/home/chain_highlight.dart';
import 'package:bike_control/widgets/home/chain_labels.dart';
import 'package:bike_control/widgets/home/ready_banner.dart';
import 'package:bike_control/widgets/home/ride_overlay_notice.dart';
import 'package:bike_control/widgets/home/trial_card.dart';
import 'package:bike_control/widgets/home/virtual_shifting_card.dart';
import 'package:bike_control/widgets/home/your_buttons.dart';
import 'package:bike_control/widgets/rides/ride_recording_line.dart';
import 'package:bike_control/widgets/rides/ride_summary_card.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkStatusColors;
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/zwift_ride_firmware_notice.dart';
import 'package:bike_control/widgets/zwift_ride_v2_unlock.dart';
import 'package:bike_control/widgets/ui/connection_method.dart'
    show connectionMethodSummary, enableLocalControl, ensureLocalNetworkAccess;
import 'package:bike_control/widgets/devices/chain_link_row.dart';
import 'package:bike_control/widgets/devices/trainer_metrics_strip.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/colors.dart' show bkAccentText;
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
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

/// The trainer the chain speaks for — on Ride, on Devices and in Settings:
/// the liveliest of the discovered proxies. See [proxyChainRank].
ProxyDevice? chainProxy() => core.connection.proxyDevices.sortedBy(proxyChainRank).firstOrNull;

/// The app card's active step is "waiting for the app to connect" and the
/// Network method is the enabled path — the moment troubleshooting helps.
///
/// Only for an app that has not connected in this session (see
/// [ChainLink.wasConnectedThisSession]). Once the connection has worked, a
/// drop is almost never something the self-test can find — the app was
/// usually just closed — so the card and the banner open its pairing guide
/// instead. An address warning that is new since then still leads to the
/// self-test, through its own step.
bool appCardOffersTroubleshooting(ChainLink link) =>
    link.key == ChainLinkKey.app &&
    !link.wasConnectedThisSession &&
    link.activeStep?.id == SetupStepId.appConnected &&
    core.logic.isObpMdnsEnabled &&
    core.obpMdnsEmulator.isStarted.value;

/// Which part of the setup chain a [HomePage] shows.
enum HomeView {
  /// The Ride section: the ready banner, the virtual shifting card and the
  /// rider's buttons.
  ride,

  /// The chain's cards, one per link — on Devices.
  setup,
}

/// Carries Ride's "Show" over to the setup cards on Devices: Ride asks for
/// the outstanding cards, the setup view scrolls to them and makes them jump
/// out.
class ChainRevealController extends ChangeNotifier {
  List<String> _pending = const [];

  void request(List<String> linkIds) {
    _pending = linkIds;
    notifyListeners();
  }

  /// The pending request, once.
  List<String> take() {
    final ids = _pending;
    _pending = const [];
    return ids;
  }
}

/// The setup chain, read off the live devices and settings.
///
/// One link per card, in signal-path order — your controllers, then the gears
/// BikeControl computes from them, then the app that receives them.
///
/// [HomeView.ride] answers "am I ready?" with one banner and shows what the
/// rider rides with: the live gear and their buttons. [HomeView.setup] is the
/// chain itself, each card stating its own status and remaining steps, so a
/// rider whose ride just broke can see *which* link failed.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.isMobile,
    required this.onUpdate,
    this.showHelpRow = true,
    this.onHelp,
    this.view = HomeView.ride,
    this.reveal,
    this.onShowSetup,
    this.activityPreview,
  });

  final bool isMobile;

  /// Lets the host clear its error banner when the rider acts on a card.
  final VoidCallback onUpdate;

  /// Hidden from 840 wide, where the sidebar carries Help & Support.
  final bool showHelpRow;
  final VoidCallback? onHelp;

  final HomeView view;

  /// Shared between Ride and the setup view — see [ChainRevealController].
  final ChainRevealController? reveal;

  /// Ride: brings the setup cards on screen (the shell switches to Devices).
  final VoidCallback? onShowSetup;

  /// Ride's right column, under the buttons, in two-column windows.
  final Widget? activityPreview;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final StreamSubscription<BaseDevice> _connectionListener;
  late final StreamSubscription<BaseNotification> _actionListener;

  /// Assumed available until proven otherwise, so the step doesn't flash as
  /// pending on every cold start before the platform has answered.
  bool _bluetoothReady = true;

  /// The last press per controller (by device id), and how many there have
  /// been — a notifier each, so a press rebuilds only that controller's
  /// buttons instead of the whole chain.
  final Map<String, ValueNotifier<ControllerPress>> _presses = {};

  ValueNotifier<ControllerPress> _pressesFor(String deviceId) =>
      _presses.putIfAbsent(deviceId, () => ValueNotifier((button: null, generation: 0)));

  bool get _isRide => widget.view == HomeView.ride;

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
      // The session keeps the reading an app connected through, whether or
      // not this page is still around to show it.
      core.appConnectionLatch.noteAddressWarning(warning);
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
        final presses = _pressesFor(notification.device.uniqueId);
        presses.value = (button: notification.buttonsClicked.first, generation: presses.value.generation + 1);
      }
    });

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

    // Right after launch the remembered devices stand in as placeholders
    // until they are back or the window runs out — see
    // [Connection.startupReconnecting].
    core.connection.startupReconnecting.addListener(_onStartupReconnectChanged);

    _maybeShowRideFirmwareDialog();
    if (!_isRide) widget.reveal?.addListener(_onRevealRequested);
  }

  void _onStartupReconnectChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reveal != widget.reveal || oldWidget.view != widget.view) {
      oldWidget.reveal?.removeListener(_onRevealRequested);
      if (!_isRide) widget.reveal?.addListener(_onRevealRequested);
    }
  }

  void _onRevealRequested() {
    final ids = widget.reveal?.take() ?? const [];
    if (ids.isNotEmpty) unawaited(_revealOutstanding(ids));
  }

  List<Listenable> _broadcastListenables = const [];

  void _onBroadcastChanged() {
    if (mounted) setState(() {});
  }

  void _onKeepAwakeChanged() {
    if (mounted) setState(() {});
  }

  /// Once per install, when a Zwift Ride first shows up on server-locked
  /// firmware (>1.2.0) without being a Zwift Ride V2, surface a one-time dialog
  /// pointing the rider at support. The persistent card notice in controller
  /// settings is the standing fallback. A Zwift Ride V2 gets its own one-time
  /// explainer instead — see [maybeShowZwiftRideV2Explainer].
  bool _rideFirmwareDialogHandled = false;
  bool _rideV2ExplainerPending = false;

  void _maybeShowRideFirmwareDialog() {
    // One of the two views asks, or a rider with both on screen gets it twice.
    if (!_isRide) return;
    _maybeShowRideV2Explainer();
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

  void _maybeShowRideV2Explainer() {
    if (screenshotMode || _rideV2ExplainerPending || core.settings.getRideV2ExplainerShown()) return;
    final hasRideV2 = core.connection.controllerDevices.any((d) => d.isConnected && d is ZwiftUnlock && d.isRideV2);
    if (!hasRideV2) return;
    _rideV2ExplainerPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted) await maybeShowZwiftRideV2Explainer(context, core.connection.controllerDevices);
      } catch (e, s) {
        recordError(e, s, context: 'HomePage.rideV2Explainer');
      } finally {
        _rideV2ExplainerPending = false;
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
    widget.reveal?.removeListener(_onRevealRequested);
    core.connection.startupReconnecting.removeListener(_onStartupReconnectChanged);
    _connectionListener.cancel();
    _actionListener.cancel();
    for (final presses in _presses.values) {
      presses.dispose();
    }
    IAPManager.instance.isPurchased.removeListener(_onPurchaseChanged);
    ClickLogic.keepAwakeStatus.removeListener(_onKeepAwakeChanged);
    for (final listenable in _broadcastListenables) {
      listenable.removeListener(_onBroadcastChanged);
    }
    for (final listenable in _advertisedAddressListenables) {
      listenable.removeListener(_onAdvertisedAddressChanged);
    }
    WidgetsBinding.instance.removeObserver(this);
    _highlights.dispose();
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
  /// Only controllers Zwift locks to its own app need it — the Zwift Click V2
  /// in the modes that actually use Zwift to unlock (the legacy unified
  /// controller, which has no other way, and the left puck when the rider chose
  /// unlock-with-Zwift) and the Zwift Ride V2. The left puck on the restart
  /// workaround never unlocks — it reboots itself instead — so a step telling
  /// the rider to open Zwift would be wrong there, and the right puck was never
  /// locked at all. See [ZwiftUnlock.requiresZwiftUnlock].
  bool? _unlockState(BaseDevice device) {
    if (device is! ZwiftUnlock || !device.requiresZwiftUnlock) return null;
    return device.isPersistedUnlocked;
  }

  /// When this controller's unlock runs out, or null if it isn't unlocked.
  /// Formatted here, next to the other display concerns — the chain model
  /// itself stays free of locales and date formats.
  String? _unlockedUntil(BaseDevice device) {
    if (device is! ZwiftUnlock || !device.requiresZwiftUnlock) return null;
    final until = device.unlockedUntil;
    return until == null ? null : DateFormat('EEEE, HH:mm').format(until);
  }

  bool _unlockUncertain(BaseDevice device) =>
      device is ZwiftUnlock && device.requiresZwiftUnlock && device.isLikelyUnlocked;

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
      } else if (proxy.isStarting.value || proxy.isConnected) {
        // The connect is still running. The Bluetooth link comes up before the
        // bridge does, and `wasConnectedThisSession` latches the moment it
        // does — so without this branch the whole window between "link up" and
        // "emulator started" read as a drop, and the banner flashed red at a
        // trainer that was connecting perfectly well.
        presence = DevicePresence.connecting;
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
            unlockUncertain: _unlockUncertain(device),
            unlockIsRideV2: device is ZwiftUnlock && device.isRideV2,
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
        // Kept for the session, not the page — see [AppConnectionLatch].
        wasConnectedThisSession: core.appConnectionLatch.wasConnected(trainerApp?.name),
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
        advertisedAddressWarningAtConnect: core.appConnectionLatch.addressWarningAtConnect,
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
    return trainerOverlayOffered(proxy);
  }

  /// Makes chain cards jump out — see [ChainCard.highlight].
  final ChainHighlightController _highlights = ChainHighlightController();

  /// One key per card, by [ChainLink.id], so the banner can bring a card into
  /// view. By id rather than by [ChainLinkKey]: several controllers share a
  /// kind, and a global key can only sit on one of them.
  final Map<String, GlobalKey> _cardKeys = {};

  /// The outstanding cards as last built — the chain as it is on screen.
  List<String> _outstandingLinkIds = const [];

  /// The bridged trainer's own name, which the pairing instructions use to
  /// spell out the entry to look for ("KICKR CORE - BikeControl").
  String? get _bridgedTrainerName => core.connection.proxyDevices.firstOrNullWhere((p) => p.isBridged)?.name;

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // The session watches every method on its own (see
    // [Connection.initialize]); looking once more here keeps the card right
    // wherever nothing else has looked yet.
    core.appConnectionLatch.sync();
    final inputs = _readInputs();

    final links = buildChain(inputs);
    final banner = deriveBanner(links);
    _outstandingLinkIds = banner.outstandingLinkIds;
    return _isRide ? _buildRide(inputs, links, banner) : _buildSetup(inputs, links);
  }

  /// The chain as the Devices groups: Controllers, then the smart trainer (or,
  /// in sensors-only mode, the sensors in its slot), then the trainer app —
  /// one row per link, each with its status and whatever it still needs.
  Widget _buildSetup(ChainInputs inputs, List<ChainLink> links) {
    final l = context.i18n;
    final devicesById = {for (final d in _knownControllers) d.uniqueId: d};
    final keyedIds = <String>{};
    Widget keyed(ChainLink link, Widget child) {
      // A global key may sit on one row only. Ids are unique by design, but a
      // duplicate must cost the banner its scroll target, not the page.
      final firstWithId = keyedIds.add(link.id);
      return KeyedSubtree(key: firstWithId ? _cardKeys.putIfAbsent(link.id, GlobalKey.new) : null, child: child);
    }

    final controllers = links.where((link) => link.key == ChainLinkKey.controller).toList();
    final slot = links.firstWhere((link) => link.key == ChainLinkKey.trainer || link.key == ChainLinkKey.sensors);
    final app = links.firstWhere((link) => link.key == ChainLinkKey.app);
    // Nothing paired yet: the placeholder row is itself the invitation.
    final nothingPaired = controllers.every((link) => link.deviceId == null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        BkGroupedSection(
          key: const ValueKey('devices-controllers'),
          header: l.controllers,
          dividerIndent: chainRowTextInset,
          children: [
            for (final link in controllers) keyed(link, _row(link, devicesById[link.deviceId], inputs)),
            if (!nothingPaired) _connectControllersRow(),
          ],
        ),
        BkGroupedSection(
          key: ValueKey('devices-${slot.key.name}'),
          header: slot.key == ChainLinkKey.sensors ? l.sensorsChainEyebrow : l.chainTrainerTitle,
          children: [keyed(slot, _row(slot, null, inputs))],
        ),
        BkGroupedSection(
          key: const ValueKey('devices-app'),
          header: l.chainAppTitle,
          children: [keyed(app, _row(app, null, inputs))],
        ),
      ],
    );
  }

  /// Whether Ride splits in two: status and shifting on the left, the buttons
  /// on the right. From 840 (the sidebar's breakpoint) at every width, while
  /// the content has room for two.
  static bool _rideTwoColumns({required double window, required double content}) =>
      window >= Breakpoints.medium && content >= 520;

  Widget _buildRide(ChainInputs inputs, List<ChainLink> links, ChainBanner banner) {
    final trial = _trialState();
    final vsBudget = vsBudgetCardState(
      isPurchased: IAPManager.instance.isPurchased.value,
      isProForDevice: IAPManager.instance.isProEnabledForCurrentDevice,
      trainerBridged: core.connection.proxyDevices.any((p) => p.isBridged),
      remainingToday: core.bridgeUsageTracker.remainingToday,
      dailyLimit: core.bridgeUsageTracker.dailyLimit,
    );

    // Right after launch the remembered devices are on their way back and
    // their cards say "Connecting…". "Switch it on" in the banner would
    // contradict that — and vanish a second later, shifting the screen — so
    // their steps wait until the window has run out.
    final reconnecting = core.connection.startupReconnecting.value;
    final reconnectingLinks = banner.kind == ChainBannerKind.pending
        ? links.where((l) => l.deviceId != null && reconnecting.contains(l.deviceId) && l.isBlocking).toList()
        : const <ChainLink>[];
    final reconnectingIds = {for (final l in reconnectingLinks) l.id};
    final shownBanner = reconnectingLinks.isEmpty
        ? banner
        : ChainBanner(
            kind: banner.kind,
            status: banner.status,
            stepsLeft: banner.stepsLeft - reconnectingLinks.fold<int>(0, (sum, l) => sum + l.remainingSteps),
            targetLinkId: reconnectingIds.contains(banner.targetLinkId)
                ? banner.outstandingLinkIds.firstOrNullWhere((id) => !reconnectingIds.contains(id))
                : banner.targetLinkId,
            targetKey: banner.targetKey,
            outstandingKeys: banner.outstandingKeys,
            outstandingLinkIds: banner.outstandingLinkIds.where((id) => !reconnectingIds.contains(id)).toList(),
            soleStep: banner.soleStep,
            appDropped: banner.appDropped,
          );
    final steps = _bannerSteps(links, shownBanner, inputs);

    final status = <Widget>[
      ReadyBanner(
        banner: shownBanner,
        appName: inputs.app.name,
        brokenLinkName: _linkName(links, shownBanner.targetLinkId),
        onAction: shownBanner.hasAction
            ? () => _openInstructions(links.firstWhere((l) => l.id == shownBanner.targetLinkId))
            : null,
        onRevealOutstanding: () => _showOutstanding(links, shownBanner.outstandingLinkIds),
        steps: steps,
        // Nothing left but the devices on their way back: say so, calmly.
        connectingNames: shownBanner.outstandingLinkIds.isEmpty && reconnectingLinks.isNotEmpty
            ? [for (final l in reconnectingLinks) _linkName(links, l.id) ?? chainLinkName(context, l.key)]
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
      // Store renders stage a finished setup, not a daily limit.
      if (vsBudget != null && !screenshotMode) ...[
        // Live while riding: the budget ticks down during a session.
        ValueListenableBuilder<Duration>(
          valueListenable: core.bridgeUsageTracker.usedTodayListenable,
          builder: (context, _, _) => VsBudgetCard(
            state:
                vsBudgetCardState(
                  isPurchased: true,
                  isProForDevice: false,
                  trainerBridged: true,
                  remainingToday: core.bridgeUsageTracker.remainingToday,
                  dailyLimit: core.bridgeUsageTracker.dailyLimit,
                ) ??
                vsBudget,
            // Base is bought, so the paywall shows the Pro plans only.
            onUpgrade: () => IAPManager.instance.purchaseFullVersion(context),
          ),
        ),
        const Gap(10),
      ],
      // Pro on the account, not on this device: carries its own gap.
      const ProUnregisteredBanner(),
    ];

    return Padding(
      // No horizontal inset: the shell's scroll view pads every section, so
      // Ride starts under the page title like the others.
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = _rideTwoColumns(
            window: MediaQuery.sizeOf(context).width,
            content: constraints.maxWidth,
          );
          final vs = _vsSlot(inputs, links, stacked: twoColumns);
          final buttons = _yourButtons(
            wide: !twoColumns && constraints.maxWidth >= Breakpoints.compact,
            // On a desktop the button list is the map at a glance; the right
            // column puts it under the pods (see [ControllerButtonsCard]).
            showButtonList: twoColumns || constraints.maxWidth >= Breakpoints.compact,
          );
          if (twoColumns) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    // The last ride heads the left column (above Ready).
                    children: [
                      const RideSummaryCard(key: ValueKey('ride-summary'), wide: true),
                      ...status,
                      ?vs,
                    ],
                  ),
                ),
                const Gap(20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buttons,
                      // While a ride records: where the record card was.
                      const RideRecordingSlot(key: ValueKey('ride-recording-slot'), textActions: true, spacing: 20),
                      if (widget.activityPreview case final preview?) ...[const Gap(20), preview],
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The last ride heads Ride, above the Ready banner.
              const RideSummaryCard(key: ValueKey('ride-summary')),
              ...status,
              // Recording status right under Virtual shifting, in the first
              // viewport: a rider sees "recording" without scrolling.
              if (vs != null) vs,
              RideRecordingSlot(key: const ValueKey('ride-recording-slot'), spacing: vs != null ? 12 : 0),
              if (vs != null) const Gap(20) else const _GapWhenRecording(),
              buttons,
              if (widget.showHelpRow) ...[const Gap(20), _helpRow()],
              if (widget.isMobile) Gap(MediaQuery.viewPaddingOf(context).bottom + 32),
            ],
          );
        },
      ),
    );
  }

  Widget _helpRow() {
    return BkTouchTarget(
      child: Button.outline(
        alignment: Alignment.center,
        onPressed: widget.onHelp ?? () => openControllerHelpSheet(context),
        child: Row(
          children: [
            Icon(LucideIcons.lifeBuoy, size: 17, color: Theme.of(context).colorScheme.primary),
            const Gap(9),
            Expanded(
              child: Text(
                context.i18n.chainSomethingNotWorking,
                style: context.typography.small.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 15, color: Theme.of(context).colorScheme.mutedForeground),
          ],
        ),
      ),
    );
  }

  /// The banner's list while setup is incomplete: every required step still
  /// outstanding, card by card. The step each card can act on now carries
  /// that card's fix — the Devices row's action under the Devices row's
  /// label; a step that waits on an earlier one has none yet. An app that
  /// went away after working is one cause with one fix: its step alone.
  List<ReadyBannerStep> _bannerSteps(List<ChainLink> links, ChainBanner banner, ChainInputs inputs) {
    if (banner.kind != ChainBannerKind.pending) return const [];
    final ids = banner.appDropped ? [banner.targetLinkId] : banner.outstandingLinkIds;
    final steps = <ReadyBannerStep>[];
    for (final id in ids) {
      final link = links.firstOrNullWhere((l) => l.id == id);
      if (link == null) continue;
      final pending = link.requiredSteps.where((s) => !s.done).toList();
      if (banner.appDropped) pending.removeWhere((s) => s.id != SetupStepId.appConnected);
      final active = link.activeStep;
      // Ride's shifting card carries the overlay offer, with its "Not now";
      // listing it here as well would ask the same question twice.
      if (_rideOffersOverlay()) pending.removeWhere((s) => s.id == SetupStepId.trainerGearOverlay);
      for (final (index, step) in pending.indexed) {
        // The fix acts on the card's active step. Where that is an optional
        // offer ahead of the required ones, the first required step carries it.
        final actionable = identical(step, active) || (index == 0 && (active?.optional ?? false));
        steps.add(
          ReadyBannerStep(
            linkId: link.id,
            linkTitle: link.title.isNotEmpty ? link.title : chainLinkName(context, link.key),
            step: step,
            actionLabel: actionable ? _fixLabel(link, inputs) : null,
            onFix: actionable ? () => _fix(link, inputs) : null,
          ),
        );
      }
    }
    return steps;
  }

  /// Whether Ride's shifting card shows the overlay offer — see
  /// [_overlayNotice].
  bool _rideOffersOverlay() {
    final proxy = chainProxy();
    if (proxy == null || proxy.fitnessBike == null) return false;
    return _overlayNotice(proxy) != null && !core.settings.getOverlayEnabled() && !core.settings.getOverlayDeclined();
  }

  /// What a card's step button does on its Devices row.
  Future<void> _fix(ChainLink link, ChainInputs inputs) async {
    // No trainer ever: the row itself is the invitation to connect one.
    if (link.key == ChainLinkKey.trainer && inputs.trainer == null) {
      await _openTrainer(chainProxy(), bridged: false);
      return;
    }
    await _openInstructions(link);
  }

  /// The label of a card's step button on its Devices row; null reads "Show
  /// me how".
  String? _fixLabel(ChainLink link, ChainInputs inputs) {
    final l = context.i18n;
    final active = link.activeStep?.id;
    switch (link.key) {
      case ChainLinkKey.controller:
        return link.deviceId == null ||
                _controllerById(link.deviceId) == null ||
                active == SetupStepId.controllerClickV2Setup
            ? l.chainSetUp
            : null;
      case ChainLinkKey.trainer:
        if (inputs.trainer == null) return l.chainSetUp;
        return active == SetupStepId.trainerGearOverlay ? l.chainStepOverlayAction : null;
      case ChainLinkKey.sensors:
        return null;
      case ChainLinkKey.app:
        return _appFixLabel(link);
    }
  }

  String? _appFixLabel(ChainLink link) {
    final l = context.i18n;
    return link.activeStep?.id == SetupStepId.appLocalControl
        ? l.chainStepLocalControlAction
        : link.activeStep?.id == SetupStepId.appNetworkAddress
        ? l.chainStepNetworkAddressAction
        : appLinkOpensConnectionSettings(link)
        ? l.chainSetUp
        : appCardOffersTroubleshooting(link)
        ? l.networkTroubleshootTroubleshoot
        : null;
  }

  /// Ride's "Show" with several cards outstanding: the cards are on Devices
  /// now, so Ride hands the request over and the shell switches there. With
  /// nobody to hand it to, the first card's fix opens instead.
  void _showOutstanding(List<ChainLink> links, List<String> linkIds) {
    if (linkIds.isEmpty) return;
    final reveal = widget.reveal;
    if (reveal != null) {
      widget.onShowSetup?.call();
      reveal.request(linkIds);
      return;
    }
    final first = links.firstOrNullWhere((l) => l.id == linkIds.first);
    if (first != null) unawaited(_openInstructions(first));
  }

  // ── Ride: virtual shifting ────────────────────────────────────────────

  /// The virtual shifting slot, by what the trainer is doing:
  ///
  /// - shifting (a definition is attached): the live card;
  /// - connecting: the trainer's name and "Connecting…";
  /// - lost this session: the trainer's name, the loss, and Connect;
  /// - not bridged while the trainer app is working: one line saying the app
  ///   handles shifting;
  /// - otherwise: an invitation to connect a trainer.
  ///
  /// Nothing in sensors-only mode: that rider has said there is no smart
  /// trainer to connect.
  Widget? _vsSlot(ChainInputs inputs, List<ChainLink> links, {required bool stacked}) {
    if (inputs.trainer == null && inputs.sensors != null) return null;
    final proxy = chainProxy();
    final trainer = inputs.trainer;
    final l = context.i18n;
    final layout = stacked ? VsCardLayout.stacked : VsCardLayout.beside;
    final Widget slot;
    if (proxy != null && proxy.fitnessBike != null) {
      slot = _LiveTrainerBody(
        key: const ValueKey('ride-vs-live'),
        proxy: proxy,
        builder: (definition, connected) => VirtualShiftingCard(
          definition: definition,
          trainerName: proxy.toString(),
          dim: !connected,
          layout: layout,
          onOpenSettings: () => _openVsSettings(proxy),
          onOpenTrainer: () => _openTrainerPage(proxy),
          footer: _vsFooter(proxy),
        ),
      );
    } else if (trainer != null &&
        (trainer.presence == DevicePresence.connecting ||
            (trainer.presence == DevicePresence.remembered &&
                core.connection.startupReconnecting.value.contains(trainer.deviceId)))) {
      // On its way — connecting now, or remembered and expected back right
      // after launch: the live card's footprint, so it swaps in in place.
      slot = VirtualShiftingCard.connecting(
        key: const ValueKey('ride-vs-placeholder'),
        trainerName: trainer.name,
        layout: layout,
      );
    } else if (trainer != null && trainer.presence == DevicePresence.lost) {
      slot = RidePromptCard(
        key: const ValueKey('ride-vs-lost'),
        icon: LucideIcons.bike,
        title: trainer.name,
        body: l.chainStatusLostConnection,
        bodyColor: BkStatusColors.of(context).danger,
        actionLabel: l.connect,
        onAction: () => _openTrainer(proxy, bridged: false),
      );
    } else if (inputs.app.isConnected && inputs.app.name != null && !inputs.app.selfHosted) {
      slot = RideStatusLine(
        key: const ValueKey('ride-vs-handled'),
        icon: LucideIcons.bike,
        text: l.chainStatusHandledByApp(inputs.app.name!),
        actionLabel: l.connect,
        onAction: () => _openTrainer(proxy, bridged: false),
      );
    } else {
      slot = RidePromptCard(
        key: const ValueKey('ride-vs-invite'),
        icon: LucideIcons.bike,
        title: l.rideVirtualShifting,
        body: l.rideVsInviteBody,
        actionLabel: l.connect,
        onAction: () => _openTrainer(proxy, bridged: false),
      );
    }
    // Each state crossfades into the next while the height eases; the live
    // card also grows in from a touch smaller, so the trainer arriving reads
    // as an arrival.
    return KeyedSubtree(
      key: const ValueKey('ride-vs-slot'),
      child: BkAnimatedSwap(scaleIn: slot.key == const ValueKey('ride-vs-live'), child: slot),
    );
  }

  /// Settings → Virtual shifting, for the trainer on Ride's card.
  Future<void> _openVsSettings(ProxyDevice proxy) async {
    final definition = proxy.fitnessBike;
    if (definition == null) return;
    await context.push(VirtualShiftingSettingsPage(definition: definition, device: proxy));
    _update();
  }

  /// The trainer's hardware page — Ride's card only exists while the trainer
  /// is in a session, so there is always something for the page to be about.
  Future<void> _openTrainerPage(ProxyDevice proxy) async {
    await context.push(ProxyDeviceDetailsPage(device: proxy));
    _update();
  }

  /// The foot of Ride's shifting card: one line summing up how the trainer
  /// shifts, opening Settings → Virtual shifting, then the overlay's offer or
  /// line where there is one.
  Widget _vsFooter(ProxyDevice proxy) {
    final definition = proxy.fitnessBike!;
    final overlay = _overlayNotice(proxy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([definition.gearRatios, definition.virtualShiftingMode]),
          builder: (context, _) => RideSettingsLine(
            key: const ValueKey('ride-vs-settings-line'),
            icon: LucideIcons.slidersHorizontal,
            text: rideVirtualShiftingSummary(context, definition),
            linkLabel: context.i18n.rideVsSettingsLink,
            onPressed: () => _openVsSettings(proxy),
          ),
        ),
        ?overlay,
      ],
    );
  }

  /// The gear-overlay offer at the foot of Ride's card, for trainer apps that
  /// keep showing their own gear — where the rider sees two numbers disagree.
  /// Only where the overlay can be offered at all (see [_overlayOffered]).
  Widget? _overlayNotice(ProxyDevice proxy) {
    final app = core.settings.getTrainerApp();
    if (app == null || !app.showsOwnGear || !_overlayOffered(proxy)) return null;
    final state = core.settings.getOverlayEnabled()
        ? RideOverlayState.on
        : core.settings.getOverlayDeclined()
        ? RideOverlayState.declined
        : RideOverlayState.offer;
    return RideOverlayNotice(
      state: state,
      appName: app.name,
      onEnable: () => _enableOverlayFromRide(proxy),
      onDecline: _declineOverlay,
      onOpen: () async {
        await context.push(overlaySettingsDestination(proxy));
        _update();
      },
    );
  }

  /// "Show the gear overlay" on Ride: turns it on in place, and the notice
  /// becomes its one-line status. Only a refusal (Android's draw-over grant,
  /// say) opens the Overlay page, where that is sorted out.
  Future<void> _enableOverlayFromRide(ProxyDevice proxy) async {
    final result = await enableTrainerOverlay(proxy);
    if (!mounted) return;
    if (!result.ok) {
      buildToast(level: LogLevel.LOGLEVEL_WARNING, title: result.riderMessage(context.i18n));
      await context.push(overlaySettingsDestination(proxy));
    }
    _update();
  }

  // ── Ride: your buttons ────────────────────────────────────────────────

  /// [wide] lets a controller list its buttons beside its picture;
  /// [showButtonList] lists them at all — beside the picture where the column
  /// has room, else under it.
  Widget _yourButtons({required bool wide, required bool showButtonList}) {
    final l = context.i18n;
    // Right after launch the remembered controllers stand in until they are
    // back (see [Connection.startupReconnecting]) — on the cards they will
    // have, so the one that connects swaps in where it already stands.
    final reconnecting = core.connection.startupReconnecting.value;
    final shown = _knownControllers
        .where((d) => d.isConnected || reconnecting.contains(d.uniqueId))
        .distinctBy((d) => d.uniqueId)
        .toList();
    final keymap = core.actionHandler.supportedApp?.keymap;
    final single = shown.length == 1 ? shown.single : null;
    return Column(
      key: const ValueKey('ride-your-buttons'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RideSectionHeader(
          title: l.rideYourButtons,
          linkLabel: single != null ? l.rideEditButtons : null,
          onLink: single != null ? () => _openController(single) : null,
        ),
        // A controller arriving grows in, one leaving shrinks out, and the
        // "no controller" prompt gives way to the first one the same way.
        BkAnimatedColumn(
          children: [
            if (shown.isEmpty)
              RidePromptCard(
                key: const ValueKey('ride-no-controller'),
                icon: LucideIcons.gamepad2,
                title: l.rideNoControllerTitle,
                body: l.rideNoControllerBody,
                actionLabel: l.connect,
                onAction: () => _openController(null),
              ),
            for (final (i, device) in shown.indexed)
              Padding(
                key: ValueKey('ride-buttons-slot-${device.uniqueId}'),
                padding: EdgeInsets.only(top: i > 0 ? 10 : 0),
                child: ControllerButtonsCard(
                  key: ValueKey('ride-buttons-${device.uniqueId}'),
                  device: device,
                  keymap: keymap,
                  presses: _pressesFor(device.uniqueId),
                  onUpdate: _update,
                  onEdit: () => _openController(device),
                  showDeviceHeader: single == null,
                  connecting: !device.isConnected,
                  wide: wide,
                  showButtonList: showButtonList,
                ),
              ),
          ],
        ),
      ],
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

  // ── Devices rows ──────────────────────────────────────────────────────

  Widget _row(ChainLink link, BaseDevice? device, ChainInputs inputs) {
    final row = switch (link.key) {
      ChainLinkKey.controller => _controllerRow(link, device, inputs),
      ChainLinkKey.trainer => _trainerRow(link, inputs),
      ChainLinkKey.sensors => _sensorsRow(link, inputs),
      ChainLinkKey.app => _appRow(link, inputs),
    };

    if (!link.dismissible) return row;

    // Only a device that isn't here can be swiped away, so this gesture can
    // never drop a working controller off the screen.
    final danger = AmpelStyle.of(context, LinkStatus.problem);
    return Dismissible(
      key: ValueKey('dismiss-${link.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        color: danger.wash,
        child: Icon(LucideIcons.trash2, size: 20, color: danger.color),
      ),
      onDismissed: (_) => _forget(link),
      child: row,
    );
  }

  /// The icon tile of a device row, faded while the device is not here.
  Widget _tile(IconData icon, {required bool live}) =>
      BkIconTile(icon: icon, color: live ? null : Theme.of(context).colorScheme.mutedForeground);

  /// "Scanning · Wake it with a button press first." while a scan runs.
  Widget _connectControllersRow() {
    return ValueListenableBuilder<bool>(
      valueListenable: core.connection.isScanning,
      builder: (context, scanning, _) {
        final l = context.i18n;
        return DeviceAddRow(
          key: const ValueKey('devices-connect-controllers'),
          title: l.connectControllers,
          subtitle: scanning ? '${l.scanning} · ${l.chainStepControllerPairedHint}' : l.chainStepControllerPairedHint,
          onPressed: () => _openController(null),
        );
      },
    );
  }

  Widget _controllerRow(ChainLink link, BaseDevice? device, ChainInputs inputs) {
    final l = context.i18n;
    if (device == null) {
      // Nothing paired yet: "Connect Controllers", and under it what that
      // takes, with its Set up.
      final accent = bkAccentText(context);
      return ValueListenableBuilder<bool>(
        valueListenable: core.connection.isScanning,
        builder: (context, scanning, _) => ChainLinkRow(
          link: link,
          highlight: _highlights.tickFor(link.id),
          appName: inputs.app.name,
          leading: BkIconTile(icon: LucideIcons.plus, color: accent),
          title: l.connectControllers,
          titleColor: accent,
          subtitle: scanning ? l.scanning : null,
          onTap: () => _openController(null),
          onInstructions: () => _openInstructions(link),
          instructionsLabel: l.chainSetUp,
        ),
      );
    }

    final connected = device.isConnected;
    return ChainLinkRow(
      key: ValueKey('devices-controller-${device.uniqueId}'),
      link: link,
      highlight: _highlights.tickFor(link.id),
      appName: inputs.app.name,
      leading: _tile(device.icon, live: connected),
      title: link.title,
      subtitle: _controllerSubtitle(device),
      statusLabel: _controllerStatusLabel(link, device),
      statusDetail: _batteryReadout(device),
      statusBadges: _controllerBadges(device),
      onTap: () => _openController(device),
      onInstructions: () => _openInstructions(link),
      instructionsLabel: link.activeStep?.id == SetupStepId.controllerClickV2Setup ? l.chainSetUp : null,
    );
  }

  /// "FW 1.2.0 · Signal good" for a connected Bluetooth controller; else what
  /// it is.
  String _controllerSubtitle(BaseDevice device) {
    final l = context.i18n;
    if (device is! BluetoothDevice || !device.isConnected) return l.chainControllerTitle;
    final rssi = device.rssi;
    final parts = [
      if (device.firmwareVersion case final fw? when fw.isNotEmpty) 'FW $fw',
      // -70 dBm is where the device page stops calling the link "Good".
      if (rssi != null) rssi >= -70 ? l.devicesSignalGood : l.devicesSignalWeak,
    ];
    return parts.isEmpty ? l.chainControllerTitle : parts.join(' · ');
  }

  /// The battery under the status, red below 20 % (the device page's
  /// threshold).
  Widget? _batteryReadout(BaseDevice device) {
    if (device is! BluetoothDevice || !device.isConnected) return null;
    final battery = device.batteryLevel;
    if (battery == null) return null;
    final cs = Theme.of(context).colorScheme;
    final low = battery < 20;
    final color = low ? cs.destructive : cs.mutedForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        Icon(
          switch (battery) {
            >= 60 => LucideIcons.batteryFull,
            >= 40 => LucideIcons.batteryMedium,
            >= 20 => LucideIcons.batteryLow,
            _ => LucideIcons.batteryWarning,
          },
          size: 14,
          color: color,
        ),
        Text('$battery%', style: TextStyle(color: color)),
      ],
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
    // Right after launch, on its way back on its own.
    if (device != null && core.connection.startupReconnecting.value.contains(device.uniqueId)) {
      return context.i18n.chainStatusConnecting;
    }
    return switch (link.status) {
      LinkStatus.ready => context.i18n.connected,
      LinkStatus.problem => context.i18n.chainStatusLostConnection,
      LinkStatus.attention => context.i18n.chainStatusOutOfRange,
      LinkStatus.off => context.i18n.chainStatusNotSetUp,
    };
  }

  /// The things that qualify "Connected": a firmware update waiting. Shown
  /// only when it is actually there — a healthy device carries no glyphs, so
  /// one appearing means something, and the detail lives one tap away on the
  /// device page. (Battery and signal have their own words on the row.)
  List<Widget> _controllerBadges(BaseDevice device) {
    if (!device.isConnected || device is! BluetoothDevice) return const [];
    final scheme = Theme.of(context).colorScheme;
    return [
      if (device is ZwiftDevice && device.hasNewerFirmwareVersion)
        Icon(LucideIcons.circleArrowUp, size: 13, color: scheme.mutedForeground),
    ];
  }

  /// For an unlocked Click V2, when its unlock runs out — which is worth more
  /// than "Connected", because that is the fact about to stop being true.
  /// Null for anything else, including a Click that is currently locked: the
  /// checklist step carries that, and a stale deadline would contradict it.
  String? _unlockStatusLabel(BaseDevice device) {
    // Store renders don't carry an expiry date.
    if (screenshotMode || _unlockState(device) != true) return null;
    final until = _unlockedUntil(device);
    if (until == null) return null;
    return _unlockUncertain(device)
        ? context.i18n.chainStepUnlockedLikelyUntil(until)
        : context.i18n.chainStepUnlockedUntil(until);
  }

  Widget _trainerRow(ChainLink link, ChainInputs inputs) {
    final l = context.i18n;
    final proxy = chainProxy();
    // Straight from the device, in onboarding's sense — not inferred back out
    // of the row's own status, which is how a remembered trainer that isn't
    // even here ended up presenting itself as bridged.
    final bridged = proxy?.isBridged ?? false;
    final appReady = inputs.app.isConnected;
    final appName = inputs.app.name ?? l.chainAppTitle;
    final appHoldsBridge = inputs.trainer?.appHoldsBridge ?? false;

    // The way out for a rider with no smart trainer: the slot stays useful —
    // it becomes their sensors. Offered whenever nothing is actually bridged:
    // a trainer the scanner merely sees, or one remembered from before, is
    // not a trainer the rider is on right now.
    final footer = inputs.trainer?.presence != DevicePresence.connected
        ? ChainCardFooterRow(
            question: inputs.app.name != null
                ? l.sensorsUseSensorsOnlyQuestionApp(inputs.app.name!)
                : l.sensorsUseSensorsOnlyQuestion,
            action: l.sensorsUseSensorsOnly,
            onPressed: _enterSensorsOnlyMode,
          )
        : null;

    // No trainer ever: an invitation to connect one.
    if (inputs.trainer == null) {
      final accent = bkAccentText(context);
      return ChainLinkRow(
        link: link,
        highlight: _highlights.tickFor(link.id),
        appName: inputs.app.name,
        leading: BkIconTile(icon: LucideIcons.plus, color: accent),
        title: l.sensorsConnectTrainer,
        titleColor: accent,
        subtitle: l.rideVsInviteBody,
        onTap: () => _openTrainer(proxy, bridged: false),
        footer: footer,
      );
    }

    // A connect in flight has its own answer — see [DevicePresence.connecting].
    // Or, right after launch, the remembered one expected back on its own.
    final connecting =
        (inputs.trainer?.presence == DevicePresence.connecting && link.status == LinkStatus.attention) ||
        (inputs.trainer?.presence == DevicePresence.remembered &&
            core.connection.startupReconnecting.value.contains(inputs.trainer!.deviceId));

    final String statusLabel;
    if (link.status == LinkStatus.problem) {
      statusLabel = l.chainStatusLostConnection;
    } else if (connecting) {
      statusLabel = l.chainStatusConnecting;
    } else if (bridged) {
      statusLabel = appHoldsBridge
          ? l.chainStatusBridged
          // "Waiting for the app" is wrong once the app is already here over
          // the controller link: it has connected, it just hasn't picked the
          // trainer entry up — the other half of its pairing screen.
          : appReady
          ? l.chainStatusWaitingForPickup(appName)
          : l.onboardingSummaryWaitingFor(appName);
    } else if (appReady && inputs.app.name != null) {
      // Only vouch for the app handling shifting when the app is actually
      // working — otherwise this row would excuse a broken link.
      statusLabel = l.chainStatusHandledByApp(appName);
    } else if (proxy?.isConnected ?? false) {
      statusLabel = l.connected;
    } else {
      statusLabel = l.notConnected;
    }
    // A trainer that is here but not connected — nearby, or lost — connects
    // from its row, the way the trainer sheet connects it; tapping the row
    // still opens the sheet with the rest.
    final offersConnect =
        proxy != null &&
        !bridged &&
        !connecting &&
        !proxy.isConnected &&
        !proxy.isStarting.value &&
        (statusLabel == l.notConnected || link.status == LinkStatus.problem);

    final activeStep = link.activeStep;
    final offersOverlay = activeStep?.id == SetupStepId.trainerGearOverlay;
    // "Not now" belongs to the step while it is required — the one time it
    // asks for an answer. Once answered and switched off again it is an
    // optional offer, and an offer has nothing to decline.
    final overlayAsksForAnswer = offersOverlay && !activeStep!.optional;

    final definition = proxy?.fitnessBike;
    return ChainLinkRow(
      link: link,
      highlight: _highlights.tickFor(link.id),
      // Nullable on purpose: the step wording falls back to "Trainer app"
      // itself, and the overlay step has a sentence of its own for that case.
      appName: inputs.app.name,
      leading: _tile(LucideIcons.bike, live: link.status == LinkStatus.ready || bridged),
      title: link.title.isEmpty ? l.chainTrainerTitle : link.title,
      subtitle: bridged ? _bridgeTransport(proxy!) : null,
      statusLabel: statusLabel,
      statusDetail: bridged && appHoldsBridge && inputs.app.name != null
          ? Text(l.devicesBridgedTo(inputs.app.name!))
          : null,
      // Until a trainer is actually bridged there is nothing to open — the
      // useful offer is to connect it, the same way onboarding does.
      onTap: () => _openTrainer(proxy, bridged: bridged),
      action: offersConnect
          ? (
              label: l.connect,
              icon: LucideIcons.plug,
              onPressed: () async {
                await connectTrainerFromPicker(context, proxy);
                _update();
              },
            )
          : null,
      onInstructions: () => _openInstructions(link),
      // The overlay step is an offer, not a puzzle: its button turns the thing
      // on rather than explaining how it works. And while the step is
      // required, the offer needs a second answer — "Not now" — or a rider who
      // doesn't want the overlay is stuck with an amber row forever.
      instructionsLabel: offersOverlay ? l.chainStepOverlayAction : null,
      secondaryActionLabel: overlayAsksForAnswer ? l.chainStepOverlayDecline : null,
      onSecondaryAction: overlayAsksForAnswer ? _declineOverlay : null,
      // Paired and shifting: the live numbers, the gear among them.
      body: proxy != null && definition != null
          ? _LiveTrainerBody(
              proxy: proxy,
              builder: (definition, _) => TrainerMetricsStrip(definition: definition),
            )
          : null,
      footer: footer,
    );
  }

  /// How the trainer app reaches the bridged trainer.
  String? _bridgeTransport(ProxyDevice proxy) => switch (proxy.retrofitMode.value) {
    RetrofitMode.bluetooth => context.i18n.connectionBluetooth,
    RetrofitMode.wifi => context.i18n.connectionWifi,
    RetrofitMode.proxy => null,
  };

  Future<void> _enterSensorsOnlyMode() async {
    await core.settings.setSensorsOnlyMode(true);
    _update();
  }

  /// Sensors-only mode's row in the trainer's slot: what is being broadcast,
  /// to whom, and — while it is live — the readings themselves.
  Widget _sensorsRow(ChainLink link, ChainInputs inputs) {
    final l = context.i18n;
    final sensors = inputs.sensors!;
    final broadcasting = sensors.broadcasting;

    final String statusLabel;
    if (broadcasting) {
      statusLabel = l.sensorsStatusBroadcasting;
    } else if (sensors.sourceNames.isEmpty) {
      statusLabel = l.sensorsStatusOffSetup;
    } else {
      statusLabel = l.sensorsStatusOff;
    }

    // The first source is the title, the rest ride the sub line ("with Assioma
    // DUO"); under the status, the wire: "Bluetooth · MyWhoosh connected". The
    // transport only matters once the broadcast is on — an idle row naming
    // "Network" would be describing a wire nothing is on.
    final rest = sensors.sourceNames.skip(1).toList();
    final meta = [
      if (broadcasting)
        sensors.transport == RetrofitMode.wifi ? l.sensorsTransportNetwork : l.sensorsTransportBluetooth,
      if (broadcasting)
        if (sensors.clientName case final client?) l.sensorsClientConnected(client),
    ].join(' · ');

    return ChainLinkRow(
      link: link,
      highlight: _highlights.tickFor(link.id),
      appName: inputs.app.name,
      leading: _tile(LucideIcons.heartPulse, live: link.status == LinkStatus.ready),
      title: link.title.isEmpty ? l.sensorsNoSensorsYet : link.title,
      subtitle: rest.isEmpty ? null : l.sensorsWith(rest.join(', ')),
      statusLabel: statusLabel,
      statusDetail: meta.isEmpty ? null : Text(meta),
      onTap: _openSensors,
      body: broadcasting ? _sensorsBody() : null,
      // The way back: sensors-only mode hid the trainer row, and short of a
      // trainer auto-connecting there was no other way to reach it — see
      // _enterSensorsOnlyMode for the entry this mirrors. Broadcast itself is
      // untouched by leaving the mode (Decision 6): the sink keeps standalone
      // until a trainer actually bridges.
      footer: ChainCardFooterRow(
        question: l.sensorsConnectTrainerQuestion,
        action: l.sensorsConnectTrainer,
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
  Widget _sensorsBody() => SensorChips(
    quantities: core.connection.broadcast?.selectedQuantities ?? const <SensorQuantity>{},
  );

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

  Widget _appRow(ChainLink link, ChainInputs inputs) {
    final l = context.i18n;
    final app = core.settings.getTrainerApp();
    final logo = app?.logoAsset;

    final String statusLabel;
    if (link.status == LinkStatus.ready) {
      statusLabel = l.chainStatusReceivingCommands;
    } else if (app != null) {
      // Name what is actually outstanding. Reporting "waiting for the app"
      // while a permission is missing points the rider at the wrong device,
      // and so would "disconnected". Once this side is done, an app that
      // worked earlier in the session has simply disconnected — most often
      // it was closed — rather than lost its connection.
      statusLabel = appStatusFollowsActiveStep(link)
          ? chainStepText(context, link.activeStep!, appName: app.name).label
          : link.dropped
          ? l.chainStatusAppDisconnected(app.name)
          : l.chainStatusWaitingForApp(app.name);
    } else {
      statusLabel = l.chainStatusNotSetUp;
    }

    return ChainLinkRow(
      link: link,
      highlight: _highlights.tickFor(link.id),
      appName: inputs.app.name,
      leading: logo != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(logo, width: BkIconTile.size, height: BkIconTile.size),
            )
          : _tile(LucideIcons.monitor, live: app != null),
      title: link.title.isEmpty ? l.chainAppTitle : link.title,
      subtitle: app == null ? null : connectionMethodSummary(context),
      statusLabel: statusLabel,
      onTap: () async {
        await context.push(const TrainerConnectionSettingsPage());
        _update();
      },
      onInstructions: () => _openInstructions(link),
      // Both of this row's actions act rather than explain, so both say what
      // they do: opening Trainer Connections is an action, and so is switching
      // Local on.
      instructionsLabel: _appFixLabel(link),
      // Local control is optional and sits behind "Waiting for {app}" while
      // the app is away — it still gets its button, the same one it has when
      // it is the step in front.
      offerLabel: (step) => step.id == SetupStepId.appLocalControl ? l.chainStepLocalControlAction : null,
      onOffer: (step) async {
        if (step.id != SetupStepId.appLocalControl) return;
        await enableLocalControl(context);
        _update();
      },
    );
  }
  // ── Actions ───────────────────────────────────────────────────────────

  /// The banner's "Show" with several cards outstanding: bring the rider to
  /// them and make each one jump out. Which of two unfinished cards comes first
  /// is render order, not priority, so opening the first one's fix — what the
  /// button used to do — reads as arbitrary.
  Future<void> _revealOutstanding(List<String> linkIds) async {
    if (linkIds.isEmpty) return;
    final first = _cardKeys[linkIds.first]?.currentContext;
    if (first != null) {
      await Scrollable.ensureVisible(
        first,
        // Near the top, with a little room above the card.
        alignment: 0.05,
        duration: prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    // Once the cards have arrived, so the pulse is not spent mid-scroll — and
    // only on those still outstanding by then: a card the rider finished
    // meanwhile has nothing left to point at.
    _highlights.play(linkIds.where(_outstandingLinkIds.contains));
  }

  /// Instruction sheets are routed on the card and its state, never on the
  /// wording of the active step — so a never-paired controller gets the pairing
  /// flow while a paired-then-dropped one gets the reconnect checklist.
  Future<void> _openInstructions(ChainLink link) async {
    switch (link.key) {
      case ChainLinkKey.controller:
        // A locked Click V2 or Ride V2 has one specific answer, and it is not
        // the generic "can't find your controller" help: send the rider
        // straight into the unlock flow for this exact device.
        final active = link.activeStep?.id;
        final device = _controllerById(link.deviceId);
        if (active == SetupStepId.controllerUnlocked && device is ZwiftUnlock) {
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
          // Including any app that connected earlier in this session and has
          // gone: it was almost always closed, and what brings it back is its
          // own pairing screen. The network self-test is only reached from
          // here through the address step above, which a dropped app only
          // gets for a warning that is new since it connected.
          await openAppGuideSheet(context);
        }
      case ChainLinkKey.sensors:
        // No checklist to explain: everything about the sensors lives on
        // their page, so any "show me" lands there.
        await context.push(const SensorsPage());
    }
    _update();
  }

  /// Turns the gear overlay on, then opens Settings → Overlay.
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
        title: result.riderMessage(context.i18n),
      );
    }
    await context.push(overlaySettingsDestination(proxy));
  }

  /// "Not now" on the overlay step (and on Ride's offer): the rider has
  /// answered, so the step leaves the card and stays away, and Ride's offer
  /// shrinks to one line. There is no undo here on purpose — the Overlay
  /// page's switch is the way back, and turning the overlay on there
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

/// The live sensor readings as chips, one per quantity the rider has a
/// source for — the same icon the signals grid uses for that quantity, so a
/// rider recognises the tile each chip summarises. Icons stay neutral: the
/// one accent is brand blue, and a hue per quantity would read as a state.
class SensorChips extends StatelessWidget {
  const SensorChips({super.key, required this.quantities});

  final Set<SensorQuantity> quantities;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (quantities.contains(SensorQuantity.heartRate))
          const _MetricChip(quantity: SensorQuantity.heartRate, icon: LucideIcons.heart, unit: 'bpm'),
        if (quantities.contains(SensorQuantity.cadence))
          const _MetricChip(quantity: SensorQuantity.cadence, icon: LucideIcons.rotateCw, unit: 'rpm'),
        if (quantities.contains(SensorQuantity.power))
          const _MetricChip(quantity: SensorQuantity.power, icon: LucideIcons.zap, unit: 'W'),
      ],
    );
  }
}

/// One live reading: icon, the number in bold, its unit muted.
class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.quantity, required this.icon, required this.unit});

  final SensorQuantity quantity;
  final IconData icon;
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
            Icon(icon, size: 14, color: theme.colorScheme.mutedForeground),
            const Gap(6),
            Text(
              value?.toString() ?? '--',
              style: context.typography.small.copyWith(fontWeight: FontWeight.w700),
            ),
            const Gap(4),
            Text(unit, style: context.typography.caption.copyWith(color: theme.colorScheme.mutedForeground)),
          ],
        ),
      ),
    );
  }
}

/// The trainer card's live drivetrain.
///
/// The trainer's definition is swapped when its transport restarts or it
/// changes mode, behind notifiers that come and go with it. Rather than
/// re-subscribing on every transition, this re-reads the trainer on a slow
/// tick — and rebuilds only itself, only when what it shows actually changed.
/// (It used to be the whole home page, every two seconds.)
class _LiveTrainerBody extends StatefulWidget {
  const _LiveTrainerBody({super.key, required this.proxy, this.builder});

  final ProxyDevice proxy;

  /// What to draw for the current definition; the trainer card's compact
  /// drivetrain when null.
  final Widget Function(FitnessBikeDefinition definition, bool connected)? builder;

  @override
  State<_LiveTrainerBody> createState() => _LiveTrainerBodyState();
}

class _LiveTrainerBodyState extends State<_LiveTrainerBody> {
  Timer? _ticker;
  FitnessBikeDefinition? _definition;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _read();
    // Not under the screenshot harness: a periodic timer never lets a widget
    // test's frame loop go quiet, and the captured state is a fixture there.
    if (!screenshotMode) {
      _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
        if (widget.proxy.fitnessBike != _definition || widget.proxy.isConnected != _connected) {
          setState(_read);
        }
      });
    }
  }

  void _read() {
    _definition = widget.proxy.fitnessBike;
    _connected = widget.proxy.isConnected;
  }

  @override
  void didUpdateWidget(covariant _LiveTrainerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _read();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = _definition;
    if (definition == null) return const SizedBox.shrink();
    if (widget.builder case final builder?) return builder(definition, _connected);
    return DrivetrainControls(definition: definition, compact: true, dim: !_connected);
  }
}

/// Below the recording slot when Ride has no Virtual shifting card: a gap
/// only while the slot shows anything.
class _GapWhenRecording extends StatelessWidget {
  const _GapWhenRecording();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: core.rides.changes,
      builder: (context, _) {
        final shows = core.rides.recorder.state.value != WorkoutState.idle || !core.rides.autoRecord;
        return shows ? const Gap(20) : const SizedBox.shrink();
      },
    );
  }
}
