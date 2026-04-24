import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/controller/controller_contour_painter.dart';
import 'package:bike_control/widgets/controller/controller_layout.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

typedef ControllerButtonBuilder = Widget Function(ControllerButton button);

class ControllerCanvas extends StatelessWidget {
  final ControllerLayout layout;
  final List<ControllerButton> availableButtons;
  final ControllerButtonBuilder buttonBuilder;
  final double buttonSize;

  const ControllerCanvas({
    super.key,
    required this.layout,
    required this.availableButtons,
    required this.buttonBuilder,
    this.buttonSize = 56,
  });

  /// When a device sets `allowMultiple: true`, its `availableButtons` are
  /// cloned with a per-device `sourceDeviceId` set, which breaks `==` against
  /// the original `ControllerButton` stored in `layout.positions`. Match on
  /// the `name` field instead — unique within any one device's button set.
  Offset? _positionFor(ControllerButton btn) {
    for (final entry in layout.positions.entries) {
      if (entry.key.name == btn.name) return entry.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: 250),
      child: AspectRatio(
        aspectRatio: layout.aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: ControllerContourPainter(
                        shape: layout.shape,
                        color: cs.border,
                        // Subtle darkening via the muted foreground at low alpha
                        // — visually distinct from the solid `cs.muted` button
                        // fill, so the buttons don't blend into the background.
                        fillColor: cs.mutedForeground.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
                for (final btn in availableButtons)
                  if (_positionFor(btn) case final pos?)
                    Positioned(
                      left: (pos.dx * w) - buttonSize / 2,
                      top: (pos.dy * h) - buttonSize / 2,
                      child: buttonBuilder(btn),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
