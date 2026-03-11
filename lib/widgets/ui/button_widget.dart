import 'package:bike_control/main.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/keymap_explanation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ButtonWidget extends StatelessWidget {
  final ControllerButton button;
  final bool big;
  final double? size;
  final Color? color;

  const ButtonWidget({super.key, required this.button, this.big = false, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        constraints: BoxConstraints(
          minWidth: size ?? (big && button.color != null ? 40 : 30),
          minHeight: size ?? (big && button.color != null ? 40 : 0),
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                color ??
                (button.color != null ? Colors.black.getContrastColor(0.3) : Theme.of(context).colorScheme.primary),
          ),
          shape: button.color != null || button.icon != null ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: button.color != null || button.icon != null ? null : BorderRadius.circular(8),
          color: color?.withLuminance(0.9) ?? button.color ?? Colors.black,
        ),
        child: Center(
          child: button.icon != null
              ? Icon(
                  button.icon,
                  color: color ?? Colors.white,
                  size: size ?? (big && button.color != null ? null : 14),
                )
              : Text(
                  button.displayName.splitByUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: screenshotMode ? null : 'monospace',
                    fontSize: big && button.color != null ? 20 : 12,
                    fontWeight: button.color != null ? FontWeight.bold : null,
                    color: color?.getContrastColor(0.3) ?? Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
