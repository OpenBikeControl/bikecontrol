import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Opens a dropdown anchored to [context] with one entry per [ButtonTrigger].
/// Tapping an entry opens the existing [ButtonEditPage] side drawer for that
/// trigger. Mirrors `keymap_explanation.dart::_openButtonEditor` but initiated
/// by a user tap on a controller button (not a physical press).
Future<void> showTriggerAssignmentPopup({
  required BuildContext context,
  required BaseDevice device,
  required ControllerButton button,
  required Keymap keymap,
  required VoidCallback onUpdate,
}) async {
  showDropdown<void>(
    context: context,
    builder: (c) => DropdownMenu(
      children: [
        for (final trigger in ButtonTrigger.values)
          MenuButton(
            leading: Icon(
              keymap.getKeyPair(button, trigger: trigger)?.icon ?? Icons.add_circle_outline,
              size: 16,
            ),
            onPressed: (ctx) async {
              Navigator.of(ctx).pop();
              await _openEditorForTrigger(
                context: context,
                device: device,
                button: button,
                keymap: keymap,
                trigger: trigger,
                onUpdate: onUpdate,
              );
            },
            child: Text(_labelFor(context, trigger, keymap, button)),
          ),
      ],
    ),
  );
}

String _labelFor(BuildContext context, ButtonTrigger trigger, Keymap keymap, ControllerButton button) {
  final kp = keymap.getKeyPair(button, trigger: trigger);
  if (kp == null || kp.hasNoAction) {
    return '${trigger.title}: ${AppLocalizations.of(context).noActionAssigned}';
  }
  final actionName = kp.inGameAction?.title ?? kp.physicalKey?.debugName ?? AppLocalizations.of(context).action;
  return '${trigger.title}: $actionName';
}

Future<void> _openEditorForTrigger({
  required BuildContext context,
  required BaseDevice device,
  required ControllerButton button,
  required Keymap keymap,
  required ButtonTrigger trigger,
  required VoidCallback onUpdate,
}) async {
  final keyPair = keymap.getOrCreateKeyPair(button, trigger: trigger);
  await openDrawer(
    context: context,
    builder: (c) => ButtonEditPage(
      device: device,
      keyPair: keyPair,
      keymap: keymap,
      trigger: trigger,
      onUpdate: () {
        keymap.signalUpdate();
        if (core.actionHandler.supportedApp is CustomApp) {
          core.settings.setKeyMap(core.actionHandler.supportedApp!);
        }
        onUpdate();
      },
    ),
    position: OverlayPosition.end,
  );
  if (core.actionHandler.supportedApp is CustomApp) {
    core.settings.setKeyMap(core.actionHandler.supportedApp!);
  }
  onUpdate();
}
