import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A controller's tile in a device row: its own silhouette when it has one
/// (a Click V2 puck, a Play, a Ride), else the one controller glyph — in the
/// same 30 px tile as every other row, so the rows still line up.
class ControllerMark extends StatelessWidget {
  const ControllerMark({super.key, required this.device, this.live = true, this.size = BkIconTile.size});

  final BaseDevice device;

  /// Brand ink while connected; muted while it is away or asleep.
  final bool live;

  /// The tile's edge. A device row draws it larger than the 30 px icon tiles
  /// so the silhouette has room to read; see [ChainLinkRow]'s leading slot.
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = BkBrandColors.of(context);
    final ink = live ? brand.tileInk : cs.mutedForeground;
    // Hairline art needs more contrast than a 16 px glyph to read at all.
    final lineInk = live ? brand.tileInk : cs.foreground.withValues(alpha: 0.62);
    final layout = device.controllerLayout;
    final svg = layout?.svgAsset;
    if (layout == null || svg == null) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: BkIconTile(icon: device.icon, color: ink),
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: live ? brand.tileWash : cs.muted,
            borderRadius: BorderRadius.circular(size * 0.27),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: Transform.flip(
              flipX: layout.mirrorX,
              child: RotatedBox(
                quarterTurns: ((layout.rotation / 90).round() % 4 + 4) % 4,
                // In the tile's ink, drawn as vectors at full resolution — a
                // thickening filter rasterised it and read as a blur.
                child: SvgPicture.asset(
                  svg,
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(lineInk, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
