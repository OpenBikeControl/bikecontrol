import 'package:shadcn_flutter/shadcn_flutter.dart';

class SmallProgressIndicator extends StatelessWidget {
  final Color? color;

  const SmallProgressIndicator({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: color,
        size: 12,
        strokeWidth: 2,
      ),
    );
  }
}
