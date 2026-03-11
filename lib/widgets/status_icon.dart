import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class StatusIcon extends StatelessWidget {
  final bool status;
  final bool started;
  final IconData icon;

  const StatusIcon({super.key, required this.status, required this.icon, required this.started});

  @override
  Widget build(BuildContext context) {
    final color = status ? const Color(0xFF22C55E) : Theme.of(context).colorScheme.mutedForeground;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.muted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: status ? null : Theme.of(context).colorScheme.mutedForeground,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: (started && !status) ? SmallProgressIndicator() : _dot(12, color),
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
