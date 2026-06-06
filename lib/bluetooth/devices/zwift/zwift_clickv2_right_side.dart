import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ZwiftClickV2RightSide extends ZwiftRide {
  ZwiftClickV2RightSide(super.scanResult)
    : super(
        isBeta: false,
        availableButtons: [
          ZwiftButtons.a,
          ZwiftButtons.b,
          ZwiftButtons.y,
          ZwiftButtons.z,
          ZwiftButtons.shiftUpRight,
        ],
      );

  @override
  String get latestFirmwareVersion => '1.1.0';

  @override
  bool get canVibrate => false;

  @override
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK_V2;

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 215 / 252.9,
    shape: ContourShape.pill,
    svgAsset: 'assets/contours/zwift_click_v2_right_side.svg',
    positions: {
      // Right puck — face-button diamond. Per the physical device: Y top,
      // Z left, A right, B bottom. Plus (shift-up-right) sits under B.
      ZwiftButtons.y: const Offset(0.500, 0.25),
      ZwiftButtons.z: const Offset(0.252, 0.44),
      ZwiftButtons.a: const Offset(0.723, 0.44),
      ZwiftButtons.b: const Offset(0.500, 0.62),
      ZwiftButtons.shiftUpRight: const Offset(0.500, 0.87),
    },
  );

  @override
  String toString() {
    return "Zwift Click V2 (right side)";
  }

  @override
  Future<void> setupHandshake() async {
    await sendCommandBuffer(Uint8List.fromList(startCommand));
    ClickLogic.setupHandshake(services!, device.deviceId, isRight: true);
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    return [
      Text(context.i18n.unlock_rightSideNeedsNoUnlock).xSmall.normal,
    ];
  }
}
