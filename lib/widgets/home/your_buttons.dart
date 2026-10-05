import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/controller_canvas.dart';
import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:bike_control/widgets/controller/trigger_assignment_popup.dart';
import 'package:bike_control/widgets/keymap/hold_action_warning.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/bk_motion.dart';
import 'package:bike_control/widgets/ui/bk_skeleton.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart' show ValueListenable, defaultTargetPlatform;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The last press of one controller, and how many there have been, so the
/// same button pressed twice still counts as a new press.
typedef ControllerPress = ({ControllerButton? button, int generation});

/// A Ride section title with an optional link at its end ("Edit buttons ›").
class RideSectionHeader extends StatelessWidget {
  const RideSectionHeader({super.key, required this.title, this.linkLabel, this.onLink});

  final String title;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final accent = bkAccentText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.typography.large.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          if (linkLabel != null && onLink != null)
            Button.ghost(
              style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
              onPressed: onLink,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(
                    linkLabel!,
                    style: context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600),
                  ),
                  Icon(LucideIcons.chevronRight, size: 16, color: accent),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The controller's own picture with its real buttons, each wearing the
/// action it sends — so the picture doubles as the button map. Tapping a
/// button opens its assignment. Null when there is nothing to draw (a SRAM
/// derailleur before its guided setup has found its paddles).
///
/// Shared by Ride's "Your buttons" and the controller cards on Devices.
Widget? controllerButtonsPicture({
  required BaseDevice device,
  required Keymap? keymap,
  required ValueListenable<ControllerPress> presses,
  required double buttonSize,
  required VoidCallback onUpdate,
  double? maxHeight,
}) {
  if (device is! SteeringDevice && device.controllerLayout == null && device.availableButtons.isEmpty) {
    return null;
  }

  Widget buttonFor(ControllerButton button) {
    return ValueListenableBuilder<ControllerPress>(
      key: ValueKey(button.name),
      valueListenable: presses,
      builder: (context, pressed, _) => AnimatedButtonWidget(
        button: button,
        pressGeneration: pressed.button?.name == button.name ? pressed.generation : 0,
        keymap: keymap,
        device: device,
        size: buttonSize,
        onUpdate: onUpdate,
      ),
    );
  }

  if (device is SteeringDevice) {
    final steering = device as SteeringDevice;
    return SteeringGauge(
      angle: steering.steeringAngle,
      calibrated: steering.steeringCalibrated,
      threshold: steering.steeringThreshold,
      device: device,
      leftButton: steering.steerLeftButton,
      rightButton: steering.steerRightButton,
      keymap: keymap,
      onUpdate: onUpdate,
    );
  }
  final layout = device.controllerLayout;
  if (layout != null) {
    return ControllerCanvas(
      layout: layout,
      availableButtons: device.availableButtons,
      buttonBuilder: buttonFor,
      buttonSize: buttonSize,
      maxHeight: maxHeight,
    );
  }
  return Wrap(spacing: 9, runSpacing: 9, children: device.availableButtons.map(buttonFor).toList());
}

/// The single-click action [button] sends, or null when it sends nothing.
String? _actionFor(Keymap? keymap, ControllerButton button) {
  final pair = keymap?.getKeyPair(button, trigger: ButtonTrigger.singleClick);
  if (pair == null || pair.hasNoAction) return null;
  final text = pair.toString();
  return text.isEmpty ? null : text;
}

bool get _touchPlatform => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => true,
  _ => false,
};

/// One controller on Ride: optionally its own header (when several are
/// connected), the hint, the picture and the last-press strip.
///
/// [wide] puts the picture on the left and the hint, strip and the list of
/// buttons on the right; without the room for that, [showButtonList] puts the
/// list under the picture.
///
/// [connecting] is the card of a remembered controller on its way back: the
/// same card, its picture faded under a slow shimmer and its name with
/// "Connecting…" where the hint goes — so when it connects nothing moves, the
/// picture just comes up to full strength.
class ControllerButtonsCard extends StatelessWidget {
  const ControllerButtonsCard({
    super.key,
    required this.device,
    required this.keymap,
    required this.presses,
    required this.onUpdate,
    required this.onEdit,
    this.showDeviceHeader = false,
    this.wide = false,
    this.showButtonList = false,
    this.connecting = false,
  });

  final BaseDevice device;
  final Keymap? keymap;
  final ValueListenable<ControllerPress> presses;
  final VoidCallback onUpdate;
  final VoidCallback onEdit;
  final bool showDeviceHeader;
  final bool wide;
  final bool showButtonList;
  final bool connecting;

  /// Below this a list beside the picture would squeeze both; the list goes
  /// under it instead.
  static const double sideBySideMinWidth = 560;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rawPicture = controllerButtonsPicture(
      device: device,
      keymap: keymap,
      presses: presses,
      buttonSize: 52 / Theme.of(context).scaling,
      onUpdate: onUpdate,
      maxHeight: wide ? 260 : null,
    );
    // Faded while it connects, then up to full strength and a touch larger:
    // the pods and their badges arrive rather than appear.
    final duration = BkMotion.of(context);
    final picture = rawPicture == null
        ? null
        : AnimatedOpacity(
            key: const ValueKey('ride-buttons-picture'),
            opacity: connecting ? 0.45 : 1,
            duration: duration,
            curve: BkMotion.curve,
            child: AnimatedScale(
              scale: connecting ? 0.97 : 1,
              duration: duration,
              curve: BkMotion.curve,
              child: connecting ? BkShimmer(child: rawPicture) : rawPicture,
            ),
          );
    final canEdit = keymap != null;
    final hint = canEdit && picture != null ? _hint(context) : null;
    final strip = picture != null
        ? LastPressStrip(device: device, keymap: keymap, presses: presses, onUpdate: onUpdate)
        : null;
    final list = canEdit && (wide || showButtonList)
        ? _ButtonList(key: const ValueKey('ride-button-list'), device: device, keymap: keymap!, onUpdate: onUpdate)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Widget content;
          if (wide && picture != null && constraints.maxWidth >= sideBySideMinWidth) {
            content = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: picture),
                const Gap(16),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ?hint,
                      if (strip != null) ...[const Gap(8), strip],
                      if (list != null) ...[const Gap(8), list],
                    ],
                  ),
                ),
              ],
            );
          } else {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hint != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: hint),
                if (picture != null) ...[const Gap(8), picture],
                if (strip != null) ...[const Gap(8), strip],
                if (list != null && picture != null) ...[
                  const Gap(8),
                  Divider(height: 1, color: cs.border),
                  const Gap(4),
                  list,
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDeviceHeader) ...[_DeviceHeader(device: device, onEdit: onEdit), const Gap(4)],
              content,
            ],
          );
        },
      ),
    );
  }

  /// "Tap a button to change what it does." — or, while connecting, the
  /// controller's name and "Connecting…" in the same slot, at the hint's
  /// height either way.
  Widget _hint(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = context.typography.small.copyWith(color: cs.mutedForeground);
    final text = Text(
      _touchPlatform ? context.i18n.rideTapButtonHint : context.i18n.rideClickButtonHint,
      style: style,
    );
    final Widget slot = connecting
        ? Stack(
            children: [
              // Holds the hint's height, so the swap moves nothing.
              Visibility(visible: false, maintainSize: true, maintainAnimation: true, maintainState: true, child: text),
              Text(
                '${device.displayName(context)} · ${context.i18n.chainStatusConnecting}',
                key: const ValueKey('ride-buttons-connecting'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ],
          )
        : text;
    if (prefersReducedMotion(context)) return slot;
    return AnimatedSwitcher(
      duration: BkMotion.standard,
      switchInCurve: BkMotion.curve,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(connecting), child: slot),
    );
  }
}

/// Name, battery and Edit, for a controller that shares Ride with others.
class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({required this.device, required this.onEdit});

  final BaseDevice device;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final battery = device is BluetoothDevice ? (device as BluetoothDevice).batteryLevel : null;
    return Row(
      children: [
        const Gap(4),
        Icon(device.icon, size: 18, color: cs.foreground),
        const Gap(8),
        Expanded(
          child: Text(
            device.displayName(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.small.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (battery != null) ...[
          Icon(
            battery < 20 ? LucideIcons.batteryWarning : LucideIcons.batteryMedium,
            size: 16,
            color: battery < 20 ? cs.destructive : cs.mutedForeground,
          ),
          const Gap(4),
          Text('$battery%', style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
        ],
        Button.ghost(
          onPressed: onEdit,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.i18n.chainEdit,
                style: context.typography.small.copyWith(color: bkAccentText(context), fontWeight: FontWeight.w600),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: bkAccentText(context)),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Just pressed Plus → Shift Up · Change": what the controller last sent,
/// and a way to change it. Hidden until the first press.
///
/// Rebuilds on its own notifier only, so a press never rebuilds Ride.
class LastPressStrip extends StatelessWidget {
  const LastPressStrip({
    super.key,
    required this.device,
    required this.keymap,
    required this.presses,
    required this.onUpdate,
  });

  final BaseDevice device;
  final Keymap? keymap;
  final ValueListenable<ControllerPress> presses;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ControllerPress>(
      valueListenable: presses,
      builder: (context, pressed, _) {
        final button = pressed.button;
        if (button == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final action = _actionFor(keymap, button);
        // Its single click is an action that only works while held.
        final holdOnClick = keymap?.getKeyPair(button, trigger: ButtonTrigger.singleClick)?.holdActionOnClick == true;
        final muted = context.typography.small.copyWith(color: cs.mutedForeground);
        return Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.only(left: 10, right: 2, top: 4, bottom: 4),
          decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              ExcludeSemantics(child: ButtonWidget(button: button, size: 24)),
              const Gap(8),
              Expanded(
                // The action never breaks mid-phrase: it follows on the same
                // line when it fits, else whole on the next one.
                child: Semantics(
                  liveRegion: true,
                  child: MergeSemantics(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Text(
                          action != null
                              ? '${context.i18n.rideJustPressed(button.displayName)} →'
                              : context.i18n.rideJustPressed(button.displayName),
                          key: const ValueKey('last-press-lead'),
                          style: muted,
                          // A long button name in a narrow column (an iPad
                          // in portrait) wraps once rather than losing its end.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (action != null)
                          Text(
                            action,
                            style: muted.copyWith(color: cs.foreground, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (holdOnClick)
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: HoldActionMarker(announce: true),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (keymap != null)
                BkTouchTarget(
                  child: Button.ghost(
                    onPressed: () => showTriggerAssignmentPopup(
                      context: context,
                      device: device,
                      button: button,
                      keymap: keymap!,
                      onUpdate: onUpdate,
                    ),
                    child: Text(
                      context.i18n.rideChange,
                      style: context.typography.small.copyWith(
                        color: bkAccentText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Every button and the action it sends, for windows wide enough to list
/// them beside the picture. A row opens that button's assignment.
class _ButtonList extends StatelessWidget {
  const _ButtonList({super.key, required this.device, required this.keymap, required this.onUpdate});

  final BaseDevice device;
  final Keymap keymap;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buttons = device.availableButtons.distinctBy((b) => b.name).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final button in buttons)
          Builder(
            builder: (context) {
              // Its first trigger that does something: the action at the
              // row's end, the trigger under the name unless a single click.
              final trigger = mappingActiveTriggers(keymap, button).firstOrNull;
              final action = trigger == null ? null : keymap.getKeyPair(button, trigger: trigger)?.toString();
              final triggerName = trigger != null && trigger != ButtonTrigger.singleClick ? trigger.title : null;
              return BkTappable(
                key: ValueKey('ride-button-row-${button.name}'),
                onPressed: () => showTriggerAssignmentPopup(
                  context: context,
                  device: device,
                  button: button,
                  keymap: keymap,
                  onUpdate: onUpdate,
                ),
                label: context.i18n.a11yEditButtonMapping(button.displayName),
                excludeChildSemantics: true,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        ButtonWidget(button: button, size: 22),
                        const Gap(10),
                        // The button's name gives way first; the action is the
                        // point of the list and is never cut — it wraps instead.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                button.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.typography.small,
                              ),
                              if (triggerName != null)
                                Text(
                                  triggerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                                ),
                            ],
                          ),
                        ),
                        const Gap(8),
                        Flexible(
                          flex: 2,
                          child: Text(
                            (action == null || action.isEmpty) ? '–' : action,
                            textAlign: TextAlign.end,
                            style: context.typography.small.copyWith(
                              color: cs.mutedForeground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
