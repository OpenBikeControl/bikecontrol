import 'dart:io';

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

  GamepadDevice(super.name, {required this.id}) : super(availableButtons: []);

  List<ControllerButton> _lastButtonsClicked = [];

  @override
  Future<void> connect() async {
    Gamepads.eventsByGamepad(id).listen((event) async {
      actionStreamInternal.add(LogNotification('Gamepad event: ${event.key} value ${event.value} type ${event.type}'));

      final int normalizedValue = switch (event.value) {
        > 1.0 => 1,
        < -1.0 => -1,
        _ => event.value.toInt(),
      };

      final buttonKey = event.type == KeyType.analog ? '${event.key}_$normalizedValue' : event.key;
      ControllerButton button = getOrAddButton(
        buttonKey,
        () => ControllerButton(buttonKey),
      );

      switch (event.type) {
        case KeyType.analog:
          final releasedValue = Platform.isWindows ? 1 : 0;

          if (event.value.round().abs() != releasedValue) {
            final buttonsClicked = [button];
            if (_lastButtonsClicked.contentEquals(buttonsClicked) == false) {
              handleButtonsClicked(buttonsClicked);
            }
            _lastButtonsClicked = buttonsClicked;
          } else {
            _lastButtonsClicked = [];
            handleButtonsClicked([]);
          }
        case KeyType.button:
          final buttonsClicked = event.value.toInt() != 1 ? [button] : <ControllerButton>[];
          if (_lastButtonsClicked.contentEquals(buttonsClicked) == false) {
            handleButtonsClicked(buttonsClicked);
          }
          _lastButtonsClicked = buttonsClicked;
      }
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
