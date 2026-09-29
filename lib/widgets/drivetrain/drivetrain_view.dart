import 'dart:math' as math;

import 'package:bike_control/widgets/drivetrain/chain_geometry.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The live gear view: a side-on drivetrain whose chain is solved rather than
/// drawn, so shifting re-routes the loop onto another cog and the derailleur
/// cage swings with it.
///
/// Takes plain values so onboarding, tests and the design's own demo can drive
/// it without a trainer attached — see [TrainerDrivetrain] for the binding to a
/// live `FitnessBikeDefinition`.
class DrivetrainView extends StatefulWidget {
  const DrivetrainView({
    super.key,
    required this.gear,
    required this.gearCount,
    this.frontShift = false,
    this.largeRingActive = false,
    this.smallChainringTeeth = 34,
    this.largeChainringTeeth = 50,
    this.moving = true,
    this.cadence = 90,
    this.dim = false,
    this.showGear = true,
    this.framed = true,
  });

  /// 1 = largest cog, i.e. the easiest gear.
  final int gear;
  final int gearCount;

  /// Draws the second chainring, the tooth count in the hub and the ring the
  /// drivetrain is currently on.
  final bool frontShift;
  final bool largeRingActive;

  final int smallChainringTeeth;
  final int largeChainringTeeth;

  /// While pedalling the chain marches and both rings turn at their true
  /// relative speeds. False freezes the drivetrain where it stands.
  final bool moving;
  final int cadence;

  /// A trainer that is paired but not carrying gears.
  final bool dim;

  /// The `12 / 24` readout in the top right. Off where a bigger gear number is
  /// already on screen.
  final bool showGear;

  /// Draws the inset panel the drivetrain sits on. Off when the caller already
  /// provides one — the chain's links are cut out in the panel colour, so the
  /// two surfaces have to be the same one, not two stacked on each other.
  final bool framed;

  @override
  State<DrivetrainView> createState() => _DrivetrainViewState();
}

/// How long a shift takes to travel to the new cog. Long enough to read as
/// movement, short enough that the picture never lags the trainer.
const double _easeSeconds = 0.26;

/// The ripple at the cog the chain just landed on. One gear is under a pixel of
/// travel on a 24-speed cassette, so the landing needs its own signal.
const double _pulseSeconds = 0.5;

class _DrivetrainViewState extends State<DrivetrainView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late final _Motion _motion = _Motion(front: _frontTarget, rear: _rearTarget);

  Duration _lastTick = Duration.zero;
  bool _reducedMotion = false;

  double get _rearTarget => rearRadiusFor(widget.gear, widget.gearCount);

  double get _frontTarget => widget.frontShift ? _activeChainringTeeth * kRadiusPerTooth : kSingleRingRadius;

  int get _activeChainringTeeth => widget.largeRingActive ? widget.largeChainringTeeth : widget.smallChainringTeeth;

  /// The chain only marches when the rider is actually turning the cranks —
  /// and never under reduced motion, where an endless loop is the exact thing
  /// the setting is there to stop.
  bool get _marching => widget.moving && !_reducedMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(DrivetrainView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _motion.rear.retarget(_rearTarget);
    _motion.front.retarget(_frontTarget);
    if (oldWidget.gear != widget.gear) _motion.startPulse();
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  /// Runs the ticker only while something is actually moving — a parked
  /// drivetrain costs no frames.
  void _syncTicker() {
    final busy = _marching || !_motion.settled;
    if (busy && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!busy && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    // First frame after a start has no previous stamp to measure against, and
    // a Ticker muted by an off-screen TickerMode resumes with a jump.
    final raw = _lastTick == Duration.zero ? 0.0 : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final dt = math.min(0.05, raw);

    final easing = _motion.tick(dt);
    if (_marching) _motion.march(dt, widget.cadence);
    _motion.notify();
    if (!easing && !_marching) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final panel = cs.muted;
    return AnimatedOpacity(
      opacity: widget.dim ? 0.5 : 1,
      duration: const Duration(milliseconds: 220),
      child: Container(
        decoration: widget.framed
            ? BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.border),
              )
            : null,
        // The inset belongs to the panel: unframed, the caller supplies both the
        // surface and its padding, and adding our own only shrinks the drawing.
        padding: widget.framed ? const EdgeInsets.fromLTRB(8, 6, 8, 4) : EdgeInsets.zero,
        child: Semantics(
          label: _semanticsLabel(),
          child: AspectRatio(
            aspectRatio: kDrivetrainBox.width / kDrivetrainBox.height,
            child: CustomPaint(
              painter: _DrivetrainPainter(
                motion: _motion,
                gear: widget.gear.clamp(1, math.max(1, widget.gearCount)),
                gearCount: widget.gearCount,
                frontShift: widget.frontShift,
                activeChainringTeeth: _activeChainringTeeth,
                idleChainringTeeth: widget.largeRingActive ? widget.smallChainringTeeth : widget.largeChainringTeeth,
                showGear: widget.showGear,
                // The painter lays out its own text, so it has to be handed the
                // app's family — an unstyled TextPainter falls back to whatever
                // the platform (or the test harness) has, which is not Geist.
                font: Theme.of(context).typography.sans,
                foreground: cs.foreground,
                muted: cs.mutedForeground,
                accent: Theme.of(context).colorScheme.primary,
                hardBorder: bkStrongBorder(context),
                panel: panel,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Reads out what is drawn, so an out-of-range gear is announced as the cog
  /// the chain is actually shown on.
  String _semanticsLabel() {
    final gear = '${widget.gear.clamp(1, math.max(1, widget.gearCount))} / ${widget.gearCount}';
    return widget.frontShift ? '$gear · ${_activeChainringTeeth}T' : gear;
  }
}

/// Everything about the drivetrain that changes between frames.
///
/// Kept out of the widget tree deliberately: the painter listens to this, so a
/// marching chain repaints without rebuilding anything.
class _Motion extends ChangeNotifier {
  _Motion({required double front, required double rear}) : front = _Eased(front), rear = _Eased(rear);

  final _Eased front;
  final _Eased rear;

  /// Where the dashed inner line of the chain currently starts.
  double chainPhase = 0;

  /// Crank and cassette rotation, radians.
  double frontTurn = 0;
  double rearTurn = 0;

  /// Seconds into the landing ripple; [_pulseSeconds] or more means finished.
  double pulseElapsed = _pulseSeconds;

  /// The cog radius the ripple started from, so it expands out of the cog the
  /// chain just left rather than out of the one it is easing towards.
  double pulseRadius = 0;

  bool get settled => front.settled && rear.settled && pulseElapsed >= _pulseSeconds;

  bool get pulsing => pulseElapsed < _pulseSeconds;

  double get pulseProgress => (pulseElapsed / _pulseSeconds).clamp(0.0, 1.0);

  void startPulse() {
    pulseRadius = rear.value;
    pulseElapsed = 0;
  }

  /// Advances the eases and the ripple. Returns true while any is still moving.
  bool tick(double dt) {
    // Both have to be ticked, so no short-circuiting here.
    final frontMoving = front.tick(dt);
    final rearMoving = rear.tick(dt);
    var busy = frontMoving || rearMoving;
    if (pulsing) {
      pulseElapsed += dt;
      busy = true;
    }
    return busy;
  }

  /// Winds the chain on by [dt] seconds of pedalling at [cadence] rpm. Both
  /// rings turn at the speed that much chain implies, which is what puts the
  /// cassette's spin and the crank's in true proportion.
  void march(double dt, int cadence) {
    final rFront = math.max(1.0, front.value);
    final travel = (math.max(20, cadence) / 60) * kTau * rFront * dt;
    chainPhase = (chainPhase - travel) % kChainPitch;
    frontTurn = (frontTurn + travel / rFront) % kTau;
    rearTurn = (rearTurn + travel / math.max(4.0, rear.value)) % kTau;
  }

  void notify() => notifyListeners();
}

/// A value that slides to its target on an ease-out cubic instead of snapping,
/// so a shift travels to the new cog.
class _Eased {
  _Eased(this._value) : _from = _value, _target = _value;

  double _value;
  double _from;
  double _target;
  double _t = 1;

  double get value => _value;

  bool get settled => _t >= 1;

  void retarget(double target) {
    if ((target - _target).abs() < 0.001) return;
    _from = _value;
    _target = target;
    _t = 0;
  }

  /// Advances by [dt] seconds. Returns true while still travelling.
  bool tick(double dt) {
    if (_t >= 1) return false;
    _t = math.min(1, _t + dt / _easeSeconds);
    final p = 1 - math.pow(1 - _t, 3).toDouble();
    _value = _from + (_target - _from) * p;
    return true;
  }
}

class _DrivetrainPainter extends CustomPainter {
  _DrivetrainPainter({
    required this.motion,
    required this.gear,
    required this.gearCount,
    required this.frontShift,
    required this.activeChainringTeeth,
    required this.idleChainringTeeth,
    required this.showGear,
    required this.font,
    required this.foreground,
    required this.muted,
    required this.accent,
    required this.hardBorder,
    required this.panel,
    // The readouts are laid out by hand rather than by a Text widget, so
    // nothing else would mark this dirty when a font finishes loading — the
    // picture would keep the fallback glyphs it was first recorded with.
  }) : super(repaint: Listenable.merge([motion, PaintingBinding.instance.systemFonts]));

  final _Motion motion;
  final int gear;
  final int gearCount;
  final bool frontShift;
  final int activeChainringTeeth;
  final int idleChainringTeeth;
  final bool showGear;
  final TextStyle font;
  final Color foreground;
  final Color muted;
  final Color accent;
  final Color hardBorder;
  final Color panel;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / kDrivetrainBox.width);
    canvas.translate(-kDrivetrainBox.left, -kDrivetrainBox.top);

    final rRear = motion.rear.value;
    final rFront = motion.front.value;
    final guide = guidePulley(rRear);
    final tension = tensionPulley(rRear);

    _paintCogStack(canvas);
    _paintCassetteHub(canvas);
    if (motion.pulsing) _paintLandingRipple(canvas);
    _paintActiveCog(canvas, rRear);
    if (frontShift) _paintIdleChainring(canvas);
    _paintCage(canvas, guide, tension);
    _paintChain(canvas, rFront, rRear);
    _paintPulley(canvas, guide);
    _paintPulley(canvas, tension);
    _paintChainring(canvas, rFront);
    if (showGear) _paintGearReadout(canvas);
    canvas.restore();
  }

  Paint _stroke(Color color, double width, {double opacity = 1}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.butt
    ..color = opacity == 1 ? color : color.withValues(alpha: color.a * opacity);

  /// A tooth crown: one short arc per tooth around the rim, so a 50T ring reads
  /// as visibly finer-toothed than a 34T one.
  void _paintTeeth(
    Canvas canvas,
    Offset centre,
    double radius,
    int teeth,
    Color color, {
    double width = 2.6,
    double opacity = 1,
  }) {
    final count = math.max(6, teeth);
    final step = kTau / count;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final paint = _stroke(color, width, opacity: opacity);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, i * step, step * 0.42, false, paint);
    }
  }

  /// The cogs the chain is not on. Above 14 speeds they thin to hairlines with
  /// every fourth picked out, so a big cassette reads as a stack instead of as
  /// a smear — the chain still lands on the exact cog.
  void _paintCogStack(Canvas canvas) {
    final hair = gearCount > 14;
    for (var i = 1; i <= gearCount; i++) {
      if (i == gear) continue;
      final ridge = !hair || i % 4 == 1;
      canvas.drawCircle(
        kCassetteCentre,
        rearRadiusFor(i, gearCount),
        _stroke(hardBorder, ridge ? 1.1 : 0.7, opacity: ridge ? 0.9 : 0.45),
      );
    }
  }

  /// The lockring cross, which is what makes the cassette's spin visible.
  void _paintCassetteHub(Canvas canvas) {
    canvas.save();
    canvas.translate(kCassetteCentre.dx, kCassetteCentre.dy);
    canvas.rotate(motion.rearTurn);
    final paint = _stroke(hardBorder, 1.4);
    canvas.drawLine(const Offset(-7, 0), const Offset(7, 0), paint);
    canvas.drawLine(const Offset(0, -7), const Offset(0, 7), paint);
    canvas.restore();
  }

  void _paintLandingRipple(Canvas canvas) {
    final p = motion.pulseProgress;
    canvas.drawCircle(
      kCassetteCentre,
      motion.pulseRadius + 1 + p * 10,
      _stroke(accent, 2, opacity: 0.55 * (1 - p)),
    );
  }

  void _paintActiveCog(Canvas canvas, double rRear) {
    final teeth = math.max(9, (rRear / kRadiusPerTooth).round());
    _paintTeeth(canvas, kCassetteCentre, rRear + 1, teeth, accent, width: 2.8);
    canvas.drawCircle(kCassetteCentre, rRear, _stroke(accent, 1.6));
    canvas.drawCircle(kCassetteCentre, 4.5, Paint()..color = panel);
    canvas.drawCircle(kCassetteCentre, 4.5, _stroke(hardBorder, 1));
  }

  /// The ring the chain is not on — only worth drawing when there are two.
  void _paintIdleChainring(Canvas canvas) {
    final radius = idleChainringTeeth * kRadiusPerTooth;
    _paintTeeth(canvas, kChainringCentre, radius + 1, idleChainringTeeth, hardBorder, width: 2.4, opacity: 0.75);
    canvas.drawCircle(kChainringCentre, radius, _stroke(hardBorder, 1.2, opacity: 0.75));
  }

  void _paintCage(Canvas canvas, Offset guide, Offset tension) {
    final paint = _stroke(muted, 2.6)..strokeCap = StrokeCap.round;
    canvas.drawLine(kCassetteCentre + const Offset(20, 6), guide, paint);
    canvas.drawLine(guide, tension, paint);
  }

  void _paintChain(Canvas canvas, double rFront, double rRear) {
    final path = chainPath(rFront, rRear);
    canvas.drawPath(
      path,
      _stroke(foreground, 4.2, opacity: 0.82)..strokeJoin = StrokeJoin.round,
    );
    // The links, marching along the outer band.
    canvas.drawPath(
      dashedPath(path, on: kChainPitch * 0.3, off: kChainPitch * 0.7, phase: motion.chainPhase),
      _stroke(panel, 1.5)..strokeCap = StrokeCap.round,
    );
  }

  /// Pulleys sit on top of the chain they carry.
  void _paintPulley(Canvas canvas, Offset centre) {
    canvas.drawCircle(centre, kPulleyRadius - 1.6, Paint()..color = panel);
    canvas.drawCircle(centre, kPulleyRadius - 1.6, _stroke(muted, 1.3));
    canvas.drawCircle(centre, 1.6, Paint()..color = muted);
  }

  void _paintChainring(Canvas canvas, double rFront) {
    final teeth = frontShift ? activeChainringTeeth : (kSingleRingRadius / kRadiusPerTooth).round();
    _paintTeeth(canvas, kChainringCentre, rFront + 1, teeth, foreground, width: 2.8, opacity: 0.9);
    canvas.drawCircle(kChainringCentre, rFront, _stroke(foreground, 1.6, opacity: 0.9));

    // The spider, which is what makes the crank's rotation visible.
    canvas.save();
    canvas.translate(kChainringCentre.dx, kChainringCentre.dy);
    canvas.rotate(motion.frontTurn);
    final spoke = _stroke(hardBorder, 2.4)..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = (i / 5) * kTau - math.pi / 2;
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(a), math.sin(a)) * (rFront - 5),
        spoke,
      );
    }
    canvas.restore();

    canvas.drawCircle(kChainringCentre, 13, Paint()..color = panel);
    if (frontShift) {
      _paintText(
        canvas,
        TextSpan(
          text: '${activeChainringTeeth}T',
          style: font.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700, color: foreground),
        ),
        anchor: kChainringCentre + const Offset(0, 4.5),
        alignEnd: false,
      );
    } else {
      canvas.drawCircle(kChainringCentre, 4.5, _stroke(hardBorder, 1));
    }
  }

  /// The `12 / 24` readout, tucked into the top right above the cassette.
  void _paintGearReadout(Canvas canvas) {
    _paintText(
      canvas,
      TextSpan(
        style: font.copyWith(fontSize: 12, color: muted),
        children: [
          TextSpan(
            text: '$gear',
            style: font.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: foreground),
          ),
          TextSpan(text: ' / $gearCount'),
        ],
      ),
      anchor: const Offset(276, 46),
      alignEnd: true,
    );
  }

  /// Paints [span] with [anchor] on its alphabetic baseline, the way the design
  /// places SVG text.
  void _paintText(Canvas canvas, TextSpan span, {required Offset anchor, required bool alignEnd}) {
    final painter = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    final baseline = painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final dx = alignEnd ? anchor.dx - painter.width : anchor.dx - painter.width / 2;
    painter.paint(canvas, Offset(dx, anchor.dy - baseline));
    painter.dispose();
  }

  @override
  bool shouldRepaint(_DrivetrainPainter old) =>
      old.gear != gear ||
      old.gearCount != gearCount ||
      old.frontShift != frontShift ||
      old.activeChainringTeeth != activeChainringTeeth ||
      old.idleChainringTeeth != idleChainringTeeth ||
      old.showGear != showGear ||
      old.font != font ||
      old.foreground != foreground ||
      old.muted != muted ||
      old.accent != accent ||
      old.hardBorder != hardBorder ||
      old.panel != panel;
}
