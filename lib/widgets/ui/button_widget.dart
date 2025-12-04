import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/widgets/keymap_explanation.dart';
import 'package:swift_control/widgets/ui/colors.dart';

class ButtonWidget extends StatelessWidget {
  final ControllerButton button;
  final bool big;
  const ButtonWidget({super.key, required this.button, this.big = false});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        constraints: BoxConstraints(
          minWidth: big && button.color != null ? 40 : 30,
          minHeight: big && button.color != null ? 40 : 0,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: button.color != null ? Colors.black.getContrastColor(0.3) : Theme.of(context).colorScheme.primary,
          ),
          shape: button.color != null || button.icon != null ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: button.color != null || button.icon != null ? null : BorderRadius.circular(4),
          color: button.color ?? BKColor.main,
        ),
        child: Center(
          child: button.icon != null
              ? Icon(
                  button.icon,
                  color: Colors.white,
                  size: big && button.color != null ? null : 14,
                )
              : Text(
                  button.name.splitByUpperCase(),
                  style: TextStyle(
                    fontFamily: screenshotMode ? null : 'monospace',
                    fontSize: big && button.color != null ? 20 : 12,
                    fontWeight: button.color != null ? FontWeight.bold : null,
                    color: button.color != null ? Colors.white : Theme.of(context).colorScheme.foreground,
                  ),
                ),
        ),
      ),
    );
  }
}
