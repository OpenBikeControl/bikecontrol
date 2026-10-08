import 'package:bike_control/bluetooth/devices/cycplus/cycplus_bc2.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/thinkrider/thinkrider_vs200.dart';
import 'package:bike_control/bluetooth/emulation/emulation_profile.dart';
import 'package:bike_control/bluetooth/emulation/profiles/misc_profiles.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/widgets/title.dart' show packageInfoValue;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'harness/test_env.dart';

Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late StubActions stubActions;

  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    stubActions = StubActions();
    core.actionHandler = stubActions;
    core.emulation.reset();
    core.emulation.attach(env.ble);
    // OpenBikeControlDevice.handleServices writes an app-info payload that
    // reads packageInfoValue!.version. Production sets this global from
    // AppUpdateButton's initState (PackageInfo.fromPlatform()); the harness never
    // runs that widget, so seed it directly or the write crashes with a
    // null-check error before the app-info write test assertion ever runs.
    packageInfoValue = PackageInfo(
      appName: 'BikeControl',
      packageName: 'app.bikecontrol',
      version: '1.0.0',
      buildNumber: '1',
    );
  });

  tearDown(() async {
    await env.resetConnection();
  });

  Future<void> connect<T extends Object>(EmulationProfile profile) async {
    core.emulation.start(profile);
    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<T>().isNotEmpty,
      description: '$T detected',
    );
  }

  test('Cycplus BC2: shift-up press performs shiftUp', () async {
    await connect<CycplusBc2>(cycplusBc2Profile);
    final session = core.emulation.sessionFor('emulated:cycplus-bc2')!;

    final up = session.inputs.whereType<EmulatedButton>().firstWhere((b) => b.label == 'Shift up');
    up.onDown();
    up.onUp();

    await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'cycplus action');
    // CycplusBc2 passes allowMultiple: true, so BluetoothDevice copies its
    // static buttons with sourceDeviceId set to this session's deviceId —
    // the performed button no longer == the bare CycplusBc2Buttons.shiftUp
    // constant (sourceDeviceId participates in ControllerButton equality).
    // Compare by name, like the dynamically-created SRAM/OBC/Di2 buttons below.
    expect(
      stubActions.performedActions.map((a) => a.button.name),
      contains(CycplusBc2Buttons.shiftUp.name),
    );
  });

  test('ThinkRider VS200: shift-up pattern performs one click', () async {
    await connect<ThinkRiderVs200>(thinkRiderVs200Profile);
    final session = core.emulation.sessionFor('emulated:thinkrider-vs200')!;

    session.inputs.whereType<EmulatedAction>().firstWhere((a) => a.label == 'Shift up').run();

    await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'thinkrider action');
    // Same allowMultiple: true caveat as CycplusBc2 above — compare by name.
    expect(
      stubActions.performedActions.map((a) => a.button.name),
      contains(ThinkRiderVs200Buttons.shiftUp.name),
    );
  });

  test('SRAM AXS: a single tap performs the generic SRAM Button (undecoded, no bond)', () async {
    await connect<SramAxs>(sramAxsProfile);
    final session = core.emulation.sessionFor('emulated:sram-axs')!;

    // A real derailleur only notifies subscribers, but the emulated platform
    // delivers regardless — wait for the app's trigger subscription so the
    // press can't land mid-connect (handleServices resets gesture state).
    await IntegrationEnv.waitFor(
      () => session.peripheral.subscriptions.contains(SramAxsConstants.TRIGGER_UUID),
      description: 'trigger-char subscription',
    );

    session.inputs.whereType<EmulatedAction>().firstWhere((a) => a.label == 'Tap').run();

    // The tap fires after the double-click window (up to 600 ms) elapses.
    await IntegrationEnv.waitFor(
      () => stubActions.performedActions.isNotEmpty,
      timeout: const Duration(seconds: 3),
      description: 'sram tap action',
    );
    expect(stubActions.performedActions.map((a) => a.button.name), contains('SRAM Button'));
  });

  test('OpenBikeControl: Shift Up press performs the Shift Up button', () async {
    await connect<OpenBikeControlDevice>(openBikeControlProfile);
    final session = core.emulation.sessionFor('emulated:openbikecontrol')!;

    // The app writes its app-info to the peripheral during handleServices.
    await IntegrationEnv.waitFor(
      () => session.peripheral.writes.isNotEmpty,
      description: 'app-info write',
    );

    final up = session.inputs.whereType<EmulatedButton>().firstWhere((b) => b.label == 'Shift Up');
    up.onDown();
    up.onUp();

    await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'obc action');
    expect(stubActions.performedActions.map((a) => a.button.name), contains('Shift Up'));
  });

  test('Shimano Di2: channel 1 press performs the D-Fly Channel 1 button', () async {
    // ShimanoDi2 creates its channel buttons via getOrAddButton, which is a
    // no-op that never populates availableButtons while supportedApp is
    // null (BaseDevice.getOrAddButton's bare-StubActions short circuit) —
    // and the device's own click handling looks buttons up in
    // availableButtons by name. Give it a real (non-CustomApp-duplicating)
    // supportedApp so the channel buttons actually get registered.
    stubActions.supportedApp = CustomApp();
    await connect<ShimanoDi2>(shimanoDi2Profile);
    final session = core.emulation.sessionFor('emulated:di2')!;

    final channel1 = session.inputs.whereType<EmulatedButton>().firstWhere((b) => b.label == 'D-Fly Channel 1');
    channel1.onDown();
    channel1.onUp();

    await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'di2 action');
    expect(stubActions.performedActions.map((a) => a.button.name), contains('D-Fly Channel 1'));
  });
}
