import 'package:bike_control/main.dart' show screenshotMotionPinned;
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A muted rounded bar standing in for text that is on its way.
class BkBone extends StatelessWidget {
  const BkBone({super.key, this.width, required this.height, this.radius});

  final double? width;
  final double height;

  /// A pill by default.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted,
        borderRadius: BorderRadius.circular(radius ?? height / 2),
      ),
    );
  }
}

/// A slow light passing over [child] — "this is loading", for placeholders
/// only. Still under reduced motion (and in store renders).
class BkShimmer extends StatefulWidget {
  const BkShimmer({super.key, required this.child});

  final Widget child;

  /// One pass of the light.
  static const Duration period = Duration(milliseconds: 1600);

  @override
  State<BkShimmer> createState() => _BkShimmerState();
}

class _BkShimmerState extends State<BkShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: BkShimmer.period);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (screenshotMotionPinned || prefersReducedMotion(context)) {
      if (_controller.isAnimating) _controller.stop();
      return widget.child;
    }
    if (!_controller.isAnimating) _controller.repeat();
    // A lighter band over the muted bones: white on graphite, the near-white
    // ground on the light theme's greys.
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final light = dark ? cs.foreground : cs.background;
    final peak = dark ? 0.10 : 0.7;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // The band travels from well left of the child to well right of it.
        final t = _controller.value * 3 - 1;
        return ShaderMask(
          key: const ValueKey('bk-shimmer'),
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1 + t * 2 - 0.6, 0),
            end: Alignment(-1 + t * 2 + 0.6, 0),
            colors: [
              light.withValues(alpha: 0),
              light.withValues(alpha: peak),
              light.withValues(alpha: 0),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
