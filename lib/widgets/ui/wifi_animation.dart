import 'package:shadcn_flutter/shadcn_flutter.dart';

class SmoothWifiAnimation extends StatefulWidget {
  const SmoothWifiAnimation({super.key});

  @override
  State<SmoothWifiAnimation> createState() => _SmoothWifiAnimationState();
}

class _SmoothWifiAnimationState extends State<SmoothWifiAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final _animationIcons = [
    Icons.wifi_1_bar,
    Icons.wifi_2_bar,
    Icons.wifi,
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
          duration: const Duration(milliseconds: 600),
          vsync: this,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _controller.reverse();
          } else if (status == AnimationStatus.dismissed) {
            _currentIndex = (_currentIndex + 1) % _animationIcons.length;
            setState(() {});
            _controller.forward();
          }
        });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: Icon(
        _animationIcons[_currentIndex],
        color: Colors.gray,
        key: ValueKey(_currentIndex),
        size: 26,
      ),
    );
  }
}
