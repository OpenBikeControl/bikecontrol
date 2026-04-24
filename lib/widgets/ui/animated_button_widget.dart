import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class AnimatedButtonWidget extends StatefulWidget {
  final ControllerButton button;
  final int pressGeneration;

  const AnimatedButtonWidget({super.key, required this.button, required this.pressGeneration});

  @override
  State<AnimatedButtonWidget> createState() => _AnimatedButtonWidgetState();
}

class _AnimatedButtonWidgetState extends State<AnimatedButtonWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(AnimatedButtonWidget old) {
    super.didUpdateWidget(old);
    if (widget.pressGeneration != old.pressGeneration && widget.pressGeneration > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: ButtonWidget(button: widget.button),
    );
  }
}
