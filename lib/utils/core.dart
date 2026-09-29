import 'dart:io';

import 'package:bike_control/bluetooth/app_connection_latch.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/devices/zwift/ftms_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/rouvy_mdns_emulator.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:bike_control/bluetooth/emulation/emulation_manager.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/bluetooth/remote_keyboard_pairing.dart';
import 'package:bike_control/repositories/remembered_devices_repository.dart';
import 'package:bike_control/bluetooth/remote_pairing.dart';
import 'package:bike_control/utils/demo_mode.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:bike_control/services/health/health_ride_feedback.dart';
import 'package:bike_control/services/health/health_ride_preferences.dart';
import 'package:bike_control/services/health/health_ride_service.dart';
import 'package:bike_control/services/health/health_workout_channel.dart';
import 'package:bike_control/services/screen_recording/screen_recording_service.dart';
import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/services/shift_feedback/shift_haptics.dart';
import 'package:bike_control/services/shift_feedback/sound_players/shift_sound_player_factory.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/shifting_configs_controller.dart';
import 'package:bike_control/services/workout/fit_writer.dart';
import 'package:bike_control/services/workout/trainer_metrics.dart';
import 'package:bike_control/services/workout/workout_recorder.dart';
import 'package:bike_control/services/workout/workout_repository.dart';
import 'package:bike_control/utils/actions/android.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/actions/remote.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/requirements/android.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/apps/local_tile.dart';
import 'package:dartx/dartx.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prop/prop.dart';
import 'package:prop/services/bridge_usage_tracker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth/connection.dart';
import '../bluetooth/devices/mywhoosh/link.dart';
import 'keymap/apps/rouvy.dart';
import 'media_key_handler.dart';
import 'package:bike_control/pages/onboarding/onboarding_trigger.dart';
import 'requirements/local_network.dart';
import 'requirements/multi.dart';
import 'requirements/platform.dart';

final core = Core();

class Core {
  late BaseActions actionHandler;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final settings = Settings();
  late final shiftingConfigs = ShiftingConfigsController(settings.prefs);
  late final rememberedDevices = RememberedDevicesRepository(settings.prefs);
  final connection = Connection();

  /// Which trainer app connected in this session, next to [Connection]'s own
  /// record of the devices that did. Kept current by [Connection.initialize].
  late final appConnectionLatch = AppConnectionLatch(
    pickedApp: () => settings.getTrainerApp()?.name,
    connectedOverRealMethod: () => logic.connectedNonLocalTrainerConnections.isNotEmpty,
  );
  late final workoutRecorder = WorkoutRecorder();
  ScreenRecordingService screenRecording = ScreenRecordingService(backend: createScreenRecorderBackend());
  /// Where finished rides are saved. Not final: tests swap in one that keeps
  /// them off the disk.
  late WorkoutRepository workoutRepository = WorkoutRepository();

  late final supabase = Supabase.instance.client;
  late final whooshLink = WhooshLink();
  BridgeUsageTracker? _bridgeUsageTracker;
  BridgeUsageTracker get bridgeUsageTracker {
    _bridgeUsageTracker ??= BridgeUsageTracker(
      prefs: settings.prefs,
      dailyLimit: const Duration(minutes: 20),
    );
    return _bridgeUsageTracker!;
  }

  late final zwiftEmulator = ZwiftEmulator();
  late final zwiftMdnsEmulator = FtmsMdnsEmulator();
  late final rouvyMdnsEmulator = RouvyMdnsEmulator();
  late final obpMdnsEmulator = OpenBikeControlMdnsEmulator();
  late final local = Local();
  late final obpBluetoothEmulator = OpenBikeControlBluetoothEmulator();
  late final remotePairing = RemotePairing();
  late final remoteKeyboardPairing = RemoteKeyboardPairing();
  late final emulation = EmulationManager();
  late final sensors = SensorHub();

  late final mediaKeyHandler = MediaKeyHandler();

  /// Phone-side shift feedback (haptics / sound). Not final: tests swap in a
  /// recording fake to assert the call sites without a platform.
  late ShiftFeedbackService shiftFeedback = ShiftFeedbackService(
    settings: settings,
    haptics: const PlatformShiftHaptics(),
    createSoundPlayer: createShiftSoundPlayer,
    onError: (context, e, s) => recordError(e, s, context: context),
  );

  final HealthWorkoutChannel _healthWorkoutChannel = MethodChannelHealthWorkout();

  /// "Save rides to Apple Health": detects/records rides on its own and
  /// writes finished ones to Health. Not final: tests swap in a fresh
  /// instance (fake channel, in-memory prefs) to assert call sites without a
  /// platform.
  late HealthRideService healthRide = HealthRideService(
    recorder: workoutRecorder,
    prefs: HealthRidePreferences(settings.prefs),
    channel: _healthWorkoutChannel,
    feedback: HealthRideToastFeedback(channel: _healthWorkoutChannel),
    isPlatformSupported: () => !kIsWeb && Platform.isIOS,
    isPro: () => IAPManager.instance.isProEnabledForCurrentDevice,
    trainerApp: () => settings.getTrainerApp(),
    target: () => settings.getLastTarget(),
    connectedTrainer: _connectedTrainerMetrics,
    saveFit: _saveAutoRideFit,
    onError: (e, s, context) => recordError(e, s, context: context),
    // Debug builds: quick on-device testing without a real 5-min ride.
    minRide: kDebugMode ? const Duration(seconds: 20) : HealthRideService.defaultMinRide,
    log: (message) => connection.signalNotification(LogNotification('HealthRide: $message')),
  );

  /// The first BLE-connected trainer's live metrics, for [healthRide] to
  /// watch. Same construction `MiniWorkoutCard` uses for a manual recording,
  /// just picked automatically rather than from a specific device's page.
  TrainerMetrics? _connectedTrainerMetrics() {
    for (final device in connection.proxyDevices) {
      if (!device.isConnected) continue;
      final metrics = TrainerMetrics.fromDefinition(device.emulator.activeDefinition);
      if (metrics != null) return metrics;
    }
    return null;
  }

  /// Persists an automatic ride's FIT file exactly like `MiniWorkoutCard`'s
  /// manual stop does.
  Future<void> _saveAutoRideFit(WorkoutResult result) async {
    final bytes = FitFileWriter.encode(samples: result.samples, summary: result.summary);
    await workoutRepository.save(startedAt: result.startedAt, fitBytes: bytes, summary: result.summary);
  }

  late final logic = CoreLogic();
  late final permissions = Permissions();

  FeedbackPromptService? _feedbackPromptService;
  FeedbackPromptService get feedbackPromptService {
    return _feedbackPromptService ??= FeedbackPromptService(
      settings: settings,
      trainerConnections: logic.trainerConnections.map((t) => t.isConnected).toList(),
      isOnTrial: () {
        final iap = IAPManager.instance;
        return !iap.isProEnabled && !iap.isPurchased.value && !iap.isTrialExpired;
      },
    );
  }

  /// Stops all active BLE connection methods and disables their settings.
  /// Call this before enabling a new BLE connection to ensure mutual exclusivity.
  Future<void> stopAllBleConnections() async {
    if (settings.getZwiftBleEmulatorEnabled()) {
      settings.setZwiftBleEmulatorEnabled(false);
      await zwiftEmulator.stopAdvertising();
    }
    if (settings.getObpBleEnabled()) {
      settings.setObpBleEnabled(false);
      await obpBluetoothEmulator.stopServer();
    }
    if (settings.getRemoteControlEnabled()) {
      settings.setRemoteControlEnabled(false);
      await remotePairing.stopAdvertising();
    }
    if (settings.getRemoteKeyboardControlEnabled()) {
      settings.setRemoteKeyboardControlEnabled(false);
      await remoteKeyboardPairing.stopAdvertising();
    }
  }
}

class Permissions {
  /// Permissions needed to *scan for Bluetooth devices*.
  ///
  /// Every caller treats a non-empty result as "don't scan", so this must stay
  /// Bluetooth-only. Local Network deliberately isn't here: a denial would
  /// silently kill BLE scanning, and probing it pops the system dialog at app
  /// start, before onboarding has been shown. It's gated per connection method
  /// instead — see [localNetworkRequirements].
  Future<List<PlatformRequirement>> getScanRequirements() async {
    final List<PlatformRequirement> list;
    if (screenshotMode || demoHidePermissions) {
      list = [];
    } else if (kIsWeb) {
      final availability = await UniversalBle.getBluetoothAvailabilityState();
      if (availability == AvailabilityState.unsupported) {
        list = [UnsupportedPlatform()];
      } else {
        list = [BluetoothTurnedOn()];
      }
    } else if (Platform.isMacOS) {
      list = [
        BluetoothTurnedOn(),
        NotificationRequirement(),
      ];
    } else if (Platform.isIOS) {
      list = [
        BluetoothTurnedOn(),
        NotificationRequirement(),
      ];
    } else if (Platform.isWindows) {
      list = [
        BluetoothTurnedOn(),
        NotificationRequirement(),
      ];
    } else if (Platform.isAndroid) {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final deviceInfo = await deviceInfoPlugin.androidInfo;
      list = [
        if (deviceInfo.version.sdkInt <= 30)
          LocationRequirement()
        else ...[
          BluetoothScanRequirement(),
          BluetoothConnectRequirement(),
        ],
        BluetoothTurnedOn(),
        NotificationRequirement(),
      ];
    } else {
      list = [UnsupportedPlatform()];
    }

    await Future.wait(list.map((e) => e.getStatus()));
    return list.where((e) => !e.status).toList();
  }

  List<PlatformRequirement> getLocalControlRequirements() {
    return [HostPlatform.isAndroid ? AccessibilityRequirement() : KeyboardRequirement()];
  }

  List<PlatformRequirement> getRemoteControlRequirements() {
    return [
      BluetoothTurnedOn(),
      if (Platform.isAndroid) ...[
        BluetoothScanRequirement(),
        BluetoothConnectRequirement(),
        BluetoothAdvertiseRequirement(),
      ],
    ];
  }
}

extension Granted on List<PlatformRequirement> {
  Future<bool> get allGranted async {
    await Future.wait(map((e) => e.getStatus()));
    return where((element) => !element.status).isEmpty;
  }
}

class CoreLogic {
  bool get showLocalControl {
    return core.settings.getLastTarget()?.connectionType == ConnectionType.local &&
        core.settings.getTrainerApp()?.acceptsSimulatedInput != false &&
        (HostPlatform.isMacOS || HostPlatform.isWindows || HostPlatform.isAndroid);
  }

  bool get canRunAndroidService {
    return HostPlatform.isAndroid && core.actionHandler is AndroidActions;
  }

  Future<bool> isAndroidServiceRunning() async {
    if (canRunAndroidService) {
      return (core.actionHandler as AndroidActions).accessibilityHandler.isRunning();
    }
    return false;
  }

  bool get isZwiftBleEnabled {
    return core.settings.getZwiftBleEmulatorEnabled() && showZwiftBleEmulator;
  }

  bool get isZwiftMdnsEnabled {
    return core.settings.getZwiftMdnsEmulatorEnabled() && showZwiftMsdnEmulator;
  }

  bool get isObpBleEnabled {
    return core.settings.getObpBleEnabled() && showObpBluetoothEmulator;
  }

  bool get isObpMdnsEnabled {
    return core.settings.getObpMdnsEnabled() && showObpMdnsEmulator;
  }

  bool get isMyWhooshLinkEnabled {
    return core.settings.getMyWhooshLinkEnabled() && showMyWhooshLink;
  }

  bool get showZwiftBleEmulator {
    final app = core.settings.getTrainerApp();
    return app != null &&
        app.supports(AppConnectionMethod.zwiftBle) &&
        core.settings.getLastTarget() != Target.thisDevice;
  }

  bool get showZwiftMsdnEmulator {
    final app = core.settings.getTrainerApp();
    return app != null && (app.supports(AppConnectionMethod.zwiftMdns) || app.supports(AppConnectionMethod.rouvyMdns));
  }

  bool get showObpMdnsEmulator {
    final app = core.settings.getTrainerApp();
    return app != null && (app.supports(AppConnectionMethod.obpMdns) || app.supports(AppConnectionMethod.obpDirCon));
  }

  bool get showObpBluetoothEmulator {
    final app = core.settings.getTrainerApp();
    return app != null &&
        app.supports(AppConnectionMethod.obpBle) &&
        core.settings.getLastTarget() != Target.thisDevice;
  }

  bool get isRemoteControlEnabled {
    return core.settings.getRemoteControlEnabled() && showRemote;
  }

  bool get isRemoteKeyboardControlEnabled {
    return core.settings.getRemoteKeyboardControlEnabled() && showRemote;
  }

  bool get showMyWhooshLink =>
      core.settings.getTrainerApp() is MyWhoosh &&
      core.settings.getLastTarget() != null &&
      core.whooshLink.isCompatible(core.settings.getLastTarget()!);

  /// Remote control pairs BikeControl as a Bluetooth keyboard/mouse to the other
  /// device, so it is only worth offering for apps that read that input at all.
  bool get showRemote =>
      core.settings.getLastTarget() != Target.thisDevice &&
      core.settings.getTrainerApp()?.acceptsSimulatedInput != false &&
      core.actionHandler is RemoteActions;

  bool get showForegroundMessage =>
      core.actionHandler is RemoteActions && !kIsWeb && Platform.isIOS && core.remotePairing.isConnected.value;

  AppInfo? get obpConnectedApp =>
      core.obpMdnsEmulator.connectedApp.value ?? core.obpBluetoothEmulator.connectedApp.value;

  /// Supported OBP buttons for the currently-selected trainer app.
  /// Order: last-persisted list (overwritten on every AppInfo) → trainer-app
  /// hard-coded defaults → empty when no trainer is selected.
  List<ControllerButton> get obpSupportedButtons {
    final trainerApp = core.settings.getTrainerApp();
    if (trainerApp == null) return const [];
    final stored = core.settings.getObpSupportedButtons(trainerApp.name);
    if (stored != null && stored.isNotEmpty) return stored;
    return trainerApp.defaultObpSupportedButtons;
  }

  List<InGameAction> get obpSupportedActions => obpSupportedButtons.mapNotNull((b) => b.action).toList();

  bool get emulatorEnabled =>
      screenshotMode ||
      (core.settings.getMyWhooshLinkEnabled() && showMyWhooshLink) ||
      (core.settings.getZwiftBleEmulatorEnabled() && showZwiftBleEmulator) ||
      (core.settings.getZwiftMdnsEmulatorEnabled() && showZwiftMsdnEmulator) ||
      (core.settings.getObpBleEnabled() && showObpBluetoothEmulator) ||
      (core.settings.getObpMdnsEnabled() && showObpMdnsEmulator);

  bool get showObpActions =>
      (core.settings.getObpBleEnabled() && showObpBluetoothEmulator) ||
      (core.settings.getObpMdnsEnabled() && showObpMdnsEmulator);

  bool get ignoreWarnings => core.settings.getTrainerApp()?.connections.isNotEmpty == true;

  bool get showLocalRemoteOptions =>
      core.actionHandler.supportedModes.isNotEmpty &&
      (showLocalControl || isRemoteControlEnabled || isRemoteKeyboardControlEnabled);

  /// The "Simulate keyboard shortcut" card is shown when the keyboard mode is
  /// supported and either Local is available (may be disabled — tapping then
  /// prompts to enable it) or remote-keyboard control is already enabled.
  bool get showLocalKeyboardCard =>
      core.actionHandler.supportedModes.contains(SupportedMode.keyboard) &&
      (showLocalControl || isRemoteKeyboardControlEnabled);

  /// The "Simulate touch / mouse" card is shown when the touch mode is
  /// supported and either Local is available or remote control is enabled.
  bool get showLocalTouchCard =>
      core.actionHandler.supportedModes.contains(SupportedMode.touch) && (showLocalControl || isRemoteControlEnabled);

  /// Whether any method that rides on the LAN is switched on.
  ///
  /// Answers both "is Apple's Local Network permission this rider's problem"
  /// and "is the network troubleshooter worth offering" — the two have the
  /// same precondition.
  bool get hasNetworkMethodEnabled => isZwiftMdnsEnabled || isObpMdnsEnabled || isMyWhooshLinkEnabled;

  /// Whether a permission check triggered by app launch should be skipped.
  ///
  /// Reuses navigation's own onboarding decision so the two cannot drift.
  /// Safe to read during `Connection.initialize()`: `setLastSeenVersion` is
  /// written later (navigation.dart), so the pref still holds the previous
  /// launch's value here.
  bool get deferLaunchPermissions => deferLaunchPermissionChecks(
    onboardingAction: decideOnboardingTrigger(
      lastSeenVersion: core.settings.getLastSeenVersion(),
      onboardingState: core.settings.getOnboardingState(),
    ),
  );

  bool get hasNoConnectionMethod =>
      !screenshotMode &&
      // Apps that take no controller input have no method to pick, so the
      // absence of one is the finished state rather than an unfinished setup.
      (core.settings.getTrainerApp()?.receivesButtonEvents ?? true) &&
      !isZwiftBleEnabled &&
      !isZwiftMdnsEnabled &&
      !showObpActions &&
      !(core.settings.getMyWhooshLinkEnabled() && showMyWhooshLink) &&
      !showLocalRemoteOptions;

  bool get hasRecommendedConnectionMethods =>
      showObpBluetoothEmulator ||
      showObpMdnsEmulator ||
      showLocalControl ||
      showZwiftBleEmulator ||
      showZwiftMsdnEmulator ||
      showMyWhooshLink;

  bool get hasOfficialConnectionMethods =>
      showObpBluetoothEmulator || showObpMdnsEmulator || showZwiftBleEmulator || showZwiftMsdnEmulator;

  List<TrainerConnection> get connectedTrainerConnections => [
    if (isObpMdnsEnabled) core.obpMdnsEmulator,
    if (isObpBleEnabled) core.obpBluetoothEmulator,
    if (core.settings.getLocalEnabled()) core.local,
    if (isMyWhooshLinkEnabled) core.whooshLink,
    if (isZwiftBleEnabled) core.zwiftEmulator,
    if (isZwiftMdnsEnabled) core.settings.getTrainerApp() is Rouvy ? core.rouvyMdnsEmulator : core.zwiftMdnsEmulator,
    if (isRemoteControlEnabled) core.remotePairing,
    if (isRemoteKeyboardControlEnabled) core.remoteKeyboardPairing,
  ].filter((e) => e.isConnected.value).toList();

  List<TrainerConnection> get connectedNonLocalTrainerConnections => [
    if (isObpMdnsEnabled) core.obpMdnsEmulator,
    if (isObpBleEnabled) core.obpBluetoothEmulator,
    if (isMyWhooshLinkEnabled) core.whooshLink,
    if (isZwiftBleEnabled) core.zwiftEmulator,
    if (isZwiftMdnsEnabled) core.settings.getTrainerApp() is Rouvy ? core.rouvyMdnsEmulator : core.zwiftMdnsEmulator,
    if (isRemoteControlEnabled) core.remotePairing,
    if (isRemoteKeyboardControlEnabled) core.remoteKeyboardPairing,
  ].filter((e) => e.isConnected.value).toList();

  List<TrainerConnection> get enabledTrainerConnections => [
    if (isObpBleEnabled) core.obpBluetoothEmulator,
    if (isObpMdnsEnabled) core.obpMdnsEmulator,
    if (core.settings.getLocalEnabled() && showLocalControl) core.local,
    if (isMyWhooshLinkEnabled) core.whooshLink,
    if (isZwiftBleEnabled) core.zwiftEmulator,
    if (isZwiftMdnsEnabled) core.settings.getTrainerApp() is Rouvy ? core.rouvyMdnsEmulator : core.zwiftMdnsEmulator,
    if (isRemoteControlEnabled) core.remotePairing,
    if (isRemoteKeyboardControlEnabled) core.remoteKeyboardPairing,
  ].sortedBy((e) => e.isConnected.value ? 0 : 1);

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

  /// The connections that count as "the trainer app is receiving commands".
  ///
  /// Local control is a fallback, not an answer: it types into whatever window
  /// happens to be in front, so it reports connected the moment it is switched
  /// on and says nothing about whether the trainer app is reachable. With a
  /// network method also enabled — the default for MyWhoosh — counting Local
  /// would call the app connected while the method the rider actually rides on
  /// sat unactivated.
  ///
  /// When Local is all there is, it IS the answer and counts. Same distinction
  /// [InactivityDisconnector] draws between `isTrainerAppConnected` and
  /// `isOnlyLocalActive`.
  List<TrainerConnection> get appFacingConnections {
    final onlyLocal = enabledNonLocalTrainerConnections.isEmpty && core.settings.getLocalEnabled();
    return onlyLocal ? connectedTrainerConnections : connectedNonLocalTrainerConnections;
  }

  List<TrainerConnection> get enabledNonLocalTrainerConnections => [
    if (isObpBleEnabled) core.obpBluetoothEmulator,
    if (isObpMdnsEnabled) core.obpMdnsEmulator,
    if (isMyWhooshLinkEnabled) core.whooshLink,
    if (isZwiftBleEnabled) core.zwiftEmulator,
    if (isZwiftMdnsEnabled) core.settings.getTrainerApp() is Rouvy ? core.rouvyMdnsEmulator : core.zwiftMdnsEmulator,
    if (isRemoteControlEnabled) core.remotePairing,
    if (isRemoteKeyboardControlEnabled) core.remoteKeyboardPairing,
  ];

  List<TrainerConnection> get trainerConnections => [
    if (showObpMdnsEmulator) core.obpMdnsEmulator,
    if (showObpBluetoothEmulator) core.obpBluetoothEmulator,
    if (showMyWhooshLink) core.whooshLink,
    if (showZwiftBleEmulator) core.zwiftEmulator,
    if (showZwiftMsdnEmulator) core.settings.getTrainerApp() is Rouvy ? core.rouvyMdnsEmulator : core.zwiftMdnsEmulator,
    if (showRemote) core.remotePairing,
    if (showRemote) core.remoteKeyboardPairing,
  ];

  Future<bool> isTrainerConnected() async {
    if (screenshotMode) {
      return true;
    } else if (showLocalControl && core.settings.getLocalEnabled()) {
      if (canRunAndroidService) {
        return isAndroidServiceRunning();
      } else {
        return true;
      }
    } else if (connectedTrainerConnections.isNotEmpty) {
      return true;
    } else {
      return false;
    }
  }

  /// [userInitiated] opts out of the onboarding deferral below. Use it when the
  /// rider just did something that should visibly take effect — granting a
  /// permission, finishing the wizard — as opposed to the unsolicited call at
  /// app launch.
  void startEnabledConnectionMethod({bool userInitiated = false}) async {
    if (screenshotMode) {
      return;
    }
    // The wizard owns the screen and drives its own methods (see
    // setOnboardingMethodEnabled, which starts servers directly), so nothing is
    // lost by holding off — and a permission prompt or warning toast arriving
    // from behind it explains nothing.
    if (!userInitiated && deferLaunchPermissions) {
      return;
    }
    if (isZwiftBleEnabled &&
        await core.permissions.getRemoteControlRequirements().allGranted &&
        !core.zwiftEmulator.isStarted.value) {
      core.zwiftEmulator.startAdvertising(() {}).catchError((e, s) {
        recordError(e, s, context: 'Zwift BLE Emulator');
        core.settings.setZwiftBleEmulatorEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Zwift mDNS Emulator: $e'),
        );
      });
    }
    // The BLE branches below already gate on their permissions; the network
    // ones used to start unconditionally and fail silently when Local Network
    // was off. Only probe when a network method is actually enabled — probing
    // is what raises the system prompt, and a rider running BLE only should
    // never see it.
    // No toast on failure: the app card carries this as a required step now,
    // which stays put instead of scrolling away.
    final localNetworkOk = !hasNetworkMethodEnabled || await localNetworkRequirements().allGranted;

    if (isZwiftMdnsEnabled && localNetworkOk) {
      if (core.settings.getTrainerApp() is Rouvy && !core.rouvyMdnsEmulator.isStarted.value) {
        core.rouvyMdnsEmulator.startServer().catchError((e, s) {
          recordError(e, s, context: 'Rouvy mDNS Emulator');
          core.settings.setZwiftMdnsEmulatorEnabled(false);
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Rouvy mDNS Emulator: $e'),
          );
        });
      } else if (!core.zwiftMdnsEmulator.isStarted.value) {
        core.zwiftMdnsEmulator.startServer().catchError((e, s) {
          recordError(e, s, context: 'Zwift mDNS Emulator');
          core.settings.setZwiftMdnsEmulatorEnabled(false);
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Zwift mDNS Emulator: $e'),
          );
        });
      }
    }

    if (isObpMdnsEnabled && isMyWhooshLinkEnabled) {
      // this doesn't make much sense to have both running at the same time, so disable Whoosh Link if OBP mDNS is enabled
      core.settings.setMyWhooshLinkEnabled(false);
    }

    if (isObpMdnsEnabled && localNetworkOk && !core.obpMdnsEmulator.isStarted.value) {
      core.obpMdnsEmulator.startServer().catchError((e, s) {
        recordError(e, s, context: 'OBP mDNS Emulator');
        core.settings.setObpMdnsEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start OpenBikeControl mDNS Emulator: $e'),
        );
      });
    }
    if (isObpBleEnabled &&
        await core.permissions.getRemoteControlRequirements().allGranted &&
        !core.obpBluetoothEmulator.isStarted.value) {
      core.obpBluetoothEmulator.startServer().catchError((e, s) {
        recordError(e, s, context: 'OBP BLE Emulator');
        core.settings.setObpBleEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start OpenBikeControl BLE Emulator: $e'),
        );
      });
    }

    if (isMyWhooshLinkEnabled && localNetworkOk && !core.whooshLink.isStarted.value) {
      core.connection.startMyWhooshServer();
    }

    if (isRemoteControlEnabled && !core.remotePairing.isStarted.value) {
      core.remotePairing.startAdvertising().catchError((e, s) {
        recordError(e, s, context: 'Remote Pairing');
        core.settings.setRemoteControlEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Remote Control pairing: $e'),
        );
      });
    }

    if (isRemoteKeyboardControlEnabled && !core.remoteKeyboardPairing.isStarted.value) {
      core.remoteKeyboardPairing.startAdvertising().catchError((e, s) {
        recordError(e, s, context: 'Remote Keyboard Pairing');
        core.settings.setRemoteKeyboardControlEnabled(false);
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Remote Keyboard Control pairing: $e'),
        );
      });
    }
  }
}

class Local extends TrainerConnection {
  Local()
    : super(
        title: () => ConnectionMethodType.local.name.capitalize(),
        type: ConnectionMethodType.local,
        supportedActions: InGameAction.values,
      ) {
    if (core.logic.canRunAndroidService) {
      core.logic.isAndroidServiceRunning().then((isRunning) {
        core.connection.signalNotification(LogNotification('Local Control: $isRunning'));
        isStarted.value = isRunning;
        isConnected.value = isRunning;
      });
    }
  }

  final ValueNotifier<bool> _isConnected = ValueNotifier(core.settings.getLocalEnabled());
  final ValueNotifier<bool> _isStarted = ValueNotifier(core.settings.getLocalEnabled());

  @override
  ValueNotifier<bool> get isConnected => _isConnected;

  @override
  ValueNotifier<bool> get isStarted => _isStarted;

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    return NotHandled(
      '',
      button: keyPair.buttons.firstOrNull,
    );
  }

  @override
  Widget getTile({bool small = false}) => LocalTile(small: small);
}
