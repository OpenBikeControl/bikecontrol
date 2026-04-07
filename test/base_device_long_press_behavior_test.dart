import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main() async {
  const testButton = ControllerButton('testButton');

  await AppLocalizations.load(Locale('en'));

  // Track devices to ensure cleanup across tests.
  final activeDevices = <BaseDevice>[];

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

  tearDown(() async {
    // Disconnect all tracked devices to cancel any running timers.
    for (final device in activeDevices) {
      await device.disconnect();
    }
    activeDevices.clear();
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
    activeDevices.add(device);

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
    activeDevices.add(device);

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

  group('implicit repeat on long press', () {
    test('starts repeating single click for Pro users with no explicit long press action', () async {
      final stubActions = core.actionHandler as StubActions;
      core.actionHandler.init(
        buildApp(
          hasSingle: true,
          hasDouble: false,
          hasLong: false,
        ),
      );
      final device = _ProTestDevice(button: testButton);
      activeDevices.add(device);

      // Press button
      await device.handleButtonsClicked([testButton]);

      // No immediate action — waiting for long press timer
      expect(stubActions.performedActions, isEmpty);

      // Wait for long press timer to fire (550ms)
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Should have started repeating single click
      expect(stubActions.performedActions, isNotEmpty);
      expect(
        stubActions.performedActions.first,
        PerformedAction(testButton, isDown: true, isUp: true, trigger: ButtonTrigger.singleClick),
      );

      // Wait for more repeats (150ms interval)
      final countAfterFirst = stubActions.performedActions.length;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(stubActions.performedActions.length, greaterThan(countAfterFirst));

      // All repeated actions should be single clicks
      for (final action in stubActions.performedActions) {
        expect(action.trigger, ButtonTrigger.singleClick);
        expect(action.isDown, true);
        expect(action.isUp, true);
      }

      // Release button to cancel repeat timer
      await device.handleButtonsClicked([]);
    });

    test('stops repeating on button release', () async {
      final stubActions = core.actionHandler as StubActions;
      core.actionHandler.init(
        buildApp(
          hasSingle: true,
          hasDouble: false,
          hasLong: false,
        ),
      );
      final device = _ProTestDevice(button: testButton);
      activeDevices.add(device);

      // Press and wait for repeat to start
      await device.handleButtonsClicked([testButton]);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(stubActions.performedActions, isNotEmpty);

      // Release button
      await device.handleButtonsClicked([]);

      // Allow any in-flight repeat callback to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final countAfterRelease = stubActions.performedActions.length;

      // Wait and verify no more repeats fire
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(stubActions.performedActions.length, countAfterRelease);
    });

    test('does not repeat for non-Pro users', () async {
      final stubActions = core.actionHandler as StubActions;
      core.actionHandler.init(
        buildApp(
          hasSingle: true,
          hasDouble: false,
          hasLong: false,
        ),
      );
      final device = _TestDevice(button: testButton); // non-Pro
      activeDevices.add(device);

      // Press button
      await device.handleButtonsClicked([testButton]);

      // Wait past long press timer — no repeat should start (no long press action for non-Pro)
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(stubActions.performedActions, isEmpty);

      // Release button — should fire single click normally
      await device.handleButtonsClicked([]);
      expect(stubActions.performedActions.length, 1);
      expect(
        stubActions.performedActions.single,
        PerformedAction(testButton, isDown: true, isUp: true, trigger: ButtonTrigger.singleClick),
      );
    });
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
}

class _ProTestDevice extends BaseDevice {
  _ProTestDevice({required ControllerButton button})
    : super(
        'ProTestDevice',
        uniqueId: 'pro-test-device-id',
        availableButtons: [button],
        icon: Icons.gamepad,
      );

  @override
  bool get isProEnabledForRepeat => true;

  @override
  Future<void> connect() async {}
}
