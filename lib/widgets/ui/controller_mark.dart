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
/// direct-drive trainer — the disc with its hub, the flywheel behind the
/// front leg, the A-frame — rather than Lucide's bicycle, which read as "a
/// bike" more than "the trainer". Outlined at the controller contours' line
/// weight and drawn bare like them; filled, it outweighed them.
class TrainerMark extends StatelessWidget {
  const TrainerMark({super.key, this.live = true, this.size = BkIconTile.defaultSize});

  /// The art, inline rather than an asset: a Shorebird patch can change
  /// Dart code but not assets, so this stays fixable after release.
  /// 64-unit box, 1.8-unit round strokes; the flywheel's outline stops
  /// where the front leg passes in front of it.
  static const String svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <g fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
    <path d="M29.74 35.48A8.0 8.0 0 1 1 21.20 48.51"/>
    <circle cx="27.0" cy="43.0" r="2.6"/>
    <circle cx="38.0" cy="19.0" r="13.5"/>
    <circle cx="38.0" cy="19.0" r="4"/>
    <path d="M29.69 29.64L13.0 55.0"/>
    <path d="M43.49 31.33L51.0 55.0"/>
    <path d="M7.0 57.5H19.0M45.0 57.5H57.0"/>
  </g>
</svg>''';

  /// The same drawing for icon sizes (under [smallBelow]): strokes heavy
  /// enough to survive 16 px, the hubs as dots rather than rings.
  static const String svgSmall = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <g fill="none" stroke="#000" stroke-width="4.2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M30.82 35.97A8.0 8.0 0 1 1 22.07 49.30"/>
    <circle cx="27.0" cy="43.0" r="2.2" fill="#000" stroke="none"/>
    <circle cx="38.0" cy="19.0" r="13.5"/>
    <circle cx="38.0" cy="19.0" r="3.4" fill="#000" stroke="none"/>
    <path d="M29.69 29.64L13.0 55.0"/>
    <path d="M43.49 31.33L51.0 55.0"/>
    <path d="M7.0 57.5H19.0M45.0 57.5H57.0"/>
  </g>
</svg>''';

  /// Edges under this draw [svgSmall].
  static const double smallBelow = 26;

  /// Brand ink while it is connected and bridged; muted otherwise.
  final bool live;

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = BkBrandColors.of(context);
    // The controllers' contour inks, so the marks in one list match.
    return TrainerGlyph(size: size, color: live ? brand.tileInk : cs.foreground.withValues(alpha: 0.62));
  }
}

/// The smart trainer's drawing used like an [Icon]: anywhere the app means
/// "the trainer" — the header chip, onboarding, a lost-trainer card — and
/// not "riding" (the Ride tab, a bike's weight), which keeps Lucide's bike.
/// Size and colour come from the surrounding [IconTheme] unless given.
class TrainerGlyph extends StatelessWidget {
  const TrainerGlyph({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final edge = size ?? theme.size ?? 24;
    final ink = color ?? theme.color ?? Theme.of(context).colorScheme.foreground;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: edge,
        child: SvgPicture.string(
          edge < TrainerMark.smallBelow ? TrainerMark.svgSmall : TrainerMark.svg,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
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
