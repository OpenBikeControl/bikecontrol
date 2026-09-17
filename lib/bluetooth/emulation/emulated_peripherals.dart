import 'dart:typed_data';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/wheeltop/wheeltop_eds.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart' show RideButtonMask;
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart' hide RideButtonMask;
import 'package:prop/utils/csc_measurement.dart';
import 'package:universal_ble/universal_ble.dart';

import 'emulated_ble_platform.dart';

String lcUuid(String uuid) => uuid.toLowerCase();

BleCharacteristic bleChar(String uuid, List<CharacteristicProperty> properties) =>
    BleCharacteristic(lcUuid(uuid), properties, []);

/// Standard device-information + battery services shared by the builders.
List<BleService> deviceInfoServices(FakePeripheral peripheral, {String firmware = '1.0.0', int battery = 88}) {
  peripheral.readValues[lcUuid(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_FIRMWARE_REVISION)] =
      Uint8List.fromList(firmware.codeUnits);
  peripheral.readValues[lcUuid(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_MANUFACTURER_NAME)] =
      Uint8List.fromList('FakeWorks'.codeUnits);
  peripheral.readValues[lcUuid(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL)] =
      Uint8List.fromList([battery]);
  return [
    BleService(lcUuid(BleUuid.DEVICE_INFORMATION_SERVICE_UUID), [
      bleChar(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_FIRMWARE_REVISION, [CharacteristicProperty.read]),
      bleChar(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_MANUFACTURER_NAME, [CharacteristicProperty.read]),
    ]),
    BleService(lcUuid(BleUuid.DEVICE_BATTERY_SERVICE_UUID), [
      bleChar(BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL, [
        CharacteristicProperty.read,
        CharacteristicProperty.notify,
      ]),
    ]),
  ];
}

/// An emulated heart rate strap, so the whole BLE sensor path can be exercised
/// in the running app without hardware. The heart rate strap is notify-only:
/// testers choose the BPM via EmulatedAction inputs on the profile, not via
/// peripheral builder parameters.
FakePeripheral heartRateStrapPeripheral({String name = 'Emulated HRM'}) {
  // advertisedServices is what a filtered scan matches on — without it the
  // strap is built but never discovered, which looks exactly like a bug in
  // the scan filter.
  final peripheral = FakePeripheral(
    deviceId: 'emulated:hrm',
    name: name,
    advertisedServices: [lcUuid(BleSensorSource.heartRateServiceUuid)],
  );
  peripheral.services.addAll([
    BleService(lcUuid(BleSensorSource.heartRateServiceUuid), [
      bleChar(BleSensorSource.heartRateMeasurementUuid, [CharacteristicProperty.notify]),
    ]),
    ...deviceInfoServices(peripheral),
  ]);
  return peripheral;
}

/// An emulated cadence sensor (Cycling Speed and Cadence Service, crank data
/// only), so the cadence path can be exercised without owning one. Same
/// notify-only shape as [heartRateStrapPeripheral]: testers pick an rpm via
/// EmulatedAction inputs on the profile.
FakePeripheral cadenceSensorPeripheral({String name = 'Emulated Cadence'}) {
  // advertisedServices is what a filtered scan matches on — without it the
  // sensor is built but never discovered, which looks exactly like a bug in
  // the scan filter.
  final peripheral = FakePeripheral(
    deviceId: 'emulated:csc',
    name: name,
    advertisedServices: [lcUuid(BleSensorSource.cscServiceUuid)],
  );
  peripheral.services.addAll([
    BleService(lcUuid(BleSensorSource.cscServiceUuid), [
      bleChar(BleSensorSource.cscMeasurementUuid, [CharacteristicProperty.notify]),
    ]),
    ...deviceInfoServices(peripheral),
  ]);
  return peripheral;
}

/// An emulated power meter (Cycling Power Service). Same notify-only shape
/// as [heartRateStrapPeripheral].
///
/// The default name deliberately matches one of the families
/// `BluetoothDevice._isKnownPowerMeterName` recognises (Favero Assioma):
/// `BluetoothDevice.fromScanResult`'s narrow rule only classifies a
/// Cycling-Power advertiser as `BlePowerDevice` when its name is on that
/// list AND it does not also advertise a trainer service — otherwise it
/// falls through to the broader (name-unaware) rule below it. A fixture
/// named anything else would still reach BlePowerDevice today, but naming it
/// after a recognised brand keeps this fixture exercising the narrow,
/// trainer-protecting rule specifically rather than the broad fallback.
FakePeripheral powerMeterPeripheral({String name = 'ASSIOMA DUO'}) {
  // advertisedServices is what a filtered scan matches on — without it the
  // meter is built but never discovered, which looks exactly like a bug in
  // the scan filter.
  final peripheral = FakePeripheral(
    deviceId: 'emulated:cps',
    name: name,
    advertisedServices: [lcUuid(BleSensorSource.cyclingPowerServiceUuid)],
  );
  peripheral.services.addAll([
    BleService(lcUuid(BleSensorSource.cyclingPowerServiceUuid), [
      bleChar(BleSensorSource.cyclingPowerMeasurementUuid, [CharacteristicProperty.notify]),
    ]),
    ...deviceInfoServices(peripheral),
  ]);
  return peripheral;
}

/// Session-scoped mutable state for the emulated cadence/power profiles: a
/// cumulative crank-revolution counter and its paired 1/1024s event clock.
/// [advance] delegates to the shared, pure `advanceCrankCounter`
/// (`package:prop/utils/csc_measurement.dart`) — the exact wrap-safe scheme
/// `SensorDefinition` uses for the standalone sink — so this fixture and
/// that sink can never encode the same rpm two different ways. See
/// `advanceCrankCounter`'s doc comment for why two consecutive frames built
/// from consecutive [advance] calls always decode back to the intended rpm
/// via `cscCadenceRpm`/`cpsCadenceRpm`, and why a fixture that reused a
/// single constant frame instead would encode no cadence at all.
class CrankCounter {
  int _revs = 0;
  int _eventTime1024 = 0;

  int get revs => _revs;
  int get eventTime1024 => _eventTime1024;

  /// Advances the counters by [rpm] revolutions over one fixed quantum.
  void advance(int rpm) {
    final next = advanceCrankCounter(crankRevs: _revs, eventTime1024: _eventTime1024, rpm: rpm);
    _revs = next.crankRevs;
    _eventTime1024 = next.eventTime1024;
  }
}

/// A Zwift Click (v1) controller. Detected through the Zwift custom service
/// plus manufacturer data type 0x09 (BC1). Answers the RideOn handshake on
/// its Sync TX characteristic like the real device.
FakePeripheral buildZwiftClick({String deviceId = 'fake-zwift-click', String name = 'Zwift Click'}) {
  final peripheral = FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [lcUuid(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID)],
    manufacturerData: ManufacturerData(
      ZwiftConstants.ZWIFT_MANUFACTURER_ID,
      Uint8List.fromList([ZwiftConstants.BC1]),
    ),
  );
  peripheral.services.addAll([
    BleService(lcUuid(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID), [
      bleChar(ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, [CharacteristicProperty.notify]),
      bleChar(ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID, [CharacteristicProperty.indicate]),
      bleChar(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, [
        CharacteristicProperty.write,
        CharacteristicProperty.writeWithoutResponse,
      ]),
    ]),
    ...deviceInfoServices(peripheral, firmware: '1.1.0'),
  ]);
  return peripheral;
}

/// One side of a Zwift Click V2. Detected via the Zwift custom service plus a
/// manufacturer-data type of [ZwiftConstants.CLICK_V2_LEFT_SIDE] or
/// [ZwiftConstants.CLICK_V2_RIGHT_SIDE]. Same GATT layout as the Click v1.
FakePeripheral buildZwiftClickV2({required int sideCode, String? deviceId}) {
  final id = deviceId ?? 'fake-zwift-click-v2-$sideCode';
  final template = buildZwiftClick(deviceId: id, name: 'Zwift Click');
  final peripheral = FakePeripheral(
    deviceId: id,
    name: 'Zwift Click',
    advertisedServices: template.advertisedServices,
    manufacturerData: ManufacturerData(
      ZwiftConstants.ZWIFT_MANUFACTURER_ID,
      Uint8List.fromList([sideCode]),
    ),
  );
  peripheral.services.addAll(template.services);
  peripheral.readValues.addAll(template.readValues);
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
    advertisedServices: [lcUuid(ShimanoDi2Constants.SERVICE_UUID)],
  );
  peripheral.services.addAll([
    BleService(lcUuid(ShimanoDi2Constants.SERVICE_UUID), [
      bleChar(ShimanoDi2Constants.D_FLY_CHANNEL_UUID, [CharacteristicProperty.notify]),
    ]),
    ...deviceInfoServices(peripheral),
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
      bleChar(FitnessBikeDefinition.FITNESS_MACHINE_FEATURE_UUID, [CharacteristicProperty.read]),
      bleChar(FitnessBikeDefinition.INDOOR_BIKE_DATA_UUID, [CharacteristicProperty.notify]),
      bleChar(FitnessBikeDefinition.FITNESS_MACHINE_CONTROL_POINT_UUID, [
        CharacteristicProperty.write,
        CharacteristicProperty.indicate,
      ]),
      bleChar(FitnessBikeDefinition.FITNESS_MACHINE_STATUS_UUID, [CharacteristicProperty.notify]),
    ]),
    BleService(FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID, [
      bleChar(FitnessBikeDefinition.CYCLING_POWER_MEASUREMENT_UUID, [CharacteristicProperty.notify]),
      bleChar(FitnessBikeDefinition.CYCLING_POWER_FEATURE_UUID, [CharacteristicProperty.read]),
    ]),
    ...deviceInfoServices(peripheral, firmware: '4.2.0'),
  ]);
  return peripheral;
}

/// A Zwift-Cog smart trainer (KICKR CORE Zwift One / Elite Direto Zwift-ready):
/// FTMS + Cycling Power like [buildFtmsTrainer], plus its own Zwift custom
/// service, so the definition classifies it as a grade-native trainer.
FakePeripheral buildZwiftCogTrainer({String deviceId = 'fake-cog', String name = 'KICKR CORE 5775'}) {
  final peripheral = buildFtmsTrainer(deviceId: deviceId, name: name);
  peripheral.advertisedServices.add(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase());
  peripheral.services.add(
    BleService(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID, [
      bleChar(ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, [CharacteristicProperty.notify]),
      bleChar(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, [CharacteristicProperty.write]),
      bleChar(ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID, [CharacteristicProperty.indicate]),
    ]),
  );
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
    final isSyncRx = characteristic.toLowerCase() == lcUuid(ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID);
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

/// A WHEELTOP EDS TX Left shifter: manufacturer-data advertisement (company
/// id 0x0F07 split off by the platform, type byte 0x36, fw 2.58, 2.92 V) and
/// a Nordic-UART GATT database with the button characteristic notifiable.
/// The real pod advertises no name.
FakePeripheral buildWheeltopEdsTxLeft({String deviceId = 'fake-wheeltop-tx-left'}) {
  final peripheral = FakePeripheral(
    deviceId: deviceId,
    name: null,
    manufacturerData: ManufacturerData(
      0x0F07,
      Uint8List.fromList([0x00, 0x14, 0x55, 0x6a, 0x84, 0x36, 0x02, 0x3a, 0x01, 0x24, 0x00, 0x00, 0x00]),
    ),
  );
  peripheral.services.add(
    BleService(lcUuid(WheeltopEdsConstants.SERVICE_UUID), [
      bleChar(WheeltopEdsConstants.TX_CHARACTERISTIC_UUID, [
        CharacteristicProperty.write,
        CharacteristicProperty.notify,
      ]),
      // Stock Nordic UART second slot — writable AND notify-capable, like the
      // demo shifter firmware (which exposes both slots write+notify). The app
      // subscribes here too so a keepalive reply on this slot is captured.
      bleChar('6e400003-b5a3-f393-e0a9-e50e24dcca9e', [
        CharacteristicProperty.write,
        CharacteristicProperty.writeWithoutResponse,
        CharacteristicProperty.notify,
      ]),
    ]),
  );
  return peripheral;
}
