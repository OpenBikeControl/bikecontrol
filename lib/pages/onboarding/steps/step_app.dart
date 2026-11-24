import 'dart:math' as math;

import 'package:bike_control/main.dart' show recordError, screenshotMotionPinned;
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
import 'package:bike_control/utils/keymap/apps/smart_trainer_apps.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';
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
/// puts the official seal in the top-left corner, for official apps shown
/// outside the "Officially supported" group.
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
          if (showOfficialBadge) Positioned(top: 5, left: 5, child: const _OfficialBadge()),
          if (selected)
            Positioned(
              top: 7,
              right: 7,
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

/// The OpenBikeControl mark on a white seal with a black outline: "this app is
/// an official BikeControl integration". Same colours in light and dark mode.
class _OfficialBadge extends StatelessWidget {
  const _OfficialBadge({this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      tooltip: (context) => TooltipContainer(child: Text(context.i18n.onboardingOfficialBadge)),
      child: Semantics(
        label: context.i18n.onboardingOfficialBadge,
        child: CustomPaint(
          size: Size.square(size),
          painter: const _SealPainter(),
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: OpenBikeControlLogo(size: size * 0.48, color: _SealPainter.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// A zig-zag edged seal, like a "certified" rosette: [_points] teeth around a
/// circle, with a thin inner ring. White inside, outlined in [ink].
class _SealPainter extends CustomPainter {
  const _SealPainter();

  static const ink = Color(0xFF000000);
  static const _fill = Color(0xFFFFFFFF);
  static const _points = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // Inset by half the outline, so the stroke stays inside the box.
    final stroke = (size.shortestSide / 28).clamp(0.8, 1.4);
    final outer = size.shortestSide / 2 - stroke / 2;
    final inner = outer * 0.84;
    final path = Path();
    for (var i = 0; i < _points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / _points;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke
        ..color = ink,
    );
    canvas.drawCircle(
      c,
      outer * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.6
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) => false;
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
  const TrainerAppGrid({super.key, required this.selected, required this.onSelect, this.hidden});

  final SupportedApp? selected;
  final ValueChanged<SupportedApp> onSelect;

  /// Leaves this app's cell empty — onboarding flies the tile in or out of it.
  final SupportedApp? hidden;

  @override
  Widget build(BuildContext context) {
    // Official integrations first, so the seals line up on the first row.
    final bigApps = SupportedApp.supportedApps.where(_isBigPlatform);
    final big = [...bigApps.where((a) => a.officialIntegration), ...bigApps.where((a) => !a.officialIntegration)];
    final rest = SupportedApp.supportedApps.where((a) => !_isBigPlatform(a));
    // Apps with a rider deal (Grimpa) lead the group.
    final officialRest = rest.where((a) => a.officialIntegration);
    final official = [
      ...officialRest.where((a) => riderDealFor(a) != null),
      ...officialRest.where((a) => riderDealFor(a) == null),
    ];
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
              Opacity(
                opacity: hidden?.name == app.name ? 0 : 1,
                child: OnboardingAppTile(
                  app: app,
                  selected: selected?.name == app.name,
                  onTap: () => onSelect(app),
                  showOfficialBadge: badgeOfficial && app.officialIntegration,
                ),
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

class _AppStepBodyState extends State<_AppStepBody> with SingleTickerProviderStateMixin {
  /// Starts on the grid even when an app is already chosen (a re-run from the
  /// menu): someone re-running setup most likely came to change it. Only a tap
  /// in the grid folds it into the spotlight.
  bool _spotlight = false;

  /// While a tile is in flight, its landing spot stays empty: the spotlight's
  /// card on the way in, the grid tile on the way back.
  bool _cardHidden = false;
  SupportedApp? _hiddenTile;

  final _gridKey = GlobalKey();
  final _cardKey = GlobalKey();
  late final AnimationController _flight = AnimationController(vsync: this, duration: _flightDuration);
  OverlayEntry? _flightEntry;

  static const _flightDuration = Duration(milliseconds: 364);

  bool get _showSpotlight => _spotlight && widget.selected != null;
  bool get _still => screenshotMotionPinned || prefersReducedMotion(context);

  @override
  void dispose() {
    _flightEntry?.remove();
    _flight.dispose();
    super.dispose();
  }

  static Rect? _globalRect(BuildContext? context) {
    final box = context?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Rect? _tileRect(SupportedApp app) {
    Rect? found;
    void visit(Element e) {
      if (found != null) return;
      final w = e.widget;
      if (w is OnboardingAppTile && w.app.name == app.name) {
        found = _globalRect(e);
        return;
      }
      e.visitChildren(visit);
    }

    _gridKey.currentContext?.visitChildElements(visit);
    return found;
  }

  void _scrollToTop() {
    final position = Scrollable.maybeOf(context)?.position;
    if (position != null && position.pixels > position.minScrollExtent) position.jumpTo(position.minScrollExtent);
  }

  /// Flies [app]'s tile from [from] to wherever [to] resolves after the next
  /// frame, morphing from grid tile (0) to spotlight card (1) or back, with
  /// [fading] (the grid as it stood) fading out underneath.
  void _fly({
    required SupportedApp app,
    required Rect from,
    required Rect? Function() to,
    required bool growing,
    Widget? fading,
    Rect? fadingRect,
    required VoidCallback onLanded,
  }) {
    final overlay = Overlay.maybeOf(context);
    // The visible part of the step: the flight and the fading grid stay
    // inside it instead of drawing over the header and footer.
    final clip = _globalRect(Scrollable.maybeOf(context)?.context);
    final overlayBox = overlay?.context.findRenderObject();
    if (overlay == null || overlayBox is! RenderBox) {
      onLanded();
      return;
    }
    Rect local(Rect r) => overlayBox.globalToLocal(r.topLeft) & r.size;
    // The landing spot only exists once the new layout is built; until then
    // the tile waits where it was tapped.
    Rect? target;
    _flightEntry?.remove();
    _flight.stop();
    _flight.value = 0;
    final curve = CurvedAnimation(parent: _flight, curve: Curves.easeInOutCubic);
    final entry = OverlayEntry(
      builder: (context) {
        final flight = AnimatedBuilder(
          animation: curve,
          builder: (context, _) {
            final t = curve.value;
            final rect = target == null ? local(from) : Rect.lerp(local(from), local(target!), t)!;
            return Stack(
              children: [
                if (fading != null && fadingRect != null)
                  _positionedAt(
                    local(fadingRect),
                    child: Opacity(opacity: (1 - _flight.value * 3).clamp(0.0, 1.0), child: fading),
                  ),
                _positionedAt(
                  rect,
                  child: _FlightCard(app: app, t: growing ? t : 1 - t),
                ),
              ],
            );
          },
        );
        return IgnorePointer(
          child: clip == null
              ? flight
              : Stack(
                  children: [
                    _positionedAt(
                      local(clip),
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: overlayBox.size.width,
                          maxWidth: overlayBox.size.width,
                          minHeight: overlayBox.size.height,
                          maxHeight: overlayBox.size.height,
                          child: Transform.translate(offset: -local(clip).topLeft, child: flight),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
    // In the overlay before the page rebuilds, so the frame that swaps the
    // grid for the spotlight already shows the fading grid and the tile —
    // no blank frame for the grid to flash back from.
    _flightEntry = entry;
    overlay.insert(entry);
    void land() {
      if (_flightEntry == entry) {
        entry.remove();
        _flightEntry = null;
      }
      if (mounted) onLanded();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_flightEntry != entry) return;
      target = mounted ? to() : null;
      if (target == null) return land();
      entry.markNeedsBuild();
      _flight.forward(from: 0).whenCompleteOrCancel(land);
    });
  }

  void _select(SupportedApp app) {
    final from = _still ? null : _tileRect(app);
    final gridRect = from == null ? null : _globalRect(_gridKey.currentContext);
    widget.onSelect(app);
    setState(() {
      _spotlight = true;
      _cardHidden = from != null;
    });
    // The spotlight fits the first screen: start there, so the card lands
    // where the rider is looking.
    _scrollToTop();
    if (from == null) return;
    _fly(
      app: app,
      from: from,
      to: () => _globalRect(_cardKey.currentContext),
      growing: true,
      fading: gridRect == null ? null : TrainerAppGrid(selected: app, onSelect: (_) {}, hidden: app),
      fadingRect: gridRect,
      onLanded: () => setState(() => _cardHidden = false),
    );
  }

  void _change() {
    final app = widget.selected;
    final from = _still || app == null ? null : _globalRect(_cardKey.currentContext);
    setState(() {
      _spotlight = false;
      _hiddenTile = from != null ? app : null;
    });
    _scrollToTop();
    if (from == null) return;
    _fly(
      app: app!,
      from: from,
      to: () => _tileRect(app),
      growing: false,
      onLanded: () => setState(() => _hiddenTile = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    final selected = widget.selected;
    final content = _showSpotlight
        ? _SelectedAppSpotlight(
            key: ValueKey('onboarding-app-spotlight-${selected!.name}'),
            cardKey: _cardKey,
            app: selected,
            still: still,
            cardHidden: _cardHidden,
            onChange: _change,
            targets: widget.targets,
            selectedTarget: widget.selectedTarget,
            onSelectTarget: widget.onSelectTarget,
          )
        : _FadeIn(
            key: const ValueKey('onboarding-app-grid'),
            still: still,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrainerAppGrid(key: _gridKey, selected: selected, onSelect: _select, hidden: _hiddenTile),
                // Back on the grid after "Change app": the choice stays
                // reachable here too, so going back and forth never hides it.
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
            ),
          );

    final revealed = onboardingReveal([
      // Shown only when the welcome screen didn't already make the offer.
      if (widget.showUpdateBanner) const OnboardingUpdateBanner(),
      OnboardingHeadline(context.i18n.onboardingAppTitle),
      Gap(18),
      content,
    ]);

    // The spotlight sits centred in what is left of the screen under the
    // headline: the free space splits evenly (spaceBetween over header,
    // content and an empty end). Content taller than the screen just stacks.
    final viewport = OnboardingViewport.bodyHeightOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _showSpotlight && viewport != null ? viewport : 0),
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

Widget _positionedAt(Rect rect, {required Widget child}) =>
    Positioned(left: rect.left, top: rect.top, width: rect.width, height: rect.height, child: child);

/// Fades its child in once, when it first appears.
class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.still, required this.child});

  final bool still;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (still) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}

/// The tile in flight between the grid and the spotlight: [t] 0 looks like a
/// grid tile, 1 like the spotlight card. Laid out at the card's proportions and
/// scaled into whatever rect the flight is at.
class _FlightCard extends StatelessWidget {
  const _FlightCard({required this.app, required this.t});

  final SupportedApp app;
  final double t;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = onboardingAccent(context);
    double lerp(double a, double b) => a + (b - a) * t;
    return Container(
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(lerp(16, 24)),
        border: Border.all(color: accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22 * t),
            blurRadius: 32 * t,
            offset: Offset(0, 10 * t),
          ),
        ],
      ),
      padding: EdgeInsets.all(lerp(10, 20)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AppLogo(app: app, size: lerp(40, 72)),
            Gap(lerp(9, 14)),
            Text(
              app.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle.lerp(
                context.typography.xSmall.copyWith(fontWeight: FontWeight.w600),
                context.typography.large.copyWith(fontWeight: FontWeight.w600),
                t,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's logo, or its initial on a muted square when it has none.
class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.app, required this.size});

  final SupportedApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (app.logoAsset != null) {
      return TrainerAppLogo(asset: app.logoAsset!, url: app.logoUrl, height: size, fit: BoxFit.contain);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 4),
        color: Theme.of(context).colorScheme.muted,
      ),
      child: Text(app.name.substring(0, 1).toUpperCase(), style: TextStyle(fontSize: size * 0.45)).semiBold.muted,
    );
  }
}

/// The chosen app, enlarged and centred, with a way back to the grid and the
/// "runs on" choice under it.
class _SelectedAppSpotlight extends StatelessWidget {
  const _SelectedAppSpotlight({
    super.key,
    required this.cardKey,
    required this.app,
    required this.still,
    required this.cardHidden,
    required this.onChange,
    required this.targets,
    required this.selectedTarget,
    required this.onSelectTarget,
  });

  final Key cardKey;
  final SupportedApp app;
  final bool still;

  /// True while the tile is still flying in to take the card's place.
  final bool cardHidden;
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
    final directoryUrl = smartTrainerAppsUrl(app);
    final deal = riderDealFor(app);

    final card = Container(
      key: cardKey,
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent, width: 2),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 32, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Gap(6),
          _AppLogo(app: app, size: 72),
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

    // Everything around the card arrives while the tile is still flying.
    Widget arriving(Duration delay, Widget child) => _entrance(
      delay: delay,
      duration: const Duration(milliseconds: 295),
      curve: Curves.easeOutCubic,
      builder: (t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(6),
        Center(
          child: Opacity(
            opacity: cardHidden ? 0 : 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                if (app.officialIntegration) const Positioned(top: 10, left: 10, child: _OfficialBadge(size: 32)),
              ],
            ),
          ),
        ),
        Gap(10),
        arriving(
          const Duration(milliseconds: 140),
          Center(
            child: Button.ghost(
              key: const ValueKey('onboarding-change-app'),
              onPressed: onChange,
              leading: const Icon(LucideIcons.arrowLeftRight, size: 15),
              child: Text(context.i18n.onboardingChangeApp).small,
            ),
          ),
        ),
        if (directoryUrl != null || deal != null) ...[
          Gap(4),
          arriving(
            const Duration(milliseconds: 168),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (deal != null) ...[
                  Center(child: _RiderDealCard(app: app, deal: deal)),
                  Gap(6),
                ],
                if (directoryUrl != null)
                  Center(
                    child: Button.link(
                      key: const ValueKey('onboarding-app-directory-link'),
                      onPressed: () => _openExternal(directoryUrl),
                      trailing: const Icon(LucideIcons.externalLink, size: 13),
                      child: Text(context.i18n.onboardingAppDirectoryLink(app.name)).xSmall.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (hasChoice) ...[
          Gap(22),
          arriving(
            const Duration(milliseconds: 196),
            Column(
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

Future<void> _openExternal(Uri url) async {
  try {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (e, s) {
    recordError(e, s, context: 'Onboarding.openAppDirectory');
  }
}

/// A trainer app's discount code for BikeControl riders, with a button that
/// copies it.
class _RiderDealCard extends StatelessWidget {
  const _RiderDealCard({required this.app, required this.deal});

  final SupportedApp app;
  final RiderDeal deal;

  Future<void> _copy(BuildContext context) async {
    final copied = context.i18n.onboardingDealCodeCopied;
    try {
      await Clipboard.setData(ClipboardData(text: deal.code));
      buildToast(title: copied);
    } catch (e, s) {
      recordError(e, s, context: 'Onboarding.copyDealCode');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('onboarding-rider-deal'),
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.ticketPercent, size: 16, color: onboardingAccent(context)),
              Gap(8),
              Expanded(child: Text(context.i18n.onboardingGrimpaDeal(deal.percentOff)).small.semiBold),
            ],
          ),
          Gap(10),
          Button.outline(
            key: const ValueKey('onboarding-rider-deal-copy'),
            onPressed: () => _copy(context),
            trailing: const Icon(LucideIcons.copy, size: 14),
            child: Text(deal.code, style: const TextStyle(letterSpacing: 1.2)).semiBold,
          ),
        ],
      ),
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
