import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:bike_control/widgets/unlock_toggle.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ZwiftClickV2LeftSide extends ZwiftClickV2 {
  ZwiftClickV2LeftSide(super.scanResult)
    : super(
        availableButtons: [
          ZwiftButtons.navigationUp,
          ZwiftButtons.navigationDown,
          ZwiftButtons.navigationLeft,
          ZwiftButtons.navigationRight,
          ZwiftButtons.shiftUpLeft,
        ],
      );

  @override
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK_V2;

  @override
  bool get isResetting => ClickLogic.isResetting(device.deviceId);

  @override
  ControllerLayout get controllerLayout => ControllerLayout(
    aspectRatio: 215 / 252.9,
    shape: ContourShape.pill,
    svgAsset: 'assets/contours/zwift_click_v2_left_side.svg',
    positions: {
      ZwiftButtons.navigationUp: const Offset(0.492, 0.25),
      ZwiftButtons.navigationLeft: const Offset(0.244, 0.44),
      ZwiftButtons.navigationRight: const Offset(0.741, 0.44),
      ZwiftButtons.navigationDown: const Offset(0.492, 0.62),
      ZwiftButtons.shiftUpLeft: const Offset(0.492, 0.87),
    },
  );

  @override
  String toString() {
    return "Zwift Click V2 (left)";
  }

  @override
  Future<void> setupHandshake() async {
    // The device is back online, so a ClickLogic-initiated reset (if any) is
    // over — un-mute its entry and notifications again.
    ClickLogic.clearResetting(device.deviceId);
    await sendCommandBuffer(Uint8List.fromList(startCommand));
    if (!core.settings.getUnlockWithZwift()) {
      await ClickLogic.setupHandshake(services!, device.deviceId, isRight: false);
    }
  }

  @override
  Future<void> processData(Uint8List bytes) async {
    if (!core.settings.getUnlockWithZwift()) {
      ClickLogic.processData(bytes, services: services!, deviceId: device.deviceId);
    }
    super.processData(bytes);
  }

  @override
  List<ControllerButton> processClickNotification(Uint8List message) {
    final buttons = super.processClickNotification(message);
    return buttons.where((button) => availableButtons.contains(button)).toList();
  }

  @override
  List<Widget> showAdditionalInformation(BuildContext context) {
    return [
      UnlockToggle(device: this, children: super.showAdditionalInformation(context)),
    ];
  }
}
