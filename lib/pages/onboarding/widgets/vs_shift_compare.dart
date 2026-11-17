import 'dart:ui' show PathMetric;

import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One shift drawn twice: through the trainer app, and through BikeControl.
///
/// The app works out a slope and sends it a beat later. BikeControl shifts at
/// the trainer: with [native] the trainer applies the gear itself (a sharp
/// step, right away); otherwise BikeControl sets the slope there, without the
/// trip through the app (eased like the app's, only sooner). The curves are
/// an illustration and say so.
class VsShiftCompare extends StatefulWidget {
  const VsShiftCompare({super.key, required this.app, required this.native, required this.active});

  /// The trainer app by name; null for the generic wording.
  final String? app;

  /// A connected trainer takes BikeControl's gears natively.
  final bool native;

  /// Draws the curves over and over while true; holds them drawn otherwise.
  final bool active;

  @override
  State<VsShiftCompare> createState() => _VsShiftCompareState();
}

class _VsShiftCompareState extends State<VsShiftCompare> with SingleTickerProviderStateMixin {
  // Draws both curves in 60% of the cycle, then holds them before redrawing.
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
    value: 1,
  );
  late final Animation<double> _progress = CurvedAnimation(parent: _draw, curve: const Interval(0, 0.6));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(VsShiftCompare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active) {
      _draw
        ..value = 0
        ..repeat();
    } else {
      _draw.stop();
      _draw.value = 1;
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n;
    final cs = Theme.of(context).colorScheme;
    final app = widget.app;
    return Column(
      key: const ValueKey('vs-stage-shift-compare'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ShiftLane(
          label: app == null ? i18n.vsStageLaneAppGeneric : i18n.vsStageLaneApp(app),
          timing: i18n.vsStageLaneLater,
          steps: [i18n.vsStageStepButton, i18n.vsStageStepAppSlope, i18n.vsStageStepTrainer],
          curve: _ShiftCurve.app,
          progress: _progress,
          emphasis: false,
        ),
        const Gap(10),
        _ShiftLane(
          label: i18n.vsStageLaneBikeControl,
          timing: widget.native ? i18n.vsStageLaneRightAway : i18n.vsStageLaneSooner,
          steps: widget.native
              ? [i18n.vsStageStepButton, i18n.vsStageStepTrainerGear]
              : [i18n.vsStageStepButton, i18n.vsStageStepBikeControlSlope, i18n.vsStageStepTrainer],
          curve: widget.native ? _ShiftCurve.native : _ShiftCurve.direct,
          progress: _progress,
          emphasis: true,
        ),
        const Gap(8),
        Text(
          i18n.vsStageShiftIllustration,
          style: context.typography.xSmall.copyWith(color: cs.mutedForeground, height: 1.35),
        ),
      ],
    );
  }
}

/// The resistance after one shift, in a 300 × 46 box (y down): flat, the
/// press at x = 70, then the climb to the new gear.
enum _ShiftCurve {
  /// The trainer app works out a slope and sends it a beat later.
  app,

  /// The trainer applies the gear itself, right away.
  native,

  /// BikeControl sets the slope at the trainer: eased like [app], but sooner.
  direct;

  Path path(Size size) {
    final sx = size.width / 300, sy = size.height / 46;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final path = Path()..moveTo(p(2, 36).dx, p(2, 36).dy);
    void line(double x, double y) => path.lineTo(p(x, y).dx, p(x, y).dy);
    void curve(double x1, double y1, double x2, double y2, double x, double y) {
      final a = p(x1, y1), b = p(x2, y2), c = p(x, y);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }

    switch (this) {
      case _ShiftCurve.app:
        line(150, 36);
        curve(175, 36, 185, 12, 215, 10);
      case _ShiftCurve.native:
        line(76, 36);
        line(84, 10);
      case _ShiftCurve.direct:
        line(96, 36);
        curve(112, 36, 120, 13, 138, 10);
    }
    line(298, 10);
    return path;
  }
}

class _ShiftLane extends StatelessWidget {
  const _ShiftLane({
    required this.label,
    required this.timing,
    required this.steps,
    required this.curve,
    required this.progress,
    required this.emphasis,
  });

  final String label;
  final String timing;
  final List<String> steps;
  final _ShiftCurve curve;
  final Animation<double> progress;

  /// BikeControl's lane: the accent colour, and its last step highlighted.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = onboardingAccent(context);
    final small = context.typography.xSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: emphasis ? cs.foreground : cs.mutedForeground,
                ),
              ),
            ),
            Text(
              timing,
              style: small.copyWith(fontWeight: FontWeight.w600, color: emphasis ? accent : cs.mutedForeground),
            ),
          ],
        ),
        const Gap(4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) Container(width: 8, height: 1.5, color: cs.border),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: emphasis && i == steps.length - 1
                      ? accent.withValues(alpha: 0.14)
                      : cs.border.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  steps[i],
                  style: context.typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: emphasis && i == steps.length - 1 ? accent : cs.mutedForeground,
                  ),
                ),
              ),
            ],
          ],
        ),
        const Gap(2),
        // Decoration: the lane's label and steps already say it in words.
        ExcludeSemantics(
          child: SizedBox(
            height: 34,
            child: AnimatedBuilder(
              animation: progress,
              builder: (context, _) => CustomPaint(
                painter: _ShiftCurvePainter(
                  curve: curve,
                  progress: progress.value,
                  color: emphasis ? accent : cs.mutedForeground,
                  grid: cs.border,
                  press: cs.foreground.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShiftCurvePainter extends CustomPainter {
  _ShiftCurvePainter({
    required this.curve,
    required this.progress,
    required this.color,
    required this.grid,
    required this.press,
  });

  final _ShiftCurve curve;
  final double progress;
  final Color color;
  final Color grid;
  final Color press;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
    // The press: a dotted vertical line.
    final x = size.width * 70 / 300;
    final dots = Paint()
      ..color = press
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 5) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 2).clamp(0, size.height)), dots);
    }
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = curve.path(size);
    if (progress >= 1) {
      canvas.drawPath(path, stroke);
      return;
    }
    for (final PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), stroke);
    }
  }

  @override
  bool shouldRepaint(_ShiftCurvePainter old) =>
      old.progress != progress || old.curve != curve || old.color != color || old.grid != grid || old.press != press;
}
