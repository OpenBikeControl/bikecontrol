import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ButtonWidget extends StatelessWidget {
  final ControllerButton button;
  final double size;
  final Keymap? keymap;

  const ButtonWidget({
    super.key,
    required this.button,
    this.size = 56,
    this.keymap,
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

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: cs.border, width: 1.5),
              boxShadow: hasAssignment
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
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
          if (actionIcon != null)
            Positioned(
              top: -badgeSize * 0.15,
              right: -badgeSize * 0.15,
              child: Container(
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
        ],
      ),
    );
  }
}
