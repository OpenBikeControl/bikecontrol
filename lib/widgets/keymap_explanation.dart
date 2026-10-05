import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/controller/controller_canvas.dart';
import 'package:bike_control/widgets/keymap/hold_action_warning.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../bluetooth/messages/notification.dart';

/// A controller's button mapping: the picture of its buttons, then a grouped
/// list with a group per button.
///
/// On its own (phones, narrow windows) a group opens into the button's three
/// triggers, each opening the action picker. With [master] it is the left
/// half of a master–detail: a row picks the button whose triggers and
/// actions the detail pane beside it shows (see `KeymapButtonDetail`).
class KeymapExplanation extends StatefulWidget {
  final Keymap keymap;
  final VoidCallback onUpdate;
  final BaseDevice? filterDevice;

  /// The picked button; created here when not given.
  final MappingSelection? selection;

  /// Rows pick a button for the detail pane instead of opening in place.
  final bool master;

  const KeymapExplanation({
    super.key,
    required this.keymap,
    required this.onUpdate,
    this.filterDevice,
    this.selection,
    this.master = false,
  });

  @override
  State<KeymapExplanation> createState() => _KeymapExplanationState();
}

class _KeymapExplanationState extends State<KeymapExplanation> {
  late StreamSubscription<void> _updateStreamListener;

  late StreamSubscription<BaseNotification> _actionSubscription;

  MappingSelection? _ownSelection;
  MappingSelection get _selection => widget.selection ?? (_ownSelection ??= MappingSelection());

  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelectionChanged);
    _updateStreamListener = widget.keymap.updateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _actionSubscription = core.connection.actionStream.listen((data) async {
      if (!mounted) {
        return;
      }
      if (data is ButtonNotification && data.buttonsClicked.length == 1) {
        final clickedButton = data.buttonsClicked.first;
        final hasFallbackLongPress =
            data.device.supportsLongPress == false &&
            widget.keymap.getKeyPair(clickedButton, trigger: ButtonTrigger.longPress)?.hasNoAction == false;
        final trigger = hasFallbackLongPress ? ButtonTrigger.longPress : ButtonTrigger.singleClick;
        if (widget.master) {
          // The detail pane beside the list follows the button just pressed.
          _selection.select(data.device, clickedButton, trigger: trigger);
        } else if (!_isDrawerOpen) {
          _openButtonEditor(data.device, clickedButton, trigger);
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _selection.removeListener(_onSelectionChanged);
    _ownSelection?.dispose();
    _updateStreamListener.cancel();
    _actionSubscription.cancel();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(KeymapExplanation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keymap != widget.keymap) {
      _updateStreamListener.cancel();
      _updateStreamListener = widget.keymap.updateStream.listen((_) {
        if (mounted) setState(() {});
      });
    }
    if (oldWidget.selection != widget.selection) {
      (oldWidget.selection ?? _ownSelection)?.removeListener(_onSelectionChanged);
      _selection.addListener(_onSelectionChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtered to one device, that device IS the answer — no need to find it in
    // the live list, which a remembered controller (switched off, still fully
    // editable) is deliberately not part of. Looking it up there left its own
    // settings page with no mapping table at all.
    final devices = widget.filterDevice != null ? [widget.filterDevice!] : core.connection.controllerDevices;
    final keyButtonMap = devices.associateWith(mappingButtonsOf);

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final MapEntry(key: device, value: buttons) in keyButtonMap.entries) ...[
          if (widget.filterDevice == null) ColoredTitle(text: device.toString()),
          if (buttons.isEmpty)
            Text(device.buttonExplanation, style: const TextStyle(height: 1)).muted
          else ...[
            if (device.controllerLayout != null) _podsCard(context, device),
            _buttonList(context, device, buttons),
          ],
        ],
      ],
    );
    // No AnimatedSize at all under reduced motion: one with a zero duration
    // finishes its resize inside its own layout and trips a framework assert.
    if (prefersReducedMotion(context)) return list;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: list,
    );
  }

  /// The controller picture; a tap on a button picks (or opens) it, and the
  /// picked one wears the accent ring.
  Widget _podsCard(BuildContext context, BaseDevice device) {
    final cs = Theme.of(context).colorScheme;
    final size = 44 / Theme.of(context).scaling;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius)),
      child: ControllerCanvas(
        layout: device.controllerLayout!,
        availableButtons: device.availableButtons,
        buttonSize: size,
        maxHeight: widget.master ? 220 : 200,
        buttonBuilder: (button) => _PodButton(
          key: ValueKey('mapping-pod-${button.name}'),
          button: button,
          keymap: widget.keymap,
          size: size,
          selected: _selection.isSelected(device, button),
          onPressed: () => _toggle(device, button),
        ),
      ),
    );
  }

  void _toggle(BaseDevice device, ControllerButton button) {
    if (!widget.master && _selection.isSelected(device, button)) {
      _selection.clear();
    } else {
      _selection.select(device, button);
    }
  }

  Widget _buttonList(BuildContext context, BaseDevice device, List<ControllerButton> buttons) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (final (i, button) in buttons.indexed) {
      final selected = _selection.isSelected(device, button);
      if (i > 0) children.add(const BkGroupedDivider(indent: _rowIndent));
      children.add(
        _ButtonRow(
          key: ValueKey('mapping-row-${button.name}'),
          button: button,
          summary: _summary(context, button),
          trigger: _summaryTrigger(button),
          selected: selected,
          master: widget.master,
          onPressed: () => _toggle(device, button),
        ),
      );
      if (!widget.master && selected) {
        for (final trigger in ButtonTrigger.values) {
          children.add(const BkGroupedDivider(indent: _rowIndent));
          children.add(_triggerRow(context, device, button, trigger));
        }
        children.add(const SizedBox(height: 4));
      }
    }
    return DecoratedBox(
      key: const ValueKey('mapping-list'),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }

  /// Where a row's text starts: the inset, the 32 px key and the gap.
  static const double _rowIndent = BkGroupedSection.inset + 32 + 12;

  /// The trigger a closed row's summary is for, named under the button's
  /// name ("Long press"); null for a single click (the default needs no
  /// name) or when nothing is assigned.
  String? _summaryTrigger(ControllerButton button) {
    final active = mappingActiveTriggers(widget.keymap, button);
    if (active.isEmpty || active.first == ButtonTrigger.singleClick) return null;
    return active.first.title;
  }

  /// What a closed row says the button does: its first assigned trigger's
  /// action ("Steer left"; the trigger itself is the row's subtitle), how
  /// many more triggers do something, or nothing.
  InlineSpan? _summary(BuildContext context, ControllerButton button) {
    final active = mappingActiveTriggers(widget.keymap, button);
    if (active.isEmpty) return null;
    final first = active.first;
    final action = widget.keymap.getKeyPair(button, trigger: first).toString();
    final cs = Theme.of(context).colorScheme;
    return TextSpan(
      children: [
        // A hold-only action on a click: marked before the summary.
        if (mappingHasHoldActionOnClick(widget.keymap, button))
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(padding: EdgeInsets.only(right: 6), child: HoldActionMarker(announce: true)),
          ),
        TextSpan(
          text: action,
          style: TextStyle(color: cs.foreground, fontWeight: FontWeight.w500),
        ),
        if (active.length > 1)
          TextSpan(
            text: '  +${active.length - 1}',
            style: TextStyle(color: cs.mutedForeground),
          ),
      ],
    );
  }

  /// One trigger of the open button: its name (PRO when it needs Pro), what
  /// it does, and a chevron into the action picker.
  Widget _triggerRow(BuildContext context, BaseDevice device, ControllerButton button, ButtonTrigger trigger) {
    final cs = Theme.of(context).colorScheme;
    KeyPair? keyPair = widget.keymap.getKeyPair(button, trigger: trigger);
    if (screenshotKeymapsStaged &&
        keyPair == null &&
        button.name == ZwiftButtons.a.name &&
        trigger == ButtonTrigger.longPress) {
      // TODO fix it in the screenshot_test.dart instead
      keyPair = KeyPair(
        physicalKey: null,
        logicalKey: null,
        modifiers: [],
        touchPosition: Offset.zero,
        inGameAction: InGameAction.steerRight,
        inGameActionValue: null,
        androidAction: null,
        command: null,
        screenshotPath: null,
        buttons: [ZwiftButtons.a],
      );
    }
    final hasAction = keyPair != null && !keyPair.hasNoAction;
    final holdOnClick = keyPair?.holdActionOnClick == true;
    final blocked = mappingTriggerBlockedHint(context, widget.keymap, device, button, trigger) != null;
    final pro = mappingTriggerIsPro(widget.keymap, button, trigger);
    final muted = context.typography.small.copyWith(color: cs.mutedForeground);
    return BkTappable(
      key: ValueKey('mapping-trigger-${button.name}-${trigger.name}'),
      wash: true,
      onPressed: () => _onTriggerPressed(device: device, button: button, trigger: trigger),
      label:
          '${trigger.title}: ${hasAction ? keyPair.toString() : context.i18n.noActionAssigned}'
          '${holdOnClick ? '. ${holdActionMarkerLabel(context)}' : ''}',
      excludeChildSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_rowIndent, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                spacing: 8,
                children: [
                  Text(trigger.title, style: muted),
                  if (pro) const ProBadge(padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1)),
                  if (holdOnClick) const HoldActionMarker(),
                  // What it does takes the rest of the row, ending at the
                  // chevron; "(none)" when nothing is on it.
                  Expanded(
                    child: blocked
                        ? const SizedBox.shrink()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            spacing: 8,
                            children: [
                              if (hasAction && keyPair.icon != null)
                                Icon(keyPair.icon, size: 14, color: cs.mutedForeground),
                              Flexible(
                                child: Text(
                                  hasAction ? keyPair.toString() : context.i18n.noActionAssignedShort,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: hasAction
                                      ? context.typography.small.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: cs.foreground,
                                        )
                                      : muted,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 16, color: cs.mutedForeground),
                ],
              ),
              if (blocked)
                Text(
                  mappingTriggerBlockedHint(context, widget.keymap, device, button, trigger)!,
                  style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                ),
              if (trigger == ButtonTrigger.longPress && !device.supportsLongPress && hasAction)
                Text(
                  context.i18n.longTapExplanation,
                  style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTriggerPressed({
    required BaseDevice device,
    required ControllerButton button,
    required ButtonTrigger trigger,
  }) async {
    final keymap = await resolveTriggerEdit(
      context,
      keymap: widget.keymap,
      device: device,
      button: button,
      trigger: trigger,
    );
    if (!mounted || keymap == null) return;
    await _openEditor(device, button, trigger, keymap);
  }

  /// A physical press opens its button's editor straight away (no questions:
  /// the rider is holding the controller, not deciding on a trigger).
  Future<void> _openButtonEditor(BaseDevice device, ControllerButton button, ButtonTrigger trigger) async {
    final keymap = await resolveTriggerEdit(
      context,
      keymap: widget.keymap,
      device: device,
      button: button,
      trigger: trigger,
      askFirst: false,
    );
    if (!mounted || keymap == null) return;
    await _openEditor(device, button, trigger, keymap);
  }

  Future<void> _openEditor(BaseDevice device, ControllerButton button, ButtonTrigger trigger, Keymap keymap) async {
    final selectedKeyPair = keymap.getOrCreateKeyPair(button, trigger: trigger);
    _isDrawerOpen = true;
    await openDrawer(
      context: context,
      builder: (c) => ButtonEditPage(
        device: device,
        keyPair: selectedKeyPair,
        keymap: keymap,
        trigger: trigger,
        onUpdate: () {
          keymap.signalUpdate();
          persistMappingEdit();
          widget.onUpdate();
        },
      ),
      position: OverlayPosition.end,
    );
    persistMappingEdit();
    widget.onUpdate();
    _isDrawerOpen = false;
  }
}

/// A button's row: its key, its name, and what it does (closed) or a
/// chevron (open). In the master list the picked row is washed in the accent.
class _ButtonRow extends StatefulWidget {
  const _ButtonRow({
    super.key,
    required this.button,
    required this.summary,
    this.trigger,
    required this.selected,
    required this.master,
    required this.onPressed,
  });

  final ControllerButton button;
  final InlineSpan? summary;

  /// The trigger [summary] is for, under the name; null for a single click.
  final String? trigger;
  final bool selected;
  final bool master;
  final VoidCallback onPressed;

  @override
  State<_ButtonRow> createState() => _ButtonRowState();
}

class _ButtonRowState extends State<_ButtonRow> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final open = widget.selected && !widget.master;
    final washed = widget.selected && widget.master;
    return BkTappable(
      onPressed: widget.onPressed,
      // The grouped rows' hover and pressed washes; the picked row's accent
      // tint lies over them.
      wash: true,
      selected: widget.master ? widget.selected : null,
      expanded: widget.master ? null : widget.selected,
      child: ColoredBox(
        color: washed ? cs.primary.withValues(alpha: 0.14) : const Color(0x00000000),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BkGroupedSection.inset, vertical: 8),
            child: Row(
              children: [
                _KeyChip(button: widget.button, selected: widget.selected),
                const Gap(12),
                // The name, with the trigger under it when it isn't a single
                // click, takes what the value leaves; the value (just the
                // action) takes its own width, up to two thirds of the row,
                // and ends at the chevron.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showSummary = !open && widget.summary != null;
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.button.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typography.base.copyWith(fontWeight: FontWeight.w500),
                                ),
                                if (showSummary && widget.trigger != null)
                                  Text(
                                    widget.trigger!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                                  ),
                              ],
                            ),
                          ),
                          if (showSummary) ...[
                            const Gap(8),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.66),
                              child: Text.rich(
                                widget.summary!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: context.typography.small,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const Gap(4),
                Icon(
                  open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 16,
                  color: cs.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small round key standing for a button in lists; the picked one in
/// the accent.
class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.button, required this.selected});

  final ControllerButton button;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? cs.primary : const Color(0x00000000), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: ButtonWidget(button: button, size: 28),
        ),
      ),
    );
  }
}

/// A button on the controller picture: the button with its action badge, the
/// accent ring when picked, and a labelled tap target.
class _PodButton extends StatelessWidget {
  const _PodButton({
    super.key,
    required this.button,
    required this.keymap,
    required this.size,
    required this.selected,
    required this.onPressed,
  });

  final ControllerButton button;
  final Keymap keymap;
  final double size;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BkTappable(
      onPressed: onPressed,
      label: context.i18n.a11yEditButtonMapping(button.displayName),
      selected: selected,
      excludeChildSemantics: true,
      borderRadius: BorderRadius.circular(size),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -5,
              top: -5,
              right: -5,
              bottom: -5,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: prefersReducedMotion(context) ? Duration.zero : const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? cs.primary.withValues(alpha: 0.22) : const Color(0x00000000),
                    border: Border.all(color: selected ? cs.primary : const Color(0x00000000), width: 2.5),
                  ),
                ),
              ),
            ),
            ButtonWidget(button: button, size: size, keymap: keymap),
          ],
        ),
      ),
    );
  }
}

extension SplitByUppercase on String {
  String splitByUpperCase() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').capitalize();
  }
}
