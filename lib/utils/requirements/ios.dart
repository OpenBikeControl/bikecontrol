import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:swift_control/utils/requirements/platform.dart';

final pm = PeripheralManager();

Future<void> startHidPeripheral() async {
  // 1) Build characteristics
  final hidInfo = GATTCharacteristic.immutable(
    uuid: UUID.fromString('2A4A'),
    value: Uint8List.fromList([0x11, 0x01, 0x00, 0x02]),
    descriptors: [], // HID v1.11, country=0, flags=2
  );

  final reportMap = GATTCharacteristic.immutable(
    uuid: UUID.fromString('2A4B'),
    value: Uint8List.fromList([
      // Mouse descriptor bytes …
    ]),
    descriptors: [],
  );

  final protocolMode = GATTCharacteristic.immutable(
    uuid: UUID.fromString('2A4E'),
    value: Uint8List.fromList([0x01]), // Report Protocol
    descriptors: [],
  );

  // Input report characteristic (notify)
  final inputReport = GATTCharacteristic.mutable(
    uuid: UUID.fromString('2A4D'),
    permissions: [GATTCharacteristicPermission.read, GATTCharacteristicPermission.write],
    properties: [GATTCharacteristicProperty.notify, GATTCharacteristicProperty.read],
    descriptors: [
      GATTDescriptor.immutable(
        // Report Reference: ID=1, Type=Input(1)
        uuid: UUID.fromString('2908'),
        value: Uint8List.fromList([0x01, 0x01]),
      ),
    ],
  );

  // 2) HID service
  final hidService = GATTService(
    uuid: UUID.fromString('1812'),
    isPrimary: true,
    characteristics: [hidInfo, reportMap, protocolMode, inputReport],
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

  final advertisement = Advertisement(name: 'SwiftControl', serviceUUIDs: [UUID.fromString('1812')]);
  await pm.startAdvertising(advertisement);
}

/*
// Send a relative mouse move + button state as 3-byte report: [buttons, dx, dy]
Future<void> sendMouseReport(int buttons, int dx, int dy) async {
  final data = Uint8List.fromList([buttons & 0x07, dx & 0xFF, dy & 0xFF]);
  await pm.notifyCharacteristic(UUID.fromString('1812'), UUID.fromString('2A4D'), data);
}*/

class PairRequirement extends PlatformRequirement {
  PairRequirement() : super('Pair to your other iOS device');

  @override
  Future<void> call() async {
    await startHidPeripheral();
  }

  @override
  Future<void> getStatus() async {
    status = false;
  }
}
