import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_sensor_device.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:universal_ble/universal_ble.dart';

/// A standards-compliant BLE power meter (Cycling Power Service) paired
/// directly to BikeControl.
///
/// Transport only, same shape as `BleHeartRateDevice`: discover, subscribe,
/// and hand bytes to [source]. [source] claims both power and cadence — a
/// power meter's crank almost always doubles as a cadence source, and the
/// CPS parser it feeds already extracts both from the same notification. No
/// buttons: a power meter has nothing for the rider to click, so it is
/// registered with an empty [availableButtons] like the other
/// non-controller accessories in this directory.
///
/// `with Accessory`: a power meter reacts to nothing and sends nothing a
/// rider binds to a button, same as a strap or a Headwind. Without the
/// mixin, `Connection` remembers it as `RememberedDeviceKind.controller`
/// instead of excluding it the way it does every other accessory, and its
/// settings page renders an empty Button Mapping table.
///
/// Detection is deliberately narrower than a cadence sensor's: many power
/// meters accept only one simultaneous BLE connection — see
/// `BluetoothDevice._advertisesTrainerService`'s doc comment for the one
/// classification guard that still applies regardless (a device advertising
/// a trainer service is a trainer, not a power meter, no matter its name).
///
/// `with BleSensorDevice`: the shared surface `Connection` and
/// `SensorQuantitySelector` dispatch on so a strap, a cadence sensor and a
/// power meter can all be reached the same way — see that mixin's doc
/// comment.
class BlePowerDevice extends BluetoothDevice with Accessory, BleSensorDevice {
  BlePowerDevice(super.scanResult) : super(availableButtons: const []) {
    source = BleSensorSource(
      // The device id is stable across restarts, which is what the rider's
      // persisted per-quantity selection is keyed on. The advertised name is
      // not — power meters rename themselves after a firmware update.
      id: device.deviceId,
      displayName: device.name ?? 'Power meter',
      provides: const {SensorQuantity.power, SensorQuantity.cadence},
    );
  }

  @override
  late final BleSensorSource source;

  /// A power meter must connect only when the rider explicitly asks. This
  /// gate matters even more here than for a strap or cadence sensor: most
  /// power meters allow only a single simultaneous BLE connection, so an
  /// auto-connect would silently take the meter away from the rider's head
  /// unit mid-ride, for no benefit to them here.
  ///
  /// Backed by the same persisted per-device consent flag `BleHeartRateDevice`
  /// uses — false until the rider selects this meter in its quantity's
  /// toggle group (`SensorQuantitySelector`), which sets the flag before
  /// calling `Connection.connectDevice`. From then on it reconnects
  /// automatically like every other remembered device, including across the
  /// fresh instance `fromScanResult` builds on every rediscovery (see
  /// `SensorHub.register`'s doc comment) — the flag is keyed by the stable
  /// BLE device id, not the object.
  @override
  bool get shouldAutoConnect => sensorAutoConnectAllowed;

  @override
  Future<void> connect() async {
    // Mirrors BleHeartRateDevice/ProxyDevice/ZwiftClickV2: stay listed and
    // keep the queue's listener wiring, but open no transport while no rider
    // action exists to ask for one.
    if (!shouldAutoConnect) return;
    await super.connect();
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid.toLowerCase() == BleSensorSource.cyclingPowerServiceUuid,
      orElse: () => throw Exception(
        'Service not found: ${BleSensorSource.cyclingPowerServiceUuid}',
      ),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == BleSensorSource.cyclingPowerMeasurementUuid,
      orElse: () => throw Exception(
        'Characteristic not found: ${BleSensorSource.cyclingPowerMeasurementUuid}',
      ),
    );

    await UniversalBle.subscribeNotifications(
      device.deviceId,
      service.uuid,
      characteristic.uuid,
    );
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic.toLowerCase() != BleSensorSource.cyclingPowerMeasurementUuid) {
      return;
    }
    source.ingestCpsMeasurement(bytes);
  }
}
