import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class SmoothWifiAnimation extends StatefulWidget {
  const SmoothWifiAnimation({
    super.key,
    this.size = 160,
    this.label = 'SCANNING',
  });

  final double size;
  final String label;

  @override
  State<SmoothWifiAnimation> createState() => _ScanningIndicatorState();
}

class _ScanningIndicatorState extends State<SmoothWifiAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    // Colors close to the screenshot
    const ringColor = Color(0xFFBFEFF2); // pale cyan
    const innerBorder = Color(0xFFE6E6E6);
    const iconColor = BKColor.main; // teal

    return SizedBox(
      width: s,
      height: s + 28, // room for the pill label
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Pulsing outer halo (two staggered ripples looks nicer)
          _Ripple(
            controller: _c,
            color: ringColor,
            beginScale: 0.80,
            endScale: 1.15,
            opacityCurve: Curves.easeOut,
            interval: const Interval(0.0, 1.0),
          ),
          _Ripple(
            controller: _c,
            color: ringColor,
            beginScale: 0.70,
            endScale: 1.05,
            opacityCurve: Curves.easeOut,
            interval: const Interval(0.35, 1.0),
          ),

          // Static ring + inner circle
          Container(
            width: s,
            height: s,
            alignment: Alignment.center,
            child: Container(
              width: s * 0.62,
              height: s * 0.62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: innerBorder, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.wifi_tethering, color: iconColor, size: 40),
            ),
          ),

          // Bottom pill label
          Positioned(
            bottom: 26,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: ShapeDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: StadiumBorder(),
                shadows: [
                  BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 3),
                    color: Color(0x33000000),
                  ),
                ],
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primaryForeground,
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  const _Ripple({
    required this.controller,
    required this.color,
    required this.beginScale,
    required this.endScale,
    required this.opacityCurve,
    required this.interval,
  });

  final AnimationController controller;
  final Color color;
  final double beginScale;
  final double endScale;
  final Curve opacityCurve;
  final Interval interval;

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: controller, curve: interval);

    // Scale 0..1 -> beginScale..endScale
    final scale = Tween<double>(begin: beginScale, end: endScale).animate(
      CurvedAnimation(parent: t, curve: Curves.easeOutCubic),
    );

    // Opacity starts visible and fades out
    final opacity = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(parent: t, curve: opacityCurve),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Transform.scale(
          scale: scale.value,
          child: Opacity(
            opacity: opacity.value,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}
