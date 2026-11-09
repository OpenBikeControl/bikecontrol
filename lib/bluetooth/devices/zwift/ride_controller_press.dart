import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart' show RideButtonMask;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:prop/prop.dart' hide RideButtonMask;

/// What an action presses on the emulated Zwift controller: buttons and/or paddles.
class RideControllerPress {
  /// Analog value of a fully pulled paddle.
  static const int fullPaddle = 100;

  final int buttonMask;
  final List<RideAnalogLocation> paddles;

  /// Paddles tilt outward (steering) unless [inward] (braking).
  final bool inward;

  const RideControllerPress({this.buttonMask = 0, this.paddles = const [], this.inward = false});

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

  /// Keypad status while held.
  List<int> get pressed => _status(buttonMask, fullPaddle);

  /// Keypad status on release. Paddles are sent back at 0: a frame without
  /// them leaves the last paddle value in place.
  List<int> get released => _status(0, 0);

  List<int> _status(int mask, int paddleValue) {
    final status = RideKeyPadStatus()..buttonMap = (~mask) & 0xFFFFFFFF;
    for (final paddle in paddles) {
      // Outward: the left paddle goes negative, the right positive. Inward is the opposite.
      final outward = paddle == RideAnalogLocation.LEFT ? -paddleValue : paddleValue;
      final value = inward ? -outward : outward;
      status.analogPaddles.add(RideAnalogKeyPress(location: paddle, analogValue: value));
    }
    return status.writeToBuffer();
  }
}
