import 'package:bike_control/widgets/ui/openbikecontrol_logo.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class StatusIcon extends StatelessWidget {
  final bool status;
  final bool started;
  final IconData? icon;
  final VoidCallback? onPressed;

  const StatusIcon({super.key, required this.status, required this.icon, required this.started, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = status ? const Color(0xFF22C55E) : Theme.of(context).colorScheme.mutedForeground;
    return Stack(
      children: [
        if (onPressed == null)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: icon != null
                ? Icon(
                    icon,
                    size: 20,
                    color: status ? null : Theme.of(context).colorScheme.mutedForeground,
                  )
                : Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: OpenBikeControlLogo(
                      size: 20,
                      color: status ? null : Theme.of(context).colorScheme.mutedForeground,
                    ),
                  ),
          )
        else
          Button(
            style: ButtonStyle.fixedIcon(),
            onPressed: onPressed,
            child: Icon(
              icon,
              size: 20,
              color: status ? null : Theme.of(context).colorScheme.mutedForeground,
            ),
          ),
        Positioned(
          right: 0,
          top: 0,
          child: (started && !status) ? RepaintBoundary(child: SmallProgressIndicator()) : _dot(12, color),
        ),
      ],
    );
  }

  Widget _dot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
