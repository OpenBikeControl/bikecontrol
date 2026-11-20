import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A controller's tile in a device row: its own silhouette when it has one
/// (a Click V2 puck, a Play, a Ride), else the one controller glyph — in the
/// same 30 px tile as every other row, so the rows still line up.
class ControllerMark extends StatelessWidget {
  const ControllerMark({super.key, required this.device, this.live = true});

  final BaseDevice device;

  /// Brand ink while connected; muted while it is away or asleep.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = BkBrandColors.of(context);
    final ink = live ? brand.tileInk : cs.mutedForeground;
    final layout = device.controllerLayout;
    final svg = layout?.svgAsset;
    if (layout == null || svg == null) {
      return BkIconTile(icon: device.icon, color: ink);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: BkIconTile.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: live ? brand.tileWash : cs.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Transform.flip(
              flipX: layout.mirrorX,
              child: RotatedBox(
                quarterTurns: ((layout.rotation / 90).round() % 4 + 4) % 4,
                // Filled in the tile's ink: the art's own outlines and fills
                // are drawn for a hero, and at this size only the shape reads.
                child: ImageFiltered(
                  // The art is hairlines drawn for a 180 px hero; at 20 px they
                  // all but vanish. Thickened, the shape reads.
                  imageFilter: ImageFilter.dilate(radiusX: 0.3, radiusY: 0.3),
                  child: SvgPicture.asset(
                    svg,
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
