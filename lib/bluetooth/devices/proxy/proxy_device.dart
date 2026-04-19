import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:prop/prop.dart';
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

  ProxyDevice(super.scanResult)
    : super(
        availableButtons: const [],
        isBeta: true,
      );

  @override
  Future<void> handleServices(List<BleService> services) async {
    emulator.setScanResult(scanResult);
    emulator.handleServices(services);

    await emulator.startServer();
    applyTrainerSettings();
    onChange.value = 'Connected to ${scanResult.name}';
  }

  /// Push persisted user settings (bike/rider weight, grade smoothing, VS mode)
  /// onto the active FitnessBikeDefinition so the physics calc uses them even
  /// when the user never opens the details page. No-op for ProxyBikeDefinition
  /// (those settings don't apply) and for WiFi modes whose definition is
  /// created lazily per TCP client — the details page rehydrates on mount.
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

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    emulator.processCharacteristic(characteristic, bytes);
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    if (!isConnected) return const [];
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
                  connected ? 'Bridge live' : 'Bridge idle',
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
      case InGameAction.trainerShiftUp:
        def.shiftUp();
        return Success('Shifted up to gear ${def.currentGear.value}');
      case InGameAction.trainerShiftDown:
        def.shiftDown();
        return Success('Shifted down to gear ${def.currentGear.value}');
      case InGameAction.trainerErgIncrease:
        final current = def.ergTargetPower.value ?? 150;
        def.setManualErgPower(current + 10);
        return Success('ERG target: ${def.ergTargetPower.value} W');
      case InGameAction.trainerErgDecrease:
        final current = def.ergTargetPower.value ?? 150;
        def.setManualErgPower(current - 10);
        return Success('ERG target: ${def.ergTargetPower.value} W');
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
  Future<void> connect() async {}

  Future<void> startProxy() => super.connect();

  @override
  Future<void> disconnect() {
    emulator.stop();
    return super.disconnect();
  }
}
