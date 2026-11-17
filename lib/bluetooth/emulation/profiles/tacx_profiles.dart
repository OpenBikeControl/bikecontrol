import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../../devices/tacx/tacx_neo_bike.dart';
import '../emulated_ble_platform.dart';
import '../emulated_peripherals.dart';
import '../emulation_profile.dart';

/// The gear tables the emulated bike answers with (teeth).
const tacxEmulatedFrontTable = [34, 50];
const tacxEmulatedRearTable = [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30];

/// A gear status frame carrying both gears.
List<int> tacxGearFrame({required int front, required int rear}) => [0x03, front, rear];

/// A button frame carrying both buttons.
List<int> tacxButtonFrame({required bool left, required bool right}) => [
  0x03,
  left ? 0x80 : 0x00,
  right ? 0x80 : 0x00,
];

/// Answers the gear table requests on the control point.
void autoRespondToTacxGearRequests(FakeUniversalBlePlatform ble, FakePeripheral peripheral) {
  peripheral.onWrite = (service, characteristic, value) {
    if (characteristic.toLowerCase() != TacxNeoBikeConstants.CONTROL_POINT_UUID || value.isEmpty) return;
    final table = switch (value[0]) {
      TacxNeoBikeConstants.OPCODE_FRONT_GEARS => tacxEmulatedFrontTable,
      TacxNeoBikeConstants.OPCODE_REAR_GEARS => tacxEmulatedRearTable,
      _ => null,
    };
    if (table == null) return;
    ble.notify(peripheral.deviceId, TacxNeoBikeConstants.CONTROL_POINT_UUID, [
      TacxControlPointResponse.responseCode,
      value[0],
      TacxControlPointResponse.success,
      table.length,
      ...table,
    ]);
  };
}

/// A Tacx NEO Bike: the FTMS trainer GATT plus the vendor service with the
/// shifters. [withVendorService] false is a bike on old firmware.
FakePeripheral buildTacxNeoBike({
  String deviceId = 'emulated:tacx-neo-bike',
  String name = 'Tacx Neo Bike 12345',
  bool withVendorService = true,
  int features = 0x0087,
}) {
  final peripheral = buildFtmsTrainer(deviceId: deviceId, name: name);
  if (withVendorService) {
    peripheral.services.add(
      BleService(TacxNeoBikeConstants.SERVICE_UUID, [
        bleChar(TacxNeoBikeConstants.FEATURES_UUID, [CharacteristicProperty.read]),
        bleChar(TacxNeoBikeConstants.ERRORS_UUID, [CharacteristicProperty.notify]),
        bleChar(TacxNeoBikeConstants.GEAR_STATUS_UUID, [CharacteristicProperty.notify]),
        bleChar(TacxNeoBikeConstants.BUTTONS_UUID, [CharacteristicProperty.notify]),
        bleChar(TacxNeoBikeConstants.CONTROL_POINT_UUID, [
          CharacteristicProperty.write,
          CharacteristicProperty.indicate,
        ]),
      ]),
    );
    peripheral.readValues[TacxNeoBikeConstants.FEATURES_UUID] = Uint8List.fromList([
      features & 0xff,
      (features >> 8) & 0xff,
    ]);
  }
  return peripheral;
}

final tacxNeoBikeProfile = EmulationProfile(
  name: 'Tacx NEO Bike (trainer + shifters)',
  category: EmulationCategory.controller,
  build: buildTacxNeoBike,
  onRegistered: autoRespondToTacxGearRequests,
  inputs: (session) {
    var front = 1;
    var rear = 5;
    void send() => session.notify(
      TacxNeoBikeConstants.GEAR_STATUS_UUID,
      tacxGearFrame(front: tacxEmulatedFrontTable[front], rear: tacxEmulatedRearTable[rear]),
    );
    EmulatedButton shift(String label, void Function() change) => EmulatedButton(
      label,
      onDown: () {
        change();
        send();
      },
      onUp: () {},
    );
    EmulatedButton button(String label, {required bool left}) => EmulatedButton(
      label,
      onDown: () => session.notify(TacxNeoBikeConstants.BUTTONS_UUID, tacxButtonFrame(left: left, right: !left)),
      onUp: () => session.notify(TacxNeoBikeConstants.BUTTONS_UUID, tacxButtonFrame(left: false, right: false)),
    );
    return [
      shift('Rear harder', () => rear = (rear - 1).clamp(0, tacxEmulatedRearTable.length - 1)),
      shift('Rear easier', () => rear = (rear + 1).clamp(0, tacxEmulatedRearTable.length - 1)),
      shift('Front big', () => front = 1),
      shift('Front small', () => front = 0),
      button('Left button', left: true),
      button('Right button', left: false),
    ];
  },
);
