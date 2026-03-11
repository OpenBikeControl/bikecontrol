import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testButton = ControllerButton('testButton');

  CustomApp buildApp({
    required bool hasSingle,
    required bool hasDouble,
    required bool hasLong,
  }) {
    final app = CustomApp(profileName: 'Test');
    if (hasSingle) {
      app.keymap.addKeyPair(
        KeyPair(
          buttons: [testButton],
          physicalKey: null,
          logicalKey: null,
          trigger: ButtonTrigger.singleClick,
          inGameAction: InGameAction.shiftUp,
        ),
      );
    }
    if (hasDouble) {
      app.keymap.addKeyPair(
        KeyPair(
          buttons: [testButton],
          physicalKey: null,
          logicalKey: null,
          trigger: ButtonTrigger.doubleClick,
          inGameAction: InGameAction.shiftDown,
        ),
      );
    }
    if (hasLong) {
      app.keymap.addKeyPair(
        KeyPair(
          buttons: [testButton],
          physicalKey: null,
          logicalKey: null,
          trigger: ButtonTrigger.longPress,
          inGameAction: InGameAction.steerLeft,
        ),
      );
    }
    return app;
  }

  setUp(() {
    core.actionHandler = StubActions();
  });

  test('fires long press immediately on button down when long press is the only mapped trigger', () async {
    final stubActions = core.actionHandler as StubActions;
    core.actionHandler.init(
      buildApp(
        hasSingle: false,
        hasDouble: false,
        hasLong: true,
      ),
    );
    final device = _TestDevice(button: testButton);

    await device.handleButtonsClicked([testButton]);

    expect(stubActions.performedActions.length, 1);
    expect(
      stubActions.performedActions.single,
      PerformedAction(testButton, isDown: true, isUp: false, trigger: ButtonTrigger.longPress),
    );

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(stubActions.performedActions.length, 1);

    await device.handleButtonsClicked([]);
    expect(stubActions.performedActions.length, 2);
    expect(
      stubActions.performedActions.last,
      PerformedAction(testButton, isDown: false, isUp: true, trigger: ButtonTrigger.longPress),
    );
  });

  test('keeps delayed long press behavior when single click action is also mapped', () async {
    final stubActions = core.actionHandler as StubActions;
    core.actionHandler.init(
      buildApp(
        hasSingle: true,
        hasDouble: false,
        hasLong: true,
      ),
    );
    final device = _TestDevice(button: testButton);

    await device.handleButtonsClicked([testButton]);
    expect(stubActions.performedActions, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(stubActions.performedActions, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(stubActions.performedActions.length, 1);
    expect(
      stubActions.performedActions.single,
      PerformedAction(testButton, isDown: true, isUp: false, trigger: ButtonTrigger.longPress),
    );
  });
}

class _TestDevice extends BaseDevice {
  _TestDevice({required ControllerButton button})
    : super(
        'TestDevice',
        uniqueId: 'test-device-id',
        availableButtons: [button],
        icon: Icons.gamepad,
      );

  @override
  Future<void> connect() async {}

  @override
  Widget showInformation(BuildContext context) => const SizedBox.shrink();
}
