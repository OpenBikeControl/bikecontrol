import 'package:bike_control/widgets/ui/app_theme.dart';
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
///
/// [title] replaces "Additional trigger assignment"; [offerPro] false leaves
/// out Go Pro where Pro wouldn't resolve the conflict (replacing what a
/// trigger already does). [removes] names, per trigger, the actions that
/// Replace would delete (see [actionsRemovedByReplacing]).
Future<TriggerConflictResolution?> showTriggerConflictDialog(
  BuildContext context,
  ButtonTrigger trigger, {
  String? hintText,
  String? title,
  bool? offerPro,
  Map<ButtonTrigger, String> removes = const {},
}) {
  return showDialog<TriggerConflictResolution>(
    context: context,
    builder: (c) => buildTriggerConflictDialog(
      context: c,
      trigger: trigger,
      hintText: hintText,
      title: title,
      offerPro: offerPro,
      removes: removes,
      onResolved: (resolution) => Navigator.of(c).pop(resolution),
    ),
  );
}

/// The dialog body [showTriggerConflictDialog] shows. Split out from the
/// `showDialog` call so it can be rendered on its own — the documentation
/// snapshots shoot this widget rather than a hand-built copy of it.
Widget buildTriggerConflictDialog({
  required BuildContext context,
  required ButtonTrigger trigger,
  String? hintText,
  String? title,
  bool? offerPro,
  Map<ButtonTrigger, String> removes = const {},
  required void Function(TriggerConflictResolution? resolution) onResolved,
}) {
  final showPro = offerPro ?? !IAPManager.instance.hasActiveSubscription;
  return Container(
    constraints: const BoxConstraints(maxWidth: 420),
    child: AlertDialog(
      title: Row(
        children: [
          if (showPro) ...[
            Icon(LucideIcons.crown, color: BkStatusColors.of(context).warning),
            const SizedBox(width: 8),
          ],
          Flexible(child: Text(title ?? AppLocalizations.of(context).additionalTriggerAssignment)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            hintText ?? AppLocalizations.of(context).anotherTriggerIsAlreadyAssignedForThisButton(trigger.title),
          ),
          // Replace deletes these: say which, so nothing goes silently.
          for (final MapEntry(key: removed, value: action) in removes.entries)
            Text(AppLocalizations.of(context).triggerConflictRemoves(removed.title, action)).semiBold,
        ],
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 8,
          children: [
            Button.secondary(
              onPressed: () => onResolved(null),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            Button.secondary(
              onPressed: () => onResolved(TriggerConflictResolution.replaceOtherTriggers),
              child: Text(AppLocalizations.of(context).replaceExisting),
            ),
            if (showPro)
              PrimaryButton(
                onPressed: () => onResolved(TriggerConflictResolution.goPro),
                child: Text(AppLocalizations.of(context).goPro),
              ),
          ],
        ),
      ],
    ),
  );
}

/// What [clearOtherTriggerAssignments] would delete on [button] when
/// [keepTrigger] stays: each other trigger with an action, and that action as
/// the rider knows it (its in-game name, or the key / command it sends).
Map<ButtonTrigger, String> actionsRemovedByReplacing(
  Keymap keymap,
  ControllerButton button,
  ButtonTrigger keepTrigger, {
  Set<ButtonTrigger> except = const {},
}) {
  return {
    for (final trigger in ButtonTrigger.values)
      if (trigger != keepTrigger && !except.contains(trigger))
        if (keymap.getKeyPair(button, trigger: trigger) case final kp? when !kp.hasNoAction)
          trigger: kp.inGameAction != null
              ? [kp.inGameAction!.title, if (kp.inGameActionValue != null) '${kp.inGameActionValue}'].join(': ')
              : kp.toString(),
  };
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
