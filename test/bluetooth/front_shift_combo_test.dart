import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/prop.dart' hide RideButtonMask;

import '../integration/harness/fake_ble_platform.dart';
import '../integration/harness/fake_peripherals.dart';
import '../integration/harness/test_env.dart';

/// Test-local StubActions subclass that exposes the combo hooks with full
/// control over [frontShiftComboEnabled], without touching the shared
/// [StubActions] (so other tests are unaffected).
class _ComboStubActions extends StubActions {
  bool comboEnabled = true;
  final List<InGameAction> inGameActionsPerformed = [];

  @override
  bool get frontShiftComboEnabled => comboEnabled;

  @override
  Future<ActionResult> performInGameAction(InGameAction action) async {
    inGameActionsPerformed.add(action);
    return Success('stub', button: null);
  }
}

Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late _ComboStubActions comboActions;

  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    comboActions = _ComboStubActions();
    comboActions.supportedApp = Zwift();
    core.actionHandler = comboActions;
  });

  tearDown(() async {
    await env.resetConnection();
  });

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
    await IntegrationEnv.waitFor(() => ride.writes.isNotEmpty, description: 'Zwift Ride handshake');
    return (ride, device);
  }

  group('same-frame both-shifters combo', () {
    test('combo enabled: single Ride frame with both shift buttons emits frontShift and suppresses rear shifts',
        () async {
      final (ride, _) = await connectRide();

      // shiftUpRight → InGameAction.shiftUp; shiftUpLeft → InGameAction.shiftDown
      // One frame containing both = same-frame combo → should fire frontShift only.
      env.ble.notify(
        ride.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftRideNotification(pressed: [RideButtonMask.SHFT_UP_R_BTN, RideButtonMask.SHFT_UP_L_BTN]),
      );
      // Release frame
      env.ble.notify(
        ride.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftRideNotification(),
      );

      await IntegrationEnv.waitFor(
        () => comboActions.inGameActionsPerformed.isNotEmpty,
        description: 'frontShift in-game action',
      );

      expect(comboActions.inGameActionsPerformed, [InGameAction.frontShift]);

      // The rear shifts must be suppressed — performedActions should be empty
      // (the combo returns early before performClick is reached).
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        comboActions.performedActions.where(
          (a) => a.button == ZwiftButtons.shiftUpRight || a.button == ZwiftButtons.shiftUpLeft,
        ),
        isEmpty,
        reason: 'rear shifts must be suppressed when combo fires',
      );
    });

    test('combo disabled: same frame fires both rear shifts normally and no frontShift', () async {
      comboActions.comboEnabled = false;

      final (ride, _) = await connectRide();

      env.ble.notify(
        ride.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftRideNotification(pressed: [RideButtonMask.SHFT_UP_R_BTN, RideButtonMask.SHFT_UP_L_BTN]),
      );
      env.ble.notify(
        ride.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftRideNotification(),
      );

      await IntegrationEnv.waitFor(
        () => comboActions.performedActions.length >= 2,
        description: 'both shift buttons performed',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        comboActions.performedActions.map((a) => a.button).toSet(),
        containsAll([ZwiftButtons.shiftUpRight, ZwiftButtons.shiftUpLeft]),
        reason: 'both rear shifts should fire when combo is disabled',
      );
      expect(comboActions.inGameActionsPerformed, isEmpty, reason: 'no frontShift when combo is disabled');
    });
  });
}
