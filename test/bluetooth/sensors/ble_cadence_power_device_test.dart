import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_cadence_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_power_device.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

BleCadenceDevice _cadenceDevice({String id = 'csc-1', String? name = 'CAD 7788'}) =>
    BleCadenceDevice(BleDevice(deviceId: id, name: name));

BlePowerDevice _powerDevice({String id = 'cps-1', String? name = 'Meter'}) =>
    BlePowerDevice(BleDevice(deviceId: id, name: name));

/// CSC frame with crank data only: flags 0x02, uint16 cum revs, uint16 event time.
List<int> _csc(int revs, int t1024) => [0x02, revs & 0xFF, (revs >> 8) & 0xFF, t1024 & 0xFF, (t1024 >> 8) & 0xFF];

void main() {
  // Constructing a BluetoothDevice with an empty availableButtons list
  // touches core.actionHandler (BaseDevice's ctor probes the current
  // keymap) — same requirement as every other device-detection test.
  core.actionHandler = StubActions();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
  });

  group('BleCadenceDevice', () {
    test('routes CSC notifications into its source', () async {
      final device = _cadenceDevice();

      await device.processCharacteristic(BleSensorSource.cscMeasurementUuid, Uint8List.fromList(_csc(10, 1024)));
      await device.processCharacteristic(BleSensorSource.cscMeasurementUuid, Uint8List.fromList(_csc(11, 2048)));

      expect(device.source.readingFor(SensorQuantity.cadence).value!.value, 60);
    });

    test('ignores a notification on an unrelated characteristic', () async {
      final device = _cadenceDevice();

      await device.processCharacteristic(
        '00002a19-0000-1000-8000-00805f9b34fb', // battery level
        Uint8List.fromList([0x00, 99]),
      );

      expect(device.source.readingFor(SensorQuantity.cadence).value, isNull);
    });

    test('the source is identified by the device id and provides only cadence', () {
      final device = _cadenceDevice();

      expect(device.source.id, 'csc-1');
      expect(device.source.provides, {SensorQuantity.cadence});
    });

    test('handleServices throws a named error when the sensor has no CSC service', () async {
      final device = _cadenceDevice();

      expect(
        () => device.handleServices(const <BleService>[]),
        throwsA(isA<Exception>()),
      );
    });

    // Same consent gate as BleHeartRateDevice: most BLE sensors accept only
    // one simultaneous connection, so an un-gated cadence sensor would sneak
    // into Connection.addDevices' auto-connect queue and steal itself away
    // from whatever app already has it.
    test('shouldAutoConnect is false until the rider explicitly connects it', () {
      final device = _cadenceDevice();

      expect(device.shouldAutoConnect, isFalse);
    });

    test('shouldAutoConnect flips true once the rider has explicitly connected this device id', () async {
      final device = _cadenceDevice();
      expect(device.shouldAutoConnect, isFalse);

      await core.settings.setSensorAutoConnect(device.device.deviceId, true);

      expect(device.shouldAutoConnect, isTrue);
    });

    test('is an Accessory, not a controller', () {
      final device = _cadenceDevice();

      expect(device, isA<Accessory>());
    });
  });

  group('BlePowerDevice', () {
    test('publishes power and claims cadence too', () async {
      final device = _powerDevice();

      await device.processCharacteristic(
        BleSensorSource.cyclingPowerMeasurementUuid,
        Uint8List.fromList([0x00, 0x00, 0xFA, 0x00]), // 250 W
      );

      expect(device.source.readingFor(SensorQuantity.power).value!.value, 250);
      expect(device.source.provides, {SensorQuantity.power, SensorQuantity.cadence});
    });

    test('ignores a notification on an unrelated characteristic', () async {
      final device = _powerDevice();

      await device.processCharacteristic(
        '00002a19-0000-1000-8000-00805f9b34fb', // battery level
        Uint8List.fromList([0x00, 99]),
      );

      expect(device.source.readingFor(SensorQuantity.power).value, isNull);
    });

    test('the source is identified by the device id', () {
      final device = _powerDevice();

      expect(device.source.id, 'cps-1');
    });

    test('handleServices throws a named error when the sensor has no Cycling Power service', () async {
      final device = _powerDevice();

      expect(
        () => device.handleServices(const <BleService>[]),
        throwsA(isA<Exception>()),
      );
    });

    test('shouldAutoConnect is false until the rider explicitly connects it', () {
      final device = _powerDevice();

      expect(device.shouldAutoConnect, isFalse);
    });

    test('is an Accessory, not a controller', () {
      final device = _powerDevice();

      expect(device, isA<Accessory>());
    });
  });

  group('detection', () {
    test('a cadence sensor with a plain name is detected via the CSC service', () {
      final scan = BleDevice(
        deviceId: 'csc-2',
        name: 'CAD 7788',
        services: [BleSensorSource.cscServiceUuid],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<BleCadenceDevice>());
    });

    // Fix round 1, Finding 1: ProxyDevice's own detection rule
    // (lib/bluetooth/devices/proxy/proxy_device.dart) matches any scan result
    // advertising the Cycling Power Service — the exact same 0x1818 UUID as
    // BleSensorSource.cyclingPowerServiceUuid — unconditionally, via
    // containsAny with no name gating, and it sits earlier in the non-web
    // switch than a plain service-based power rule is allowed to (staying
    // after it is what protects real DirCon-bridged trainers). This group
    // proves the actual fix — a second, narrow rule placed BEFORE the
    // ProxyDevice branch, gated on a name already known to be a power meter
    // (BluetoothDevice._isKnownPowerMeterName, built from _powerMeterNames).
    //
    // Detection has no separate opt-in step any more: selecting a source in
    // the Sensors UI (`SensorQuantitySelector`) IS the rider's consent, so
    // nothing here is gated on a persisted flag — see
    // `BluetoothDevice._powerMeterNames`'s doc comment.
    test('a known power meter resolves to BlePowerDevice, not ProxyDevice, with no opt-in required', () {
      final scan = BleDevice(
        deviceId: 'pm-1',
        name: 'ASSIOMA DUO-1234',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<BlePowerDevice>());
    });

    // A brand this codebase used to hide entirely until the rider opted in
    // (Favero Assioma, Quarq, PowerCrank) is now just another known power
    // meter — nothing hides it any more.
    test('a formerly-hidden power meter name is now visible with no opt-in at all', () {
      final scan = BleDevice(
        deviceId: 'pm-2',
        name: 'ASSIOMA DUO-5678',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<BlePowerDevice>());
    });

    // The test that proves existing trainers are unaffected: a device
    // advertising bare Cycling Power Service whose name is NOT a known power
    // meter — e.g. a power-only trainer with no FTMS — must keep resolving to
    // ProxyDevice exactly as it did before this task. The narrow rule's name
    // gate is what keeps it out of BlePowerDevice's way.
    // 'X2Max' mirrors the generic FE-C trainer fixture name used in
    // proxy_device_smart_trainer_test.dart — deliberately not a real power
    // meter brand, so it can never collide with _powerMeterNames.
    test('a CPS advertiser with a non-power-meter name still resolves to ProxyDevice', () {
      final scan = BleDevice(
        deviceId: 'trainer-cps-1',
        name: 'X2Max 1234',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<ProxyDevice>());
    });

    // A3 (fix-wave-A) originally proved a recognised-but-not-hidden brand
    // like Stages could still become a BlePowerDevice once opted in. There is
    // no opt-in step left, so it now resolves directly.
    test('a recognised power meter brand resolves directly to BlePowerDevice', () {
      final scan = BleDevice(
        deviceId: 'pm-3',
        name: 'STAGES 1234',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<BlePowerDevice>());
    });

    // fix-wave-D: widening _powerMeterNames to recognise brands like Stages,
    // SRM, and Rotor was correct on its own — but those brands do not only
    // make crank/pedal power meters: Stages makes the SB20 smart bike, SRM
    // makes an indoor trainer. Neither the narrow rule above nor its
    // web-branch twin excluded a device that also advertises a trainer
    // service, so a rider with one of those would have this rule claim their
    // trainer as a bare BlePowerDevice before the ProxyDevice branch below
    // ever saw it — losing resistance, ERG, and virtual shifting entirely. A
    // device advertising a trainer service is a TRAINER that also reports
    // power, not a power meter; trainer control must always win. The guard
    // added here excludes FTMS/FE-C the same way ProxyDevice.isSmartTrainer
    // does, so the two notions of "trainer" cannot drift apart. This is one
    // of the invariants the sensor-sources-phase2 UI redesign must not
    // break: removing the power-meter opt-in must only drop the opt-in
    // condition from the narrow rule, not the name/service/trainer-exclusion
    // checks that protect a real trainer sold under one of these brands.
    test('a smart bike whose name matches a known power-meter brand keeps trainer '
        'control (resolves to ProxyDevice, not BlePowerDevice)', () {
      final scan = BleDevice(
        deviceId: 'stages-sb20-1',
        name: 'STAGES SB20 1234',
        services: [BleSensorSource.cyclingPowerServiceUuid, FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      );

      final classified = BluetoothDevice.fromScanResult(scan);
      expect(classified, isA<ProxyDevice>());
      expect(classified, isNot(isA<BlePowerDevice>()));
      expect((classified as ProxyDevice).isSmartTrainer, isTrue);
    });

    // Same guard, the FE-C-over-BLE half of "trainer service" — an SRM
    // trainer that speaks FE-C rather than FTMS needs the same protection;
    // ProxyDevice.isSmartTrainer treats the two as equivalent, and so does
    // this guard. The other half of the same invariant as the test above.
    test('a FE-C trainer whose name matches a known power-meter brand keeps trainer control', () {
      final scan = BleDevice(
        deviceId: 'srm-fec-1',
        name: 'SRM 4400',
        services: [BleSensorSource.cyclingPowerServiceUuid, FitnessBikeDefinition.FEC_BLE_SERVICE_UUID],
      );

      final classified = BluetoothDevice.fromScanResult(scan);
      expect(classified, isA<ProxyDevice>());
      expect(classified, isNot(isA<BlePowerDevice>()));
    });

    // Regression guard: the trainer-service exclusion above must not touch
    // the case the narrow rule exists FOR — a real power meter with no
    // trainer service at all keeps working exactly as A3 established.
    test('a power meter with no trainer service still resolves to BlePowerDevice', () {
      final scan = BleDevice(
        deviceId: 'assioma-fixd-1',
        name: 'ASSIOMA DUO-1234',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<BlePowerDevice>());
    });
  });

  // A3 (fix-wave-A): `fromScanResult`'s web branch had a broad
  // `_ when scanResult.services.contains(cyclingPowerServiceUuid) =>
  // BlePowerDevice(scanResult)` rule with NO opt-in check at all — that used
  // to be a real bug (any power meter became selectable with no consent).
  // There is no opt-in step left anywhere in this file any more: picking a
  // source in the Sensors UI is the rider's consent (see
  // `SensorQuantitySelector`), so the broad rule is now deliberately
  // unconditional too — see its comment in `fromScanResult`.
  // `BluetoothDevice.debugIsWeb` lets this branch run under the normal (VM)
  // test runner, where the real compile-time kIsWeb is always false.
  group('web detection (kIsWeb branch, via debugIsWeb)', () {
    setUp(() {
      BluetoothDevice.debugIsWeb = () => true;
    });

    tearDown(() {
      BluetoothDevice.debugIsWeb = null;
    });

    test('a power meter with an unrecognised name still resolves to BlePowerDevice on web', () {
      final scan = BleDevice(
        deviceId: 'web-pm-1',
        name: 'Totally Unknown Meter 1',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<BlePowerDevice>());
    });

    test('a known power-meter name is no longer hidden on web', () {
      final scan = BleDevice(
        deviceId: 'web-pm-3',
        name: 'ASSIOMA DUO-9999',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<BlePowerDevice>());
    });

    // fix-wave-D: the web branch's narrow rule gets the same
    // _advertisesTrainerService guard as the non-web one, for the symmetry
    // the comment above this group's narrow rule (in fromScanResult) already
    // asks for — but unlike the non-web branch, this does NOT change the
    // observable outcome for a Stages SB20-shaped device today. Web has no
    // ProxyDevice/trainer-bridging concept at all to fall back to: the broad
    // CPS rule right below the narrow one has no FTMS/FE-C exclusion of its
    // own (see fix-wave-A's comment above this group — it is deliberately
    // name-unaware) and still claims the device, and
    // wifi_trainer_scanner.dart's `if (kIsWeb) return;` plus custom_app.dart
    // excluding zwiftMdns/zwiftBle on web confirm BikeControl never offers
    // trainer bridging in a browser in the first place. So there is no
    // "trainer control" for this device to lose on web, and this test
    // documents the real (unchanged) result rather than asserting a
    // ProxyDevice-shaped outcome the web branch cannot produce.
    test('a Stages SB20-shaped device still resolves to BlePowerDevice on web (no bridging concept there)', () {
      final scan = BleDevice(
        deviceId: 'web-stages-sb20-1',
        name: 'STAGES SB20 1234',
        services: [BleSensorSource.cyclingPowerServiceUuid, FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<BlePowerDevice>());
    });

    // Regression guard, mirrored from the non-web branch: a real power meter
    // with no trainer service must keep resolving to BlePowerDevice on web.
    test('a power meter with no trainer service resolves to BlePowerDevice on web', () {
      final scan = BleDevice(
        deviceId: 'web-assioma-fixd-1',
        name: 'ASSIOMA DUO-1234',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      expect(BluetoothDevice.fromScanResult(scan), isA<BlePowerDevice>());
    });
  });

  // fix-wave-C: `Connection.performScanning`'s getSystemDevices branch feeds
  // `BluetoothDevice.fromScanResult`'s output through
  // `BluetoothDevice.isEligibleSystemDevice` before handing it to
  // `addDevices`. That branch exists because `getSystemDevices` reports
  // devices the OS already considers connected/bonded — not just ones
  // actively advertising nearby — and it has to filter by service UUID to
  // return anything at all. Once Cycling Power became one of the queried
  // services (for power meters and cadence sensors), every power meter the
  // OS has ever bonded started coming back too, including ones currently
  // held by another app. Those hit the exact same
  // `ProxyDevice.proxyServiceUUIDs` rule a live-scanned power-only trainer
  // does (see the "CPS advertiser with a non-power-meter name" test above)
  // and were added to `proxyDevices` as if they were a trainer: the "Looking
  // for smart trainers" hint disappeared, the setup chain could speak for a
  // power meter, and tapping the tile would overwrite `rememberedTrainer`.
  // `isEligibleSystemDevice` is the guard that keeps that from happening
  // without touching `fromScanResult` or `ProxyDevice.proxyServiceUUIDs`
  // themselves — both of which stay correct for a live scan result.
  group('BluetoothDevice.isEligibleSystemDevice (fix-wave-C)', () {
    test('a system-connected power meter with an unrecognised name is excluded', () {
      final scan = BleDevice(
        deviceId: 'system-pm-1',
        name: 'Totally Unknown Meter 3',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      final classified = BluetoothDevice.fromScanResult(scan);
      // Sanity check on the mechanism being guarded against: bare Cycling
      // Power with an unrecognised name classifies as a trainer.
      expect(classified, isA<ProxyDevice>());
      expect(BluetoothDevice.isEligibleSystemDevice(classified!), isFalse);
    });

    test('a known power meter stays eligible', () {
      final scan = BleDevice(
        deviceId: 'system-pm-2',
        name: 'STAGES 5678',
        services: [BleSensorSource.cyclingPowerServiceUuid],
      );

      final classified = BluetoothDevice.fromScanResult(scan);
      expect(classified, isA<BlePowerDevice>());
      expect(BluetoothDevice.isEligibleSystemDevice(classified!), isTrue);
    });

    test('a cadence sensor stays eligible', () {
      final scan = BleDevice(
        deviceId: 'system-csc-1',
        name: 'CAD 9911',
        services: [BleSensorSource.cscServiceUuid],
      );

      final classified = BluetoothDevice.fromScanResult(scan);
      expect(classified, isA<BleCadenceDevice>());
      expect(BluetoothDevice.isEligibleSystemDevice(classified!), isTrue);
    });

    test('a real smart trainer that also exposes bare Cycling Power stays eligible', () {
      final scan = BleDevice(
        deviceId: 'system-trainer-1',
        name: 'X2Max 9999',
        services: [BleSensorSource.cyclingPowerServiceUuid, FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      );

      final classified = BluetoothDevice.fromScanResult(scan);
      expect(classified, isA<ProxyDevice>());
      expect((classified as ProxyDevice).isSmartTrainer, isTrue);
      expect(BluetoothDevice.isEligibleSystemDevice(classified), isTrue);
    });

    test('a FE-C-over-BLE trainer with no FTMS stays eligible', () {
      final scan = BleDevice(
        deviceId: 'system-trainer-2',
        name: 'X2Max 8888',
        services: [BleSensorSource.cyclingPowerServiceUuid, FitnessBikeDefinition.FEC_BLE_SERVICE_UUID],
      );

      final classified = BluetoothDevice.fromScanResult(scan);
      expect(classified, isA<ProxyDevice>());
      expect(BluetoothDevice.isEligibleSystemDevice(classified!), isTrue);
    });
  });
}
