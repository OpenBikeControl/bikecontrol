import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ButtonWidget extends StatelessWidget {
  final ControllerButton button;
  final double size;
  final Keymap? keymap;

  /// When set, wraps the button in a [Hero] with this tag so navigation
  /// transitions can fly the same circular button between routes. Leave null
  /// when this widget is rendered in popovers, drawers, or list rows that
  /// don't participate in a route transition.
  final Object? heroTag;

  const ButtonWidget({
    super.key,
    required this.button,
    this.size = 56,
    this.keymap,
    this.heroTag,
  });

  List<KeyPair> get _assignedPairs {
    if (keymap == null) return const [];
    return keymap!.getKeyPairs(button).where((kp) => !kp.hasNoAction).toList();
  }

  IconData? get _primaryActionIcon {
    const ordered = [ButtonTrigger.singleClick, ButtonTrigger.doubleClick, ButtonTrigger.longPress];
    for (final t in ordered) {
      final kp = _assignedPairs.firstOrNullWhere((p) => p.trigger == t);
      if (kp?.icon != null) return kp!.icon;
    }
    return _assignedPairs.firstOrNull?.icon;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = button.color ?? cs.muted;
    // Pick a foreground that contrasts with the actual button background
    // rather than the theme's `cs.foreground`, which stays dark on light
    // themes even when `button.color` is explicitly set to black.
    final onBg = bg.computeLuminance() < 0.5 ? Colors.white : Colors.black;
    final actionIcon = _primaryActionIcon;
    final hasAssignment = _assignedPairs.isNotEmpty;
    final badgeSize = size * 0.44;

    final core = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: cs.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: hasAssignment ? 0.22 : 0.0),
                  blurRadius: hasAssignment ? 6 : 0,
                  offset: Offset(0, hasAssignment ? 2 : 0),
                ),
              ],
            ),
          ),
          if (button.icon != null)
            Icon(button.icon, size: size * 0.42, color: onBg)
          else
            Text(
              button.initials,
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: onBg,
              ),
            ),
          Positioned(
            top: -badgeSize * 0.15,
            right: -badgeSize * 0.15,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.elasticOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
              child: actionIcon == null
                  ? SizedBox(key: const ValueKey('no-badge'), width: badgeSize, height: badgeSize)
                  : Container(
                      key: ValueKey(actionIcon.codePoint),
                      width: badgeSize,
                      height: badgeSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.background, width: 1.5),
                      ),
                      child: Icon(actionIcon, size: badgeSize * 0.6, color: cs.primaryForeground),
                    ),
            ),
          ),
        ],
      ),
    );

    if (heroTag == null) return core;
    return Hero(tag: heroTag!, child: core);
  }
}
