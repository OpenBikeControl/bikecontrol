import 'package:bike_control/bluetooth/devices/smart_bike/smart_bike_trainer.dart';
import 'package:bike_control/bluetooth/devices/tacx/tacx_neo_bike.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/profiles/tacx_profiles.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';

import 'harness/test_env.dart';

/// A Tacx NEO Bike is ONE peripheral that is both a smart trainer and the
/// host of its shifters. Through the real Connection class it must show up as
/// a controller AND as a trainer over a single BLE connection, read its gear
/// tables, and turn gear changes into shifts.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late StubActions stubActions;

  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    stubActions = StubActions();
    core.actionHandler = stubActions;
  });

  tearDown(() async {
    await env.resetConnection();
  });

  Future<TacxNeoBike> connectBike(FakePeripheral bike) async {
    autoRespondToTacxGearRequests(env.ble, bike);
    env.ble.addPeripheral(bike);
    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<TacxNeoBike>().any((d) => d.isConnected),
      description: 'NEO Bike connected as a controller',
    );
    return core.connection.devices.whereType<TacxNeoBike>().single;
  }

  test('the bike is a controller and a trainer over one connection', () async {
    final bike = buildTacxNeoBike();
    final controller = await connectBike(bike);

    await IntegrationEnv.waitFor(() => core.connection.proxyDevices.isNotEmpty, description: 'trainer listed');
    final trainer = core.connection.proxyDevices.single;
    expect(trainer, isA<SmartBikeTrainer>());
    expect((trainer as SmartBikeTrainer).host, controller);
    expect(core.connection.controllerDevices, [controller]);
    expect(bike.connectAttempts, 1);

    final mirrored = (await trainer.discoverUpstreamServices()).map((s) => s.uuid.toLowerCase()).toList();
    expect(mirrored, isNot(contains(TacxNeoBikeConstants.SERVICE_UUID)));
    expect(mirrored, contains(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase()));
  });

  test('subscribes the vendor characteristics and asks for the gear tables', () async {
    final bike = buildTacxNeoBike();
    final controller = await connectBike(bike);

    for (final uuid in [
      TacxNeoBikeConstants.ERRORS_UUID,
      TacxNeoBikeConstants.GEAR_STATUS_UUID,
      TacxNeoBikeConstants.BUTTONS_UUID,
      TacxNeoBikeConstants.CONTROL_POINT_UUID,
    ]) {
      expect(bike.subscriptions, contains(uuid));
    }
    final cpWrites = bike.writes.where(
      (w) => w.characteristic.toLowerCase() == TacxNeoBikeConstants.CONTROL_POINT_UUID,
    );
    expect(cpWrites.map((w) => w.value.toList()), [
      [TacxNeoBikeConstants.OPCODE_FRONT_GEARS],
      [TacxNeoBikeConstants.OPCODE_REAR_GEARS],
    ]);
    await IntegrationEnv.waitFor(
      () => controller.shiftDetector.rearTable != null && controller.shiftDetector.frontTable != null,
      description: 'gear tables received',
    );
    expect(controller.shiftDetector.rearTable, tacxEmulatedRearTable);
    expect(controller.shiftDetector.frontTable, tacxEmulatedFrontTable);
  });

  test('a gear change on the bike is a shift', () async {
    final bike = buildTacxNeoBike();
    final controller = await connectBike(bike);
    await IntegrationEnv.waitFor(() => controller.shiftDetector.rearTable != null, description: 'gear tables');

    env.ble.notify(bike.deviceId, TacxNeoBikeConstants.GEAR_STATUS_UUID, tacxGearFrame(front: 50, rear: 17));
    env.ble.notify(bike.deviceId, TacxNeoBikeConstants.GEAR_STATUS_UUID, tacxGearFrame(front: 50, rear: 15));
    await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'shift action');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      stubActions.performedActions.map((a) => a.button),
      [TacxNeoBikeButtons.rearUp],
    );
  });

  test('old firmware without the vendor service stays a trainer only', () async {
    final bike = buildTacxNeoBike(withVendorService: false);
    env.ble.addPeripheral(bike);
    await core.connection.performScanning();
    await IntegrationEnv.waitFor(() => core.connection.proxyDevices.isNotEmpty, description: 'trainer listed');
    expect(core.connection.proxyDevices.single, isA<SmartBikeTrainer>());
  });
}
