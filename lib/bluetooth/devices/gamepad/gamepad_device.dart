import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/beta_pill.dart';

class GamepadDevice extends BaseDevice {
  final String id;

  GamepadDevice(super.name, {required this.id}) : super(availableButtons: [], isBeta: true);

  @override
  Future<void> connect() async {
    Gamepads.eventsByGamepad(id).listen((event) {
      actionStreamInternal.add(LogNotification('Gamepad event: $event'));

      ControllerButton? button = availableButtons.firstOrNullWhere((b) => b.name == event.key);

      if (button == null) {
        button = ControllerButton(event.key);
        availableButtons.add(button);
      }

      if (event.value == 0.0) {
        handleButtonsClicked([button]);
      } else {
        handleButtonsClicked([]);
      }
    });
  }

  @override
  Widget showInformation(BuildContext context) {
    return Row(
      children: [
        Text(
          name.screenshot,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (isBeta) BetaPill(),
      ],
    );
  }
}
