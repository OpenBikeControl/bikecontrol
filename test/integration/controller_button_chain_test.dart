import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' hide RideButtonMask;

import 'harness/fake_ble_platform.dart';
import 'harness/fake_peripherals.dart';
import 'harness/test_env.dart';

/// The full reaction chain when a controller button is pressed: BLE
/// notification bytes → protocol parser → press/trigger state machine →
/// keymap lookup → performAction. Everything real except the BLE platform and
/// the final action executor (StubActions records instead of pressing keys).
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late StubActions stubActions;

  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    stubActions = StubActions();
    stubActions.supportedApp = Zwift();
    core.actionHandler = stubActions;
  });

  tearDown(() async {
    await env.resetConnection();
  });

  Future<(FakePeripheral, ZwiftClick)> connectClick() async {
    final click = buildZwiftClick();
    autoRespondToZwiftHandshake(env.ble, click);
    env.ble.addPeripheral(click);
    await core.connection.performScanning();
    await IntegrationEnv.waitFor(
      () => core.connection.devices.whereType<ZwiftClick>().isNotEmpty,
      description: 'Zwift Click in device list',
    );
    final device = core.connection.devices.whereType<ZwiftClick>().first;
    // The RideOn handshake write is the last step of the connect flow — only
    // after it is the device fully wired (customService set, subscriptions
    // active). Pressing earlier races handleServices.
    await IntegrationEnv.waitFor(() => click.writes.isNotEmpty, description: 'Zwift Click handshake');
    return (click, device);
  }

  void press(FakePeripheral click, {required bool plus, required bool minus}) {
    env.ble.notify(
      click.deviceId,
      ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
      zwiftClickNotification(plusPressed: plus, minusPressed: minus),
    );
  }

  void release(FakePeripheral click) => press(click, plus: false, minus: false);

  group('single click', () {
    test('plus press + release performs the mapped shiftUp button action', () async {
      final (click, _) = await connectClick();

      press(click, plus: true, minus: false);
      release(click);

      await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'performed action');
      final action = stubActions.performedActions.single;
      expect(action.button, ZwiftButtons.shiftUpRight);
      expect(action.isDown, isTrue);
      expect(action.isUp, isTrue);
      expect(action.trigger, ButtonTrigger.singleClick);

      // The Zwift keymap maps this button to the shiftUp in-game action —
      // the part of the chain a trainer connection would consume next.
      final keyPair = stubActions.supportedApp!.keymap.getKeyPair(action.button, trigger: ButtonTrigger.singleClick);
      expect(keyPair!.inGameAction, InGameAction.shiftUp);
    });

    test('minus press maps to shiftDown', () async {
      final (click, _) = await connectClick();

      press(click, plus: false, minus: true);
      release(click);

      await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'performed action');
      expect(stubActions.performedActions.single.button, ZwiftButtons.shiftUpLeft);
      final keyPair = stubActions.supportedApp!.keymap.getKeyPair(
        ZwiftButtons.shiftUpLeft,
        trigger: ButtonTrigger.singleClick,
      );
      expect(keyPair!.inGameAction, InGameAction.shiftDown);
    });

    test('duplicate BLE frames for the same press are de-duplicated', () async {
      final (click, _) = await connectClick();

      press(click, plus: true, minus: false);
      press(click, plus: true, minus: false); // device repeats while held
      press(click, plus: true, minus: false);
      release(click);

      await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'performed action');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(stubActions.performedActions.length, 1);
    });

    test('a button press emits a ButtonNotification on the connection action stream', () async {
      final (click, _) = await connectClick();

      final notifications = <BaseNotification>[];
      final sub = core.connection.actionStream.listen(notifications.add);

      press(click, plus: true, minus: false);
      release(click);

      await IntegrationEnv.waitFor(
        () => notifications.whereType<ButtonNotification>().isNotEmpty,
        description: 'ButtonNotification on action stream',
      );
      final buttonNotification = notifications.whereType<ButtonNotification>().first;
      expect(buttonNotification.buttonsClicked, [ZwiftButtons.shiftUpRight]);
      await sub.cancel();
    });
  });

  group('trigger configuration', () {
    test('double click triggers the doubleClick keypair, suppressing the single click', () async {
      final (click, _) = await connectClick();

      // Configure: double-clicking plus performs a u-turn.
      stubActions.supportedApp!.keymap.keyPairs.add(
        KeyPair(
          buttons: [ZwiftButtons.shiftUpRight],
          physicalKey: null,
          logicalKey: null,
          trigger: ButtonTrigger.doubleClick,
          inGameAction: InGameAction.uturn,
        ),
      );

      press(click, plus: true, minus: false);
      release(click);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      press(click, plus: true, minus: false);
      release(click);

      await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'double click action');
      // Wait past the single-click window to be sure no extra single fires.
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(stubActions.performedActions.length, 1);
      expect(stubActions.performedActions.single.trigger, ButtonTrigger.doubleClick);
    });

    test('a single click with a doubleClick mapping waits out the window, then fires single', () async {
      final (click, _) = await connectClick();

      stubActions.supportedApp!.keymap.keyPairs.add(
        KeyPair(
          buttons: [ZwiftButtons.shiftUpRight],
          physicalKey: null,
          logicalKey: null,
          trigger: ButtonTrigger.doubleClick,
          inGameAction: InGameAction.uturn,
        ),
      );

      press(click, plus: true, minus: false);
      release(click);

      // Inside the 320 ms double-click window nothing must fire yet.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(stubActions.performedActions, isEmpty);

      await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'deferred single');
      expect(stubActions.performedActions.single.trigger, ButtonTrigger.singleClick);
    });

    test('holding a long-press-mapped button performs down on hold and release on let-go', () async {
      final (click, _) = await connectClick();

      stubActions.supportedApp!.keymap.keyPairs.add(
        KeyPair(
          buttons: [ZwiftButtons.shiftUpRight],
          physicalKey: null,
          logicalKey: null,
          trigger: ButtonTrigger.longPress,
          inGameAction: InGameAction.usePowerUp,
        ),
      );

      press(click, plus: true, minus: false);
      // Hold past the 550 ms long-press threshold.
      await IntegrationEnv.waitFor(
        () => stubActions.performedActions.isNotEmpty,
        timeout: const Duration(seconds: 2),
        description: 'long-press down',
      );
      final down = stubActions.performedActions.single;
      expect(down.trigger, ButtonTrigger.longPress);
      expect(down.isDown, isTrue);
      expect(down.isUp, isFalse);

      release(click);
      await IntegrationEnv.waitFor(() => stubActions.performedActions.length >= 2, description: 'long-press release');
      final up = stubActions.performedActions.last;
      expect(up.isDown, isFalse);
      expect(up.isUp, isTrue);
    });

    test('an unmapped button still routes through performAction and reports the error result', () async {
      final (click, device) = await connectClick();

      // Strip the keymap so the button has no action.
      stubActions.supportedApp!.keymap.keyPairs.clear();

      final results = <ActionNotification>[];
      final sub = device.actionStream.listen((n) {
        if (n is ActionNotification) results.add(n);
      });

      press(click, plus: true, minus: false);
      release(click);

      await IntegrationEnv.waitFor(() => results.isNotEmpty, description: 'action result notification');
      await sub.cancel();
      // StubActions returns an Error result; the chain must surface it.
      // (base_actions.Error clashes with dart:core.Error, so compare by name.)
      expect(results.first.result.runtimeType.toString(), 'Error');
    });
  });

  group('Zwift Ride protobuf buttons', () {
    Future<(FakePeripheral, ZwiftRide)> connectRide() async {
      final ride = buildZwiftRide();
      autoRespondToZwiftHandshake(env.ble, ride, startResponse: ZwiftConstants.RESPONSE_START_PLAY);
      env.ble.addPeripheral(ride);
      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.devices.whereType<ZwiftRide>().isNotEmpty,
        description: 'Zwift Ride in device list',
      );
      final device = core.connection.devices.whereType<ZwiftRide>().first;
      // Wait for the handshake write — the Ride vibrates on shift presses,
      // which needs the custom service resolved by handleServices first.
      await IntegrationEnv.waitFor(() => ride.writes.isNotEmpty, description: 'Zwift Ride handshake');
      return (ride, device);
    }

    test('a shift-up-right press decodes from the buttonMap (inverted bits)', () async {
      final (ride, _) = await connectRide();

      env.ble.notify(
        ride.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftRideNotification(pressed: [RideButtonMask.SHFT_UP_R_BTN]),
      );
      env.ble.notify(
        ride.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftRideNotification(),
      );

      await IntegrationEnv.waitFor(() => stubActions.performedActions.isNotEmpty, description: 'ride action');
      expect(stubActions.performedActions.single.button, ZwiftButtons.shiftUpRight);
    });

    test('multiple simultaneous buttons fire a combined click immediately', () async {
      final (ride, _) = await connectRide();

      env.ble.notify(
        ride.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftRideNotification(pressed: [RideButtonMask.A_BTN, RideButtonMask.B_BTN]),
      );
      env.ble.notify(
        ride.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftRideNotification(),
      );

      await IntegrationEnv.waitFor(
        () => stubActions.performedActions.length >= 2,
        description: 'both buttons performed',
      );
      expect(
        stubActions.performedActions.map((a) => a.button).toSet(),
        {ZwiftButtons.a, ZwiftButtons.b},
      );
    });
  });
}
