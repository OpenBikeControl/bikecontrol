import 'dart:typed_data';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart' show RideButtonMask;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart' hide RideButtonMask;
import 'package:universal_ble/universal_ble.dart';

import 'fake_ble_platform.dart';

String _lc(String uuid) => uuid.toLowerCase();

BleCharacteristic _char(String uuid, List<CharacteristicProperty> properties) =>
    BleCharacteristic(_lc(uuid), properties, []);

/// Standard device-information + battery services shared by the builders.
List<BleService> _deviceInfoServices(FakePeripheral peripheral, {String firmware = '1.0.0', int battery = 88}) {
  peripheral.readValues[_lc(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_FIRMWARE_REVISION)] =
      Uint8List.fromList(firmware.codeUnits);
  peripheral.readValues[_lc(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_MANUFACTURER_NAME)] =
      Uint8List.fromList('FakeWorks'.codeUnits);
  peripheral.readValues[_lc(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL)] =
      Uint8List.fromList([battery]);
  return [
    BleService(_lc(BleUuid.DEVICE_INFORMATION_SERVICE_UUID), [
      _char(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_FIRMWARE_REVISION, [CharacteristicProperty.read]),
      _char(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_MANUFACTURER_NAME, [CharacteristicProperty.read]),
    ]),
    BleService(_lc(BleUuid.DEVICE_BATTERY_SERVICE_UUID), [
      _char(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL, [
        CharacteristicProperty.read,
        CharacteristicProperty.notify,
      ]),
    ]),
  ];
}

/// A Zwift Click (v1) controller. Detected through the Zwift custom service
/// plus manufacturer data type 0x09 (BC1). Answers the RideOn handshake on
/// its Sync TX characteristic like the real device.
FakePeripheral buildZwiftClick({String deviceId = 'fake-zwift-click', String name = 'Zwift Click'}) {
  final peripheral = FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [_lc(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID)],
    manufacturerData: ManufacturerData(
      ZwiftConstants.ZWIFT_MANUFACTURER_ID,
      Uint8List.fromList([ZwiftConstants.BC1]),
    ),
  );
  peripheral.services.addAll([
    BleService(_lc(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID), [
      _char(ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, [CharacteristicProperty.notify]),
      _char(ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID, [CharacteristicProperty.indicate]),
      _char(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, [
        CharacteristicProperty.write,
        CharacteristicProperty.writeWithoutResponse,
      ]),
    ]),
    ..._deviceInfoServices(peripheral, firmware: '1.1.0'),
  ]);
  return peripheral;
}

/// A Zwift Ride (left controller). Detected via manufacturer data type 0x08.
/// Same GATT layout as the Click — only the manufacturer data type differs.
FakePeripheral buildZwiftRide({String deviceId = 'fake-zwift-ride', String name = 'Zwift Ride'}) {
  final template = buildZwiftClick(deviceId: deviceId, name: name);
  final peripheral = FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: template.advertisedServices,
    services: template.services,
    manufacturerData: ManufacturerData(
      ZwiftConstants.ZWIFT_MANUFACTURER_ID,
      Uint8List.fromList([ZwiftConstants.RIDE_LEFT_SIDE]),
    ),
  );
  peripheral.readValues.addAll(template.readValues);
  return peripheral;
}

/// A Shimano Di2 wireless shifting unit, detected via its service UUID.
FakePeripheral buildShimanoDi2({String deviceId = 'fake-di2', String name = 'RDR Di2'}) {
  final peripheral = FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [_lc(ShimanoDi2Constants.SERVICE_UUID)],
  );
  peripheral.services.addAll([
    BleService(_lc(ShimanoDi2Constants.SERVICE_UUID), [
      _char(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, [CharacteristicProperty.notify]),
    ]),
    ..._deviceInfoServices(peripheral),
  ]);
  return peripheral;
}

/// An FTMS smart trainer reachable over BLE (classified as ProxyDevice).
FakePeripheral buildFtmsTrainer({String deviceId = 'fake-kickr', String name = 'KICKR CORE 1234'}) {
  final peripheral = FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [
      FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID,
      FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID,
    ],
  );
  // FTMS feature map: power + resistance target setting supported.
  peripheral.readValues[FitnessBikeDefinition.FITNESS_MACHINE_FEATURE_UUID] =
      Uint8List.fromList([0x8a, 0x40, 0x00, 0x00, 0x0c, 0xe0, 0x00, 0x00]);
  peripheral.services.addAll([
    BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, [
      _char(FitnessBikeDefinition.FITNESS_MACHINE_FEATURE_UUID, [CharacteristicProperty.read]),
      _char(FitnessBikeDefinition.INDOOR_BIKE_DATA_UUID, [CharacteristicProperty.notify]),
      _char(FitnessBikeDefinition.FITNESS_MACHINE_CONTROL_POINT_UUID, [
        CharacteristicProperty.write,
        CharacteristicProperty.indicate,
      ]),
      _char(FitnessBikeDefinition.FITNESS_MACHINE_STATUS_UUID, [CharacteristicProperty.notify]),
    ]),
    BleService(FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID, [
      _char(FitnessBikeDefinition.CYCLING_POWER_MEASUREMENT_UUID, [CharacteristicProperty.notify]),
      _char(FitnessBikeDefinition.CYCLING_POWER_FEATURE_UUID, [CharacteristicProperty.read]),
    ]),
    ..._deviceInfoServices(peripheral, firmware: '4.2.0'),
  ]);
  return peripheral;
}

/// Wires the standard Zwift controller handshake: when the app writes RideOn
/// to Sync RX, the device acknowledges on Sync TX with its start response.
void autoRespondToZwiftHandshake(
  FakeUniversalBlePlatform ble,
  FakePeripheral peripheral, {
  List<int>? startResponse,
}) {
  bool startsWithRideOn(Uint8List value) {
    if (value.length < ZwiftConstants.RIDE_ON.length) return false;
    for (var i = 0; i < ZwiftConstants.RIDE_ON.length; i++) {
      if (value[i] != ZwiftConstants.RIDE_ON[i]) return false;
    }
    return true;
  }

  peripheral.onWrite = (service, characteristic, value) {
    final isSyncRx = characteristic.toLowerCase() == _lc(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID);
    if (isSyncRx && startsWithRideOn(value)) {
      ble.notify(peripheral.deviceId, ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID, [
        ...ZwiftConstants.RIDE_ON,
        ...(startResponse ?? ZwiftConstants.RESPONSE_START_CLICK),
        // 16 bytes of fake device public key
        ...List.filled(16, 0x42),
      ]);
    }
  };
}

/// Encodes a Zwift Click (v1) button-state notification (message type 0x37).
/// Zwift quirk: ON means pressed and is the protobuf default (0), so the
/// "nothing pressed" frame must set both buttons to OFF explicitly.
List<int> zwiftClickNotification({required bool plusPressed, required bool minusPressed}) {
  final status = ClickKeyPadStatus(
    buttonPlus: plusPressed ? PlayButtonStatus.ON : PlayButtonStatus.OFF,
    buttonMinus: minusPressed ? PlayButtonStatus.ON : PlayButtonStatus.OFF,
  );
  return [ZwiftConstants.CLICK_NOTIFICATION_MESSAGE_TYPE, ...status.writeToBuffer()];
}

/// Encodes a Zwift Ride keypad notification (CONTROLLER_NOTIFICATION opcode).
/// In the Ride buttonMap a CLEARED bit means pressed (ON == 0). Uses the
/// app-side [RideButtonMask] enum (zwift_ride.dart), whose bit layout is what
/// the parser checks.
List<int> zwiftRideNotification({List<RideButtonMask> pressed = const []}) {
  var buttonMap = 0xFFFFFFFF;
  for (final mask in pressed) {
    buttonMap &= ~mask.mask;
  }
  final status = RideKeyPadStatus(buttonMap: buttonMap);
  return [ZwiftConstants.RIDE_NOTIFICATION_MESSAGE_TYPE, ...status.writeToBuffer()];
}

/// Encodes a Zwift battery-level notification.
List<int> zwiftBatteryNotification(int percent) => [ZwiftConstants.BATTERY_LEVEL_TYPE, 0x00, percent];
