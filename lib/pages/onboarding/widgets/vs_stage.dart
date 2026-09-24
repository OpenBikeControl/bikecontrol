import 'dart:async';

import 'package:bike_control/main.dart' show screenshotMode;
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart' show onboardingMotionPinned;
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_curve.dart';
import 'package:bike_control/pages/proxy_device_details/gear_ratio_presets.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/apps/openbikecontrol.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/widgets/drivetrain/drivetrain_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// What Virtual Shifting buys a rider, shown rather than listed: it works
/// everywhere, the gearing is yours, there's a front derailleur in it too —
/// and a last scene for the features that don't need a picture.
///
/// Each scene animates the widget the rider will actually meet later — the
/// real ratio curve from the gear editor, the real chainring picture from the
/// front-shift setting — so the preview can't drift away from the product.
/// Holds still under reduced motion and in [screenshotMode], where it shows
/// the first scene only.
/// Opens every [VirtualShiftingStage] on this scene instead of its
/// [VirtualShiftingStage.initialScene]. The onboarding video starts past the
/// "works in every app" scene: by step 4 its viewer has already picked a
/// trainer.
@visibleForTesting
int? debugVirtualShiftingStageOpeningScene;

class VirtualShiftingStage extends StatefulWidget {
  const VirtualShiftingStage({super.key, this.initialScene = 0});

  /// Which scene to open on — and, where motion is off, the only one shown.
  /// Snapshot tests set it to capture each scene; the wizard leaves it at 0.
  final int initialScene;

  /// How long each scene holds before the next one takes over.
  static const Duration dwell = Duration(milliseconds: 5500);

  @override
  State<VirtualShiftingStage> createState() => _VirtualShiftingStageState();
}

class _VirtualShiftingStageState extends State<VirtualShiftingStage> {
  late int _scene = debugVirtualShiftingStageOpeningScene ?? widget.initialScene;
  bool _paused = false;
  Timer? _advance;

  /// Horizontal distance dragged in the current swipe, and whether a finger is
  /// still down — the stage nudges along with the drag and springs back if the
  /// swipe doesn't carry.
  double _drag = 0;
  bool _dragging = false;

  static const int _sceneCount = 4;

  /// How far the stage may follow a finger, how far a swipe has to travel to
  /// count, and the fling speed that counts regardless of distance.
  static const double _dragMax = 80;
  static const double _dragCommit = 45;
  static const double _flingVelocity = 250;

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _sync(bool still) {
    if (still || _paused) {
      _advance?.cancel();
      _advance = null;
      return;
    }
    _advance ??= Timer.periodic(VirtualShiftingStage.dwell, (_) {
      if (mounted) setState(() => _scene = (_scene + 1) % _sceneCount);
    });
  }

  /// A tap on the dots, or a swipe, is a rider taking over — the carousel
  /// stops moving under them rather than snatching the scene back a few
  /// seconds later.
  void _pick(int i) {
    setState(() {
      _scene = i;
      _paused = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragging = true;
      _drag = (_drag + d.delta.dx).clamp(-_dragMax, _dragMax);
    });
  }

  /// Swiping left goes forward, right goes back, and both wrap — the dots
  /// already say where in the four you are, so a dead end at either edge would
  /// only read as the swipe having failed.
  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    final step = (velocity < -_flingVelocity || _drag <= -_dragCommit)
        ? 1
        : (velocity > _flingVelocity || _drag >= _dragCommit)
            ? -1
            : 0;
    setState(() {
      _dragging = false;
      _drag = 0;
    });
    if (step != 0) _pick((_scene + step + _sceneCount) % _sceneCount);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Nothing moves on its own in either case. They differ in what a rider can
    // still do: [screenshotMode] pins the scene so captures are deterministic,
    // while reduced motion only means "don't move by yourself" — swiping and
    // the dots still work.
    final still = onboardingMotionPinned || reduceMotion;
    _sync(still);
    final scene = onboardingMotionPinned ? widget.initialScene : _scene;

    final captions = <({String label, String hint})>[
      (label: context.i18n.vsStageAppsLabel, hint: context.i18n.vsStageAppsHint),
      (label: context.i18n.vsStageRatiosLabel, hint: context.i18n.vsStageRatiosHint),
      (label: context.i18n.frontShiftEnableLabel, hint: context.i18n.vsStageFrontHint),
      (label: context.i18n.vsStageMoreLabel, hint: context.i18n.vsStageMoreHint),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          // Opaque so the whole stage answers a swipe, including the gaps
          // between a scene's own widgets.
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: () => setState(() {
            _dragging = false;
            _drag = 0;
          }),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.muted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: AnimatedSlide(
              // Follows the finger a little, then springs back on release —
              // enough for the swipe to feel answered before the scene turns
              // over. The border stays put; only the contents move.
              offset: Offset(reduceMotion ? 0 : _drag / _dragMax * 0.05, 0),
              duration: _dragging ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              // Every scene is laid out, so the stage keeps the height of the
              // tallest one and nothing jumps as they cross-fade.
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < _sceneCount; i++)
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: i == scene ? 1 : 0,
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOut,
                        // Full width under the Stack's loose constraints, so
                        // the shorter scenes centre instead of hugging the top.
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            child: switch (i) {
                              0 => _SceneApps(active: i == scene && !still),
                              1 => _SceneRatios(active: i == scene && !still),
                              2 => _SceneFront(active: i == scene && !still),
                              _ => const _SceneMore(),
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const Gap(11),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(captions[scene].label).small.semiBold,
                  Text(captions[scene].hint).xSmall.muted,
                ],
              ),
            ),
            const Gap(12),
            for (var i = 0; i < _sceneCount; i++) ...[
              if (i > 0) const Gap(5),
              _Dot(active: i == scene, onTap: () => _pick(i)),
            ],
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Button.ghost(
      style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2)),
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: active ? 18 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: active ? onboardingAccent(context) : cs.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// Drives an integer through a repeating sequence while [active], and holds at
/// [initial] otherwise. The scenes are all "step a value, redraw" — this keeps
/// the timer bookkeeping in one place.
class _Stepper extends StatefulWidget {
  const _Stepper({
    required this.active,
    required this.period,
    required this.builder,
  });

  final bool active;
  final Duration period;
  final Widget Function(BuildContext context, int tick) builder;

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  int _tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Stepper old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    if (!widget.active) {
      _timer?.cancel();
      _timer = null;
      // Back to the opening frame, so a scene always starts where it did the
      // first time it was shown.
      if (_tick != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !widget.active) setState(() => _tick = 0);
        });
      }
      return;
    }
    _timer ??= Timer.periodic(widget.period, (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _tick);
}

// ── Scene 1: works everywhere ───────────────────────────────────────────────

/// Trainer brands are illustrative — the point is the breadth, and these are
/// the ones riders recognise. The apps come from the list the app actually
/// supports, minus BikeControl's own targets, so it can't overpromise.
const List<String> _trainers = ['Wahoo KICKR', 'Tacx NEO', 'Elite Direto', 'Zwift Hub', 'Saris H3', 'JetBlack'];

List<String> _rideApps() => SupportedApp.supportedApps
    .where((a) => a is! BikeControl && a is! OpenBikeControl && a is! CustomApp)
    .map((a) => a.name)
    .toList();

class _SceneApps extends StatelessWidget {
  const _SceneApps({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final apps = _rideApps();
    const ok = Color(0xFF22C55E);
    return _Stepper(
      active: active,
      period: const Duration(milliseconds: 950),
      builder: (context, tick) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(context, context.i18n.vsStageTrainersHeading),
          const Gap(6),
          _chips(context, _trainers, tick % _trainers.length, onboardingAccent(context)),
          const Gap(9),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: cs.border)),
              const Gap(8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: onboardingAccent(context).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'BIKECONTROL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: onboardingAccent(context),
                  ),
                ),
              ),
              const Gap(8),
              Expanded(child: Container(height: 1, color: cs.border)),
            ],
          ),
          const Gap(9),
          _heading(context, context.i18n.vsStageAppsHeading),
          const Gap(6),
          _chips(context, apps, apps.isEmpty ? -1 : tick % apps.length, ok),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.3,
      color: Theme.of(context).colorScheme.mutedForeground,
    ),
  );

  Widget _chips(BuildContext context, List<String> items, int highlighted, Color accent) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var i = 0; i < items.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: i == highlighted ? accent.withValues(alpha: 0.16) : cs.border.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: i == highlighted ? accent.withValues(alpha: 0.5) : Colors.transparent),
            ),
            child: Text(
              items[i],
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: i == highlighted ? accent : cs.mutedForeground,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Scene 2: your gearing ───────────────────────────────────────────────────

/// The gear editor's own curve, walked through the presets a rider can pick
/// there, with the selected gear sweeping up and down the cassette.
class _SceneRatios extends StatelessWidget {
  const _SceneRatios({required this.active});

  final bool active;

  static const int _gears = ShiftingConfig.maxGearDefault;
  static const int _lowGear = 8;
  static const int _highGear = 19;

  @override
  Widget build(BuildContext context) {
    final presets = gearRatioPresets(context, _gears);
    return _Stepper(
      active: active,
      period: const Duration(milliseconds: 300),
      builder: (context, tick) {
        // One preset every eight steps of the gear sweep, so the curve
        // re-shapes while the gear keeps moving.
        final preset = presets[(tick ~/ 8) % presets.length];
        final gear = _sweep(tick);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GearRatioCurveView(ratios: preset.values, currentGear: gear, animated: true),
            const Gap(8),
            Row(
              children: [
                for (var i = 0; i < presets.length; i++) ...[
                  if (i > 0) const Gap(5),
                  Expanded(child: _presetChip(context, presets[i], presets[i].label == preset.label)),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  /// Ping-pongs between [_lowGear] and [_highGear].
  static int _sweep(int tick) {
    const span = _highGear - _lowGear;
    final p = tick % (span * 2);
    return _lowGear + (p <= span ? p : span * 2 - p);
  }

  Widget _presetChip(BuildContext context, GearRatioPreset preset, bool active) {
    final cs = Theme.of(context).colorScheme;
    final accent = onboardingAccent(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      decoration: BoxDecoration(
        color: active ? accent : cs.border.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            preset.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: active ? onboardingOnAccent : cs.mutedForeground,
            ),
          ),
          Text(
            preset.range,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              color: active ? onboardingOnAccent.withValues(alpha: 0.75) : cs.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scene 3: virtual front derailleur ───────────────────────────────────────

/// The front-shift setting as it appears in the gear settings, shifting
/// between its two chainrings on its own.
class _SceneFront extends StatelessWidget {
  const _SceneFront({required this.active});

  final bool active;

  static const int _gears = 12;

  /// A rear cog in the middle of the block, held still: this scene is about the
  /// ring the chain is on, not the cog.
  static const int _gear = 6;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = onboardingAccent(context);
    return _Stepper(
      active: active,
      period: const Duration(milliseconds: 1700),
      builder: (context, tick) {
        final large = tick.isOdd;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: cs.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.i18n.frontShiftEnableLabel).xSmall.semiBold,
                        Text(context.i18n.frontShiftChainringCount).xSmall.muted,
                      ],
                    ),
                  ),
                  const Gap(8),
                  // Decorative: the real switch lives in the gear settings.
                  Container(
                    width: 34,
                    height: 20,
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          width: 16,
                          decoration: const BoxDecoration(color: onboardingOnAccent, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(12),
            // The same drivetrain the rider gets on the trainer page: the chain
            // walks across to the other ring rather than the picture swapping,
            // which is the difference between showing a front shift and
            // captioning one. Marches only while this scene is the live one —
            // [active] is already false under reduced motion and in captures.
            DrivetrainView(
              gear: _gear,
              gearCount: _gears,
              frontShift: true,
              largeRingActive: large,
              smallChainringTeeth: ShiftingConfig.smallChainringDefault,
              largeChainringTeeth: ShiftingConfig.largeChainringDefault,
              moving: active,
              cadence: 85,
              showGear: false,
            ),
          ],
        );
      },
    );
  }
}

// ── Scene 4: everything else ────────────────────────────────────────────────

/// The features that don't need a picture — four of them, in a grid. The one
/// still scene: there is nothing here that moves, and a rider is reading it
/// rather than watching it.
class _SceneMore extends StatelessWidget {
  const _SceneMore();

  @override
  Widget build(BuildContext context) {
    final i18n = context.i18n;
    final items = <({String title, String sub})>[
      (title: i18n.vsStageMoreInstantTitle, sub: i18n.vsStageMoreInstantSub),
      (title: i18n.vsStageMoreWifiTitle, sub: i18n.vsStageMoreWifiSub),
      (title: i18n.vsStageMoreControllersTitle, sub: i18n.vsStageMoreControllersSub),
      (title: i18n.vsStageMoreGearCountTitle, sub: i18n.vsStageMoreGearCountSub),
      (title: i18n.vsStageMoreModesTitle, sub: i18n.vsStageMoreModesSub),
      (title: i18n.vsStageMoreProfilesTitle, sub: i18n.vsStageMoreProfilesSub),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < items.length ~/ 2; row++) ...[
          if (row > 0) const Gap(8),
          // Both cells in a row share the taller one's height, so the grid
          // stays a grid once a translation wraps.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _cell(context, items[row * 2])),
                const Gap(8),
                Expanded(child: _cell(context, items[row * 2 + 1])),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _cell(BuildContext context, ({String title, String sub}) item) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: cs.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: onboardingAccent(context), shape: BoxShape.circle),
          ),
          const Gap(7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2, color: cs.foreground),
                ),
                const Gap(2),
                Text(
                  item.sub,
                  style: TextStyle(fontSize: 10.5, height: 1.25, color: cs.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
