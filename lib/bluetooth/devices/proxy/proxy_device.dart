import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/dircon/fitness_dircon.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class ProxyDevice extends BluetoothDevice {
  static final List<String> proxyServiceUUIDs = [
    //FitnessDircon.HEART_RATE_SERVICE_UUID, // Heart Rate
    FitnessDircon.CYCLING_POWER_SERVICE_UUID, // Heart Rate
    FitnessDircon.FITNESS_MACHINE_SERVICE_UUID, // Fitness Machine
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

    emulator.startServer();
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    emulator.processCharacteristic(characteristic, bytes);
  }

  @override
  Widget showInformation(BuildContext context, {required bool showFull}) {
    return Column(
      children: [
        Row(
          spacing: 16,
          children: [
            Expanded(child: super.showInformation(context, showFull: showFull)),
            if (!isConnected) ...[
              Button.primary(
                style: ButtonStyle.primary(size: ButtonSize.small),
                onPressed: () {
                  super.connect();
                },
                child: Text('Proxy'),
              ),
              if (scanResult.services.any((service) => service == FitnessDircon.CYCLING_POWER_SERVICE_UUID))
                Button.primary(
                  style: ButtonStyle.primary(size: ButtonSize.small),
                  onPressed: () {
                    emulator.setRetrofit(true);
                    super.connect();
                  },
                  child: Text('Retrofit'),
                ),
            ] else ...[
              if (kDebugMode)
                Button.primary(
                  style: ButtonStyle.primary(size: ButtonSize.small),
                  onPressed: () async {
                    await emulator.debug();
                  },
                  child: Text('Debug'),
                ),
              StatusIcon(
                status: emulator.isConnected.value,
                icon: Icons.wifi,
                started: emulator.isStarted.value,
              ),
            ],
          ],
        ),
        if (isConnected)
          ValueListenableBuilder(
            valueListenable: emulator.data,
            builder: (context, value, child) {
              return value.isNotEmpty ? Text('Data: $value') : const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() {
    emulator.stop();
    return super.disconnect();
  }
}
