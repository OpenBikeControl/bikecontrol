import 'package:bike_control/bluetooth/devices/sensors/ble_heart_rate_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import 'harness/test_env.dart';

/// Fix-wave-1 (F2): `SensorHub.register` had zero production callers, so
/// `sourcesFor()` was always empty and the entire external-sensor feature was
/// dead in the running app even though the hub itself was fully unit tested.
/// A hub-only test cannot see that kind of gap — it never touches the caller
/// that was missing. This drives a heart rate strap through the REAL
/// `Connection`: scan, classification, connect queue, same as
/// `controller_connection_test.dart`.
///
/// `BleHeartRateDevice.shouldAutoConnect` is false (fix-wave-1 F1: a strap
/// must never be auto-connected), and there is no rider-facing "pair this
/// strap" action yet to drive `device.connect()` through its normal upstream
/// path. So instead of waiting on the connect queue, this connects the fake
/// peripheral directly at the platform level — exactly what a real BLE stack
/// reports regardless of *why* the radio connected. `Connection`'s
/// `connectionStream` listener is already attached the moment the strap
/// enters the connect queue (it runs for every device, auto-connectable or
/// not — see `shouldAutoConnect`'s doc comment), and reacts to that report
/// the same way either way. That listener, and the disconnect path beside it,
/// are exactly the wiring this test exists to prove.
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

  FakePeripheral heartRateStrap({String deviceId = 'hr-strap-1', String name = 'TICKR 1234'}) => FakePeripheral(
    deviceId: deviceId,
    name: name,
    advertisedServices: [BleSensorSource.heartRateServiceUuid],
    services: [
      BleService(BleSensorSource.heartRateServiceUuid, [
        BleCharacteristic(BleSensorSource.heartRateMeasurementUuid, [CharacteristicProperty.notify], const []),
      ]),
    ],
  );

  test('a connected heart rate strap registers its source with the hub, and a transient drop '
      'unregisters it WITHOUT clearing the selection', () async {
    final peripheral = heartRateStrap();
    env.ble.addPeripheral(peripheral);

    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<BleHeartRateDevice>().isNotEmpty,
      description: 'the strap to be discovered and classified',
    );
    final device = core.connection.devices.whereType<BleHeartRateDevice>().first;

    // Not auto-connected (F1) and not registered at construction (F2) — the
    // queue must leave it alone until something actually connects it.
    expect(device.isConnected, isFalse);
    expect(core.sensors.sourcesFor(SensorQuantity.heartRate), isEmpty);

    // Drive the radio-level connect directly (see file doc comment for why).
    await env.ble.connect(peripheral.deviceId);

    await IntegrationEnv.waitFor(
      () => core.sensors.sourcesFor(SensorQuantity.heartRate).isNotEmpty,
      description: 'the connected strap to register its source with the hub',
    );
    expect(device.isConnected, isTrue);
    expect(core.sensors.sourcesFor(SensorQuantity.heartRate).single.id, device.source.id);

    // The rider actually picks this strap as their heart rate source.
    core.sensors.select(SensorQuantity.heartRate, device.source.id);
    expect(core.sensors.selectionFor(SensorQuantity.heartRate), device.source.id);

    // Fix-wave-1 round 2: a transient BLE drop (strap out of range for a
    // couple of seconds, no rider action involved) must unregister the dead
    // source but leave the rider's choice in place — permanently reverting
    // to the trainer on every routine drop is the bug this test guards.
    env.ble.dropConnection(peripheral.deviceId);

    await IntegrationEnv.waitFor(
      () => core.sensors.sourcesFor(SensorQuantity.heartRate).isEmpty,
      description: 'the disconnected strap to unregister its source from the hub',
    );
    expect(core.sensors.selectionFor(SensorQuantity.heartRate), device.source.id);
    expect(core.sensors.droppedOut(SensorQuantity.heartRate).value, isTrue);
  });

  // Fix-wave-1 round 2: the counterpart of the test above — when the rider
  // actually forgets the device (the "Remove"/"Ignore" action on its
  // settings page, which always passes forget: true), the selection MUST be
  // cleared rather than left pointing forever at a device that is never
  // coming back.
  test('forgetting a connected strap clears its heart-rate selection', () async {
    final peripheral = heartRateStrap(deviceId: 'hr-strap-2');
    env.ble.addPeripheral(peripheral);

    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<BleHeartRateDevice>().isNotEmpty,
      description: 'the strap to be discovered and classified',
    );
    final device = core.connection.devices.whereType<BleHeartRateDevice>().first;

    await env.ble.connect(peripheral.deviceId);
    await IntegrationEnv.waitFor(
      () => core.sensors.sourcesFor(SensorQuantity.heartRate).isNotEmpty,
      description: 'the connected strap to register its source with the hub',
    );

    core.sensors.select(SensorQuantity.heartRate, device.source.id);
    expect(core.sensors.selectionFor(SensorQuantity.heartRate), device.source.id);

    // Mirrors controller_settings.dart's "Remove" action.
    await core.connection.disconnect(device, persistForget: false, forget: true);

    expect(core.sensors.selectionFor(SensorQuantity.heartRate), isNull);
  });

  // V3 (wave 3): the Pro gate used to live only in
  // `SensorQuantitySelector._handleChanged`, a one-shot check at the moment
  // the rider taps the dropdown — nothing re-evaluated afterwards, so a
  // rider who selected a sensor while subscribed and then lapsed kept it
  // resolving indefinitely. This drives the REAL `core.connection.initialize`
  // wiring end to end (not a hand-built SensorHub) to prove
  // `core.sensors.isProEnabled` is actually connected to IAPManager in the
  // running app, not just correct in isolation.
  test('a lapsed subscription stops the real wiring from resolving heart rate, and resumes once restored', () async {
    IAPManager.instance.setProForTesting(enabled: true);
    addTearDown(() => IAPManager.instance.setProForTesting(enabled: false));

    final peripheral = heartRateStrap(deviceId: 'hr-strap-3');
    env.ble.addPeripheral(peripheral);

    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<BleHeartRateDevice>().isNotEmpty,
      description: 'the strap to be discovered and classified',
    );
    final device = core.connection.devices.whereType<BleHeartRateDevice>().first;

    await env.ble.connect(peripheral.deviceId);
    await IntegrationEnv.waitFor(
      () => core.sensors.sourcesFor(SensorQuantity.heartRate).isNotEmpty,
      description: 'the connected strap to register its source with the hub',
    );

    core.sensors.select(SensorQuantity.heartRate, device.source.id);
    env.ble.notify(peripheral.deviceId, BleSensorSource.heartRateMeasurementUuid, [0x00, 155]);
    await IntegrationEnv.waitFor(
      () => core.sensors.resolved(SensorQuantity.heartRate).value == 155,
      description: 'the reading to resolve while the rider is subscribed',
    );

    // The subscription lapses mid-ride — no rider action, no reselecting.
    IAPManager.instance.setProForTesting(enabled: false);
    core.sensors.tick();

    expect(core.sensors.resolved(SensorQuantity.heartRate).value, isNull);
    // Still selected: this must resume on its own once Pro comes back.
    expect(core.sensors.selectionFor(SensorQuantity.heartRate), device.source.id);

    IAPManager.instance.setProForTesting(enabled: true);
    core.sensors.tick();

    expect(core.sensors.resolved(SensorQuantity.heartRate).value, 155);
  });
}
