import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BaseActions.isExemptInternalTrainerAction', () {
    // Free tester changing gears on a live bridge a trainer app is holding.
    bool exempt({
      bool handledInternally = true,
      bool isProForDevice = false,
      bool hasFullVersion = false,
      bool bridgeCountingDown = true,
      bool appHoldsBridge = true,
    }) => BaseActions.isExemptInternalTrainerAction(
      handledInternally: handledInternally,
      isProForDevice: isProForDevice,
      hasFullVersion: hasFullVersion,
      bridgeCountingDown: bridgeCountingDown,
      appHoldsBridge: appHoldsBridge,
    );

    test('exempt when a free tester changes gears internally on a live bridge', () {
      expect(exempt(), isTrue);
    });

    test('not exempt when the action was not handled internally by the FBD', () {
      expect(exempt(handledInternally: false), isFalse);
    });

    test('not exempt for a Pro (this device) user', () {
      expect(exempt(isProForDevice: true), isFalse);
    });

    test('not exempt for a full-version owner', () {
      expect(exempt(hasFullVersion: true), isFalse);
    });

    test('not exempt once the 20-minute bridge budget is no longer counting down', () {
      expect(exempt(bridgeCountingDown: false), isFalse);
    });

    // A shift with no trainer app holding the bridge reaches nothing, so there
    // is no delivered command to charge for.
    test('exempt when no trainer app has picked the bridge up', () {
      expect(exempt(bridgeCountingDown: false, appHoldsBridge: false), isTrue);
    });

    test('still exempt when the budget ticks and the app has not picked it up', () {
      expect(exempt(appHoldsBridge: false), isTrue);
    });

    test('an undelivered shift is still not exempt for owners', () {
      expect(exempt(bridgeCountingDown: false, appHoldsBridge: false, hasFullVersion: true), isFalse);
      expect(exempt(bridgeCountingDown: false, appHoldsBridge: false, isProForDevice: true), isFalse);
    });

    test('an undelivered action the trainer did not handle is still counted', () {
      expect(exempt(handledInternally: false, appHoldsBridge: false), isFalse);
    });
  });

  group('BaseActions.passesCommandLimit', () {
    // The daily command limit is used up; does the press still go through?
    bool passes({InGameAction? action = InGameAction.shiftUp, bool bridgeCountingDown = true}) =>
        BaseActions.passesCommandLimit(action: action, bridgeCountingDown: bridgeCountingDown);

    test('gear changes run on the virtual shifting trial while it is counting down', () {
      expect(passes(action: InGameAction.shiftUp), isTrue);
      expect(passes(action: InGameAction.shiftDown), isTrue);
      expect(passes(action: InGameAction.frontShift), isTrue);
    });

    test('not once the virtual shifting trial is not counting down', () {
      expect(passes(bridgeCountingDown: false), isFalse);
    });

    test('other actions stay limited', () {
      expect(passes(action: InGameAction.navigateLeft), isFalse);
      // Handled by the local workout recorder, not the trainer.
      expect(passes(action: InGameAction.workoutPauseResume), isFalse);
      expect(passes(action: null), isFalse);
    });
  });
}
