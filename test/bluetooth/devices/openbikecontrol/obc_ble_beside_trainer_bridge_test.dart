import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/ble_definition.dart';
import 'package:prop/emulators/transporter/bluetooth_transporter.dart';
import 'package:prop/emulators/transporter/shared_peripheral.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../../fakes/fake_ble_peripheral_platform.dart';
import '../../../integration/harness/test_env.dart';

const _ftms = '00001826-0000-1000-8000-00805f9b34fb';
const _ftmsControlPoint = '00002ad9-0000-1000-8000-00805f9b34fb';

/// A trainer app (e.g. Biketerra on iOS) takes its buttons from BikeControl's
/// OpenBikeControl service and its trainer from the Bluetooth trainer bridge —
/// both served by the phone's one BLE peripheral.
Future<void> main() async {
  await IntegrationEnv.setUp();

  late FakeUniversalBlePeripheralPlatform fake;
  late OpenBikeControlBluetoothEmulator obc;

  Set<String> hosted() => fake.services.map((s) => s.uuid.toLowerCase()).toSet();

  setUp(() async {
    fake = FakeUniversalBlePeripheralPlatform();
    UniversalBlePeripheral.setInstance(fake);
    obc = OpenBikeControlBluetoothEmulator();
    await obc.startServer();
  });

  tearDown(() async {
    await obc.stopServer();
    SharedPeripheral.debugReset();
  });

  test('the OpenBikeControl service survives the trainer bridge starting', () async {
    final bridge = BluetoothTransporter(definition: _TrainerDef());
    await bridge.start();

    expect(hosted(), containsAll([OpenBikeControlConstants.SERVICE_UUID, _ftms]));
    await bridge.stop();
  });

  test('the OpenBikeControl service survives the trainer bridge stopping', () async {
    final bridge = BluetoothTransporter(definition: _TrainerDef());
    await bridge.start();
    await bridge.stop();

    expect(hosted(), contains(OpenBikeControlConstants.SERVICE_UUID));
    expect(hosted(), isNot(contains(_ftms)));
  });

  test('the trainer app can still introduce itself once the bridge is up', () async {
    final trainer = _TrainerDef();
    final bridge = BluetoothTransporter(definition: trainer);
    await bridge.start();

    // App Information v1: app id "biketerra", empty version, no buttons.
    fake.centralWrite('biketerra', OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID, [
      OpenBikeProtocolParser.MSG_TYPE_APP_INFO,
      0x01,
      9,
      ...'biketerra'.codeUnits,
      0,
      0,
    ]);
    fake.centralWrite('biketerra', _ftmsControlPoint, [0x00]);

    expect(obc.connectedApp.value?.appId, 'biketerra');
    expect(trainer.writes, [
      [0x00],
    ]);
    await bridge.stop();
  });

  test("stopping OpenBikeControl leaves the trainer bridge's services in place", () async {
    final bridge = BluetoothTransporter(definition: _TrainerDef());
    await bridge.start();

    await obc.stopServer();

    expect(hosted(), contains(_ftms));
    expect(hosted(), isNot(contains(OpenBikeControlConstants.SERVICE_UUID)));
    await bridge.stop();
  });
}

class _TrainerDef extends BleDefinition {
  final writes = <List<int>>[];

  @override
  List<String> get serviceUUIDs => const [_ftms];

  @override
  List<String> get advertiseServiceUUIDs => const ['0x1826'];

  @override
  List<BleCharacteristic> getCharacteristics(String serviceUUID) => serviceUUID.toLowerCase() == _ftms
      ? [
          BleCharacteristic(_ftmsControlPoint, [CharacteristicProperty.write], []),
        ]
      : const [];

  @override
  void onWriteRequest(String characteristicUUID, List<int> characteristicData) => writes.add(characteristicData);

  @override
  void onNotification(String characteristic, Uint8List bytes) {}
}
