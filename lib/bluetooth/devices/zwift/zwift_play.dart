import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/devices/zwift/protocol/zwift.pb.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/keymap/buttons.dart';

class ZwiftPlay extends ZwiftDevice {
  ZwiftPlay(super.scanResult)
    : super(
        availableButtons: [
          ZwiftButtons.y,
          ZwiftButtons.z,
          ZwiftButtons.a,
          ZwiftButtons.b,
          ZwiftButtons.onOffRight,
          ZwiftButtons.sideButtonRight,
          ZwiftButtons.paddleRight,
          ZwiftButtons.navigationUp,
          ZwiftButtons.navigationLeft,
          ZwiftButtons.navigationRight,
          ZwiftButtons.navigationDown,
          ZwiftButtons.onOffLeft,
          ZwiftButtons.sideButtonLeft,
          ZwiftButtons.paddleLeft,
        ],
      );

  @override
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_PLAY;

  @override
  bool get canVibrate => true;

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
  Widget showInformation(BuildContext context) {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        super.showInformation(context),

        Checkbox(
          trailing: Expanded(child: Text(context.i18n.enableVibrationFeedback)),
          state: core.settings.getVibrationEnabled() ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (value) async {
            await core.settings.setVibrationEnabled(value == CheckboxState.checked);
          },
        ),
      ],
    );
  }
}
