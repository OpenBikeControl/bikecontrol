import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:prop/emulators/ftms_emulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class ProxyDevice extends BluetoothDevice {
  static final List<String> proxyServiceUUIDs = [
    '0000180d-0000-1000-8000-00805f9b34fb', // Heart Rate
    '00001818-0000-1000-8000-00805f9b34fb', // Cycling Power
    '00001826-0000-1000-8000-00805f9b34fb', // Fitness Machine
  ];

  final FtmsEmulator emulator = FtmsEmulator();

  ProxyDevice(super.scanResult)
    : super(
        availableButtons: const [],
        isBeta: true,
      );

  late final List<BleService> services;

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
  Widget showInformation(BuildContext context) {
    return Column(
      spacing: 16,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        super.showInformation(context),
        if (!isConnected)
          Button.primary(
            style: ButtonStyle.primary(size: ButtonSize.small),
            onPressed: () {
              super.connect();
            },
            child: Text('Proxy'),
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
