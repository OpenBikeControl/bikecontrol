import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The two Zwift Click V2 pucks side by side, with the left one fading in as
/// the onboarding pager moves from "right side only" (page 0) to "unlock with
/// Zwift" (page 1).
///
/// The right puck leads on page 0 because it is the one that option keeps:
/// Zwift never locked it, so it needs no unlock and never restarts. The left
/// puck — the locked one — is what page 1 adds back, at the price of the
/// 24-hour unlock.
///
/// Takes a fractional [page] rather than owning a PageController so a swipe
/// scrubs the transition continuously instead of snapping at the page
/// boundary — and so the widget can be driven by a plain animation when the
/// flow is reopened for review.
///
/// When [animate] is true (the default), a small badge cross-fades with [page]
/// to explain that option's trade-off: an open padlock on page 0 (nothing to
/// unlock, ever) and a closed one on page 1 (Zwift's 24-hour unlock), the
/// latter with a sweep-ring flourish that is suppressed when the platform
/// requests reduced motion. Pass `animate: false` to render just the two
/// silhouettes, with no badge and no loop — the onboarding pager's decision
/// page uses this: both options are already laid out in the buttons there, so
/// the badge that explains page 1's trade-off would just be noise on a page
/// about choosing.
///
/// Callers must give this widget a bounded width and a finite height — the
/// `Row`/`Flexible` layout below asserts if width is unbounded. It is
/// designed for a box around [_designHeight] (180px) tall, such as the
/// onboarding pager's hero; below that it degrades gracefully (see
/// [_designHeight]) but is not intended for arbitrarily tall boxes.
class ClickContours extends StatefulWidget {
  /// 0 = right side only, 1 = unlock with Zwift. Values outside are clamped.
  final double page;

  /// Whether to run the looping badge flourishes and render the badges at
  /// all. False for static thumbnail use (e.g. a small device-preview card),
  /// where a sweeping padlock would be cramped and distracting.
  final bool animate;

  const ClickContours({super.key, required this.page, this.animate = true});

  static const double _mutedOpacity = 0.15;
  static const double _mutedScale = 0.92;

  // The absolute pixel values below (glow blur/spread, right-puck offset)
  // were authored against the onboarding pager's 180px-tall hero box. A
  // later task reuses this widget as a much smaller card thumbnail, where
  // these same absolute pixels would overwhelm the art (e.g. a 34px blur in
  // a ~40px-tall thumbnail). _designHeight lets us scale them down
  // proportionally to whatever height the widget is actually given, while
  // leaving the look unchanged at 180px or taller.
  static const double _designHeight = 180;
  static const double _mutedOffset = 14;
  static const double _glowBlurRadius = 34;
  static const double _glowSpreadRadius = 2;

  @override
  State<ClickContours> createState() => _ClickContoursState();
}

class _ClickContoursState extends State<ClickContours> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  bool get _shouldLoop => widget.animate && !MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Looping must never run under disableAnimations: a perpetually pending
    // frame makes pumpAndSettle hang and burns battery on the overview page.
    if (_shouldLoop && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!_shouldLoop && _loop.isAnimating) {
      _loop.stop();
      _loop.value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.page.clamp(0.0, 1.0);
    final cs = Theme.of(context).colorScheme;
    // Same treatment ControllerCanvas gives these silhouettes: tint in dark
    // mode, leave the source art alone in light mode.
    final colorFilter = Theme.of(context).brightness == Brightness.dark
        ? ColorFilter.mode(cs.primary, BlendMode.srcIn)
        : null;
    // Constant null (not just a stopped controller) when looping shouldn't
    // run, so the badges and the puck dimming can render their exact resting
    // state without depending on a controller's momentary value.
    final loopAnim = _shouldLoop ? _loop : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale the absolute-pixel constants down when given less height
        // than the design was authored for (e.g. a small thumbnail), but
        // never scale them up beyond their authored size.
        final k = constraints.maxHeight.isFinite
            ? (constraints.maxHeight / ClickContours._designHeight).clamp(0.0, 1.0)
            : 1.0;

        // The pucks stay in physical order — left puck on the left — while the
        // *emphasis* swaps: page 0 is about the right puck alone, so it takes
        // the glow and the left one recedes.
        final row = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Transform.translate(
                key: const ValueKey('click-contour-muted-translate'),
                // Negative: the receding puck drifts away from its partner,
                // which for the left one means leftwards.
                offset: Offset(-ClickContours._mutedOffset * k * (1 - t), 0),
                child: Transform.scale(
                  key: const ValueKey('click-contour-muted-scale'),
                  scale: ClickContours._mutedScale + (1 - ClickContours._mutedScale) * t,
                  child: Opacity(
                    key: const ValueKey('click-contour-muted-opacity'),
                    opacity: ClickContours._mutedOpacity + (1 - ClickContours._mutedOpacity) * t,
                    child: SvgPicture.asset(
                      'assets/contours/zwift_click_v2_left_side.svg',
                      fit: BoxFit.contain,
                      colorFilter: colorFilter,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: DecoratedBox(
                key: const ValueKey('click-contour-lead-glow'),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // The glow marks the right puck as the one carrying the
                      // load on page 0, and fades out as the left puck joins it.
                      color: cs.primary.withValues(alpha: 0.28 * (1 - t)),
                      blurRadius: ClickContours._glowBlurRadius * k,
                      spreadRadius: ClickContours._glowSpreadRadius * k,
                    ),
                  ],
                ),
                child: SvgPicture.asset(
                  'assets/contours/zwift_click_v2_right_side.svg',
                  fit: BoxFit.contain,
                  colorFilter: colorFilter,
                ),
              ),
            ),
          ],
        );

        if (!widget.animate) return row;

        return Stack(
          children: [
            row,
            Opacity(
              key: const ValueKey('click-contour-free-badge'),
              opacity: 1 - t,
              child: _FreeBadge(scale: k),
            ),
            Opacity(
              key: const ValueKey('click-contour-lock-badge'),
              opacity: t,
              child: _LockBadge(sweep: loopAnim, settle: t, scale: k),
            ),
          ],
        );
      },
    );
  }
}

/// Page-0 badge: a small open-padlock pill under the right puck. It is the
/// resting counterpart to [_LockBadge] — same pill, same padlock, no sweep and
/// no loop, because the whole point of this option is that nothing ever has to
/// be unlocked. Deliberately static: an animated flourish here would imply
/// something happens periodically, which is exactly what it does not.
class _FreeBadge extends StatelessWidget {
  final double scale;

  const _FreeBadge({required this.scale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final k = scale;

    return Align(
      alignment: const Alignment(0.55, 0.85),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6 * k, vertical: 2 * k),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.border),
        ),
        child: Icon(LucideIcons.lockOpen, size: 12 * k, color: cs.primary),
      ),
    );
  }
}

/// Page-1 badge: a padlock between the pucks whose shackle lifts once the
/// page settles on the Zwift-unlock option, wrapped in a ring that sweeps
/// once through 360° per loop of [sweep]. [sweep] is null when looping
/// shouldn't run, in which case the ring renders as a plain static circle.
class _LockBadge extends StatelessWidget {
  final Animation<double>? sweep;
  final double settle;
  final double scale;

  const _LockBadge({required this.sweep, required this.settle, required this.scale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final k = scale;
    final size = 34.0 * k;
    // The shackle only lifts once the swipe has essentially committed to
    // this page, so it doesn't flicker open mid-drag.
    final lift = ((settle - 0.9) / 0.1).clamp(0.0, 1.0);

    Widget ringAt(double progress) {
      return CustomPaint(
        size: Size(size, size),
        painter: _SweepRingPainter(color: cs.primary, progress: progress),
      );
    }

    final ring = sweep == null
        ? ringAt(0.0)
        : AnimatedBuilder(animation: sweep!, builder: (context, _) => ringAt(sweep!.value));

    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ring,
            Transform.translate(
              offset: Offset(0, -3 * k * lift),
              child: Icon(lift > 0.5 ? LucideIcons.lockOpen : LucideIcons.lock, size: 16 * k, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SweepRingPainter extends CustomPainter {
  final Color color;

  /// 0..1, one full lap of the ring per loop cycle.
  final double progress;

  _SweepRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    const arcLength = math.pi / 2;
    final start = -math.pi / 2 + progress * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      arcLength,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SweepRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
