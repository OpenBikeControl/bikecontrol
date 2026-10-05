import 'package:bike_control/utils/reduced_motion.dart';
import 'package:flutter/widgets.dart';

/// The app's routine motion: how long a state change takes and how it eases.
///
/// Every duration here collapses to zero under [prefersReducedMotion], so a
/// change still happens — it just happens at once.
abstract final class BkMotion {
  /// A routine state change: a row arriving, a card swapping its content.
  static const Duration standard = Duration(milliseconds: 250);

  /// A row leaving: quicker than it arrived, so the list never waits on it.
  static const Duration exit = Duration(milliseconds: 180);

  /// Confident deceleration — arrives fast, settles softly. No bounce.
  static const Curve curve = Cubic(0.16, 1, 0.3, 1);

  /// [duration], or zero while the rider asked for less motion.
  static Duration of(BuildContext context, [Duration duration = standard]) =>
      prefersReducedMotion(context) ? Duration.zero : duration;
}

/// A column whose children animate in and out as the list changes.
///
/// Children are matched by their [Key] (every child needs one). A new key
/// grows in — its height opens while it fades and slides up a few pixels — and
/// a key that is gone shrinks out from where it was. Children present on the
/// first build are simply there: a screen that opens is not a change.
///
/// Under reduced motion every change is instant.
class BkAnimatedColumn extends StatefulWidget {
  const BkAnimatedColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  State<BkAnimatedColumn> createState() => _BkAnimatedColumnState();
}

class _Entry {
  _Entry(this.key, this.child, this.controller)
    : eased = CurvedAnimation(parent: controller, curve: BkMotion.curve, reverseCurve: Curves.easeIn),
      // The height leads, the content follows: it fades in over the later
      // part, so text never draws squashed into a sliver.
      fade = CurvedAnimation(
        parent: controller,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      );

  final Key key;
  Widget child;
  final AnimationController controller;
  final CurvedAnimation eased;
  final CurvedAnimation fade;
  bool leaving = false;

  void dispose() {
    eased.dispose();
    fade.dispose();
    controller.dispose();
  }
}

class _BkAnimatedColumnState extends State<BkAnimatedColumn> with TickerProviderStateMixin {
  final List<_Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    for (final child in widget.children) {
      _entries.add(_Entry(_keyOf(child), child, _controller(value: 1)));
    }
  }

  static Key _keyOf(Widget child) {
    final key = child.key;
    assert(key != null, 'BkAnimatedColumn children need keys');
    return key ?? UniqueKey();
  }

  AnimationController _controller({required double value}) => AnimationController(
    vsync: this,
    value: value,
    duration: BkMotion.standard,
    reverseDuration: BkMotion.exit,
  );

  @override
  void didUpdateWidget(covariant BkAnimatedColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final instant = prefersReducedMotion(context);
    final incoming = {for (final child in widget.children) _keyOf(child): child};

    // Gone: shrink out where they stand (or vanish at once).
    for (final entry in [..._entries]) {
      if (incoming.containsKey(entry.key)) continue;
      if (instant) {
        _dispose(entry);
        continue;
      }
      if (entry.leaving) continue;
      entry.leaving = true;
      entry.controller.reverse().whenComplete(() {
        if (!mounted || !entry.leaving) return;
        setState(() => _dispose(entry));
      });
    }

    // Kept and new, in the new order; a leaving entry keeps its slot after
    // the entry it used to follow.
    final merged = <_Entry>[];
    final byKey = {for (final e in _entries) e.key: e};
    var cursor = 0;
    void flushLeavingUpTo(int index) {
      while (cursor < index && cursor < _entries.length) {
        final e = _entries[cursor++];
        if (e.leaving && !merged.contains(e)) merged.add(e);
      }
    }

    for (final child in widget.children) {
      final key = _keyOf(child);
      final existing = byKey[key];
      if (existing != null) {
        flushLeavingUpTo(_entries.indexOf(existing));
        existing.child = child;
        if (existing.leaving) {
          // Came back mid-exit: grow back from wherever it got to.
          existing.leaving = false;
          if (instant) {
            existing.controller.value = 1;
          } else {
            existing.controller.forward();
          }
        }
        merged.add(existing);
      } else {
        final entry = _Entry(key, child, _controller(value: instant ? 1 : 0));
        if (!instant) entry.controller.forward();
        merged.add(entry);
      }
    }
    flushLeavingUpTo(_entries.length);
    _entries
      ..clear()
      ..addAll(merged.where((e) => e.leaving || incoming.containsKey(e.key)));
  }

  void _dispose(_Entry entry) {
    _entries.remove(entry);
    entry.dispose();
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in _entries)
          KeyedSubtree(
            key: entry.key,
            child: IgnorePointer(
              ignoring: entry.leaving,
              child: SizeTransition(
                sizeFactor: entry.eased,
                alignment: Alignment.topCenter,
                child: FadeTransition(
                  opacity: entry.fade,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(entry.eased),
                    child: entry.child,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Swaps [child] for the next one with a crossfade while the space it takes
/// eases to the new height — so a card that changes what it is never jumps.
///
/// Give each state's child its own key; a child with the same key just
/// rebuilds in place. Instant under reduced motion.
class BkAnimatedSwap extends StatelessWidget {
  const BkAnimatedSwap({super.key, required this.child, this.alignment = Alignment.topCenter, this.scaleIn = false});

  final Widget child;
  final AlignmentGeometry alignment;

  /// The incoming child also grows from 98 % — for content arriving live
  /// (a trainer's card replacing its placeholder), not for a mere relabel.
  final bool scaleIn;

  @override
  Widget build(BuildContext context) {
    // Nothing to ease: the new child simply stands where the old one was.
    // (AnimatedSize at zero duration re-dirties its own layout.)
    if (prefersReducedMotion(context)) return child;
    const duration = BkMotion.standard;
    return AnimatedSize(
      duration: duration,
      curve: BkMotion.curve,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: BkMotion.exit,
        switchInCurve: BkMotion.curve,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: alignment,
          children: [
            // The outgoing one fades out behind, without claiming height.
            for (final p in previous)
              Positioned.fill(
                child: OverflowBox(alignment: alignment, maxHeight: double.infinity, child: p),
              ),
            ?current,
          ],
        ),
        transitionBuilder: (child, animation) {
          final faded = FadeTransition(opacity: animation, child: child);
          if (!scaleIn) return faded;
          return ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(animation), child: faded);
        },
        child: child,
      ),
    );
  }
}
