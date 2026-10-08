import 'dart:async';

import 'package:bike_control/main.dart' show shownKeymapName;
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap/hold_action_warning.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_word_safe_text.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The right half of the wide button mapping: the picked button, its three
/// triggers as cards (the picked trigger outlined, PRO where it needs Pro),
/// and the actions the picked trigger can send, grouped by kind — the same
/// action picker the phone opens in a drawer, laid out in place.
///
/// A built-in mapping can't be changed, so until the rider starts editing
/// (which copies it) the picker is replaced by a note and an Edit button.
class KeymapButtonDetail extends StatefulWidget {
  const KeymapButtonDetail({super.key, required this.selection, required this.onUpdate});

  final MappingSelection selection;
  final VoidCallback onUpdate;

  @override
  State<KeymapButtonDetail> createState() => _KeymapButtonDetailState();
}

class _KeymapButtonDetailState extends State<KeymapButtonDetail> {
  StreamSubscription<void>? _keymapUpdates;
  Keymap? _listenedKeymap;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_changed);
  }

  @override
  void didUpdateWidget(KeymapButtonDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      oldWidget.selection.removeListener(_changed);
      widget.selection.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_changed);
    _keymapUpdates?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Follows the current mapping's edits, re-subscribing when the rider
  /// switches mapping (or editing copies a built-in one).
  void _listenTo(Keymap keymap) {
    if (identical(keymap, _listenedKeymap)) return;
    _keymapUpdates?.cancel();
    _listenedKeymap = keymap;
    _keymapUpdates = keymap.updateStream.listen((_) => _changed());
  }

  Future<void> _pickTrigger(BaseDevice device, ControllerButton button, Keymap keymap, ButtonTrigger trigger) async {
    final edited = await resolveTriggerEdit(context, keymap: keymap, device: device, button: button, trigger: trigger);
    if (!mounted || edited == null) return;
    widget.selection.selectTrigger(trigger);
    widget.onUpdate();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.selection.device;
    final button = widget.selection.button;
    final app = core.actionHandler.supportedApp;
    if (device == null || button == null || app == null) return const SizedBox.shrink();
    final keymap = app.keymap;
    _listenTo(keymap);
    final cs = Theme.of(context).colorScheme;
    final trigger = widget.selection.trigger;
    final editable = app is CustomApp;

    return Column(
      key: const ValueKey('mapping-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The picked button.
        Padding(
          key: ValueKey('mapping-detail-${button.name}'),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          child: Row(
            children: [
              ExcludeSemantics(child: ButtonWidget(button: button, size: 52)),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        button.displayName,
                        style: context.typography.x2Large.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
                      ),
                    ),
                    Text(
                      '${device.displayName(context)} · ${context.i18n.mappingForApp(shownKeymapName(app.name))}',
                      style: context.typography.small.copyWith(color: cs.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Its triggers.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            for (final t in ButtonTrigger.values)
              Expanded(
                child: _TriggerCard(
                  key: ValueKey('mapping-trigger-card-${t.name}'),
                  trigger: t,
                  keyPair: keymap.getKeyPair(button, trigger: t),
                  pro: mappingTriggerIsPro(keymap, button, t),
                  selected: editable && t == trigger,
                  onPressed: () => _pickTrigger(device, button, keymap, t),
                ),
              ),
          ],
        ),
        const Gap(20),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Semantics(
            header: true,
            child: Text(
              context.i18n.editingTrigger(trigger.title),
              style: context.typography.large.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
          ),
        ),
        if (editable)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            decoration: BoxDecoration(
              color: cs.card,
              borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
            ),
            child: ButtonEditPage(
              // A fresh picker per button, trigger and mapping: it edits the
              // key pair it was built with.
              key: ValueKey('picker-${identityHashCode(keymap)}-${button.name}-${trigger.name}'),
              embedded: true,
              device: device,
              keyPair: keymap.getOrCreateKeyPair(button, trigger: trigger),
              keymap: keymap,
              trigger: trigger,
              onUpdate: () {
                keymap.signalUpdate();
                persistMappingEdit();
                widget.onUpdate();
              },
              // The picker follows the action to its long press.
              onMovedToLongPress: () {
                widget.selection.selectTrigger(ButtonTrigger.longPress);
                widget.onUpdate();
              },
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.card,
              borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Text(
                  context.i18n.mappingEditMakesCopy(shownKeymapName(app.name)),
                  style: context.typography.small.copyWith(color: cs.mutedForeground),
                ),
                BkPillButton(
                  expand: false,
                  onPressed: () => _pickTrigger(device, button, keymap, trigger),
                  leading: const Icon(LucideIcons.pencil, size: 16),
                  child: Text(context.i18n.chainEdit),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One trigger of the picked button: its name (PRO when it needs Pro) over
/// the action it sends. The one being edited is outlined in the accent.
class _TriggerCard extends StatelessWidget {
  const _TriggerCard({
    super.key,
    required this.trigger,
    required this.keyPair,
    required this.pro,
    required this.selected,
    required this.onPressed,
  });

  final ButtonTrigger trigger;
  final KeyPair? keyPair;
  final bool pro;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kp = keyPair;
    final hasAction = kp != null && !kp.hasNoAction;
    final value = hasAction ? kp.toString() : context.i18n.noActionAssignedShort;
    final holdOnClick = kp?.holdActionOnClick == true;
    return BkTappable(
      onPressed: onPressed,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label:
          '${trigger.title}: ${hasAction ? value : context.i18n.noActionAssigned}'
          '${holdOnClick ? '. ${holdActionMarkerLabel(context)}' : ''}',
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(14),
      // The card is the tappable's own fill, so it takes the grouped rows'
      // hover and pressed washes.
      color: cs.card,
      wash: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? cs.primary : const Color(0x00000000), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            // Three cards share the pane, so on an iPad each is narrow: the
            // badges go under the trigger when they don't fit beside it, and
            // neither line ever breaks a word ("Auswähle" / "n") or cuts it.
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BkWordSafeText(
                  trigger.title,
                  style: context.typography.small.copyWith(color: cs.mutedForeground),
                ),
                if (pro) const ProBadge(padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1)),
                if (holdOnClick) const HoldActionMarker(),
              ],
            ),
            Row(
              spacing: 6,
              children: [
                if (hasAction && kp.icon != null) Icon(kp.icon, size: 16, color: cs.foreground),
                Expanded(
                  child: BkWordSafeText(
                    value,
                    style: hasAction
                        ? context.typography.base.copyWith(fontWeight: FontWeight.w600)
                        : context.typography.small.copyWith(color: cs.mutedForeground),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
