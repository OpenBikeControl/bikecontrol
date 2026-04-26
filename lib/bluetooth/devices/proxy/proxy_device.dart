import 'dart:async';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart' show TrainerConnectionType;
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:prop/prop.dart' hide TrainerMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class ProxyDevice extends BluetoothDevice {
  static final List<String> proxyServiceUUIDs = [
    FitnessBikeDefinition.HEART_RATE_MEASUREMENT_UUID, // Heart Rate
    FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID, // Heart Rate
    FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, // Fitness Machine
  ];

  final DirconEmulator emulator = DirconEmulator();
  final ValueChangeNotifier<String> onChange = ValueChangeNotifier('');

  /// True while the initial BLE connect + service discovery for this proxy is
  /// in flight. The emulator's `isStarted` only flips once startServer runs
  /// (after services are discovered); UI that needs to render a "Connecting…"
  /// state between tap and first successful start should watch this instead.
  final ValueNotifier<bool> isStarting = ValueNotifier(false);

  StreamSubscription<void>? _bridgeBudgetSub;

  /// Latest [FitnessBikeDefinition] handed to us via
  /// [DirconEmulator.onFitnessBikeDefinitionCreated]. The emulator builds a
  /// fresh definition each time the transport starts, so this reference is
  /// rebound on every session — read it through [_isTrainerActive] to gate
  /// the bridge-usage timer on real trainer activity.
  FitnessBikeDefinition? _currentFbd;

  ProxyDevice(super.scanResult)
    : super(
        availableButtons: const [],
        icon: _iconFor(scanResult),
        isBeta: true,
      ) {
    emulator.onFitnessBikeDefinitionCreated = _seedFitnessBikeDefinition;
    emulator.isTrial = () {
      return !IAPManager.instance.isProEnabledForCurrentDevice;
    };
    emulator.shouldAdvertise = () => !_isBridgeTrialOver;
    emulator.trainerName = () => core.settings.getTrainerApp()?.name ?? 'BikeControl';
    emulator.isConnected.addListener(_syncBridgeTracking);
    emulator.retrofitMode.addListener(_syncBridgeTracking);
  }

  void _syncBridgeTracking() {
    final isBridgeSession = emulator.isConnected.value && emulator.retrofitMode.value != RetrofitMode.proxy;
    final isPro = IAPManager.instance.isProEnabledForCurrentDevice;
    if (isBridgeSession && !isPro) {
      if (core.bridgeUsageTracker.isExhausted) {
        // Already at the daily limit — pause advertising so no new clients can
        // discover us, but keep the transport pipeline + upstream BLE alive.
        // Deferred via microtask: we may be inside a notifyListeners chain of
        // emulator.isConnected that led us here, so we must not call any
        // synchronous dispose/teardown on the same call stack.
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
    if (emulator.retrofitMode.value == RetrofitMode.proxy) return false;
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
      1340,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('BridgeTrial', 'Bridge Trial Status'),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  void _seedFitnessBikeDefinition(FitnessBikeDefinition def) {
    _currentFbd = def;
    final cfg = core.shiftingConfigs.activeFor(trainerKey);
    def.setMaxGear(cfg.maxGear);
    def.setBicycleWeightKg(cfg.bikeWeightKg);
    def.setRiderWeightKg(cfg.riderWeightKg);
    def.setGradeSmoothingEnabled(cfg.gradeSmoothing);
    def.setVirtualShiftingMode(cfg.mode);
    if (cfg.gearRatios != null && cfg.gearRatios!.length == def.maxGear) {
      def.setGearRatios(cfg.gearRatios!);
    }
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
    emulator.setScanResult(scanResult);
    emulator.handleServices(services);

    try {
      await emulator.startServer();
      applyTrainerSettings();
      // Read the trainer's FTMS Feature map proactively so the UI can gate
      // virtual-shifting options and the feedback payload can report it. Runs
      // off the critical path — failures just leave trainerFeature null.
      final def = emulator.activeDefinition;
      if (def is FitnessBikeDefinition) unawaited(def.probeTrainerFeatures());
      onChange.value = 'Connected to ${scanResult.name}';

      if (_isBridgeTrialOver) {
        _announceBridgeTrialOver();
      }
    } catch (e) {
      core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Failed to start emulator: $e'));
      onChange.value = 'Failed to start emulator: $e';
      emulator.stop();
      disconnect();
    }
  }

  /// Push persisted user settings (bike/rider weight, grade smoothing, VS mode)
  /// onto the active FitnessBikeDefinition so the physics calc uses them even
  /// when the user never opens the details page. No-op for ProxyBikeDefinition
  /// (those settings don't apply) and for WiFi modes whose definition is
  /// created lazily per TCP client — the details page rehydrates on mount.
  String get trainerKey => scanResult.name ?? scanResult.deviceId;

  /// Whether the underlying device looks like a smart trainer (FTMS-capable).
  /// Power-meter-only or HR-only devices have no trainer commands to drive,
  /// so Virtual Shifting is meaningless for them — they stay on Proxy.
  bool get _isSmartTrainer => scanResult.services.any(
    (s) => s.toLowerCase() == FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase(),
  );

  /// Default connect mode when the user hasn't explicitly picked one. Smart
  /// trainers default to Virtual Shifting (transport resolved from the
  /// active Trainer Connection Settings); other devices fall back to Proxy.
  /// When VS is the conceptual default but no transport is enabled in
  /// Connection Settings, falls through to Proxy so the device still works.
  RetrofitMode get defaultRetrofitMode {
    if (!_isSmartTrainer) return RetrofitMode.proxy;
    final transport = core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections);
    return switch (transport) {
      TrainerConnectionType.bluetooth => RetrofitMode.bluetooth,
      TrainerConnectionType.wifi => RetrofitMode.wifi,
      null => RetrofitMode.proxy,
    };
  }

  void applyTrainerSettings() {
    final def = emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) return;
    _seedFitnessBikeDefinition(def);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    emulator.processCharacteristic(characteristic, bytes);
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    if (isConnected) {
      return [
        ValueListenableBuilder<String>(
          valueListenable: emulator.data,
          builder: (context, value, _) {
            if (value.isEmpty) return const SizedBox.shrink();
            final def = emulator.activeDefinition;
            final parts = <Widget>[];
            if (def is ProxyBikeDefinition) {
              _addMetric(parts, context, def.powerW.value, 'W', LucideIcons.zap);
              _addMetric(parts, context, def.heartRateBpm.value, 'bpm', LucideIcons.heart);
              _addMetric(parts, context, def.cadenceRpm.value, 'rpm', LucideIcons.rotateCw);
              final speed = def.speedKph.value;
              if (speed != null) {
                _addMetric(parts, context, speed.round(), 'km/h', LucideIcons.gauge);
              }
            } else if (def is FitnessBikeDefinition) {
              _addMetric(parts, context, def.powerW.value, 'W', LucideIcons.zap);
              _addMetric(parts, context, def.heartRateBpm.value, 'bpm', LucideIcons.heart);
              _addMetric(parts, context, def.cadenceRpm.value, 'rpm', LucideIcons.rotateCw);
              final speed = def.speedKph.value;
              if (speed != null) {
                _addMetric(parts, context, speed.round(), 'km/h', LucideIcons.gauge);
              }
              // Gear (sim / VS mode) or ERG target wattage (erg mode).
              if (def.trainerMode.value == TrainerMode.ergMode) {
                final watts = def.ergTargetPower.value;
                if (watts != null) {
                  _addTextMetric(parts, context, 'ERG $watts W', LucideIcons.target);
                }
              } else {
                _addTextMetric(
                  parts,
                  context,
                  'Gear ${def.currentGear.value}/${def.maxGear}',
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
    return [_buildFeatureList(context)];
  }

  Widget _buildFeatureList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 11, color: cs.mutedForeground);

    final services = scanResult.services.map((s) => s.toLowerCase()).toSet();
    final hasZwiftAdv = services.contains(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase());
    final controller = core.connection.controllerDevices.firstOrNull;
    final supportsWifiProxy = services.contains(FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID.toLowerCase());

    final features = <(IconData, String)>[
      if (!hasZwiftAdv) (LucideIcons.sparkles, 'Add virtual shifting capability'),
      (LucideIcons.slidersHorizontal, 'Adjust virtual shifting gears'),
      if (controller != null) (LucideIcons.gamepad2, 'Direct gear / intensity / mode changes via ${controller.name}'),
      (LucideIcons.dumbbell, 'Start a mini workout'),
      if (supportsWifiProxy) (LucideIcons.wifi, 'Proxy to WiFi'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Connect your $name for:', style: muted),
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

  ActionResult handleTrainerAction(InGameAction action) {
    final def = emulator.activeDefinition;
    if (def is! FitnessBikeDefinition) {
      return NotHandled('No active FitnessBikeDefinition');
    }
    switch (action) {
      case InGameAction.trainerUp:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          final current = def.ergTargetPower.value ?? 150;
          def.setManualErgPower(current + 10);
          return Success('ERG target: ${def.ergTargetPower.value} W');
        } else {
          def.shiftUp();
          unawaited(_triggerKeymapAction(InGameAction.shiftUp));
          return Success('Shifted up to gear ${def.currentGear.value}');
        }
      case InGameAction.trainerDown:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          final current = def.ergTargetPower.value ?? 150;
          def.setManualErgPower(current - 10);
          return Success('ERG target: ${def.ergTargetPower.value} W');
        } else {
          def.shiftDown();
          unawaited(_triggerKeymapAction(InGameAction.shiftDown));
          return Success('Shifted down to gear ${def.currentGear.value}');
        }
      case InGameAction.trainerSwitchMode:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          def.exitErgMode();
          return Success('Switched to sim mode');
        } else {
          final current = def.ergTargetPower.value ?? 150;
          def.setManualErgPower(current);
          return Success('Switched to erg mode @ $current W');
        }
      case InGameAction.trainerIntensityUp:
        def.adjustIntensity(0.05);
        return Success('Intensity +5%');
      case InGameAction.trainerIntensityDown:
        def.adjustIntensity(-0.05);
        return Success('Intensity -5%');
      default:
        return NotHandled('');
    }
  }

  /// Fires the user-defined [inGameAction] from the active keymap, if any.
  /// Used so that virtual-shifting trainer actions (trainerUp/Down) can also
  /// surface as the keymap's shift actions in the connected app.
  Future<void> _triggerKeymapAction(InGameAction inGameAction) async {
    final keymap = core.actionHandler.supportedApp?.keymap;
    if (keymap == null) return;
    final keyPair = keymap.keyPairs.firstOrNullWhere(
      (kp) => kp.inGameAction == inGameAction && !kp.hasNoAction,
    );
    final button = keyPair?.buttons.firstOrNull;
    if (keyPair == null || button == null) return;

    await core.actionHandler.performAction(
      button,
      isKeyDown: true,
      isKeyUp: true,
      trigger: keyPair.trigger,
    );
  }

  @override
  Future<void> connect() async {
    // ProxyDevice intentionally skips the upstream auto-connect — BLE is only
    // opened once the user explicitly starts the emulator via startProxy().
    // If they connected previously and haven't since tapped Disconnect,
    // honour that intent by kicking off startProxy() here (fire-and-forget).
    if (!isStarting.value && !emulator.isStarted.value && core.settings.getAutoConnect(trainerKey)) {
      final savedMode = core.settings.getRetrofitMode(trainerKey, fallback: defaultRetrofitMode);
      emulator.setRetrofitMode(savedMode);
      await startProxy();
    }
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
    isStarting.value = true;
    try {
      await super.connect();
    } finally {
      isStarting.value = false;
    }
  }

  @override
  Future<void> disconnect() {
    emulator.isConnected.removeListener(_syncBridgeTracking);
    emulator.retrofitMode.removeListener(_syncBridgeTracking);
    _bridgeBudgetSub?.cancel();
    _bridgeBudgetSub = null;
    core.bridgeUsageTracker.stopSession();
    emulator.stop();
    return super.disconnect();
  }
}
