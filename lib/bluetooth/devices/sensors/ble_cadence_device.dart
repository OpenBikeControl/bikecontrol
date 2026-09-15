import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_sensor_device.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:universal_ble/universal_ble.dart';

/// A standards-compliant BLE cadence sensor (CSC — Cycling Speed and Cadence
/// Service) paired directly to BikeControl.
///
/// Transport only, same shape as `BleHeartRateDevice`: discover, subscribe,
/// and hand bytes to [source]. The source owns parsing — including the
/// two-sample delta CSC cadence needs — and the hub above it owns whether
/// this reading is the one the rider actually wants. No buttons: a cadence
/// sensor has nothing for the rider to click, so it is registered with an
/// empty [availableButtons] like the other non-controller accessories in
/// this directory.
///
/// `with Accessory`: a cadence sensor reacts to nothing and sends nothing a
/// rider binds to a button, same as a strap or a Headwind. Without the
/// mixin, `Connection` remembers it as `RememberedDeviceKind.controller`
/// instead of excluding it the way it does every other accessory, and its
/// settings page renders an empty Button Mapping table.
///
/// `with BleSensorDevice`: the shared surface `Connection` and
/// `SensorQuantitySelector` dispatch on so a strap, a cadence sensor and a
/// power meter can all be reached the same way — see that mixin's doc
/// comment.
class BleCadenceDevice extends BluetoothDevice with Accessory, BleSensorDevice {
  BleCadenceDevice(super.scanResult) : super(availableButtons: const []) {
    source = BleSensorSource(
      // The device id is stable across restarts, which is what the rider's
      // persisted per-quantity selection is keyed on. The advertised name is
      // not — cadence sensors rename themselves after a firmware update.
      id: device.deviceId,
      displayName: device.name ?? 'Cadence sensor',
      provides: const {SensorQuantity.cadence},
    );
  }

  @override
  late final BleSensorSource source;

  /// A cadence sensor must connect only when the rider explicitly asks.
  /// Without this, `Connection.addDevices` pushes every cadence sensor it
  /// ever sees into the auto-connect queue, and most only allow a single
  /// simultaneous BLE connection — silently taking the rider's sensor away
  /// from Zwift, their bike computer or their watch, for no benefit to them
  /// here.
  ///
  /// Backed by the same persisted per-device consent flag `BleHeartRateDevice`
  /// uses — false until the rider selects this sensor in its quantity's
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
      (e) => e.uuid.toLowerCase() == BleSensorSource.cscServiceUuid,
      orElse: () => throw Exception(
        'Service not found: ${BleSensorSource.cscServiceUuid}',
      ),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == BleSensorSource.cscMeasurementUuid,
      orElse: () => throw Exception(
        'Characteristic not found: ${BleSensorSource.cscMeasurementUuid}',
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
    if (characteristic.toLowerCase() != BleSensorSource.cscMeasurementUuid) {
      return;
    }
    source.ingestCscMeasurement(bytes);
  }
}
