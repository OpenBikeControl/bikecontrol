import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/widgets/status_icon.dart';
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
            if (!isConnected)
              Button.primary(
                style: ButtonStyle.primary(size: ButtonSize.small),
                onPressed: () {
                  super.connect();
                },
                child: Text('Proxy'),
              )
            else
              StatusIcon(
                status: emulator.isConnected.value,
                icon: Icons.wifi,
                started: emulator.isStarted.value,
              ),
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
