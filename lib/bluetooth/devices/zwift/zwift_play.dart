import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:prop/prop.dart';

class ZwiftPlay extends ZwiftDevice {
  final ZwiftDeviceType deviceType;

  ZwiftPlay(super.scanResult, {required this.deviceType})
    : super(
        availableButtons: [
          if (deviceType == ZwiftDeviceType.playLeft) ...[
            ZwiftButtons.navigationUp,
            ZwiftButtons.navigationLeft,
            ZwiftButtons.navigationRight,
            ZwiftButtons.navigationDown,
            ZwiftButtons.onOffLeft,
            ZwiftButtons.sideButtonLeft,
            ZwiftButtons.paddleLeft,
          ],
          if (deviceType == ZwiftDeviceType.playRight) ...[
            ZwiftButtons.y,
            ZwiftButtons.z,
            ZwiftButtons.a,
            ZwiftButtons.b,
            ZwiftButtons.onOffRight,
            ZwiftButtons.sideButtonRight,
            ZwiftButtons.paddleRight,
          ],
        ],
      );

  @override
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_PLAY;

  @override
  bool get canVibrate => true;

  @override
  String get name => '${super.name} (${deviceType.name.splitByUpperCase().split(' ').last})';

  @override
  List<ControllerButton> processClickNotification(Uint8List message) {
    final status = PlayKeyPadStatus.fromBuffer(message);

    return [
      if (status.rightPad == PlayButtonStatus.ON) ...[
        if (status.buttonYUp == PlayButtonStatus.ON) ZwiftButtons.y,
        if (status.buttonZLeft == PlayButtonStatus.ON) ZwiftButtons.z,
        if (status.buttonARight == PlayButtonStatus.ON) ZwiftButtons.a,
        if (status.buttonBDown == PlayButtonStatus.ON) ZwiftButtons.b,
        if (status.buttonOn == PlayButtonStatus.ON) ZwiftButtons.onOffRight,
        if (status.buttonShift == PlayButtonStatus.ON) ZwiftButtons.sideButtonRight,
        if (status.analogLR.abs() == 100) ZwiftButtons.paddleRight,
      ],
      if (status.rightPad == PlayButtonStatus.OFF) ...[
        if (status.buttonYUp == PlayButtonStatus.ON) ZwiftButtons.navigationUp,
        if (status.buttonZLeft == PlayButtonStatus.ON) ZwiftButtons.navigationLeft,
        if (status.buttonARight == PlayButtonStatus.ON) ZwiftButtons.navigationRight,
        if (status.buttonBDown == PlayButtonStatus.ON) ZwiftButtons.navigationDown,
        if (status.buttonOn == PlayButtonStatus.ON) ZwiftButtons.onOffLeft,
        if (status.buttonShift == PlayButtonStatus.ON) ZwiftButtons.sideButtonLeft,
        if (status.analogLR.abs() == 100) ZwiftButtons.paddleLeft,
      ],
    ];
  }

  @override
  String get latestFirmwareVersion => '1.3.1';

  @override
  ControllerLayout get controllerLayout {
    if (deviceType == ZwiftDeviceType.playLeft) {
      // Mirrored: grip on the right half, handlebar drop curving to the left.
      return ControllerLayout(
        aspectRatio: 1.3,
        shape: ContourShape.zwiftPlayLeft,
        positions: {
          // D-pad diamond in the right-side grip.
          ZwiftButtons.navigationUp: const Offset(0.78, 0.24),
          ZwiftButtons.navigationLeft: const Offset(0.66, 0.40),
          ZwiftButtons.navigationRight: const Offset(0.90, 0.40),
          ZwiftButtons.navigationDown: const Offset(0.78, 0.56),
          // Handlebar-drop buttons (mirrored from the right variant).
          ZwiftButtons.onOffLeft: const Offset(0.40, 0.20),
          ZwiftButtons.sideButtonLeft: const Offset(0.22, 0.30),
          ZwiftButtons.paddleLeft: const Offset(0.08, 0.60),
        },
      );
    }
    // Right variant matches the user-supplied sketch.
    return ControllerLayout(
      aspectRatio: 1.3,
      shape: ContourShape.zwiftPlayRight,
      positions: {
        // Face-button diamond in the left-side grip.
        ZwiftButtons.y: const Offset(0.22, 0.24),
        ZwiftButtons.z: const Offset(0.10, 0.40),
        ZwiftButtons.a: const Offset(0.34, 0.40),
        ZwiftButtons.b: const Offset(0.22, 0.56),
        // Handlebar-drop buttons on the right C-curve.
        ZwiftButtons.onOffRight: const Offset(0.60, 0.20),
        ZwiftButtons.sideButtonRight: const Offset(0.78, 0.30),
        ZwiftButtons.paddleRight: const Offset(0.92, 0.60),
      },
    );
  }
}
