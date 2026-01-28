import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/pages/device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:dartx/dartx.dart';
import 'package:gamepads/gamepads.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GamepadDevice extends BaseDevice {
  final String id;

  GamepadDevice(super.name, {required this.id}) : super(availableButtons: [], uniqueId: id);

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
        () => ControllerButton(buttonKey, sourceDeviceId: id),
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
                toString().screenshot,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (isBeta) BetaPill(),
            ],
          ),
          if (Platform.isAndroid && !core.settings.getLocalEnabled())
            Warning(
              children: [
                Text(
                  'For it to work properly, even when BikeControl is in the background, you need to enable the local connection method in the next tab.',
                ).small,
              ],
            ),
        ],
      ),
    );
  }
}
