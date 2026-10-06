import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/widgets/controller/trigger_conflict_dialog.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Which button (and which of its triggers) the button-mapping screen is
/// showing. Shared by the list of buttons and, in wide windows, the detail
/// pane beside it.
class MappingSelection extends ChangeNotifier {
  BaseDevice? _device;
  ControllerButton? _button;
  ButtonTrigger _trigger = ButtonTrigger.singleClick;

  BaseDevice? get device => _device;
  ControllerButton? get button => _button;
  ButtonTrigger get trigger => _trigger;

  bool isSelected(BaseDevice device, ControllerButton button) =>
      _device?.uniqueId == device.uniqueId && _button?.name == button.name;

  /// Picks [button] of [device], on [trigger] (single click unless given).
  void select(BaseDevice device, ControllerButton button, {ButtonTrigger trigger = ButtonTrigger.singleClick}) {
    if (isSelected(device, button) && _trigger == trigger) return;
    _device = device;
    _button = button;
    _trigger = trigger;
    notifyListeners();
  }

  /// Collapses the selection (the phone list's open row closes).
  void clear() {
    if (_button == null) return;
    _button = null;
    notifyListeners();
  }

  void selectTrigger(ButtonTrigger trigger) {
    if (_trigger == trigger) return;
    _trigger = trigger;
    notifyListeners();
  }

  /// Selects the first button of [device] when nothing of it is selected
  /// yet — the wide layout always shows one button's detail.
  void ensureFor(BaseDevice device) {
    if (_device?.uniqueId == device.uniqueId && _button != null) return;
    final first = mappingButtonsOf(device).firstOrNull;
    if (first == null) return;
    _device = device;
    _button = first;
    _trigger = ButtonTrigger.singleClick;
  }
}

/// [device]'s buttons in the order the mapping lists them: coloured face
/// buttons first, then the rest, each by icon.
List<ControllerButton> mappingButtonsOf(BaseDevice device) => device.availableButtons.distinct().sortedBy(
  (button) => button.color != null ? '0${(button.icon?.codePoint ?? 0)}' : '1${(button.icon?.codePoint ?? 0)}',
);

/// The triggers of [button] that send something, in trigger order.
List<ButtonTrigger> mappingActiveTriggers(Keymap keymap, ControllerButton button) => ButtonTrigger.values.where((
  trigger,
) {
  final keyPair = keymap.getKeyPair(button, trigger: trigger);
  return keyPair != null && !keyPair.hasNoAction;
}).toList();

/// Without Pro a button does one thing. Once it has an action, its other
/// triggers are Pro: they carry the PRO badge.
bool mappingTriggerIsPro(Keymap keymap, ControllerButton button, ButtonTrigger trigger) {
  if (IAPManager.instance.hasActiveSubscription) return false;
  final active = mappingActiveTriggers(keymap, button);
  return active.isNotEmpty && active.first != trigger;
}

/// A trigger beyond the one a button may have without Pro that is still
/// assigned (e.g. from before Pro ran out): editing it asks first.
bool mappingTriggerOverLimit(Keymap keymap, ControllerButton button, ButtonTrigger trigger) {
  if (IAPManager.instance.hasActiveSubscription) return false;
  final active = mappingActiveTriggers(keymap, button);
  return active.length > 1 && active.skip(1).contains(trigger);
}

/// Why [trigger] can't fire on its own for a controller that reports no
/// hold: its long press is set, so presses toggle instead. Null when it can.
String? mappingTriggerBlockedHint(
  BuildContext context,
  Keymap keymap,
  BaseDevice device,
  ControllerButton button,
  ButtonTrigger trigger,
) {
  final longPress = keymap.getKeyPair(button, trigger: ButtonTrigger.longPress);
  final togglesOnLongPress = !device.supportsLongPress && longPress != null && !longPress.hasNoAction;
  if (!togglesOnLongPress || trigger == ButtonTrigger.longPress) return null;
  return context.i18n.removeOnePressAction(device.name);
}

/// What editing [trigger] of [button] needs before the action picker opens:
/// the Pro / one-action-per-button question when it applies, and a copy of a
/// built-in mapping (which can't be changed itself). Returns the keymap to
/// edit, or null when the rider backed out. [askFirst] false skips the
/// question (a physical press opens its editor straight away).
Future<Keymap?> resolveTriggerEdit(
  BuildContext context, {
  required Keymap keymap,
  required BaseDevice device,
  required ControllerButton button,
  required ButtonTrigger trigger,
  bool askFirst = true,
}) async {
  final keyPair = keymap.getKeyPair(button, trigger: trigger);
  final hasAction = keyPair != null && !keyPair.hasNoAction;
  final hintText = mappingTriggerBlockedHint(context, keymap, device, button, trigger);
  final isPro = IAPManager.instance.hasActiveSubscription;
  final hasOtherAssignedTrigger = hasActiveTriggerOtherThan(keymap, button, trigger);
  final shouldAsk =
      hintText != null || mappingTriggerOverLimit(keymap, button, trigger) || (!hasAction && hasOtherAssignedTrigger);

  var clearOtherTriggers = false;
  if (askFirst && (!isPro || hintText != null) && shouldAsk) {
    final resolution = await showTriggerConflictDialog(
      context,
      trigger,
      hintText: hintText,
      removes: actionsRemovedByReplacing(keymap, button, trigger),
    );
    if (!context.mounted || resolution == null) return null;
    if (resolution == TriggerConflictResolution.goPro) {
      await IAPManager.instance.purchaseSubscription(context);
      if (!context.mounted || !IAPManager.instance.hasActiveSubscription) return null;
    } else {
      clearOtherTriggers = true;
    }
  }

  var selectedKeymap = keymap;
  if (core.actionHandler.supportedApp is! CustomApp) {
    final currentProfile = core.actionHandler.supportedApp!.name;
    final newName = await KeymapManager().duplicate(context, currentProfile, skipName: '$currentProfile (Copy)');
    if (!context.mounted) return null;
    if (newName != null) {
      buildToast(title: context.i18n.createdNewCustomProfile(newName));
      selectedKeymap = core.actionHandler.supportedApp!.keymap;
    }
  }

  if (clearOtherTriggers) {
    clearOtherTriggerAssignments(selectedKeymap, button, trigger);
    selectedKeymap.signalUpdate();
  }
  return selectedKeymap;
}

/// Saves a custom mapping after an edit (built-in ones aren't stored).
void persistMappingEdit() {
  if (core.actionHandler.supportedApp is CustomApp) {
    core.settings.setKeyMap(core.actionHandler.supportedApp!);
  }
}

/// Moves what [from] of [button] does onto [to], replacing whatever [to]
/// did, and leaves [from] empty.
void moveTriggerAssignment(
  Keymap keymap,
  ControllerButton button, {
  required ButtonTrigger from,
  required ButtonTrigger to,
}) {
  final source = keymap.getOrCreateKeyPair(button, trigger: from);
  final target = keymap.getOrCreateKeyPair(button, trigger: to);
  target
    ..physicalKey = source.physicalKey
    ..logicalKey = source.logicalKey
    ..modifiers = List.of(source.modifiers)
    ..touchPosition = source.touchPosition
    ..inGameAction = source.inGameAction
    ..inGameActionValue = source.inGameActionValue
    ..androidAction = source.androidAction
    ..androidIntentAction = source.androidIntentAction
    ..command = source.command
    ..screenshotPath = source.screenshotPath;
  source
    ..physicalKey = null
    ..logicalKey = null
    ..modifiers = []
    ..touchPosition = Offset.zero
    ..inGameAction = null
    ..inGameActionValue = null
    ..androidAction = null
    ..androidIntentAction = null
    ..command = null
    ..screenshotPath = null;
  keymap.signalUpdate();
}

/// The warning for [action] sitting on a click: steering in its own words,
/// any other hold-only action by name.
String holdActionWarningText(BuildContext context, InGameAction action) =>
    action == InGameAction.steerLeft || action == InGameAction.steerRight
    ? context.i18n.holdWarningSteering
    : context.i18n.holdWarningAction(action.title);

/// Moves the hold-only action on [from] (a single or double click) of
/// [button] to its long press, where it works.
///
/// Without Pro a button does one thing: when another trigger would stay
/// assigned beside the long press, the Pro question comes first (Go Pro, or
/// replace the other triggers). When the long press already does something
/// else, the rider confirms replacing it. A built-in mapping is copied first.
/// Returns the keymap that was changed, or null when the rider backed out.
Future<Keymap?> moveHoldActionToLongPress(
  BuildContext context, {
  required Keymap keymap,
  required ControllerButton button,
  required ButtonTrigger from,
}) async {
  const to = ButtonTrigger.longPress;
  final source = keymap.getKeyPair(button, trigger: from);
  if (source == null || source.hasNoAction) return null;
  final action = source.toString();

  final staying = mappingActiveTriggers(keymap, button).where((t) => t != from && t != to);
  var clearOthers = false;
  if (staying.isNotEmpty && !IAPManager.instance.hasActiveSubscription) {
    final resolution = await showTriggerConflictDialog(
      context,
      to,
      // [from] moves onto the long press; only the others are lost.
      removes: actionsRemovedByReplacing(keymap, button, to, except: {from}),
    );
    if (!context.mounted || resolution == null) return null;
    if (resolution == TriggerConflictResolution.goPro) {
      await IAPManager.instance.purchaseSubscription(context);
      if (!context.mounted || !IAPManager.instance.hasActiveSubscription) return null;
    } else {
      clearOthers = true;
    }
  }

  final target = keymap.getKeyPair(button, trigger: to);
  final sameAction =
      target != null &&
      target.inGameAction == source.inGameAction &&
      target.inGameActionValue == source.inGameActionValue;
  if (!clearOthers && target != null && !target.hasNoAction && !sameAction) {
    final resolution = await showTriggerConflictDialog(
      context,
      to,
      title: context.i18n.holdAssignToLongPress,
      hintText: context.i18n.holdReplaceLongPress(target.toString(), action),
      offerPro: false,
    );
    if (!context.mounted || resolution == null) return null;
  }

  var selectedKeymap = keymap;
  if (core.actionHandler.supportedApp is! CustomApp) {
    final currentProfile = core.actionHandler.supportedApp!.name;
    final newName = await KeymapManager().duplicate(context, currentProfile, skipName: '$currentProfile (Copy)');
    if (!context.mounted || newName == null) return null;
    buildToast(title: context.i18n.createdNewCustomProfile(newName));
    selectedKeymap = core.actionHandler.supportedApp!.keymap;
  }

  moveTriggerAssignment(selectedKeymap, button, from: from, to: to);
  if (clearOthers) {
    clearOtherTriggerAssignments(selectedKeymap, button, to);
    selectedKeymap.signalUpdate();
  }
  persistMappingEdit();
  buildToast(title: context.i18n.holdMovedToLongPress(action));
  return selectedKeymap;
}
