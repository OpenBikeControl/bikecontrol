import 'package:shadcn_flutter/shadcn_flutter.dart';

class WifiAnimation extends StatefulWidget {
  const WifiAnimation({super.key});

  @override
  State<WifiAnimation> createState() => _WifiAnimationState();
}

class _WifiAnimationState extends State<WifiAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<int> _index;

  final _animationIcons = [
    Icons.wifi_1_bar,
    Icons.wifi_2_bar,
    Icons.wifi,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _index = IntTween(begin: 0, end: _animationIcons.length - 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _index,
      builder: (_, __) {
        return Icon(
          _animationIcons[_index.value],
          color: Colors.gray,
        );
      },
    );
  }
}
