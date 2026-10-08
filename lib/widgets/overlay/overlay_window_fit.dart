import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Keeps the desktop overlay window as wide as its content: reports the size
/// [TrainerOverlayView.fitWindowSizeOf] asks for whenever it changes — when a
/// field is turned on or off, the mode flips, or the text size changes; never
/// for the values alone.
class OverlayWindowFit extends StatefulWidget {
  const OverlayWindowFit({super.key, required this.state, required this.onSize, required this.child});

  final ValueListenable<TrainerOverlayState> state;

  /// Called after the frame with the new size; resize the window here.
  final ValueChanged<Size> onSize;
  final Widget child;

  @override
  State<OverlayWindowFit> createState() => _OverlayWindowFitState();
}

class _OverlayWindowFitState extends State<OverlayWindowFit> {
  Size? _reported;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TrainerOverlayState>(
      valueListenable: widget.state,
      builder: (context, s, child) {
        final size = TrainerOverlayView.fitWindowSizeOf(context, s);
        if (size != _reported) {
          _reported = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _reported == size) widget.onSize(size);
          });
        }
        return child!;
      },
      child: widget.child,
    );
  }
}
