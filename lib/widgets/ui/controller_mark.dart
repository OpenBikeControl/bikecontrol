import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The edge of every mark in the device lists — a controller's silhouette,
/// the trainer, an accessory's or an app's tile alike — so the rows match.
/// Larger than the 30 px icon tiles elsewhere: a silhouette needs the room.
const double deviceMarkSize = 40;

/// A controller's mark: its own silhouette when it has one (a Click V2 puck,
/// a Play, a Ride), drawn bare, else the one controller glyph in a tile.
class ControllerMark extends StatelessWidget {
  const ControllerMark({super.key, required this.device, this.live = true, this.size = BkIconTile.defaultSize});

  final BaseDevice device;

  /// Brand ink while connected; muted while it is away or asleep.
  final bool live;

  /// The mark's edge; [deviceMarkSize] in the device lists.
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = BkBrandColors.of(context);
    final layout = device.controllerLayout;
    final svg = layout?.svgAsset;
    if (layout == null || svg == null) {
      return BkIconTile(icon: device.icon, color: live ? brand.tileInk : cs.mutedForeground, size: size);
    }
    final ink = live ? brand.tileInk : cs.foreground.withValues(alpha: 0.62);
    // Bare: the silhouette is the shape, a tile behind it only a second one.
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Transform.flip(
          flipX: layout.mirrorX,
          child: RotatedBox(
            quarterTurns: ((layout.rotation / 90).round() % 4 + 4) % 4,
            // Drawn as vectors at full resolution — a thickening filter
            // rasterised it and read as a blur.
            child: SvgPicture.asset(svg, fit: BoxFit.contain, colorFilter: _solidInk(ink)),
          ),
        ),
      ),
    );
  }
}

/// The smart trainer's mark in a device row and the setup banner: a drawn
/// direct-drive trainer — a solid disc with its hub, the flywheel, the
/// A-frame — rather than Lucide's bicycle, which read as "a bike" more than
/// "the trainer". Drawn bare, like the controllers' silhouettes.
class TrainerMark extends StatelessWidget {
  const TrainerMark({super.key, this.live = true, this.size = BkIconTile.defaultSize});

  /// The art, inline rather than an asset: a Shorebird patch can change
  /// Dart code but not assets, so this stays fixable after release.
  /// 64-unit box: the disc (with the hub cut out) and the flywheel filled,
  /// the legs and feet as round strokes.
  static const String svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <g fill="#000" fill-rule="evenodd">
    <path d="M38 5a14 14 0 1 0 0.01 0Z M38 15.5a3.5 3.5 0 1 1 -0.01 0Z"/>
    <circle cx="24" cy="42" r="8"/>
  </g>
  <g fill="none" stroke="#000" stroke-width="4.5" stroke-linecap="round">
    <path d="M30 30L13 54"/>
    <path d="M44 32L51 54"/>
    <path d="M6 57.5H19M45 57.5H58"/>
  </g>
</svg>''';

  /// Brand ink while it is connected and bridged; muted otherwise.
  final bool live;

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = BkBrandColors.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: SvgPicture.string(
          svg,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(live ? brand.tileInk : cs.mutedForeground, BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// Paints every drawn pixel in [ink], its coverage boosted: the contour art
/// is hairlines, partly translucent, drawn for a 180 px hero, and at 40 px a
/// plain tint left them barely there. Per pixel at full resolution, so the
/// lines stay sharp (a thickening layer filter rasterised them into a blur).
ColorFilter _solidInk(Color ink) {
  const boost = 2.6;
  return ColorFilter.matrix([
    0, 0, 0, 0, ink.r * 255, //
    0, 0, 0, 0, ink.g * 255,
    0, 0, 0, 0, ink.b * 255,
    0, 0, 0, boost * ink.a, 0,
  ]);
}
