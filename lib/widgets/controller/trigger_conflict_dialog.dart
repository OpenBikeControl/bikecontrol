import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Result of the additional-trigger-assignment confirmation dialog. Callers
/// act on it: `goPro` triggers a paywall; `replaceOtherTriggers` wipes other
/// triggers on the same button before continuing.
enum TriggerConflictResolution {
  goPro,
  replaceOtherTriggers,
}

/// Shared "another trigger is already assigned" dialog, used by both the
/// physical-press flow in `KeymapExplanation` and the tap-to-assign popup in
/// `showTriggerAssignmentPopup`. Returns `null` when the user cancels.
Future<TriggerConflictResolution?> showTriggerConflictDialog(
  BuildContext context,
  ButtonTrigger trigger, {
  String? hintText,
}) {
  return showDialog<TriggerConflictResolution>(
    context: context,
    builder: (c) => Container(
      constraints: const BoxConstraints(maxWidth: 420),
      child: AlertDialog(
        title: Row(
          children: [
            if (!IAPManager.instance.hasActiveSubscription) ...[
              Icon(Icons.workspace_premium, color: Colors.orange),
              const SizedBox(width: 8),
            ],
            Text(AppLocalizations.of(context).additionalTriggerAssignment),
          ],
        ),
        content: Text(
          hintText ?? AppLocalizations.of(context).anotherTriggerIsAlreadyAssignedForThisButton(trigger.title),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 8,
            children: [
              Button.secondary(
                onPressed: () => Navigator.of(c).pop(),
                child: Text(AppLocalizations.of(context).cancel),
              ),
              Button.secondary(
                onPressed: () => Navigator.of(c).pop(TriggerConflictResolution.replaceOtherTriggers),
                child: Text(AppLocalizations.of(context).replaceExisting),
              ),
              if (!IAPManager.instance.hasActiveSubscription)
                PrimaryButton(
                  onPressed: () => Navigator.of(c).pop(TriggerConflictResolution.goPro),
                  child: Text(AppLocalizations.of(context).goPro),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// True when [button] has at least one assigned trigger other than [trigger]
/// with a non-empty action in [keymap].
bool hasActiveTriggerOtherThan(Keymap keymap, ControllerButton button, ButtonTrigger trigger) {
  for (final other in ButtonTrigger.values) {
    if (other == trigger) continue;
    final keyPair = keymap.getKeyPair(button, trigger: other);
    if (keyPair != null && !keyPair.hasNoAction) return true;
  }
  return false;
}

/// Wipe every trigger assignment on [button] except [keepTrigger]. Used after
/// the user chose `replaceOtherTriggers` in [showTriggerConflictDialog].
void clearOtherTriggerAssignments(
  Keymap keymap,
  ControllerButton button,
  ButtonTrigger keepTrigger,
) {
  for (final trigger in ButtonTrigger.values) {
    if (trigger == keepTrigger) continue;
    final existing = keymap.getKeyPair(button, trigger: trigger);
    if (existing == null || existing.hasNoAction) continue;

    final keyPair = keymap.getOrCreateKeyPair(button, trigger: trigger);
    keyPair.physicalKey = null;
    keyPair.logicalKey = null;
    keyPair.modifiers = [];
    keyPair.touchPosition = Offset.zero;
    keyPair.inGameAction = null;
    keyPair.inGameActionValue = null;
    keyPair.androidAction = null;
    keyPair.command = null;
    keyPair.screenshotPath = null;
  }
}
