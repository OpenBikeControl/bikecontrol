import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/utils/requirements/platform.dart';

final pm = PeripheralManager();

Central? _connectedCentral;
GATTCharacteristic? _connectedCharacteristic;

Future<void> startHidPeripheral() async {
  final reportMapDataRelative = Uint8List.fromList([
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
    // End Collection
  ]);

  final reportMapDataAbsolute = Uint8List.fromList([
    0x05, 0x01, // Usage Page (Generic Desktop)
    0x09, 0x02, // Usage (Mouse)
    0xA1, 0x01, // Collection (Application)
    0x85, 0x01, //   Report ID (1)
    0x09, 0x01, //   Usage (Pointer)
    0xA1, 0x00, //   Collection (Physical)
    0x05, 0x09, //     Usage Page (Buttons)
    0x19, 0x01, //     Usage Minimum (1)
    0x29, 0x03, //     Usage Maximum (3)
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
    0x26, 0xFF, 0x7F, //     Logical Max (32767)
    0x75, 0x10, //     Report Size (16 bits per axis)
    0x95, 0x02, //     Report Count (2 axes)
    0x81, 0x02, //     Input (Data,Var,Abs)  // ABSOLUTE
    0xC0, //   End Collection
    0xC0, // End Collection
  ]);

  final reportMapData = Uint8List.fromList([
    0x05, 0x0d, // USAGE_PAGE (Digitizers)
    0x09, 0x04, // USAGE (Touch Screen)
    0xa1, 0x01, // COLLECTION (Application)
    0x85, 0x02, //   REPORT_ID (Touch)
    0x09, 0x20, //   USAGE (Stylus)
    0xa1, 0x00, //   COLLECTION (Physical)
    0x09, 0x42, //     USAGE (Tip Switch)
    0x15, 0x00, //     LOGICAL_MINIMUM (0)
    0x25, 0x01, //     LOGICAL_MAXIMUM (1)
    0x75, 0x01, //     REPORT_SIZE (1)
    0x95, 0x01, //     REPORT_COUNT (1)
    0x81, 0x02, //     INPUT (Data,Var,Abs)
    0x95, 0x03, //     REPORT_COUNT (3)
    0x81, 0x03, //     INPUT (Cnst,Ary,Abs)
    0x09, 0x32, //     USAGE (In Range)
    0x09, 0x47, //     USAGE (Confidence)
    0x95, 0x02, //     REPORT_COUNT (2)
    0x81, 0x02, //     INPUT (Data,Var,Abs)
    0x95, 0x0a, //     REPORT_COUNT (10)
    0x81, 0x03, //     INPUT (Cnst,Ary,Abs)
    0x05, 0x01, //     USAGE_PAGE (Generic Desktop)
    0x26, 0xff, 0x7f, //     LOGICAL_MAXIMUM (32767)
    0x75, 0x10, //     REPORT_SIZE (16)
    0x95, 0x01, //     REPORT_COUNT (1)
    0xa4, //     PUSH
    0x55, 0x0d, //     UNIT_EXPONENT (-3)
    0x65, 0x00, //     UNIT (None)
    0x09, 0x30, //     USAGE (X)
    0x35, 0x00, //     PHYSICAL_MINIMUM (0)
    0x46, 0x00, 0x00, //     PHYSICAL_MAXIMUM (0)
    0x81, 0x02, //     INPUT (Data,Var,Abs)
    0x09, 0x31, //     USAGE (Y)
    0x46, 0x00, 0x00, //     PHYSICAL_MAXIMUM (0)
    0x81, 0x02, //     INPUT (Data,Var,Abs)
    0xb4, //     POP
    0x05, 0x0d, //     USAGE PAGE (Digitizers)
    0x09, 0x48, //     USAGE (Width)
    0x09, 0x49, //     USAGE (Height)
    0x95, 0x02, //     REPORT_COUNT (2)
    0x81, 0x02, //     INPUT (Data,Var,Abs)
    0x95, 0x01, //     REPORT_COUNT (1)
    0x81, 0x03, //     INPUT (Cnst,Ary,Abs)
    0xc0, //   END_COLLECTION
    0xc0, // END_COLLECTION
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
    print(
      'Notify state changed for characteristic: ${char.characteristic.uuid} vs ${char.characteristic.uuid == inputReport.uuid}',
    );
  });

  await pm.startAdvertising(advertisement);
}

// Send a relative mouse move + button state as 3-byte report: [buttons, dx, dy]
Future<void> sendMouseReport(int buttons, int dx, int dy) async {
  final data = Uint8List.fromList([buttons & 0x07, dx & 0xFF, dy & 0xFF]);
  await pm.notifyCharacteristic(_connectedCentral!, _connectedCharacteristic!, value: data);
}

Uint8List absMouseReport(int buttons3bit, int x, int y) {
  final b = buttons3bit & 0x07; // lower 3 bits used
  return Uint8List.fromList([
    0x01, // Report ID
    b, // buttons + implicit padding
    x & 0xFF, (x >> 8) & 0xFF, // X 0..32767
    y & 0xFF, (y >> 8) & 0xFF, // Y 0..32767
  ]);
}

// Send a relative mouse move + button state as 3-byte report: [buttons, dx, dy]
Future<void> sendAbsMouseReport(int buttons, int dx, int dy) async {
  await pm.notifyCharacteristic(_connectedCentral!, _connectedCharacteristic!, value: absMouseReport(buttons, dx, dy));
}

class ConnectRequirement extends PlatformRequirement {
  ConnectRequirement() : super('Connect to your other iOS device');

  @override
  Future<void> call() async {
    if (Platform.isAndroid) {
      await pm.authorize();
    }
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
            sendAbsMouseReport(1, (32767 / 2).toInt(), (32767 / 2).toInt());
          },
          child: Text('1'),
        ),
        ElevatedButton(
          onPressed: () async {
            sendAbsMouseReport(1, 10, 10);
          },
          child: Text('2'),
        ),
      ],
    );
  }

  @override
  Future<void> getStatus() async {
    status = false;
  }
}
