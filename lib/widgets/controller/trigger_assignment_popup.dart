import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/widgets/controller/trigger_conflict_dialog.dart';
import 'package:bike_control/widgets/ui/toast.dart';
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
        MenuLabel(child: Text(button.displayName)),
        for (final trigger in ButtonTrigger.values)
          MenuButton(
            onPressed: (ctx) async {
              await _openEditorForTrigger(
                context: context,
                device: device,
                button: button,
                keymap: keymap,
                trigger: trigger,
                onUpdate: onUpdate,
              );
            },
            child: _TriggerLabel(trigger: trigger, keymap: keymap, button: button),
          ),
      ],
    ),
  );
}

class _TriggerLabel extends StatelessWidget {
  final ButtonTrigger trigger;
  final Keymap keymap;
  final ControllerButton button;

  static const double _titleWidth = 110;
  static const double _rowHeight = 44;

  const _TriggerLabel({required this.trigger, required this.keymap, required this.button});

  @override
  Widget build(BuildContext context) {
    final kp = keymap.getKeyPair(button, trigger: trigger);
    final assigned = kp != null && !kp.hasNoAction;
    final value = assigned ? kp.toString() : AppLocalizations.of(context).noActionAssigned;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: _rowHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _titleWidth,
            child: Text(trigger.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (kp?.icon != null) Icon(kp!.icon, size: 16),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: assigned ? null : cs.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openEditorForTrigger({
  required BuildContext context,
  required BaseDevice device,
  required ControllerButton button,
  required Keymap keymap,
  required ButtonTrigger trigger,
  required VoidCallback onUpdate,
}) async {
  Keymap selectedKeymap = keymap;
  if (core.actionHandler.supportedApp is! CustomApp) {
    final currentProfile = core.actionHandler.supportedApp!.name;
    final newName = await KeymapManager().duplicate(
      context,
      currentProfile,
      skipName: '$currentProfile (Copy)',
    );
    if (!context.mounted) return;
    if (newName == null) return;
    buildToast(title: context.i18n.createdNewCustomProfile(newName));
    selectedKeymap = core.actionHandler.supportedApp!.keymap;
  }

  final currentKeyPair = selectedKeymap.getKeyPair(button, trigger: trigger);
  final hasAction = currentKeyPair != null && !currentKeyPair.hasNoAction;
  final isPro = IAPManager.instance.hasActiveSubscription;
  final hasOtherAssignedTrigger = hasActiveTriggerOtherThan(selectedKeymap, button, trigger);
  bool clearOtherTriggers = false;

  if (!isPro && !hasAction && hasOtherAssignedTrigger) {
    final resolution = await showTriggerConflictDialog(context, trigger);
    if (!context.mounted || resolution == null) return;

    if (resolution == TriggerConflictResolution.goPro) {
      await IAPManager.instance.purchaseSubscription(context);
      if (!context.mounted || !IAPManager.instance.hasActiveSubscription) return;
    } else if (resolution == TriggerConflictResolution.replaceOtherTriggers) {
      clearOtherTriggers = true;
    }
  }

  if (clearOtherTriggers) {
    clearOtherTriggerAssignments(selectedKeymap, button, trigger);
    selectedKeymap.signalUpdate();
  }

  final keyPair = selectedKeymap.getOrCreateKeyPair(button, trigger: trigger);
  await openDrawer(
    context: context,
    builder: (c) => ButtonEditPage(
      device: device,
      keyPair: keyPair,
      keymap: selectedKeymap,
      trigger: trigger,
      onUpdate: () {
        selectedKeymap.signalUpdate();
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
