import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_update_banner.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_group_label.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_note.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:shadcn_flutter/shadcn_flutter.dart';

const _success = Color(0xFF22C55E);

/// 10 padding + 40 logo + 9 gap + two xSmall caption lines + 10 padding, with
/// a little slack.
const _tileHeight = 108.0;

/// One app tile per the design: white card, logo (or monogram), dark caption,
/// blue 1.5px border + top-right blue check dot when selected. Public so the
/// grid-uniformity test can measure the rendered tiles.
class OnboardingAppTile extends StatelessWidget {
  const OnboardingAppTile({super.key, required this.app, required this.selected, required this.onTap});
  final SupportedApp app;
  final bool selected;
  final VoidCallback onTap;

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
            border: Border.all(color: selected ? onboardingAccent(context) : scheme.border, width: 1.5),
            borderRadius: BorderRadius.circular(12),
            color: scheme.card,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              height: 40,
              child: Center(
                child: app.logoAsset != null
                    ? Image.asset(app.logoAsset!, height: 36, fit: BoxFit.contain)
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
        if (selected)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: onboardingAccent(context)),
              child: Icon(LucideIcons.check, size: 11, color: onboardingOnAccent),
            ),
          ),
      ]),
    );
  }
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

Widget _verifiedBadge(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: _success.withValues(alpha: 0.12),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _success, letterSpacing: 0.6),
        child: Text(context.i18n.onboardingVerified.toUpperCase()).xSmall.semiBold,
      ),
    );

Widget onboardingAppBody(BuildContext context,
    {required SupportedApp? selected,
    required ValueChanged<SupportedApp> onSelect,
    bool showUpdateBanner = false}) {
  final official = SupportedApp.supportedApps.where((a) => a.officialIntegration).toList();
  final other = SupportedApp.supportedApps.where((a) => !a.officialIntegration).toList();

  Widget grid(List<SupportedApp> apps) => LayoutBuilder(builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 5 : 3;
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
              OnboardingAppTile(app: app, selected: selected?.name == app.name, onTap: () => onSelect(app)),
          ],
        );
      });

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: onboardingReveal([
      // Shown only when the welcome screen didn't already make the offer.
      if (showUpdateBanner) const OnboardingUpdateBanner(),
      Text(context.i18n.onboardingAppTitle).h4,
      Gap(6),
      Text(context.i18n.onboardingAppSubtitle).small.muted,
      Gap(18),
      OnboardingGroupLabel(context.i18n.officiallySupported, trailing: _verifiedBadge(context)),
      grid(official),
      Gap(18),
      OnboardingGroupLabel(context.i18n.otherTrainerApps),
      grid(other),
      Gap(14),
      OnboardingNote(context.i18n.onboardingAppNote),
    ]),
  );
}
