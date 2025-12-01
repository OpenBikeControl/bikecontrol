import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/widgets/ui/gradient_text.dart';

class ColoredTitle extends StatelessWidget {
  final String text;
  const ColoredTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return GradientText(text).bold;
  }
}
