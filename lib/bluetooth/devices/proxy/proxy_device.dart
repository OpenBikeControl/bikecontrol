import 'dart:async';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
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

  ProxyDevice(super.scanResult)
    : super(
        availableButtons: const [],
        icon: _iconFor(scanResult),
      ) {
    emulator.onFitnessBikeDefinitionCreated = _seedFitnessBikeDefinition;
    emulator.advertisementNameOverride = () {
      return IAPManager.instance.isProEnabledForCurrentDevice ? null : 'BikeControl - 20 min trial';
    };
    emulator.isConnected.addListener(_syncBridgeTracking);
    emulator.retrofitMode.addListener(_syncBridgeTracking);
  }

  void _syncBridgeTracking() {
    // Only count minutes when a trainer app is actually consuming the Bridge
    // (isConnected), not merely while we're advertising (isStarted).
    final isBridgeSession = emulator.isConnected.value && emulator.retrofitMode.value != RetrofitMode.proxy;
    final isPro = IAPManager.instance.isProEnabledForCurrentDevice;
    if (isBridgeSession && !isPro) {
      if (core.bridgeUsageTracker.isExhausted) {
        // Already at daily limit — stop the transporters but keep the upstream
        // BLE connection. The user can reconnect tomorrow or after going Pro.
        emulator.stop();
        return;
      }
      core.bridgeUsageTracker.startSession();
      _bridgeBudgetSub ??= core.bridgeUsageTracker.onBudgetExhausted.listen((_) {
        // Stop the Bridge (transporters + mDNS) but leave the upstream BLE
        // trainer connection intact so the user sees live data.
        emulator.stop();
      });
    } else {
      core.bridgeUsageTracker.stopSession();
    }
  }

  void _seedFitnessBikeDefinition(FitnessBikeDefinition def) {
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

    await emulator.startServer();
    applyTrainerSettings();
    // Read the trainer's FTMS Feature map proactively so the UI can gate
    // virtual-shifting options and the feedback payload can report it. Runs
    // off the critical path — failures just leave trainerFeature null.
    final def = emulator.activeDefinition;
    if (def is FitnessBikeDefinition) unawaited(def.probeTrainerFeatures());
    onChange.value = 'Connected to ${scanResult.name}';
  }

  /// Push persisted user settings (bike/rider weight, grade smoothing, VS mode)
  /// onto the active FitnessBikeDefinition so the physics calc uses them even
  /// when the user never opens the details page. No-op for ProxyBikeDefinition
  /// (those settings don't apply) and for WiFi modes whose definition is
  /// created lazily per TCP client — the details page rehydrates on mount.
  String get trainerKey => scanResult.name ?? scanResult.deviceId;

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
    return [
      ValueListenableBuilder<RetrofitMode>(
        valueListenable: emulator.retrofitMode,
        builder: (context, mode, _) {
          final icon = switch (mode) {
            RetrofitMode.proxy => LucideIcons.wifi,
            RetrofitMode.wifi => LucideIcons.cog,
            RetrofitMode.bluetooth => LucideIcons.bluetooth,
          };
          return ValueListenableBuilder<bool>(
            valueListenable: emulator.isConnected,
            builder: (context, connected, _) => Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: connected ? const Color(0xFF22C55E) : Theme.of(context).colorScheme.mutedForeground,
                ),
                Text(
                  connected ? 'Bridge live' : 'Waiting for connection...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ];
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    if (!isConnected) return const [];
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
          }
          if (parts.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(left: 60.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: parts,
            ),
          );
        },
      ),
    ];
  }

  void _addMetric(List<Widget> parts, BuildContext context, int? value, String unit, IconData icon) {
    if (value == null) return;
    parts.add(
      Container(
        constraints: BoxConstraints(minWidth: 52),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(icon, size: 12, color: Theme.of(context).colorScheme.mutedForeground),
            Text(
              '$value $unit',
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
          return Success('Shifted up to gear ${def.currentGear.value}');
        }
      case InGameAction.trainerDown:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          final current = def.ergTargetPower.value ?? 150;
          def.setManualErgPower(current - 10);
          return Success('ERG target: ${def.ergTargetPower.value} W');
        } else {
          def.shiftDown();
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

  @override
  Future<void> connect() async {
    // ProxyDevice intentionally skips the upstream auto-connect — BLE is only
    // opened once the user explicitly starts the emulator via startProxy().
    // If they connected previously and haven't since tapped Disconnect,
    // honour that intent by kicking off startProxy() here (fire-and-forget).
    if (!isStarting.value && !emulator.isStarted.value && core.settings.getAutoConnect(trainerKey)) {
      final savedMode = core.settings.getRetrofitMode(trainerKey);
      emulator.setRetrofitMode(savedMode);
      await startProxy();
    }
  }

  Future<void> startProxy() async {
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
