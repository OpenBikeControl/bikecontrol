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
    final color = button.color ?? cs.muted;
    final icon = _primaryActionIcon ?? button.icon;
    final assignedCount = _assignedPairs.length;
    // Pick a foreground that contrasts with the actual button background
    // rather than the theme's `cs.foreground`, which stays dark on light
    // themes even when `button.color` is explicitly set to black.
    final onColor = color.computeLuminance() < 0.5 ? Colors.white : Colors.black;
    final onColorMuted = onColor.withValues(alpha: 0.65);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: cs.border, width: 1.5),
            ),
          ),
          if (icon != null)
            Icon(icon, size: size * 0.42, color: onColor)
          else
            Text(
              button.initials,
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: onColor,
              ),
            ),
          if (icon != null)
            Positioned(
              bottom: 2,
              child: Text(
                button.initials,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: onColorMuted),
              ),
            ),
          if (assignedCount > 1)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: Text(
                  '$assignedCount',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: cs.primaryForeground),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
