import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// BikeControl's mark: the app icon's handlebar line-art (signal arcs, the
/// bar, the ± shifter), white in a small blue→teal disc. It leads the
/// "BikeControl" wordmark — the phone's large title on Ride and the desktop
/// sidebar's header — and nowhere else.
///
/// Decorative: the wordmark beside it already names the app, so the mark is
/// not announced.
class BkBrandMark extends StatelessWidget {
  const BkBrandMark({super.key, this.size = 34});

  /// The disc's diameter.
  final double size;

  /// The traced handlebar mark (white on transparent).
  static const String asset = 'assets/brand/bikecontrol_mark.svg';

  @override
  Widget build(BuildContext context) {
    // The app icon's own gradient in both themes: the mark is the icon.
    const brand = BkBrandColors.light;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [brand.bandStart, brand.bandEnd],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.15),
            child: SvgPicture.asset(
              asset,
              colorFilter: ColorFilter.mode(brand.onBand, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
