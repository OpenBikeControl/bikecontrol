import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
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
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    emulator.processCharacteristic(characteristic, bytes);
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    if (!isConnected) return const [];
    return [
      ValueListenableBuilder<bool>(
        valueListenable: emulator.isConnected,
        builder: (context, connected, _) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(
              Icons.wifi,
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
      ),
    ];
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
