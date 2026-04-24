import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/widgets/controller/trigger_assignment_popup.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class AnimatedButtonWidget extends StatefulWidget {
  final ControllerButton button;
  final int pressGeneration;
  final Keymap? keymap;
  final BaseDevice? device;
  final VoidCallback? onUpdate;
  final double size;

  const AnimatedButtonWidget({
    super.key,
    required this.button,
    required this.pressGeneration,
    this.keymap,
    this.device,
    this.onUpdate,
    this.size = 56,
  });

  @override
  State<AnimatedButtonWidget> createState() => _AnimatedButtonWidgetState();
}

class _AnimatedButtonWidgetState extends State<AnimatedButtonWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void didUpdateWidget(covariant AnimatedButtonWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pressGeneration != oldWidget.pressGeneration && widget.pressGeneration != 0) {
      _ctrl.forward(from: 0.0).then((_) => _ctrl.reverse());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canOpenPopup => widget.keymap != null && widget.device != null && widget.onUpdate != null;

  Future<void> _onTap() async {
    if (!_canOpenPopup) return;
    await showTriggerAssignmentPopup(
      context: context,
      device: widget.device!,
      button: widget.button,
      keymap: widget.keymap!,
      onUpdate: widget.onUpdate!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.18).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
      child: ButtonWidget(button: widget.button, size: widget.size, keymap: widget.keymap),
    );
    if (!_canOpenPopup) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: child,
    );
  }
}
