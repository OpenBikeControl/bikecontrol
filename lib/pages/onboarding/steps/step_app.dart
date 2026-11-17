import 'dart:math' as math;

import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_headline.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_update_banner.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_group_label.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_note.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:bike_control/widgets/ui/trainer_app_logo.dart';
import 'package:bike_control/widgets/ui/openbikecontrol_logo.dart';
import 'package:bike_control/utils/keymap/apps/biketerra.dart';
import 'package:bike_control/utils/keymap/apps/fulgaz.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol_trainer_apps.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/tacx.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';


/// 10 padding + 40 logo + 9 gap + two xSmall caption lines + 10 padding, with
/// a little slack.
const _tileHeight = 108.0;

/// One app tile per the design: white card, logo (or monogram), dark caption,
/// blue 1.5px border + top-right blue check dot when selected. Public so the
/// grid-uniformity test can measure the rendered tiles. [showOfficialBadge]
/// puts the OpenBikeControl mark in the top-left corner, for official apps
/// shown outside the "Officially supported" group.
class OnboardingAppTile extends StatelessWidget {
  const OnboardingAppTile({
    super.key,
    required this.app,
    required this.selected,
    required this.onTap,
    this.showOfficialBadge = false,
  });
  final SupportedApp app;
  final bool selected;
  final VoidCallback onTap;
  final bool showOfficialBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Button.ghost(
      style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
      onPressed: onTap,
      child: Stack(children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? onboardingAccent(context) : const Color(0x00000000), width: 2),
            borderRadius: BorderRadius.circular(16),
            color: scheme.card,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              height: 40,
              // Wide logos (icTrainer) stay clear of the corner seal.
              padding: EdgeInsets.symmetric(horizontal: showOfficialBadge ? 20 : 0),
              child: Center(
                child: app.logoAsset != null
                    ? TrainerAppLogo(asset: app.logoAsset!, url: app.logoUrl, height: 36, fit: BoxFit.contain)
                    : Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: scheme.muted,
                        ),
                        child: Text(app.name.substring(0, 1).toUpperCase()).semiBold.muted,
                      ),
              ),
            ),
            Gap(9),
            _TileCaption(app.name),
          ]),
        ),
        if (showOfficialBadge)
          Positioned(top: 5, right: 5, child: const _OfficialBadge()),
        if (selected)
          Positioned(
            // The seal holds the top-right corner; the check takes the other.
            top: 7,
            left: showOfficialBadge ? 7 : null,
            right: showOfficialBadge ? null : 7,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: onboardingAccent(context)),
              child: Icon(LucideIcons.check, size: 11, color: onboardingOnAccent(context)),
            ),
          ),
      ]),
    );
  }
}

/// The OpenBikeControl mark in an accent-washed circle: "this app is an
/// official BikeControl integration".
class _OfficialBadge extends StatelessWidget {
  const _OfficialBadge({this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = onboardingAccent(context);
    return Tooltip(
      tooltip: (context) => TooltipContainer(child: Text(context.i18n.onboardingOfficialBadge)),
      child: Semantics(
        label: context.i18n.onboardingOfficialBadge,
        child: CustomPaint(
          size: Size.square(size),
          painter: _SealPainter(accent),
          child: SizedBox.square(
            dimension: size,
            child: Center(child: OpenBikeControlLogo(size: size * 0.48, color: onboardingOnAccent(context))),
          ),
        ),
      ),
    );
  }
}

/// A zig-zag edged seal, like a "certified" rosette: [_points] teeth around a
/// circle, with a thin inner ring.
class _SealPainter extends CustomPainter {
  const _SealPainter(this.color);

  final Color color;
  static const _points = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.84;
    final path = Path();
    for (var i = 0; i < _points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / _points;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(
      c,
      outer * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.color != color;
}

/// A tile's app name: up to two lines, broken only between words. A single
/// word wider than the tile ("TrainingPeaks" in a 110 px tile) is not cut in
/// two: the name is laid out as wide as that word and scaled down to fit.
class _TileCaption extends StatelessWidget {
  const _TileCaption(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: _AtLeastWidestWord(
          width: constraints.maxWidth,
          child: Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis).xSmall.semiBold,
        ),
      ),
    );
  }
}

/// Lays its text child out at [width], or at the width of the child's widest
/// word if that is more — a paragraph's min intrinsic width is exactly that.
/// Done at layout rather than in build, so a font arriving late (or a system
/// font change) re-measures it.
class _AtLeastWidestWord extends SingleChildRenderObjectWidget {
  const _AtLeastWidestWord({required this.width, required super.child});

  final double width;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAtLeastWidestWord(width);

  @override
  void updateRenderObject(BuildContext context, _RenderAtLeastWidestWord renderObject) {
    renderObject.width = width;
  }
}

class _RenderAtLeastWidestWord extends RenderProxyBox {
  _RenderAtLeastWidestWord(this._width);

  double _width;
  set width(double value) {
    if (value == _width) return;
    _width = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    final widestWord = child.getMinIntrinsicWidth(double.infinity);
    final width = _width.isFinite ? (widestWord > _width ? widestWord : _width) : widestWord;
    child.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}

/// Explains the tile badge next to the "Big platforms" label.
Widget _officialLegend(BuildContext context) => ExcludeSemantics(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const _OfficialBadge(size: 18),
        Gap(5),
        Text(context.i18n.officiallySupported).xSmall.muted,
      ]),
    );

Widget _verifiedBadge(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: BkStatusColors.of(context).successWash,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: BkStatusColors.of(context).success, letterSpacing: 0.6),
        child: Text(context.i18n.onboardingVerified.toUpperCase()).xSmall.semiBold,
      ),
    );

/// The big platforms shown in the "Big platforms" group.
bool _isBigPlatform(SupportedApp a) =>
    a is MyWhoosh ||
    a is Zwift ||
    (a is OpenBikeControlTrainerApp && a.name == 'icTrainer') || a is TrainingPeaks || a is Biketerra || a is Rouvy || a is Tacx || a is FulGaz;

/// Every supported trainer app as a grid of tiles: the big platforms first
/// (official ones marked with the OpenBikeControl badge), then the other
/// official integrations under their verified badge, then the rest. Onboarding's app step
/// shows it, and so does the trainer-app picker in Connection settings.
class TrainerAppGrid extends StatelessWidget {
  const TrainerAppGrid({super.key, required this.selected, required this.onSelect});

  final SupportedApp? selected;
  final ValueChanged<SupportedApp> onSelect;

  @override
  Widget build(BuildContext context) {
    // Official integrations first, so the seals line up on the first row.
    final bigApps = SupportedApp.supportedApps.where(_isBigPlatform);
    final big = [...bigApps.where((a) => a.officialIntegration), ...bigApps.where((a) => !a.officialIntegration)];
    final rest = SupportedApp.supportedApps.where((a) => !_isBigPlatform(a));
    final official = rest.where((a) => a.officialIntegration).toList();
    final other = rest.where((a) => !a.officialIntegration).toList();

    Widget grid(List<SupportedApp> apps, {bool badgeOfficial = false}) => LayoutBuilder(builder: (context, constraints) {
          final cols = constraints.maxWidth >= Breakpoints.onboardingAppGridWide ? 5 : 3;
          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Fixed tile height: the content (padding, logo, gap, two caption
            // lines) doesn't shrink with the column width, so an aspect ratio
            // would let two-line captions spill out of narrow tiles.
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: _tileHeight,
            ),
            children: [
              for (final app in apps)
                OnboardingAppTile(
                  app: app,
                  selected: selected?.name == app.name,
                  onTap: () => onSelect(app),
                  showOfficialBadge: badgeOfficial && app.officialIntegration,
                ),
            ],
          );
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingGroupLabel(context.i18n.onboardingBigPlatforms, trailing: _officialLegend(context)),
        grid(big, badgeOfficial: true),
        Gap(18),
        OnboardingGroupLabel(context.i18n.officiallySupported, leading: const _OfficialBadge(size: 18), trailing: _verifiedBadge(context)),
        grid(official),
        Gap(18),
        OnboardingGroupLabel(context.i18n.otherTrainerApps),
        grid(other),
      ],
    );
  }
}

Widget onboardingAppBody(BuildContext context,
    {required SupportedApp? selected,
    required ValueChanged<SupportedApp> onSelect,
    bool showUpdateBanner = false}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: onboardingReveal([
      // Shown only when the welcome screen didn't already make the offer.
      if (showUpdateBanner) const OnboardingUpdateBanner(),
      OnboardingHeadline(context.i18n.onboardingAppTitle),
      Gap(6),
      Text(context.i18n.onboardingAppSubtitle).small.muted,
      Gap(18),
      TrainerAppGrid(selected: selected, onSelect: onSelect),
      Gap(14),
      OnboardingNote(context.i18n.onboardingAppNote),
    ]),
  );
}
