import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/pages/trainer_connection_settings.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/controller_canvas.dart';
import 'package:bike_control/widgets/controller/steering_gauge.dart';
import 'package:bike_control/widgets/controller/trigger_assignment_popup.dart';
import 'package:bike_control/widgets/keymap/hold_action_warning.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:bike_control/widgets/ui/animated_button_widget.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkStatusColors;
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
/// same button pressed twice still counts as a new press. [trigger] is the
/// gesture it resolved to once known (null until then).
typedef ControllerPress = ({ControllerButton? button, int generation, ButtonTrigger? trigger});

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
              // Barlow Condensed caps, the brand's section voice.
              child: Text(
                title.toUpperCase(),
                style: BkNumerals.display(
                  context.typography.x2Large.fontSize ?? 24,
                  color: Theme.of(context).colorScheme.foreground,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ).copyWith(letterSpacing: 0.2),
              ),
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

/// Whether [device] has anything for [controllerButtonsPicture] to draw: an
/// outline, buttons, or a steering angle. A SRAM derailleur has none until its
/// guided setup has heard its paddles.
bool hasButtonsPicture(BaseDevice device) =>
    device is SteeringDevice || device.controllerLayout != null || device.availableButtons.isNotEmpty;

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
  Widget? cornerBadge,
  bool dimmed = false,
}) {
  if (!hasButtonsPicture(device)) return null;

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

  // An angle, not buttons: the live gauge and the two actions it drives.
  // Without an outline of its own the badge goes on the picture's corner.
  Widget decorated(Widget picture) => cornerBadge == null && !dimmed
      ? picture
      : Stack(
          children: [
            Opacity(opacity: dimmed ? 0.45 : 1, child: picture),
            if (cornerBadge != null) PositionedDirectional(top: 0, end: 0, child: cornerBadge),
          ],
        );

  if (device is SteeringDevice) {
    final steering = device as SteeringDevice;
    return decorated(
      SteeringGauge(
        angle: steering.steeringAngle,
        calibrated: steering.steeringCalibrated,
        threshold: steering.steeringThreshold,
        leftAction: steeringActionFor(keymap, steering.steerLeftButton),
        rightAction: steeringActionFor(keymap, steering.steerRightButton),
      ),
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
      cornerBadge: cornerBadge,
      dimmed: dimmed,
    );
  }
  return decorated(Wrap(spacing: 9, runSpacing: 9, children: device.availableButtons.map(buttonFor).toList()));
}

/// The single-click action [button] sends, or null when it sends nothing.
String? _actionFor(Keymap? keymap, ControllerButton button, {ButtonTrigger trigger = ButtonTrigger.singleClick}) {
  final pair = keymap?.getKeyPair(button, trigger: trigger);
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
///
/// [setupNeed] is a controller that does nothing until the rider has set it up
/// or unlocked it (see [BaseDevice.setupNeed]): a warning above the picture
/// says so and [onSetup] leads into that setup, and the picture wears a
/// warning badge and stays faded, since its buttons do not work yet.
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
    this.setupNeed,
    this.onSetup,
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
  final DeviceSetupNeed? setupNeed;
  final VoidCallback? onSetup;

  /// Below this a list beside the picture would squeeze both; the list goes
  /// under it instead. The list gets 4/9 of the row: at 780 that is ~340 px,
  /// enough for an action like "Runterschalten" on one line — at the old 560
  /// (a portrait tablet) it was ~240 and every action broke mid-word.
  static const double sideBySideMinWidth = 780;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final needsSetup = setupNeed != null;
    final rawPicture = controllerButtonsPicture(
      device: device,
      keymap: keymap,
      presses: presses,
      buttonSize: 52 / Theme.of(context).scaling,
      onUpdate: onUpdate,
      maxHeight: wide ? 260 : null,
      // On the outline itself, at full strength over the faded picture:
      // these buttons are not live yet.
      cornerBadge: needsSetup ? _SetupBadge(key: ValueKey('ride-setup-badge-${device.uniqueId}')) : null,
      dimmed: needsSetup,
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
    final warning = setupNeed == null
        ? null
        : _SetupWarning(
            key: ValueKey('ride-setup-warning-${device.uniqueId}'),
            need: setupNeed!,
            onSetup: onSetup,
          );
    // A steering input has no buttons to tap, no presses to show and no
    // list of them: it says what it does and shows its angle.
    final steering = device is SteeringDevice;
    final canEdit = keymap != null && !steering;
    final hint = steering
        ? _steeringHint(context)
        : canEdit && picture != null
        ? _hint(context, _touchPlatform ? context.i18n.rideTapButtonHint : context.i18n.rideClickButtonHint)
        : null;
    final strip = picture != null && !steering
        ? LastPressStrip(device: device, keymap: keymap, presses: presses, onUpdate: onUpdate)
        : null;
    final list = canEdit && (wide || showButtonList)
        ? _ButtonList(key: const ValueKey('ride-button-list'), device: device, keymap: keymap!, onUpdate: onUpdate)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: bkCardShadow(context),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Widget content;
          if (wide && !steering && picture != null && constraints.maxWidth >= sideBySideMinWidth) {
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
              if (warning != null) ...[warning, const Gap(8)],
              content,
            ],
          );
        },
      ),
    );
  }

  /// "Turn your handlebar to steer." and, for an input that drifts (phone
  /// steering), a one-tap Recalibrate at its end.
  Widget _steeringHint(BuildContext context) {
    final hint = _hint(context, context.i18n.steeringRideHint);
    final steering = device;
    if (connecting || steering is! RecalibratableSteering || steering is! SteeringDevice) return hint;
    // On the hint's first line: a wrapped hint must not push it to the middle.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: hint),
        ValueListenableBuilder<bool>(
          valueListenable: (steering as SteeringDevice).steeringCalibrated,
          builder: (context, calibrated, _) => BkTouchTarget(
            child: Button.ghost(
              key: const ValueKey('ride-steering-recalibrate'),
              style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
              onPressed: calibrated ? (steering as RecalibratableSteering).recalibrate : null,
              child: Text(
                context.i18n.steeringRecalibrate,
                style: context.typography.small.copyWith(
                  color: calibrated ? bkAccentText(context) : Theme.of(context).colorScheme.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "Tap a button to change what it does." — or, while connecting, the
  /// controller's name and "Connecting…" in the same slot, at the hint's
  /// height either way.
  Widget _hint(BuildContext context, String hint) {
    final cs = Theme.of(context).colorScheme;
    final style = context.typography.small.copyWith(color: cs.mutedForeground);
    final text = Text(hint, style: style);
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

/// "Setup needed · Set up ›" or "Device is currently locked · Unlock now ›" at
/// the top of a controller's card: what stands between the rider and these
/// buttons, and the way into it.
class _SetupWarning extends StatelessWidget {
  const _SetupWarning({super.key, required this.need, this.onSetup});

  final DeviceSetupNeed need;
  final VoidCallback? onSetup;

  @override
  Widget build(BuildContext context) {
    final l = context.i18n;
    final status = BkStatusColors.of(context);
    final accent = bkAccentText(context);
    final (message, action) = switch (need) {
      DeviceSetupNeed.setup => (l.onboardingSetupNeeded, l.chainSetUp),
      DeviceSetupNeed.unlock => (l.rideControllerLocked, l.unlock_unlockNow),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: status.warningWash, borderRadius: BorderRadius.circular(10)),
      child: BkTouchTarget(
        child: Button.ghost(
          style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          onPressed: onSetup,
          child: Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 18, color: status.warning),
              const Gap(8),
              Expanded(
                child: Text(
                  message,
                  style: context.typography.small.copyWith(
                    color: Theme.of(context).colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onSetup != null) ...[
                const Gap(8),
                Text(
                  action,
                  style: context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600),
                ),
                Icon(LucideIcons.chevronRight, size: 16, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The warning on a not-yet-working controller's picture.
class _SetupBadge extends StatelessWidget {
  const _SetupBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final status = BkStatusColors.of(context);
    return ExcludeSemantics(
      // The warning row above says it in words; this is the same news on the
      // outline, for the eye.
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: status.warningWash, shape: BoxShape.circle),
        child: Icon(LucideIcons.triangleAlert, size: 20, color: status.warning),
      ),
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
        // The action of the gesture that ran; until it is known (a double
        // click or long press is still being told apart), the single click's.
        final action = _actionFor(keymap, button, trigger: pressed.trigger ?? ButtonTrigger.singleClick);
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
    // Its first trigger that does something: the action at the row's end,
    // the trigger under the name unless a single click.
    final rows = [
      for (final button in buttons) (button: button, trigger: mappingActiveTriggers(keymap, button).firstOrNull),
    ];
    KeyPair? pairOf(({ControllerButton button, ButtonTrigger? trigger}) row) =>
        row.trigger == null ? null : keymap.getKeyPair(row.button, trigger: row.trigger!);
    // An action no connection method that's on can carry: a dash on its row
    // and one note above them all, not the same sentence on every row.
    final anyWaits = rows.any((row) => pairOf(row)?.waitsForConnectionMethod ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (anyWaits) _WaitsNote(onUpdate: onUpdate),
        for (final row in rows)
          Builder(
            builder: (context) {
              final (:button, :trigger) = row;
              final pair = pairOf(row);
              final action = pair == null || pair.waitsForConnectionMethod ? null : pair.actionLabel;
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
                        // The action takes its own width, up to half the row;
                        // the name and its trigger get the rest, so neither
                        // is starved into breaking mid-word ("Navigatio" /
                        // "n Left") while a short action leaves room unused.
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) => Row(
                              children: [
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
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.typography.xSmall.copyWith(color: cs.mutedForeground),
                                        ),
                                    ],
                                  ),
                                ),
                                const Gap(8),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: (constraints.maxWidth - 8) / 2),
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

/// "Buttons marked – need a connection method · Open connection settings":
/// said once above the list, for every row whose action waits for one.
class _WaitsNote extends StatelessWidget {
  const _WaitsNote({required this.onUpdate});

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('ride-button-list-waits-note'),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
            context.i18n.rideButtonsWaitForConnection,
            style: context.typography.small.copyWith(color: cs.mutedForeground),
          ),
          BkTouchTarget(
            child: Button.ghost(
              key: const ValueKey('ride-button-list-open-connections'),
              style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
              onPressed: () async {
                await context.push(const TrainerConnectionSettingsPage());
                onUpdate();
              },
              child: Text(
                context.i18n.openConnectionSettings,
                style: context.typography.small.copyWith(color: bkAccentText(context), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
