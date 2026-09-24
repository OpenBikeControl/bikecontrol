import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/trigger_assignment_popup.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
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

/// The numeric line under the gauge: the tilt in whole degrees, then the
/// trigger threshold. Rounded as an int, so a bar a hair right of centre
/// reads "0°" rather than "-0°".
String steeringReadout(double angle, double threshold) =>
    '${angle.round()}°  ·  ±${threshold.toStringAsFixed(0)}°';

/// Compact horizontal gauge for the Phone-Steering device card footer. A knob
/// glides left/right with the live tilt and a fill grows from the center to the
/// knob, glowing once the tilt passes ±threshold (marked by ticks). The left and
/// right halves are tap targets that open each steer button's remap editor.
/// Positive tilt ⇒ LEFT (matches the device's `_applyPWMSteering`).
class SteeringGauge extends StatelessWidget {
  final ValueListenable<double> angle;
  final ValueListenable<bool> calibrated;
  final double threshold;

  final BaseDevice device;
  final ControllerButton leftButton;
  final ControllerButton rightButton;
  final Keymap? keymap;
  final VoidCallback? onUpdate;

  const SteeringGauge({
    super.key,
    required this.angle,
    required this.calibrated,
    required this.threshold,
    required this.device,
    required this.leftButton,
    required this.rightButton,
    this.keymap,
    this.onUpdate,
  });

  bool get _canEdit => keymap != null && onUpdate != null;

  Future<void> _edit(BuildContext context, ControllerButton button) async {
    if (!_canEdit) return;
    await showTriggerAssignmentPopup(
      context: context,
      device: device,
      button: button,
      keymap: keymap!,
      onUpdate: onUpdate!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final range = displayRangeFor(threshold);
    return ValueListenableBuilder<bool>(
      valueListenable: calibrated,
      builder: (context, isCalibrated, _) {
        return ValueListenableBuilder<double>(
          valueListenable: angle,
          builder: (context, liveAngle, _) {
            final side = isCalibrated ? steerSideFor(liveAngle, threshold) : SteerSide.none;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Smoothly eases the knob between sensor frames.
                      TweenAnimationBuilder<double>(
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
                      // Tap-to-remap halves (transparent): left half ⇒ leftButton.
                      if (_canEdit)
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _edit(context, leftButton),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _edit(context, rightButton),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                // Numeric readout / calibrating hint, below the bar.
                isCalibrated
                    ? Text(
                        steeringReadout(liveAngle, threshold),
                      ).xSmall.muted
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SmallProgressIndicator(),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context).steeringCalibrating).xSmall.muted,
                        ],
                      ),
              ],
            );
          },
        );
      },
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
