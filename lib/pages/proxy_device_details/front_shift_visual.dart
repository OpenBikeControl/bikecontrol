import 'dart:math' as math;

import 'package:bike_control/gen/l10n.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The virtual front derailleur, drawn: two chainrings with the engaged one
/// filled in, next to the ratio range that ring gives you.
///
/// Shown both in the gear settings (under the enable toggle, above the teeth
/// steppers) and in the onboarding preview, where the ring toggles on its own
/// so a rider can see what a second chainring buys before owning one.
class FrontShiftVisual extends StatelessWidget {
  const FrontShiftVisual({
    super.key,
    required this.smallTeeth,
    required this.largeTeeth,
    required this.largeRingActive,
    this.ratios = const <double>[],
    this.gearCount,
  });

  final int smallTeeth;
  final int largeTeeth;

  /// Which ring the drivetrain is on right now.
  final bool largeRingActive;

  /// The rear ratios, i.e. the range on the small ring. Empty hides the range
  /// readout and leaves the rings and the factor — the open-source trainer
  /// stub reports no ratios until a real definition is attached.
  final List<double> ratios;

  /// Gear count to spell out. Defaults to `ratios.length`.
  final int? gearCount;

  static const Duration _swap = Duration(milliseconds: 420);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final factor = smallTeeth <= 0 ? 1.0 : largeTeeth / smallTeeth;
    final activeTeeth = largeRingActive ? largeTeeth : smallTeeth;
    final gears = gearCount ?? ratios.length;

    final hasRange = ratios.isNotEmpty;
    final baseLo = hasRange ? ratios.reduce(math.min) : 0.0;
    final baseHi = hasRange ? ratios.reduce(math.max) : 0.0;
    final ringFactor = largeRingActive ? factor : 1.0;
    final lo = baseLo * ringFactor;
    final hi = baseHi * ringFactor;
    // Both rings share one scale — the large ring's top ratio — so the bar
    // grows to the right on a front shift instead of being re-fitted, which
    // is the whole point of the picture.
    final scaleMax = baseHi * factor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ring(context, teeth: smallTeeth, size: 44, active: !largeRingActive, accent: accent),
        const Gap(10),
        _ring(context, teeth: largeTeeth, size: 56, active: largeRingActive, accent: accent),
        const Gap(16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hasRange ? l10n.frontShiftRangeLabel : l10n.frontShiftFactorLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: cs.mutedForeground,
                      ),
                    ),
                  ),
                  Text(
                    '${factor.toStringAsFixed(2)}×',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.mutedForeground),
                  ),
                ],
              ),
              const Gap(2),
              Text(
                hasRange
                    ? '${lo.toStringAsFixed(2)} – ${hi.toStringAsFixed(2)}'
                    : '$smallTeeth / $largeTeeth',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: cs.foreground,
                ),
              ),
              if (hasRange && scaleMax > 0) ...[
                const Gap(8),
                _RangeBar(start: lo / scaleMax, end: hi / scaleMax, accent: accent, track: cs.border),
              ],
              const Gap(7),
              Text(
                gears > 0
                    ? '${l10n.frontShiftRingActive(activeTeeth)} · ${l10n.gearsCount(gears)}'
                    : l10n.frontShiftRingActive(activeTeeth),
                style: TextStyle(fontSize: 11, color: cs.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A chainring: solid and washed when engaged, dashed and muted when not.
  Widget _ring(BuildContext context, {required int teeth, required double size, required bool active, required Color accent}) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: _swap,
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? accent.withValues(alpha: 0.16) : Colors.transparent,
      ),
      child: CustomPaint(
        painter: _RingPainter(
          color: active ? accent : cs.border,
          dashed: !active,
        ),
        child: Center(
          child: Text(
            '$teeth',
            style: TextStyle(
              fontSize: size >= 56 ? 13 : 11,
              fontWeight: FontWeight.w700,
              color: active ? accent : cs.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.start, required this.end, required this.accent, required this.track});

  final double start;
  final double end;
  final Color accent;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final left = (start.clamp(0.0, 1.0)) * w;
        final right = (end.clamp(0.0, 1.0)) * w;
        return SizedBox(
          height: 5,
          child: Stack(
            children: [
              Container(decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(999))),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                left: left,
                width: math.max(right - left, 2),
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final radius = (math.min(size.width, size.height) - paint.strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    if (!dashed) {
      canvas.drawCircle(center, radius, paint);
      return;
    }
    // Even dash/gap pairs around the circumference, so the ring reads as
    // "available but not engaged" at any size.
    const dashes = 16;
    final sweep = math.pi * 2 / dashes;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color || old.dashed != dashed;
}
