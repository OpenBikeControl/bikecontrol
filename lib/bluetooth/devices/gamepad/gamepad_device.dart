import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/ui/beta_pill.dart';

class GamepadDevice extends BaseDevice {
  final String id;

  GamepadDevice(super.name, {required this.id}) : super(availableButtons: [], isBeta: true);

  List<ControllerButton> _lastButtonsClicked = [];

  @override
  Future<void> connect() async {
    Gamepads.eventsByGamepad(id).listen((event) async {
      actionStreamInternal.add(LogNotification('Gamepad event: $event'));

      ControllerButton button = await getOrAddButton(
        event.key,
        () => ControllerButton(event.key),
      );

      final buttonsClicked = event.value == 0.0 ? [button] : <ControllerButton>[];
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
            spacing: 8,
            children: [
              Text(
                name.screenshot,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isBeta) BetaPill(),
            ],
          ),
        ],
      ),
    );
  }
}
