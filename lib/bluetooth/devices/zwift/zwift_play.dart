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
            ZwiftButtons.paddleLeftInward,
            ZwiftButtons.paddleLeftOutward,
          ],
          if (deviceType == ZwiftDeviceType.playRight) ...[
            ZwiftButtons.y,
            ZwiftButtons.z,
            ZwiftButtons.a,
            ZwiftButtons.b,
            ZwiftButtons.onOffRight,
            ZwiftButtons.sideButtonRight,
            ZwiftButtons.paddleRightInward,
            ZwiftButtons.paddleRightOutward,
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
        if (status.analogLR.abs() == ZwiftPaddle.full) ZwiftPaddle.button(right: true, value: status.analogLR),
      ],
      if (status.rightPad == PlayButtonStatus.OFF) ...[
        if (status.buttonYUp == PlayButtonStatus.ON) ZwiftButtons.navigationUp,
        if (status.buttonZLeft == PlayButtonStatus.ON) ZwiftButtons.navigationLeft,
        if (status.buttonARight == PlayButtonStatus.ON) ZwiftButtons.navigationRight,
        if (status.buttonBDown == PlayButtonStatus.ON) ZwiftButtons.navigationDown,
        if (status.buttonOn == PlayButtonStatus.ON) ZwiftButtons.onOffLeft,
        if (status.buttonShift == PlayButtonStatus.ON) ZwiftButtons.sideButtonLeft,
        if (status.analogLR.abs() == ZwiftPaddle.full) ZwiftPaddle.button(right: false, value: status.analogLR),
      ],
    ];
  }

  @override
  String get latestFirmwareVersion => '1.3.1';

  @override
  ControllerLayout get controllerLayout {
    if (deviceType == ZwiftDeviceType.playLeft) {
      // Mirrored: grip on the right (~40-98%), handlebar drop on the left (~2-44%).
      return ControllerLayout(
        aspectRatio: 260 / 288,
        shape: ContourShape.steeringPad,
        svgAsset: 'assets/contours/zwift_play.svg',
        positions: {
          // On/off sits directly below the down button.
          ZwiftButtons.onOffLeft: const Offset(0.69, 0.76),
          // D-pad diamond in the right-side grip.
          ZwiftButtons.navigationUp: const Offset(0.69, 0.24),
          ZwiftButtons.navigationLeft: const Offset(0.54, 0.40),
          ZwiftButtons.navigationRight: const Offset(0.84, 0.40),
          ZwiftButtons.navigationDown: const Offset(0.69, 0.56),
          // Paddle on top of the drop, side button to its LEFT on the left
          // controller. Outward keeps the paddle's spot; inward sits below it,
          // in toward the grip (no room for both side by side).
          ZwiftButtons.paddleLeftOutward: const Offset(0.32, 0.19),
          ZwiftButtons.paddleLeftInward: const Offset(0.29, 0.50),
          ZwiftButtons.sideButtonLeft: const Offset(0.08, 0.19),
        },
      );
    }
    // Framed on the pod and its buttons together (the paddle and side button
    // reach past the art on the right), so the whole picture sits centred.
    // Frame: x 108..443 of the 515-wide drawing the positions were measured
    // in; the art keeps its place in it via [svgAlignment].
    return ControllerLayout(
      aspectRatio: 335 / 288,
      shape: ContourShape.steeringPad,
      svgAsset: 'assets/contours/zwift_play.svg',
      mirrorX: true,
      svgAlignment: const Alignment(-0.63, 0),
      positions: {
        ZwiftButtons.onOffRight: const Offset(0.262, 0.76),
        ZwiftButtons.y: const Offset(0.262, 0.24),
        ZwiftButtons.a: const Offset(0.416, 0.40),
        ZwiftButtons.z: const Offset(0.108, 0.40),
        ZwiftButtons.b: const Offset(0.262, 0.56),
        // Outward keeps the paddle's spot; inward sits below it, toward the grip.
        ZwiftButtons.paddleRightOutward: const Offset(0.677, 0.19),
        ZwiftButtons.paddleRightInward: const Offset(0.70, 0.50),
        ZwiftButtons.sideButtonRight: const Offset(0.892, 0.19),
      },
    );
  }
}
