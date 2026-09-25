import 'package:bike_control/main.dart' show screenshotMode, screenshotMotionPinned;
import 'package:shadcn_flutter/shadcn_flutter.dart';


/// Reveals its child with a fade + rise once [delay] has elapsed.
///
/// Staggering these — see [onboardingReveal] — is what makes a wizard screen
/// arrive rather than appear: the eye is led down the page in the order the
/// content is meant to be read, instead of being handed everything at once and
/// left to find the starting point itself.
///
/// Renders statically under reduced motion and in [screenshotMode] (which the
/// snapshot harness enables, keeping captures deterministic).
class OnboardingReveal extends StatelessWidget {
  const OnboardingReveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  /// The rise and the span the welcome screen uses. Long enough to read as
  /// movement, short enough that a staggered column has finished arriving
  /// before a rider could act on it.
  static const Duration span = Duration(milliseconds: 520);
  static const double rise = 14;

  /// Gap between consecutive items in a staggered column.
  static const Duration interval = Duration(milliseconds: 70);

  /// How many items still earn a longer delay. The controller step's list grows
  /// with every device in the room, and without a ceiling the last entry on a
  /// busy screen would arrive a second and a half after the first — long enough
  /// that a rider reaching for it watches it move.
  static const int maxStaggered = 8;

  @override
  Widget build(BuildContext context) {
    if (screenshotMotionPinned || MediaQuery.of(context).disableAnimations) return child;
    final total = span + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, rise * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Wraps a column's [children] so they arrive one after another.
///
/// [Gap]s are passed through untouched: they are empty space, so animating
/// them would buy nothing visually while making the cadence uneven — and
/// leaving them in place from the first frame means the column's layout is
/// settled before anything fades in, so nothing shifts under the rider's eye.
List<Widget> onboardingReveal(
  List<Widget> children, {
  Duration delay = Duration.zero,
  Duration interval = OnboardingReveal.interval,
}) {
  var index = 0;
  return [
    for (final child in children)
      if (child is Gap)
        child
      else
        OnboardingReveal(
          delay: delay + interval * (index++).clamp(0, OnboardingReveal.maxStaggered),
          child: child,
        ),
  ];
}
