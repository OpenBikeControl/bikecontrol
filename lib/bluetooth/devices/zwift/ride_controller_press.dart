import 'dart:async';

import 'package:bike_control/bluetooth/devices/zwift/constants.dart' show ZwiftPaddle;
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart' show RideButtonMask;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:prop/prop.dart' hide RideButtonMask;

/// What an action presses on the emulated Zwift controller: buttons and/or paddles.
class RideControllerPress {
  /// Analog value of a fully pulled paddle.
  static const int fullPaddle = ZwiftPaddle.full;

  final int buttonMask;
  final List<RideAnalogLocation> paddles;

  /// Paddles tilt outward (steering) unless [inward] (braking).
  final bool inward;

  /// How long the press stays down at least, even if the button is let go
  /// sooner. Zwift only fires some actions on a hold.
  final Duration? minHold;

  const RideControllerPress({this.buttonMask = 0, this.paddles = const [], this.inward = false, this.minHold});

  /// Zwift fires the Ride On Bomb when Z is held for 750 ms; a tap only shows it.
  static const rideOnBombHold = Duration(milliseconds: 1000);

  RideControllerPress.button(RideButtonMask button) : this(buttonMask: button.mask);

  /// Whether the emulators present themselves as a Zwift Ride to the selected app.
  static bool get emulatesRide => core.settings.getTrainerApp()?.emulatesZwiftRide ?? false;

  static RideControllerPress? of(InGameAction? action) {
    return switch (action) {
      InGameAction.shiftUp => RideControllerPress.button(RideButtonMask.SHFT_UP_R_BTN),
      InGameAction.shiftDown => RideControllerPress.button(RideButtonMask.SHFT_UP_L_BTN),
      InGameAction.uturn => RideControllerPress.button(RideButtonMask.DOWN_BTN),
      // A Ride steers with the paddles; on a Ride, Zwift uses D-pad left/right for menus.
      InGameAction.steerLeft when emulatesRide => const RideControllerPress(paddles: [RideAnalogLocation.LEFT]),
      InGameAction.steerRight when emulatesRide => const RideControllerPress(paddles: [RideAnalogLocation.RIGHT]),
      InGameAction.steerLeft => RideControllerPress.button(RideButtonMask.LEFT_BTN),
      InGameAction.steerRight => RideControllerPress.button(RideButtonMask.RIGHT_BTN),
      InGameAction.navigateLeft when emulatesRide => RideControllerPress.button(RideButtonMask.LEFT_BTN),
      InGameAction.navigateRight when emulatesRide => RideControllerPress.button(RideButtonMask.RIGHT_BTN),
      InGameAction.openActionBar => RideControllerPress.button(RideButtonMask.UP_BTN),
      InGameAction.usePowerUp => RideControllerPress.button(RideButtonMask.Y_BTN),
      InGameAction.select => RideControllerPress.button(RideButtonMask.A_BTN),
      InGameAction.back => RideControllerPress.button(RideButtonMask.B_BTN),
      InGameAction.rideOnBomb when emulatesRide => RideControllerPress(
        buttonMask: RideButtonMask.Z_BTN.mask,
        minHold: rideOnBombHold,
      ),
      InGameAction.rideOnBomb => RideControllerPress.button(RideButtonMask.Z_BTN),
      InGameAction.leftDropButton => RideControllerPress.button(RideButtonMask.POWERUP_L_BTN),
      InGameAction.rightDropButton => RideControllerPress.button(RideButtonMask.POWERUP_R_BTN),
      InGameAction.leftShiftButton2 => RideControllerPress.button(RideButtonMask.SHFT_DN_L_BTN),
      InGameAction.rightShiftButton2 => RideControllerPress.button(RideButtonMask.SHFT_DN_R_BTN),
      InGameAction.brake => const RideControllerPress(
        paddles: [RideAnalogLocation.LEFT, RideAnalogLocation.RIGHT],
        inward: true,
      ),
      _ => null,
    };
  }

  /// The controller button an action is pressed as, shown under its name
  /// ([InGameAction.alternativeTitle]). As a Ride, steering is the paddles
  /// and the D-pad's left and right navigate instead.
  static String? caption(InGameAction action) {
    if (!emulatesRide) return action.alternativeTitle;
    return switch (action) {
      InGameAction.steerLeft || InGameAction.steerRight => null,
      InGameAction.navigateLeft => InGameAction.steerLeft.alternativeTitle,
      InGameAction.navigateRight => InGameAction.steerRight.alternativeTitle,
      _ => action.alternativeTitle,
    };
  }

  /// Keypad status while held.
  List<int> get pressed => _status(buttonMask, fullPaddle);

  /// Keypad status on release. Paddles are sent back at 0: a frame without
  /// them leaves the last paddle value in place.
  List<int> get released => _status(0, 0);

  List<int> _status(int mask, int paddleValue) {
    final status = RideKeyPadStatus()..buttonMap = (~mask) & 0xFFFFFFFF;
    for (final paddle in paddles) {
      final value = ZwiftPaddle.value(
        right: paddle == RideAnalogLocation.RIGHT,
        inward: inward,
        magnitude: paddleValue,
      );
      status.analogPaddles.add(RideAnalogKeyPress(location: paddle, analogValue: value));
    }
    return status.writeToBuffer();
  }
}

/// Holds back the release of a press with a [RideControllerPress.minHold]
/// until that time has passed since it went down.
class RideReleaseDelay {
  final Map<InGameAction, Timer> _holds = {};
  final Map<InGameAction, void Function()> _pending = {};

  /// Call when [action] goes down.
  void down(InGameAction action, RideControllerPress press) {
    // A new press of the same action: let go of the previous one first.
    _holds.remove(action)?.cancel();
    _pending.remove(action)?.call();
    final minHold = press.minHold;
    if (minHold == null) return;
    _holds[action] = Timer(minHold, () {
      _holds.remove(action);
      _pending.remove(action)?.call();
    });
  }

  /// Whether the release of [action] waits for its minimum hold. If so,
  /// [release] runs once that time has passed; otherwise the caller releases.
  bool deferRelease(InGameAction action, void Function() release) {
    if (!(_holds[action]?.isActive ?? false)) return false;
    _pending[action] = release;
    return true;
  }
}
