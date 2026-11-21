import 'dart:async';
import 'dart:math' as math;

import 'package:bike_control/main.dart' show screenshotMotionPinned;
import 'package:bike_control/utils/reduced_motion.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_headline.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_viewport.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_update_banner.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_group_label.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
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
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? onboardingAccent(context) : const Color(0x00000000), width: 2),
              borderRadius: BorderRadius.circular(16),
              color: scheme.card,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
              ],
            ),
          ),
          if (showOfficialBadge) Positioned(top: 5, right: 5, child: const _OfficialBadge()),
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
        ],
      ),
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
            child: Center(
              child: OpenBikeControlLogo(size: size * 0.48, color: onboardingOnAccent(context)),
            ),
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
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const _OfficialBadge(size: 18),
      Gap(5),
      Text(context.i18n.officiallySupported).xSmall.muted,
    ],
  ),
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
    (a is OpenBikeControlTrainerApp && a.name == 'icTrainer') ||
    a is TrainingPeaks ||
    a is Biketerra ||
    a is Rouvy ||
    a is Tacx ||
    a is FulGaz;

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

    Widget grid(List<SupportedApp> apps, {bool badgeOfficial = false}) => LayoutBuilder(
      builder: (context, constraints) {
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
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingGroupLabel(context.i18n.onboardingBigPlatforms, trailing: _officialLegend(context)),
        grid(big, badgeOfficial: true),
        Gap(18),
        OnboardingGroupLabel(
          context.i18n.officiallySupported,
          leading: const _OfficialBadge(size: 18),
          trailing: _verifiedBadge(context),
        ),
        grid(official),
        Gap(18),
        OnboardingGroupLabel(context.i18n.otherTrainerApps),
        grid(other),
      ],
    );
  }
}

/// Step 1: which app, and — where there is a choice — whether it runs on this
/// device or another one.
///
/// Picking an app folds the grid away: the chosen tile grows into the middle of
/// the screen, with a "Change app" button to bring the grid back, and the "runs
/// on" choice sits right under it — the one question left on this step.
Widget onboardingAppBody(
  BuildContext context, {
  required SupportedApp? selected,
  required ValueChanged<SupportedApp> onSelect,
  bool showUpdateBanner = false,
  List<Target> targets = const [],
  Target? selectedTarget,
  ValueChanged<Target>? onSelectTarget,
}) {
  return _AppStepBody(
    selected: selected,
    onSelect: onSelect,
    showUpdateBanner: showUpdateBanner,
    targets: targets,
    selectedTarget: selectedTarget,
    onSelectTarget: onSelectTarget,
  );
}

class _AppStepBody extends StatefulWidget {
  const _AppStepBody({
    required this.selected,
    required this.onSelect,
    required this.showUpdateBanner,
    required this.targets,
    required this.selectedTarget,
    required this.onSelectTarget,
  });

  final SupportedApp? selected;
  final ValueChanged<SupportedApp> onSelect;
  final bool showUpdateBanner;
  final List<Target> targets;
  final Target? selectedTarget;
  final ValueChanged<Target>? onSelectTarget;

  @override
  State<_AppStepBody> createState() => _AppStepBodyState();
}

class _AppStepBodyState extends State<_AppStepBody> {
  /// Starts on the grid even when an app is already chosen (a re-run from the
  /// menu): someone re-running setup most likely came to change it. Only a tap
  /// in the grid folds it into the spotlight.
  bool _spotlight = false;

  /// Whether the content sits centred in the space under the headline. Stays
  /// on for the length of the morph after "Change app", so the growing grid
  /// glides up from the middle instead of jumping to the top first.
  bool _centered = false;
  Timer? _uncenter;

  static const _morph = Duration(milliseconds: 480);

  @override
  void dispose() {
    _uncenter?.cancel();
    super.dispose();
  }

  void _change() {
    setState(() => _spotlight = false);
    _uncenter?.cancel();
    _uncenter = Timer(_morph, () {
      if (mounted && !_spotlight) setState(() => _centered = false);
    });
  }

  bool get _showSpotlight => _spotlight && widget.selected != null;

  void _select(SupportedApp app) {
    widget.onSelect(app);
    _uncenter?.cancel();
    setState(() {
      _spotlight = true;
      _centered = true;
    });
    // The rider may have scrolled down to "Other trainer apps"; the spotlight
    // is short and sits in the first screen.
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || position.pixels <= position.minScrollExtent) return;
    if (prefersReducedMotion(context)) {
      position.jumpTo(position.minScrollExtent);
    } else {
      position.animateTo(position.minScrollExtent, duration: _morph, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final still = screenshotMotionPinned || prefersReducedMotion(context);
    final selected = widget.selected;
    final content = _showSpotlight
        ? _SelectedAppSpotlight(
            key: ValueKey('onboarding-app-spotlight-${selected!.name}'),
            app: selected,
            still: still,
            onChange: _change,
            targets: widget.targets,
            selectedTarget: widget.selectedTarget,
            onSelectTarget: widget.onSelectTarget,
          )
        : Column(
            key: const ValueKey('onboarding-app-grid'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrainerAppGrid(selected: selected, onSelect: _select),
              // Back on the grid after "Change app": the choice stays reachable
              // here too, so going back and forth never hides it.
              if (selected != null && widget.targets.length > 1 && widget.onSelectTarget != null) ...[
                Gap(20),
                OnboardingGroupLabel(context.i18n.onboardingRunsOn(selected.name)),
                OnboardingTargetChoice(
                  targets: widget.targets,
                  selected: widget.selectedTarget,
                  onSelect: widget.onSelectTarget!,
                ),
              ],
            ],
          );

    final revealed = onboardingReveal([
      // Shown only when the welcome screen didn't already make the offer.
      if (widget.showUpdateBanner) const OnboardingUpdateBanner(),
      OnboardingHeadline(context.i18n.onboardingAppTitle),
      Gap(18),
      if (still)
        content
      else
        AnimatedSize(
          duration: _morph,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: _morph,
            reverseDuration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            // Old and new stacked from the top, so the grid fades out where
            // it stood while the spotlight grows in over it.
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
            child: content,
          ),
        ),
    ]);

    // Centred in what is left of the screen under the headline: the space
    // above and below the content splits evenly (spaceBetween over header,
    // content and an empty end). Content taller than the screen just stacks.
    final viewport = OnboardingViewport.bodyHeightOf(context);
    final centered = _centered && widget.selected != null && viewport != null;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: centered ? viewport : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: revealed.sublist(0, revealed.length - 1),
          ),
          revealed.last,
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// The chosen app, enlarged and centred, with a way back to the grid and the
/// "runs on" choice under it.
class _SelectedAppSpotlight extends StatelessWidget {
  const _SelectedAppSpotlight({
    super.key,
    required this.app,
    required this.still,
    required this.onChange,
    required this.targets,
    required this.selectedTarget,
    required this.onSelectTarget,
  });

  final SupportedApp app;
  final bool still;
  final VoidCallback onChange;
  final List<Target> targets;
  final Target? selectedTarget;
  final ValueChanged<Target>? onSelectTarget;

  /// Plays [builder] from 0 to 1 once, after [delay] — or sits at 1 when
  /// motion is off.
  Widget _entrance({
    required Duration delay,
    required Duration duration,
    required Curve curve,
    required Widget Function(double t, Widget child) builder,
    required Widget child,
  }) {
    if (still) return builder(1, child);
    final total = delay + duration;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: curve),
      builder: (context, t, child) => builder(t, child!),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = onboardingAccent(context);
    final hasChoice = targets.length > 1 && onSelectTarget != null;

    final logo = app.logoAsset != null
        ? TrainerAppLogo(asset: app.logoAsset!, url: app.logoUrl, height: 72, fit: BoxFit.contain)
        : Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: scheme.muted),
            child: Text(app.name.substring(0, 1).toUpperCase(), style: context.typography.h3).muted,
          );

    final card = Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent, width: 2),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 32, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 80,
            child: Center(
              child: _entrance(
                delay: const Duration(milliseconds: 120),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutBack,
                builder: (t, child) => Transform.scale(scale: 0.6 + 0.4 * t, child: child),
                child: logo,
              ),
            ),
          ),
          Gap(14),
          Text(
            app.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.typography.large.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(6),
        Center(
          child: _entrance(
            delay: Duration.zero,
            duration: const Duration(milliseconds: 560),
            curve: Curves.easeOutBack,
            builder: (t, child) => Transform.scale(scale: 0.82 + 0.18 * t, child: child),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                if (app.officialIntegration) const Positioned(top: 10, left: 10, child: _OfficialBadge(size: 32)),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _entrance(
                    delay: const Duration(milliseconds: 280),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    builder: (t, child) => Transform.scale(scale: t, child: child),
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                      child: Icon(LucideIcons.check, size: 15, color: onboardingOnAccent(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Gap(10),
        Center(
          child: Button.ghost(
            key: const ValueKey('onboarding-change-app'),
            onPressed: onChange,
            leading: const Icon(LucideIcons.arrowLeftRight, size: 15),
            child: Text(context.i18n.onboardingChangeApp).small,
          ),
        ),
        if (hasChoice) ...[
          Gap(22),
          _entrance(
            delay: const Duration(milliseconds: 220),
            duration: const Duration(milliseconds: 480),
            curve: Curves.easeOutCubic,
            builder: (t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.i18n.onboardingRunsOn(app.name),
                  textAlign: TextAlign.center,
                  style: context.typography.h4,
                ),
                Gap(14),
                OnboardingTargetChoice(
                  targets: targets,
                  selected: selectedTarget,
                  onSelect: onSelectTarget!,
                  large: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "This device | Other device" as one segmented control.
class OnboardingTargetChoice extends StatelessWidget {
  const OnboardingTargetChoice({
    super.key,
    required this.targets,
    required this.selected,
    required this.onSelect,
    this.large = false,
  });

  final List<Target> targets;
  final Target? selected;
  final ValueChanged<Target> onSelect;

  /// The spotlight's version: taller segments and bigger icons, as the one
  /// question left on the step.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final t in targets)
            Expanded(
              child: Button.ghost(
                key: ValueKey('onboarding-where-${t.name}'),
                style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
                onPressed: () => onSelect(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(vertical: large ? 18 : 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: t == selected ? onboardingAccent(context) : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        t.icon,
                        size: large ? 22 : 17,
                        color: t == selected ? onboardingOnAccent(context) : cs.mutedForeground,
                      ),
                      Gap(8),
                      Flexible(
                        child: Text(
                          t.getTitle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (large ? context.typography.base : context.typography.small).copyWith(
                            fontWeight: FontWeight.w600,
                            color: t == selected ? onboardingOnAccent(context) : cs.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
