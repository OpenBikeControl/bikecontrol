import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Some actions only do something while the button is held: the trainer app
/// steers (or keeps the microphone open) for as long as it sees the press. A
/// single or double click sends the press and its release back to back, so
/// on a click they do next to nothing.
void main() {
  test('exactly the steering and push-to-talk actions require a hold', () {
    final requiringHold = InGameAction.values.where((a) => a.requiresHold).toSet();
    expect(requiringHold, {
      // MyWhoosh Link sends "Steering -1/1" on the press and "0" on the
      // release; the Zwift-protocol and OpenBikeControl paths send the
      // LEFT/RIGHT button as held until the release.
      InGameAction.steerLeft,
      InGameAction.steerRight,
      // OpenBikeControl's push-to-talk talks while its button reads pressed.
      InGameAction.pushToTalk,
    });
  });

  group('KeyPair.holdActionOnClick', () {
    KeyPair pair(InGameAction? action, ButtonTrigger trigger) => KeyPair(
      buttons: [ZwiftButtons.navigationLeft],
      physicalKey: null,
      logicalKey: null,
      inGameAction: action,
      trigger: trigger,
    );

    test('a hold action on a single or double click is flagged', () {
      expect(pair(InGameAction.steerLeft, ButtonTrigger.singleClick).holdActionOnClick, isTrue);
      expect(pair(InGameAction.steerRight, ButtonTrigger.doubleClick).holdActionOnClick, isTrue);
      expect(pair(InGameAction.pushToTalk, ButtonTrigger.singleClick).holdActionOnClick, isTrue);
    });

    test('on a long press, or for an action a click does fine, it is not', () {
      expect(pair(InGameAction.steerLeft, ButtonTrigger.longPress).holdActionOnClick, isFalse);
      expect(pair(InGameAction.shiftUp, ButtonTrigger.singleClick).holdActionOnClick, isFalse);
      expect(pair(null, ButtonTrigger.singleClick).holdActionOnClick, isFalse);
    });
  });

  test('no built-in mapping ships a hold action on a click', () {
    final offenders = <String>[];
    for (final app in SupportedApp.supportedApps.where((a) => a is! CustomApp)) {
      for (final kp in app.keymap.keyPairs.where((k) => k.holdActionOnClick)) {
        offenders.add(
          '${app.name}: ${kp.buttons.map((b) => b.name).join('+')} ${kp.trigger.name} → ${kp.inGameAction}',
        );
      }
    }
    expect(offenders, isEmpty);
  });

  test('MyWhoosh: the right navigation buttons steer right, not left', () {
    final keymap = MyWhoosh().keymap;
    final rightButtons = ControllerButton.values.where((b) => b.action == InGameAction.navigateRight);
    expect(rightButtons, isNotEmpty);
    for (final b in rightButtons) {
      expect(
        keymap.getKeyPair(b, trigger: ButtonTrigger.longPress)?.inGameAction,
        InGameAction.steerRight,
        reason: b.name,
      );
    }
  });

  group('moveTriggerAssignment', () {
    setUp(() => core.actionHandler = StubActions());

    test('moves the action, its key and value to the other trigger and clears the click', () {
      final keymap = Keymap(
        keyPairs: [
          KeyPair(
            buttons: [ZwiftButtons.navigationLeft],
            physicalKey: PhysicalKeyboardKey.arrowLeft,
            logicalKey: LogicalKeyboardKey.arrowLeft,
            touchPosition: const Offset(10, 20),
            inGameAction: InGameAction.steerLeft,
          ),
        ],
      );
      moveTriggerAssignment(
        keymap,
        ZwiftButtons.navigationLeft,
        from: ButtonTrigger.singleClick,
        to: ButtonTrigger.longPress,
      );

      final moved = keymap.getKeyPair(ZwiftButtons.navigationLeft, trigger: ButtonTrigger.longPress)!;
      expect(moved.inGameAction, InGameAction.steerLeft);
      expect(moved.physicalKey, PhysicalKeyboardKey.arrowLeft);
      expect(moved.logicalKey, LogicalKeyboardKey.arrowLeft);
      expect(moved.touchPosition, const Offset(10, 20));
      final click = keymap.getKeyPair(ZwiftButtons.navigationLeft, trigger: ButtonTrigger.singleClick);
      expect(click == null || click.hasNoAction, isTrue);
    });

    test('replaces what the long press did', () {
      final keymap = Keymap(
        keyPairs: [
          KeyPair(
            buttons: [ZwiftButtons.a],
            physicalKey: null,
            logicalKey: null,
            inGameAction: InGameAction.steerRight,
            trigger: ButtonTrigger.doubleClick,
          ),
          KeyPair(
            buttons: [ZwiftButtons.a],
            physicalKey: PhysicalKeyboardKey.keyK,
            logicalKey: LogicalKeyboardKey.keyK,
            inGameAction: InGameAction.shiftUp,
            trigger: ButtonTrigger.longPress,
          ),
        ],
      );
      moveTriggerAssignment(keymap, ZwiftButtons.a, from: ButtonTrigger.doubleClick, to: ButtonTrigger.longPress);

      final moved = keymap.getKeyPair(ZwiftButtons.a, trigger: ButtonTrigger.longPress)!;
      expect(moved.inGameAction, InGameAction.steerRight);
      expect(moved.physicalKey, isNull, reason: 'the old long press key goes with its action');
      expect(keymap.getKeyPair(ZwiftButtons.a, trigger: ButtonTrigger.doubleClick)!.hasNoAction, isTrue);
    });
  });
}
