import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/base_actions.dart';
import 'package:swift_control/utils/actions/ios.dart';
import 'package:swift_control/utils/requirements/platform.dart';

final peripheralManager = PeripheralManager();
bool _isAdvertising = false;
bool _isSubscribedToEvents = false;

class ConnectRequirement extends PlatformRequirement {
  ConnectRequirement() : super('Connect to your other iOS device');

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  Future<void> startAdvertising(VoidCallback onUpdate) async {
    if (Platform.isAndroid) {
      await peripheralManager.authorize();
    }
    await peripheralManager.removeAllServices();

    final reportMapDataAbsolute = Uint8List.fromList([
      0x05, 0x01, // Usage Page (Generic Desktop)
      0x09, 0x02, // Usage (Mouse)
      0xA1, 0x01, // Collection (Application)
      0x85, 0x01, //   Report ID (1)
      0x09, 0x01, //   Usage (Pointer)
      0xA1, 0x00, //   Collection (Physical)
      0x05, 0x09, //     Usage Page (Button)
      0x19, 0x01, //     Usage Min (1)
      0x29, 0x03, //     Usage Max (3)
      0x15, 0x00, //     Logical Min (0)
      0x25, 0x01, //     Logical Max (1)
      0x95, 0x03, //     Report Count (3)
      0x75, 0x01, //     Report Size (1)
      0x81, 0x02, //     Input (Data,Var,Abs)  // buttons
      0x95, 0x01, //     Report Count (1)
      0x75, 0x05, //     Report Size (5)
      0x81, 0x03, //     Input (Const,Var,Abs) // padding
      0x05, 0x01, //     Usage Page (Generic Desktop)
      0x09, 0x30, //     Usage (X)
      0x09, 0x31, //     Usage (Y)
      0x15, 0x00, //     Logical Min (0)
      0x25, 0x64, //     Logical Max (100)
      0x75, 0x08, //     Report Size (8)
      0x95, 0x02, //     Report Count (2)
      0x81, 0x02, //     Input (Data,Var,Abs)
      0xC0,
      0xC0,
    ]);

    // 1) Build characteristics
    final hidInfo = GATTCharacteristic.immutable(
      uuid: UUID.fromString('2A4A'),
      value: Uint8List.fromList([0x11, 0x01, 0x00, 0x02]),
      descriptors: [], // HID v1.11, country=0, flags=2
    );

    final reportMap = GATTCharacteristic.immutable(
      uuid: UUID.fromString('2A4B'),
      //properties: [GATTCharacteristicProperty.read],
      //permissions: [GATTCharacteristicPermission.read],
      value: reportMapDataAbsolute,
      descriptors: [
        GATTDescriptor.immutable(uuid: UUID.fromString('2908'), value: Uint8List.fromList([0x0, 0x0])),
      ],
    );

    final protocolMode = GATTCharacteristic.mutable(
      uuid: UUID.fromString('2A4E'),
      properties: [GATTCharacteristicProperty.read, GATTCharacteristicProperty.writeWithoutResponse],
      permissions: [GATTCharacteristicPermission.read, GATTCharacteristicPermission.write],
      descriptors: [],
    );

    final hidControlPoint = GATTCharacteristic.mutable(
      uuid: UUID.fromString('2A4C'),
      properties: [GATTCharacteristicProperty.writeWithoutResponse],
      permissions: [GATTCharacteristicPermission.write],
      descriptors: [],
    );

    // Input report characteristic (notify)
    final inputReport = GATTCharacteristic.mutable(
      uuid: UUID.fromString('2A4D'),
      permissions: [GATTCharacteristicPermission.read],
      properties: [GATTCharacteristicProperty.notify, GATTCharacteristicProperty.read],
      descriptors: [
        GATTDescriptor.immutable(
          // Report Reference: ID=1, Type=Input(1)
          uuid: UUID.fromString('2908'),
          value: Uint8List.fromList([0x01, 0x01]),
        ),
      ],
    );
    // Input report characteristic (notify)
    final keyboardInputReport = GATTCharacteristic.mutable(
      uuid: UUID.fromString('2A4D'),
      permissions: [GATTCharacteristicPermission.read],
      properties: [GATTCharacteristicProperty.notify, GATTCharacteristicProperty.read],
      descriptors: [
        GATTDescriptor.immutable(
          // Report Reference: ID=1, Type=Input(1)
          uuid: UUID.fromString('2908'),
          value: Uint8List.fromList([0x02, 0x01]),
        ),
      ],
    );

    final outputReport = GATTCharacteristic.mutable(
      uuid: UUID.fromString('2A4D'),
      permissions: [GATTCharacteristicPermission.read, GATTCharacteristicPermission.write],
      properties: [
        GATTCharacteristicProperty.read,
        GATTCharacteristicProperty.write,
        GATTCharacteristicProperty.writeWithoutResponse,
      ],
      descriptors: [
        GATTDescriptor.immutable(
          // Report Reference: ID=1, Type=Input(1)
          uuid: UUID.fromString('2908'),
          value: Uint8List.fromList([0x02, 0x02]),
        ),
      ],
    );

    // 2) HID service
    final hidService = GATTService(
      uuid: UUID.fromString('00001812-0000-1000-8000-00805F9B34FB'),
      isPrimary: true,
      characteristics: [
        hidInfo,
        reportMap,
        protocolMode,
        outputReport,
        hidControlPoint,
        keyboardInputReport,
        inputReport,
      ],
      includedServices: [],
    );

    if (!_isSubscribedToEvents) {
      _isSubscribedToEvents = true;
      peripheralManager.characteristicReadRequested.forEach((char) {
        print('Read request for characteristic: ${char}');
        // You can respond to read requests here if needed
      });

      if (Platform.isAndroid) {
        peripheralManager.connectionStateChanged.forEach((state) {
          print('Peripheral connection state: ${state.state}');
        });
        peripheralManager.stateChanged.forEach((state) {
          print('Peripheral manager state: ${state.state}');
        });
      }

      peripheralManager.characteristicNotifyStateChanged.forEach((char) {
        if (char.characteristic.uuid == inputReport.uuid) {
          if (char.state) {
            (actionHandler as AccessibilityActions).setConnectedCentral(char.central, char.characteristic);
          } else {
            (actionHandler as AccessibilityActions).setConnectedCentral(null, null);
          }
          onUpdate();
        }
        print(
          'Notify state changed for characteristic: ${char.characteristic.uuid} vs ${char.characteristic.uuid == inputReport.uuid}: ${char.state}',
        );
      });
    }
    await peripheralManager.addService(hidService);

    // 3) Optional Battery service
    await peripheralManager.addService(
      GATTService(
        uuid: UUID.fromString('180F'),
        isPrimary: true,
        characteristics: [
          GATTCharacteristic.immutable(
            uuid: UUID.fromString('2A19'),
            value: Uint8List.fromList([100]),
            descriptors: [],
          ),
        ],
        includedServices: [],
      ),
    );

    final advertisement = Advertisement(
      name: 'SwiftControl',
      serviceUUIDs: [UUID.fromString('00001812-0000-1000-8000-00805F9B34FB')],
    );
    /*pm.connectionStateChanged.forEach((state) {
    print('Peripheral connection state: $state');
  });*/
    print('Starting advertising with HID service...');

    await peripheralManager.startAdvertising(advertisement);
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return StatefulBuilder(
      builder:
          (context, setState) => Column(
            spacing: 10,
            children: [
              Row(
                spacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (_isAdvertising) {
                        await peripheralManager.stopAdvertising();
                        _isAdvertising = false;
                        (actionHandler as AccessibilityActions).setConnectedCentral(null, null);
                        onUpdate();
                        setState(() {});
                      } else {
                        _isAdvertising = true;
                        setState(() {});
                        await startAdvertising(onUpdate);
                      }
                    },
                    child: Text(_isAdvertising ? 'Stop Pairing' : 'Start Pairing'),
                  ),
                  if (_isAdvertising) SizedBox(height: 20, width: 20, child: CircularProgressIndicator()),
                  if (kDebugMode)
                    ElevatedButton(
                      onPressed: () {
                        final instance = IosActions();
                        instance.setConnectedCentral(
                          (actionHandler as AccessibilityActions).connectedCentral,
                          (actionHandler as AccessibilityActions).connectedCharacteristic,
                        );
                        instance.sendAbsMouseReport(0, 90, 90);
                        instance.sendAbsMouseReport(1, 90, 90);
                        instance.sendAbsMouseReport(0, 90, 90);
                      },
                      child: Text('Test'),
                    ),
                ],
              ),
              if (_isAdvertising)
                Text(
                  'On your other iOS device, go to Settings > Accessibility > Touch > AssistiveTouch > Pointer Devices > Devices and pair your device. Make sure to AssistiveTouch is enabled.',
                ),
            ],
          ),
    );
  }

  @override
  Future<void> getStatus() async {
    status = (actionHandler as AccessibilityActions).isConnected;
  }
}
