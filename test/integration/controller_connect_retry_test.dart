import 'dart:async';

import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/test_env.dart';

/// A controller whose connect times out (macOS: `UniversalBle.connect` throws
/// TimeoutException and the platform never reports a disconnect) must be
/// tried again — through the REAL Connection class; only the BLE platform is
/// fake. The peripheral advertises once only, so the retry can't come from
/// rediscovery: the scan-result dedupe swallows repeats of the same advert.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();

  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    final stubActions = StubActions();
    stubActions.supportedApp = Zwift();
    core.actionHandler = stubActions;
    core.connection.connectRetryBaseDelay = const Duration(milliseconds: 200);
  });

  tearDown(() async {
    await env.resetConnection();
  });

  FakePeripheral timingOutClick() {
    final click = buildZwiftClick();
    autoRespondToZwiftHandshake(env.ble, click);
    click.connectError = TimeoutException('Future not completed', const Duration(minutes: 1));
    click.connectErrorDeliversDisconnect = false;
    return click;
  }

  test('a controller that timed out connecting is tried again and connects', () async {
    final click = timingOutClick();
    env.ble.addPeripheral(click);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(() => click.connectAttempts >= 1, description: 'first connect attempt');
    // The controller is reachable again by the time the retry fires.
    click.connectError = null;

    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<ZwiftClick>().any((d) => d.isConnected),
      timeout: const Duration(seconds: 5),
      description: 'retry to connect the controller',
    );
    expect(click.connectAttempts, 2);
  });

  test('keeps retrying with a growing delay while the connect keeps timing out', () async {
    final click = timingOutClick();
    env.ble.addPeripheral(click);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(
      () => click.connectAttempts >= 3,
      timeout: const Duration(seconds: 5),
      description: 'two retries',
    );
    // Never two attempts at once: exactly one device instance, not connected.
    expect(core.connection.devices.whereType<ZwiftClick>(), hasLength(1));
  });

  test('no retry once the rider removed the controller', () async {
    core.connection.connectRetryBaseDelay = const Duration(milliseconds: 400);
    final click = timingOutClick();
    env.ble.addPeripheral(click);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(() => click.connectAttempts >= 1, description: 'first connect attempt');
    final device = core.connection.devices.whereType<ZwiftClick>().single;
    await core.connection.disconnect(device, forget: true, persistForget: false);

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(click.connectAttempts, 1);
    expect(core.connection.devices.whereType<ZwiftClick>(), isEmpty);
  });

  test('no retry once the rider disconnected the controller in place', () async {
    core.connection.connectRetryBaseDelay = const Duration(milliseconds: 400);
    final click = timingOutClick();
    env.ble.addPeripheral(click);
    await core.connection.performScanning();

    await IntegrationEnv.waitFor(() => click.connectAttempts >= 1, description: 'first connect attempt');
    final device = core.connection.devices.whereType<ZwiftClick>().single;
    await core.connection.disconnect(device, forget: false, persistForget: false, keepInList: true);

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(click.connectAttempts, 1);
  });
}
