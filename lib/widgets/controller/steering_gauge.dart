import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_steering_angle.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/keymap/mapping.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Which steer direction is active for [angle] given [threshold]. Mirrors
/// `GyroscopeSteering._applyPWMSteering`: positive ⇒ left, negative ⇒ right.
enum SteerSide { left, right, none }

SteerSide steerSideFor(double angle, double threshold) {
  if (angle > threshold) return SteerSide.left;
  if (angle < -threshold) return SteerSide.right;
  return SteerSide.none;
}

/// Full-scale tilt (deg) shown on the gauge: a few multiples of the trigger
/// threshold, so the threshold ticks sit well inside the track and the knob
/// still travels for typical steering angles. Clamped to a sane span.
double displayRangeFor(double threshold) => (threshold * 3).clamp(18.0, 90.0);

/// The live readout: how far the bars are turned, in whole degrees. The
/// direction is told by the gauge and the lit action, so the number carries
/// no sign (and a bar a hair right of centre reads "0°", not "-0°").
String steeringAngleText(double angle) => '${angle.abs().round()}°';

/// The dead zone as the rider reads it: "±5°".
String steeringDeadZoneText(double threshold) => '±${threshold.round()}°';

/// The trigger of [button] that carries its steering action: the first one
/// that does something, else the long press (steering only works held).
ButtonTrigger steeringTriggerFor(Keymap keymap, ControllerButton button) =>
    mappingActiveTriggers(keymap, button).firstOrNull ?? ButtonTrigger.longPress;

/// What turning towards [button] sends in the trainer app, or null when it
/// sends nothing (no app picked, or the mapping leaves it empty).
String? steeringActionFor(Keymap? keymap, ControllerButton button) {
  if (keymap == null) return null;
  final pair = keymap.getKeyPair(button, trigger: steeringTriggerFor(keymap, button));
  if (pair == null || pair.hasNoAction) return null;
  final text = pair.toString();
  return text.isEmpty ? null : text;
}

/// Whether one of [sinks] is an OpenBikeControl app that listed `0x1B` and can
/// be reached: it then steers from the exact angle.
bool steeringAngleReachesApp(Iterable<SteeringAngleSink> sinks) =>
    sinks.any((s) => s.canSendSteeringAngle && (s.connectedApp.value?.supportsSteeringAngle ?? false));

/// Opens the action picker for one steering direction: the action only,
/// never a choice of single / double / long press — an angle has no presses.
Future<void> openSteeringActionEditor(
  BuildContext context, {
  required BaseDevice device,
  required ControllerButton button,
  required Keymap keymap,
  required IconData icon,
  required String label,
  required VoidCallback onUpdate,
}) async {
  final trigger = steeringTriggerFor(keymap, button);
  final selected = await resolveTriggerEdit(
    context,
    keymap: keymap,
    device: device,
    button: button,
    trigger: trigger,
    askFirst: false,
  );
  if (!context.mounted || selected == null) return;
  await openDrawer(
    context: context,
    position: OverlayPosition.end,
    builder: (c) => ButtonEditPage(
      device: device,
      keyPair: selected.getOrCreateKeyPair(button, trigger: trigger),
      keymap: selected,
      trigger: trigger,
      steeringInput: (icon: icon, label: label),
      onUpdate: () {
        selected.signalUpdate();
        persistMappingEdit();
        onUpdate();
      },
    ),
  );
  persistMappingEdit();
  onUpdate();
}

/// A steering input as an instrument: the live angle in the display face, a
/// horizontal gauge whose knob follows the bars (the dead zone marked by two
/// ticks), and at each end the trainer-app action that direction drives — lit
/// while the bars are past the dead zone on that side.
///
/// Read-only: an angle has no buttons to tap. Positive tilt ⇒ LEFT (matches
/// the devices' `_applyPWMSteering`). [large] is the steering page's hero.
class SteeringGauge extends StatelessWidget {
  final ValueListenable<double> angle;
  final ValueListenable<bool> calibrated;
  final double threshold;

  /// What steering left / right sends; null shows "No action assigned".
  final String? leftAction;
  final String? rightAction;

  final bool large;

  const SteeringGauge({
    super.key,
    required this.angle,
    required this.calibrated,
    required this.threshold,
    this.leftAction,
    this.rightAction,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final range = displayRangeFor(threshold);
    final numeralSize = (context.typography.x2Large.fontSize ?? 24) * (large ? 1.5 : 1.0);
    return ValueListenableBuilder<bool>(
      valueListenable: calibrated,
      builder: (context, isCalibrated, _) {
        return ValueListenableBuilder<double>(
          valueListenable: angle,
          builder: (context, liveAngle, _) {
            final side = isCalibrated ? steerSideFor(liveAngle, threshold) : SteerSide.none;
            final readout = isCalibrated
                ? Text(
                    steeringAngleText(liveAngle),
                    key: const ValueKey('steering-angle-readout'),
                    style: BkNumerals.display(
                      numeralSize,
                      color: side == SteerSide.none ? cs.foreground : bkAccentText(context),
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SmallProgressIndicator(),
                      const Gap(8),
                      Text(
                        l.steeringCalibrating,
                        style: context.typography.small.copyWith(color: cs.mutedForeground),
                      ),
                    ],
                  );
            return Semantics(
              container: true,
              label: isCalibrated
                  ? '${l.steeringAngle} ${steeringAngleText(liveAngle)}'
                      '${side == SteerSide.left ? ', ${leftAction ?? ''}' : side == SteerSide.right ? ', ${rightAction ?? ''}' : ''}'
                  : l.steeringCalibrating,
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Holds the numeral's height either way, so calibrating
                    // moves nothing.
                    SizedBox(height: numeralSize * 1.1, child: Center(child: readout)),
                    SizedBox(
                      height: large ? 52 : 40,
                      // Smoothly eases the knob between sensor frames.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: liveAngle.clamp(-range, range)),
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOut,
                        builder: (context, animatedAngle, _) => CustomPaint(
                          painter: _HorizontalSteeringPainter(
                            angle: animatedAngle,
                            threshold: threshold,
                            range: range,
                            side: side,
                            dimmed: !isCalibrated,
                            trackColor: cs.border,
                            knobColor: cs.mutedForeground,
                            activeColor: cs.primary,
                          ),
                        ),
                      ),
                    ),
                    const Gap(4),
                    // Each end takes the room its words need, so two short
                    // labels never wrap just because the row is split in half.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: _ActionEnd(
                            icon: LucideIcons.chevronsLeft,
                            label: leftAction ?? l.noActionAssigned,
                            active: side == SteerSide.left,
                            assigned: leftAction != null,
                          ),
                        ),
                        const Gap(12),
                        Flexible(
                          child: _ActionEnd(
                            icon: LucideIcons.chevronsRight,
                            label: rightAction ?? l.noActionAssigned,
                            active: side == SteerSide.right,
                            assigned: rightAction != null,
                            end: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// One end of the gauge: the action that direction sends, lit while active.
class _ActionEnd extends StatelessWidget {
  const _ActionEnd({
    required this.icon,
    required this.label,
    required this.active,
    required this.assigned,
    this.end = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool assigned;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = active ? bkAccentText(context) : (assigned ? cs.foreground : cs.mutedForeground);
    final glyph = Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Icon(icon, size: 16, color: active ? color : cs.mutedForeground),
    );
    final text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      style: context.typography.small.copyWith(
        color: color,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      ),
    );
    // One line, always: when both actions don't fit side by side at full
    // size, each shrinks a little rather than breaking onto a second line.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: end ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: end ? [text, glyph] : [glyph, text],
      ),
    );
  }
}

class _HorizontalSteeringPainter extends CustomPainter {
  final double angle; // clamped tilt, degrees
  final double threshold;
  final double range; // full-scale tilt mapped to the track ends
  final SteerSide side;
  final bool dimmed;
  final Color trackColor;
  final Color knobColor;
  final Color activeColor;

  _HorizontalSteeringPainter({
    required this.angle,
    required this.threshold,
    required this.range,
    required this.side,
    required this.dimmed,
    required this.trackColor,
    required this.knobColor,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = dimmed ? 0.4 : 1.0;
    final midY = size.height / 2;
    final knobR = size.height * 0.30;
    final pad = knobR + 2; // keep the knob fully inside at full deflection
    final centerX = size.width / 2;
    final halfW = (size.width / 2) - pad;
    final active = side != SteerSide.none;

    // Positive tilt (steer LEFT) moves the knob to the LEFT.
    double xFor(double tilt) => centerX - (tilt / range).clamp(-1.0, 1.0) * halfW;

    final track = size.height * 0.14;

    // Base track (full width).
    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: opacity)
      ..strokeWidth = track
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(xFor(range), midY), Offset(xFor(-range), midY), trackPaint);

    // Center-anchored deflection fill (center → knob); glows past ±threshold.
    final knobX = xFor(angle);
    final fillPaint = Paint()
      ..color = (active ? activeColor : knobColor).withValues(alpha: opacity * (active ? 1.0 : 0.5))
      ..strokeWidth = track
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centerX, midY), Offset(knobX, midY), fillPaint);

    // Ticks: strong center + the two threshold marks.
    final tickH = size.height * 0.30;
    final centerTick = Paint()
      ..color = trackColor.withValues(alpha: opacity)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centerX, midY - tickH), Offset(centerX, midY + tickH), centerTick);
    final thrTick = Paint()
      ..color = knobColor.withValues(alpha: opacity * 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final t in [threshold, -threshold]) {
      final x = xFor(t);
      canvas.drawLine(Offset(x, midY - tickH), Offset(x, midY + tickH), thrTick);
    }

    // Knob (thin ring for separation).
    canvas.drawCircle(Offset(knobX, midY), knobR + 1.5, Paint()..color = trackColor.withValues(alpha: opacity));
    canvas.drawCircle(
      Offset(knobX, midY),
      knobR,
      Paint()..color = (active ? activeColor : knobColor).withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant _HorizontalSteeringPainter old) =>
      old.angle != angle ||
      old.threshold != threshold ||
      old.range != range ||
      old.side != side ||
      old.dimmed != dimmed ||
      old.trackColor != trackColor ||
      old.knobColor != knobColor ||
      old.activeColor != activeColor;
}
