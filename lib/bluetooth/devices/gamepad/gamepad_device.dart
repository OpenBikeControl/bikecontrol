import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:dartx/dartx.dart';
import 'package:gamepads/gamepads.dart';
import 'package:prop/emulators/shared.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class GamepadDevice extends BaseDevice {
  final String id;

  GamepadDevice(super.name, {required this.id}) : super(availableButtons: [], uniqueId: id, icon: LucideIcons.gamepad2);

  List<ControllerButton> _lastButtonsClicked = [];

  @override
  Future<void> connect() async {
    isConnected = true;

    Gamepads.normalizedEvents.where((pad) => pad.gamepadId == id).listen((event) async {
      if (event.axis != null && event.value.abs().round() != 1 && event.value.abs().round() != 0) {
        // ignore axis events that are not fully pressed to avoid accidental triggers from analog drift or light touches
        return;
      }
      final buttonKey = event.button?.name ?? '${event.axis!.name}_${event.value.round()}';

      actionStreamInternal.add(
        LogNotification('Gamepad event: ${event.button?.name ?? event.axis!.name} value ${event.value}'),
      );

      if (event.axis != null) {
        if (event.value.round().abs() != 0) {
          ControllerButton button = getOrAddButton(
            buttonKey,
            () => ControllerButton(buttonKey, sourceDeviceId: id),
          );
          final buttonsClicked = [button];
          if (_lastButtonsClicked.contentEquals(buttonsClicked) == false) {
            handleButtonsClicked(buttonsClicked);
          }
          _lastButtonsClicked = buttonsClicked;
        } else {
          _lastButtonsClicked = [];
          handleButtonsClicked([]);
        }
      } else {
        ControllerButton button = getOrAddButton(
          buttonKey,
          () => ControllerButton(buttonKey, sourceDeviceId: id),
        );
        final buttonsClicked = event.value.toInt() == 1 ? [button] : <ControllerButton>[];
        if (_lastButtonsClicked.contentEquals(buttonsClicked) == false) {
          Logger.info("Buttons clicked: ${buttonsClicked.map((b) => b.name).join(', ')}");
          handleButtonsClicked(buttonsClicked);
        }
        _lastButtonsClicked = buttonsClicked;
      }
    });
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    return [
      if (Platform.isAndroid && !core.settings.getLocalEnabled())
        Warning(
          children: [
            Text(context.i18n.androidAccessibilityHint).xSmall,
          ],
        ),
    ];
  }
}
