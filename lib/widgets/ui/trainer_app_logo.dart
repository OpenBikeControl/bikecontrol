import 'package:bike_control/widgets/ui/bk_grouped_section.dart' show BkIconTile;
import 'package:bike_control/widgets/ui/app_theme.dart' show BkBrandColors;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A trainer app's logo: the bundled [asset], falling back to [url] when the
/// asset can't be loaded.
///
/// The fallback exists for logos added after a build shipped: an over-the-air
/// patch can't add assets, so on older builds the asset is missing and the
/// logo is fetched from the website instead. With no [url], or when that
/// fails as well, an empty box of the same size keeps the layout steady.
class TrainerAppLogo extends StatelessWidget {
  const TrainerAppLogo({super.key, required this.asset, this.url, this.width, this.height, this.fit});

  final String asset;
  final String? url;
  final double? width;
  final double? height;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, _, _) {
        final url = this.url;
        if (url == null) return _empty;
        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, _, _) => _empty,
        );
      },
    );
  }

  Widget get _empty => SizedBox(width: width, height: height);
}

/// A trainer app without a bundled logo, as its initial ("Z" for Zwift) on a
/// tile — what the onboarding's app picker shows for it, instead of a generic
/// screen icon that says nothing about which app it is.
///
/// Styled like [BkIconTile], so it sits in a row of icon tiles; [size]
/// defaults to theirs.
class TrainerAppMonogram extends StatelessWidget {
  const TrainerAppMonogram({super.key, required this.name, this.size = BkIconTile.size, this.live = true});

  final String name;
  final double size;

  /// False greys it out, like an icon tile for something not set up.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = BkBrandColors.of(context);
    final initial = name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: live ? brand.tileWash : cs.muted,
          borderRadius: BorderRadius.circular(size * 8 / 30),
        ),
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w700,
            height: 1,
            color: live ? brand.tileInk : cs.mutedForeground,
          ),
        ),
      ),
    );
  }
}

/// A trainer app in a row of icon tiles: its bundled logo, else its initial
/// ([TrainerAppMonogram]). Shared by the home screen's trainer-app row and the
/// onboarding's checklist, so an app looks the same in both.
class TrainerAppMark extends StatelessWidget {
  const TrainerAppMark({super.key, required this.name, this.logoAsset, this.logoUrl});

  final String name;
  final String? logoAsset;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final logo = logoAsset;
    if (logo == null) return TrainerAppMonogram(name: name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TrainerAppLogo(asset: logo, url: logoUrl, width: BkIconTile.size, height: BkIconTile.size),
    );
  }
}
