import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/utils/requirements/platform.dart';

final pm = PeripheralManager();

Central? _connectedCentral;
GATTCharacteristic? _connectedCharacteristic;

Future<void> startHidPeripheral() async {
  final reportMapData = Uint8List.fromList([
    // Mouse (Report ID 1)
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x02, // Usage (Mouse)
    0xA1, 0x01, // Collection (Application)
    0x85, 0x01, //   Report ID (1)
    0x09, 0x01, //   Usage (Pointer)
    0xA1, 0x00, //   Collection (Physical)
    0x05, 0x09, //     Usage Page (Buttons)
    0x19, 0x01, //     Usage Minimum (1)
    0x29, 0x03, //     Usage Maximum (3)
    0x15, 0x00, //     Logical Minimum (0)
    0x25, 0x01, //     Logical Maximum (1)
    0x95, 0x03, //     Report Count (3)
    0x75, 0x01, //     Report Size (1)
    0x81, 0x02, //     Input (Data, Variable, Absolute)
    0x95, 0x01, //     Report Count (1)
    0x75, 0x05, //     Report Size (5)
    0x81, 0x03, //     Input (Constant, Variable, Absolute)
    0x05, 0x01, //     Usage Page (Generic Desktop)
    0x09, 0x30, //     Usage (X)
    0x09, 0x31, //     Usage (Y)
    0x15, 0x81, //     Logical Minimum (-127)
    0x25, 0x7F, //     Logical Maximum (127)
    0x75, 0x08, //     Report Size (8)
    0x95, 0x02, //     Report Count (2)
    0x81, 0x06, //     Input (Data, Variable, Relative)
    0xC0, //   End Collection
    0xC0, // End Collection
    // Keyboard (Report ID 2)A
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x06, // Usage (Keyboard)
    0xA1, 0x01, // Collection (Application)
    0x85, 0x02, //   Report ID (2)
    0x05, 0x07, // Usage Page (Key Codes)
    0x19, 0xE0, // Usage Minimum (224)
    0x29, 0xE7, // Usage Maximum (231)
    0x15, 0x00, // Logical Minimum (0)
    0x25, 0x01, // Logical Maximum (1)
    0x75, 0x01, // Report Size (1)
    0x95, 0x08, // Report Count (8)
    0x81, 0x02, // Input (Data, Variable, Absolute) ; Modifier byte
    0x95, 0x01, // Report Count (1)
    0x75, 0x08, // Report Size (8)
    0x81, 0x01, // Input (Constant) ; Reserved byte
    0x95, 0x05, // Report Count (5)
    0x75, 0x01, // Report Size (1)
    0x05, 0x08, // Usage Page (LEDs)
    0x19, 0x01, // Usage Minimum (1)
    0x29, 0x05, // Usage Maximum (5)
    0x91, 0x02, // Output (Data, Variable, Absolute) ; LED report
    0x95, 0x01, // Report Count (1)
    0x75, 0x03, // Report Size (3)
    0x91, 0x01, // Output (Constant) ; Padding
    0x95, 0x06, // Report Count (6)
    0x75, 0x08, // Report Size (8)
    0x15, 0x00, // Logical Minimum (0)
    0x25, 0x65, // Logical Maximum (101)
    0x05, 0x07, // Usage Page (Key Codes)
    0x19, 0x00, // Usage Minimum (0)
    0x29, 0x65, // Usage Maximum (101)
    0x81, 0x00, // Input (Data, Array) ; Key arrays (6 bytes)
    0xC0, // End Collection
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
    value: reportMapData,
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

  await pm.addService(hidService);

  // 3) Optional Battery service
  await pm.addService(
    GATTService(
      uuid: UUID.fromString('180F'),
      isPrimary: true,
      characteristics: [
        GATTCharacteristic.immutable(uuid: UUID.fromString('2A19'), value: Uint8List.fromList([100]), descriptors: []),
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

  pm.characteristicReadRequested.forEach((char) {
    print('Read request for characteristic: ${char}');
    // You can respond to read requests here if needed
  });

  pm.characteristicNotifyStateChanged.forEach((char) {
    _connectedCentral = char.central;
    _connectedCharacteristic = char.characteristic;
    print('Notify state changed for characteristic: ${char.characteristic.uuid}');
  });

  await pm.startAdvertising(advertisement);
}

// Send a relative mouse move + button state as 3-byte report: [buttons, dx, dy]
Future<void> sendMouseReport(int buttons, int dx, int dy) async {
  final data = Uint8List.fromList([buttons & 0x07, dx & 0xFF, dy & 0xFF]);
  await pm.notifyCharacteristic(_connectedCentral!, _connectedCharacteristic!, value: data);
}

class ConnectRequirement extends PlatformRequirement {
  ConnectRequirement() : super('Connect to your other iOS device');

  @override
  Future<void> call() async {
    await startHidPeripheral();
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return Row(
      spacing: 10,
      children: [
        ElevatedButton(
          onPressed: () async {
            await call();
            onUpdate();
          },
          child: Text('Start Pairing'),
        ),
        ElevatedButton(
          onPressed: () async {
            sendMouseReport(1, 20, 20);
          },
          child: Text('Simulate'),
        ),
        ElevatedButton(
          onPressed: () async {
            sendMouseReport(1, -20, -20);
          },
          child: Text('Simulate'),
        ),
      ],
    );
  }

  @override
  Future<void> getStatus() async {
    status = false;
  }
}
