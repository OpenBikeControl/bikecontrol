import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
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

  /// Only the unlock-with-Zwift mode asks the rider to unlock this puck; the
  /// restart workaround reboots it instead.
  @override
  bool get requiresZwiftUnlock => core.settings.getUnlockWithZwift();

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

  /// The name written to the ignored-devices list alongside the id, and the
  /// only thing that identifies those entries as this puck later — see
  /// [ClickV2Onboarding.chooseUnlockWithZwift], which has to find and un-ignore
  /// them when the rider switches to the mode that needs both sides.
  static const label = 'Zwift Click V2 (left)';

  @override
  String toString() {
    return label;
  }

  /// The card header is the only cue telling the two pucks apart, so the side
  /// has to be readable in the rider's language — otherwise an English "(left)"
  /// sits above translated copy that names the *other* side, and there is no
  /// way to tell which card the copy belongs to. [toString] stays English for
  /// logs and crash reports.
  @override
  String displayName(BuildContext context) => context.i18n.deviceSideLeft(super.toString());

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
      UnlockToggle(children: unlockWarnings(context)),
    ];
  }
}
