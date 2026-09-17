import 'package:bike_control/bluetooth/devices/sensors/ble_cadence_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import 'harness/test_env.dart';

/// Fix-wave-A (A1): the heart-rate half of external sensor sources was
/// reachable end to end (see `sensor_source_registration_test.dart`), but the
/// cadence and power halves were not. `Connection._registerSensorSource` and
/// `_unregisterSensorSource` gated on `is! BleHeartRateDevice`, and
/// `SensorDiscoverySection` only ever listed that same concrete type — so a
/// discovered `BleCadenceDevice`/`BlePowerDevice` could be classified by
/// `BluetoothDevice.fromScanResult` but never reach connected state through
/// any rider action, and even if something else had connected one, its
/// source would never reach `SensorHub`: `sourcesFor(cadence)` /
/// `sourcesFor(power)` were permanently empty.
///
/// This drives a cadence sensor through the REAL `Connection`, exactly like
/// `sensor_source_registration_test.dart` does for heart rate, to prove the
/// fix (widening both gates — and the discovery section — to a shared
/// `BleSensorDevice` interface rather than a second `is` check) actually
/// closes the gap for a SECOND sensor type, not just the one that happened to
/// already have a test. `BlePowerDevice` shares the exact same code path
/// through `BleSensorDevice`, so a dedicated copy of this test for power
/// would only re-prove the interface dispatch, not the gating fix itself.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();

  // initialize() wires UniversalBle callbacks onto the fake platform; run it
  // once for the whole file like the app does at startup.
  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    core.actionHandler = StubActions();
  });

  tearDown(() async {
    await env.resetConnection();
  });

  FakePeripheral cadenceSensor({String deviceId = 'csc-sensor-1', String name = 'CAD 7788'}) => FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [BleSensorSource.cscServiceUuid],
    services: [
      BleService(BleSensorSource.cscServiceUuid, [
        BleCharacteristic(BleSensorSource.cscMeasurementUuid, [CharacteristicProperty.notify], const []),
      ]),
    ],
  );

  test('a connected cadence sensor registers its source with the hub, and a transient drop '
      'unregisters it WITHOUT clearing the selection', () async {
    final peripheral = cadenceSensor();
    env.ble.addPeripheral(peripheral);

    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<BleCadenceDevice>().isNotEmpty,
      description: 'the cadence sensor to be discovered and classified',
    );
    final device = core.connection.devices.whereType<BleCadenceDevice>().first;

    // Not auto-connected (same consent gate as a heart rate strap) and not
    // registered at construction — the queue must leave it alone until
    // something actually connects it.
    expect(device.isConnected, isFalse);
    expect(core.sensors.sourcesFor(SensorQuantity.cadence), isEmpty);

    // Drive the radio-level connect directly (see the heart rate file's doc
    // comment for why: there is no rider-facing "pair this sensor" action to
    // drive device.connect() through its normal upstream path here, and
    // sensor_discovery_section_test.dart already proves that action
    // generically for BleSensorDevice).
    await env.ble.connect(peripheral.deviceId);

    await IntegrationEnv.waitFor(
      () => core.sensors.sourcesFor(SensorQuantity.cadence).isNotEmpty,
      description: 'the connected cadence sensor to register its source with the hub',
    );
    expect(device.isConnected, isTrue);
    expect(core.sensors.sourcesFor(SensorQuantity.cadence).single.id, device.source.id);

    // The rider actually picks this sensor as their cadence source.
    core.sensors.select(SensorQuantity.cadence, device.source.id);
    expect(core.sensors.selectionFor(SensorQuantity.cadence), device.source.id);

    // A transient BLE drop (sensor out of range for a couple of seconds, no
    // rider action involved) must unregister the dead source but leave the
    // rider's choice in place — same contract fix-wave-1 proved for heart
    // rate.
    env.ble.dropConnection(peripheral.deviceId);

    await IntegrationEnv.waitFor(
      () => core.sensors.sourcesFor(SensorQuantity.cadence).isEmpty,
      description: 'the disconnected cadence sensor to unregister its source from the hub',
    );
    expect(core.sensors.selectionFor(SensorQuantity.cadence), device.source.id);
    expect(core.sensors.droppedOut(SensorQuantity.cadence).value, isTrue);
  });
}
