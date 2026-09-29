import 'dart:math' as math;

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/network_test/network_tokens.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The verdict card's 64px ring: how many checks passed, out of how many ran.
///
/// A count, not a percentage — "7 of 8" says which checks are left to look at,
/// where "88%" says nothing a rider can act on. The arc takes the colour of the
/// worst thing found, so the ring reads before the sentence beside it does.
class NetworkGauge extends StatelessWidget {
  const NetworkGauge({super.key, required this.passed, required this.total, required this.color});

  final int passed;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = NetworkTokens.of(context);
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(64),
            painter: _RingPainter(
              progress: total == 0 ? 0 : passed / total,
              track: tokens.hairline,
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$passed',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.02),
              ),
              Text(
                AppLocalizations.of(context).networkChecksPassedOf(total),
                style: Theme.of(context).typography.mono.copyWith(
                  // Fixed 64 px ring: geometry, not the type scale; 11 is the floor.
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.color});

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color || old.track != track;
}
