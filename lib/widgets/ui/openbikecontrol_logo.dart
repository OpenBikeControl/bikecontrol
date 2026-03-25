import 'package:bike_control/widgets/ui/colors.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class OpenBikeControlLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const OpenBikeControlLogo({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'openbikecontrol.png',
      width: size,
      height: size,
      color: color ?? BKColor.main,
    );
  }
}
