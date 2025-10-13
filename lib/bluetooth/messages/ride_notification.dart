import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/bluetooth/protocol/zwift.pb.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';

enum _RideButtonMask {
  LEFT_BTN(0x00001),
  UP_BTN(0x00002),
  RIGHT_BTN(0x00004),
  DOWN_BTN(0x00008),

  A_BTN(0x00010),
  B_BTN(0x00020),
  Y_BTN(0x00040),
  Z_BTN(0x00080),

  SHFT_UP_L_BTN(0x00100),
  SHFT_DN_L_BTN(0x00200),
  SHFT_UP_R_BTN(0x01000),
  SHFT_DN_R_BTN(0x02000),

  POWERUP_L_BTN(0x00400),
  POWERUP_R_BTN(0x04000),
  ONOFF_L_BTN(0x00800),
  ONOFF_R_BTN(0x08000);

  final int mask;

  const _RideButtonMask(this.mask);
}

class RideNotification extends BaseNotification {
  late List<ControllerButton> buttonsClicked;
  late List<ControllerButton> analogButtons;

  RideNotification(Uint8List message, {required int analogPaddleThreshold}) {
    final status = RideKeyPadStatus.fromBuffer(message);

    // Debug: Log all button mask detections (moved to ZwiftRide.processClickNotification)

    // Process DIGITAL buttons separately
    buttonsClicked = [
      if (status.buttonMap & _RideButtonMask.LEFT_BTN.mask == PlayButtonStatus.ON.value)
        ControllerButton.navigationLeft,
      if (status.buttonMap & _RideButtonMask.RIGHT_BTN.mask == PlayButtonStatus.ON.value)
        ControllerButton.navigationRight,
      if (status.buttonMap & _RideButtonMask.UP_BTN.mask == PlayButtonStatus.ON.value) ControllerButton.navigationUp,
      if (status.buttonMap & _RideButtonMask.DOWN_BTN.mask == PlayButtonStatus.ON.value)
        ControllerButton.navigationDown,
      if (status.buttonMap & _RideButtonMask.A_BTN.mask == PlayButtonStatus.ON.value) ControllerButton.a,
      if (status.buttonMap & _RideButtonMask.B_BTN.mask == PlayButtonStatus.ON.value) ControllerButton.b,
      if (status.buttonMap & _RideButtonMask.Y_BTN.mask == PlayButtonStatus.ON.value) ControllerButton.y,
      if (status.buttonMap & _RideButtonMask.Z_BTN.mask == PlayButtonStatus.ON.value) ControllerButton.z,
      if (status.buttonMap & _RideButtonMask.SHFT_UP_L_BTN.mask == PlayButtonStatus.ON.value)
        ControllerButton.shiftUpLeft,
      if (status.buttonMap & _RideButtonMask.SHFT_DN_L_BTN.mask == PlayButtonStatus.ON.value)
        ControllerButton.shiftDownLeft,
      if (status.buttonMap & _RideButtonMask.SHFT_UP_R_BTN.mask == PlayButtonStatus.ON.value)
        ControllerButton.shiftUpRight,
      if (status.buttonMap & _RideButtonMask.SHFT_DN_R_BTN.mask == PlayButtonStatus.ON.value)
        ControllerButton.shiftDownRight,
      if (status.buttonMap & _RideButtonMask.POWERUP_L_BTN.mask == PlayButtonStatus.ON.value)
        ControllerButton.powerUpLeft,
      if (status.buttonMap & _RideButtonMask.POWERUP_R_BTN.mask == PlayButtonStatus.ON.value)
        ControllerButton.powerUpRight,
      if (status.buttonMap & _RideButtonMask.ONOFF_L_BTN.mask == PlayButtonStatus.ON.value) ControllerButton.onOffLeft,
      if (status.buttonMap & _RideButtonMask.ONOFF_R_BTN.mask == PlayButtonStatus.ON.value) ControllerButton.onOffRight,
    ];

    // Process ANALOG inputs separately - now properly separated from digital
    // All analog paddles (L0-L3) appear in field 3 as repeated RideAnalogKeyPress
    analogButtons = [];
    try {
      for (final paddle in status.analogPaddles) {
        if (paddle.hasLocation() && paddle.hasAnalogValue()) {
          if (paddle.analogValue.abs() >= analogPaddleThreshold) {
            final button = switch (paddle.location.value) {
              0 => ControllerButton.paddleLeft, // L0 = left paddle
              1 => ControllerButton.paddleRight, // L1 = right paddle
              _ => null, // L2, L3 unused
            };

            if (button != null) {
              buttonsClicked.add(button);
              analogButtons.add(button);
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing analog paddle data: $e');
      }
    }
  }

  @override
  String toString() {
    final digitalButtons = buttonsClicked.where((b) => !analogButtons.contains(b)).toList();
    return 'Digital: ${digitalButtons.joinToString(transform: (e) => e.name.splitByUpperCase())} | Analog: ${analogButtons.joinToString(transform: (e) => e.name.splitByUpperCase())}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RideNotification &&
          runtimeType == other.runtimeType &&
          buttonsClicked.contentEquals(other.buttonsClicked);

  @override
  int get hashCode => buttonsClicked.hashCode;
}
