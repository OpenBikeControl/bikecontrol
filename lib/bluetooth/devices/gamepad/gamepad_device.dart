import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/ui/beta_pill.dart';

import '../../../widgets/ui/warning.dart';

class GamepadDevice extends BaseDevice {
  final String id;

  GamepadDevice(super.name, {required this.id}) : super(availableButtons: [], isBeta: true);

  List<ControllerButton> _lastButtonsClicked = [];

  @override
  Future<void> connect() async {
    Gamepads.eventsByGamepad(id).listen((event) {
      actionStreamInternal.add(LogNotification('Gamepad event: $event'));

      ControllerButton? button = core.actionHandler.supportedApp?.keymap.getOrAddButton(
        event.key,
        () => ControllerButton(event.key),
      );

      final buttonsClicked = event.value == 0.0 && button != null ? [button] : <ControllerButton>[];
      if (_lastButtonsClicked.contentEquals(buttonsClicked) == false) {
        handleButtonsClicked(buttonsClicked);
      }
      _lastButtonsClicked = buttonsClicked;
    });
  }

  @override
  Widget showInformation(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        spacing: 8,
        children: [
          Row(
            children: [
              Text(
                name.screenshot,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isBeta) BetaPill(),
            ],
          ),

          if (core.actionHandler.supportedApp is! CustomApp)
            Warning(
              children: [
                Text('Use a custom keymap to use the buttons on $name.'),
              ],
            ),
        ],
      ),
    );
  }
}
