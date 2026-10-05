import 'dart:math' as math;

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Power and heart rate as two stacked strips on one time axis — no dual
/// axis — with pauses hatched across both and the lines broken there. Power
/// in the brand accent, heart rate in secondary ink (red means error here).
///
/// [compact] is the summary card's strip pair; the full chart on Details adds
/// value ticks, the dashed average, the time axis and a scrub (hover, or
/// press and drag) that reads out both series at a moment.
class RideChartView extends StatefulWidget {
  const RideChartView({super.key, required this.summary, this.compact = false});

  final WorkoutSummary summary;
  final bool compact;

  @override
  State<RideChartView> createState() => _RideChartViewState();
}

class _RideChartViewState extends State<RideChartView> {
  /// The scrubbed bucket, or null.
  int? _scrub;

  RideChart? get _chart => widget.summary.chart;

  void _scrubAt(Offset local, Size size, _Geometry g) {
    final chart = _chart;
    if (chart == null) return;
    final count = math.max(chart.power.length, chart.heartRate.length);
    if (count == 0) return;
    final t = ((local.dx - g.left) / g.width).clamp(0.0, 1.0);
    final i = (t * (count - 1)).round();
    if (i != _scrub) setState(() => _scrub = i);
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    if (chart == null || (!chart.hasPower && !chart.hasHeartRate)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final typography = context.typography;
    final style = _ChartStyle(
      accent: cs.primary,
      heart: cs.mutedForeground,
      grid: cs.border,
      ink: cs.foreground,
      muted: cs.mutedForeground,
      card: cs.card,
      label: typography.xSmall.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
      unit: typography.xSmall.copyWith(fontWeight: FontWeight.w500, color: cs.mutedForeground),
      tick: typography.xSmall.copyWith(color: cs.mutedForeground, fontFeatures: BkNumerals.tabular),
    );
    final hrAvg = widget.summary.avgHeartRateBpm;
    final labels = _Labels(
      power: l10n.sensorQuantityPower,
      heart: l10n.sensorQuantityHeartRate,
      heartUnit: widget.compact && hrAvg > 0 ? 'Ø $hrAvg bpm' : 'bpm',
      pause: l10n.ridesPause,
      minutes: 'min',
      avg: widget.summary.avgPowerW > 0 ? 'Ø ${widget.summary.avgPowerW}' : null,
    );
    return Semantics(
      label: l10n.ridesChartA11y,
      image: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final g = _Geometry.of(chart, width: width, compact: widget.compact, tick: style.tick);
          final painter = _RideChartPainter(
            chart: chart,
            geometry: g,
            style: style,
            labels: labels,
            avgPower: widget.summary.avgPowerW,
            compact: widget.compact,
            scrub: _scrub,
          );
          final canvas = CustomPaint(size: Size(width, g.height), painter: painter);
          if (widget.compact) return canvas;
          return MouseRegion(
            onHover: (e) => _scrubAt(e.localPosition, Size(width, g.height), g),
            onExit: (_) => setState(() => _scrub = null),
            child: Listener(
              onPointerDown: (e) => _scrubAt(e.localPosition, Size(width, g.height), g),
              onPointerMove: (e) => _scrubAt(e.localPosition, Size(width, g.height), g),
              onPointerUp: (_) => setState(() => _scrub = null),
              onPointerCancel: (_) => setState(() => _scrub = null),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  canvas,
                  if (_scrub case final i?) _tooltip(context, chart, g, i, l10n),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(BuildContext context, RideChart chart, _Geometry g, int i, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final p = i < chart.power.length ? chart.power[i] : null;
    final h = i < chart.heartRate.length ? chart.heartRate[i] : null;
    final x = g.xAt(i);
    final bold = context.typography.xSmall.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.foreground,
      fontFeatures: BkNumerals.tabular,
    );
    final muted = context.typography.xSmall.copyWith(color: cs.mutedForeground);
    Widget key(Color c) => Container(width: 8, height: 2, margin: const EdgeInsets.only(right: 5), color: c);
    final paused = p == null && h == null;
    return Positioned(
      left: math.min(math.max(0, x + 10), g.left + g.width - 96),
      top: 0,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cs.muted,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x33000000))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatRideDuration(Duration(seconds: i * chart.stepSeconds)), style: bold),
              if (paused) Text(l10n.ridesPause, style: muted),
              if (p != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    key(cs.primary),
                    Text('$p', style: bold),
                    Text(' W', style: muted),
                  ],
                ),
              if (h != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    key(cs.mutedForeground),
                    Text('$h', style: bold),
                    Text(' bpm', style: muted),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartStyle {
  const _ChartStyle({
    required this.accent,
    required this.heart,
    required this.grid,
    required this.ink,
    required this.muted,
    required this.card,
    required this.label,
    required this.unit,
    required this.tick,
  });

  final Color accent, heart, grid, ink, muted, card;
  final TextStyle label, unit, tick;
}

class _Labels {
  const _Labels({
    required this.power,
    required this.heart,
    required this.heartUnit,
    required this.pause,
    required this.minutes,
    required this.avg,
  });

  final String power, heart, heartUnit, pause, minutes;
  final String? avg;
}

/// Where everything goes, in logical px.
class _Geometry {
  _Geometry({
    required this.left,
    required this.width,
    required this.count,
    required this.powerTop,
    required this.powerHeight,
    required this.heartTop,
    required this.heartHeight,
    required this.height,
    required this.powerMax,
    required this.heartMin,
    required this.heartMax,
    required this.axisY,
  });

  final double left, width;
  final int count;
  final double? powerTop, powerHeight, heartTop, heartHeight;
  final double height;
  final double powerMax, heartMin, heartMax;
  final double? axisY;

  double xAt(int i) => left + (count <= 1 ? 0 : i / (count - 1) * width);

  double xAtSeconds(int s, int step) => left + (count <= 1 ? 0 : (s / step) / (count - 1) * width).clamp(0, width);

  static _Geometry of(RideChart chart, {required double width, required bool compact, required TextStyle tick}) {
    final count = math.max(chart.power.length, chart.heartRate.length);
    final hasP = chart.hasPower, hasH = chart.hasHeartRate;
    final peak = chart.power.whereType<int>().fold<int>(0, math.max);
    final powerMax = compact ? math.max(peak * 1.05, 100.0) : (math.max(peak, 100) / 100).ceil() * 100.0;
    final hrs = chart.heartRate.whereType<int>().where((v) => v > 0);
    final hrLo = hrs.isEmpty ? 60 : hrs.reduce(math.min);
    final hrHi = hrs.isEmpty ? 180 : hrs.reduce(math.max);
    final heartMin = compact ? hrLo - 5.0 : ((hrLo - 5) / 20).floor() * 20.0;
    final heartMax = compact ? hrHi + 5.0 : math.max(heartMin + 40, ((hrHi + 5) / 20).ceil() * 20.0);
    final labelH = (tick.fontSize ?? 11) + 8;
    final left = compact ? 0.0 : 30.0;
    final plotW = width - left - (compact ? 0 : 4);
    double y = compact ? labelH + 2 : labelH + 6;
    double? pTop, pH, hTop, hH;
    if (hasP) {
      pTop = y;
      pH = compact ? 40 : 96;
      y += pH + (compact ? 6 : 10);
    }
    if (hasH) {
      y += labelH;
      hTop = y;
      hH = compact ? 22 : 58;
      y += hH;
    }
    double? axis;
    if (!compact) {
      axis = y;
      y += labelH + 4;
    } else {
      y += 4;
    }
    return _Geometry(
      left: left,
      width: plotW,
      count: count,
      powerTop: pTop,
      powerHeight: pH,
      heartTop: hTop,
      heartHeight: hH,
      height: y,
      powerMax: powerMax,
      heartMin: heartMin,
      heartMax: heartMax,
      axisY: axis,
    );
  }
}

class _RideChartPainter extends CustomPainter {
  _RideChartPainter({
    required this.chart,
    required this.geometry,
    required this.style,
    required this.labels,
    required this.avgPower,
    required this.compact,
    required this.scrub,
  });

  final RideChart chart;
  final _Geometry geometry;
  final _ChartStyle style;
  final _Labels labels;
  final int avgPower;
  final bool compact;
  final int? scrub;

  void _text(Canvas canvas, String s, TextStyle ts, Offset at, {TextAlign align = TextAlign.left, TextSpan? tail}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: ts, children: [?tail]),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right || TextAlign.end => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final grid = Paint()
      ..color = style.grid
      ..strokeWidth = 1;
    final top = g.powerTop ?? g.heartTop ?? 0;
    final bottom = (g.heartTop != null ? g.heartTop! + g.heartHeight! : g.powerTop! + g.powerHeight!);

    // Pauses: a hatched column across both strips.
    for (final (start, end) in chart.pauses) {
      final x0 = g.xAtSeconds(start, chart.stepSeconds);
      final x1 = g.xAtSeconds(end, chart.stepSeconds);
      if (x1 - x0 < 1) continue;
      final rect = Rect.fromLTRB(x0, top, x1, bottom);
      canvas.save();
      canvas.clipRect(rect);
      final hatch = Paint()
        ..color = style.muted.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (double d = rect.left - rect.height; d < rect.right; d += 6) {
        canvas.drawLine(Offset(d, rect.bottom), Offset(d + rect.height, rect.top), hatch);
      }
      canvas.restore();
      if (!compact) {
        _text(
          canvas,
          labels.pause,
          style.tick.copyWith(fontWeight: FontWeight.w600),
          Offset((x0 + x1) / 2, top - 4),
          align: TextAlign.center,
        );
      }
    }

    if (g.powerTop case final pTop?) {
      final pH = g.powerHeight!;
      double y(num v) => pTop + pH - (v / g.powerMax).clamp(0, 1) * pH;
      if (compact) {
        canvas.drawLine(Offset(g.left, pTop + pH), Offset(g.left + g.width, pTop + pH), grid);
      } else {
        for (final v in [0, g.powerMax / 2, g.powerMax]) {
          canvas.drawLine(Offset(g.left, y(v)), Offset(g.left + g.width, y(v)), grid);
          _text(canvas, '${v.round()}', style.tick, Offset(g.left - 6, y(v) + 5), align: TextAlign.right);
        }
      }
      _series(canvas, chart.power, y, baseline: pTop + pH, color: style.accent, fill: true);
      if (!compact && avgPower > 0) {
        final ay = y(avgPower);
        final dash = Paint()
          ..color = style.ink.withValues(alpha: 0.45)
          ..strokeWidth = 1;
        for (double x = g.left; x < g.left + g.width; x += 6) {
          canvas.drawLine(Offset(x, ay), Offset(math.min(x + 3, g.left + g.width), ay), dash);
        }
        if (labels.avg case final avg?) {
          _text(canvas, avg, style.tick, Offset(g.left + g.width, ay - 3), align: TextAlign.right);
        }
      }
      _text(
        canvas,
        labels.power,
        style.label,
        Offset(g.left, pTop - (compact ? 5 : 6)),
        tail: TextSpan(text: ' · W', style: style.unit),
      );
    }

    if (g.heartTop case final hTop?) {
      final hH = g.heartHeight!;
      double y(num v) => hTop + hH - ((v - g.heartMin) / (g.heartMax - g.heartMin)).clamp(0, 1) * hH;
      if (compact) {
        canvas.drawLine(Offset(g.left, hTop + hH), Offset(g.left + g.width, hTop + hH), grid);
      } else {
        final step = (g.heartMax - g.heartMin) / 2;
        for (final v in [g.heartMin, g.heartMin + step, g.heartMax]) {
          canvas.drawLine(Offset(g.left, y(v)), Offset(g.left + g.width, y(v)), grid);
          _text(canvas, '${v.round()}', style.tick, Offset(g.left - 6, y(v) + 5), align: TextAlign.right);
        }
      }
      _series(canvas, chart.heartRate, y, baseline: hTop + hH, color: style.heart, fill: false);
      _text(
        canvas,
        labels.heart,
        style.label,
        Offset(g.left, hTop - (compact ? 5 : 8)),
        tail: TextSpan(text: ' · ${labels.heartUnit}', style: style.unit),
      );
    }

    if (g.axisY case final axis?) {
      canvas.drawLine(
        Offset(g.left, axis),
        Offset(g.left + g.width, axis),
        Paint()
          ..color = style.ink.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      final totalMin = chart.totalSeconds / 60;
      final every = totalMin <= 20
          ? 5
          : totalMin <= 60
          ? 10
          : totalMin <= 150
          ? 30
          : 60;
      for (var m = 0; m <= totalMin; m += every) {
        final x = g.xAtSeconds(m * 60, chart.stepSeconds);
        final last = m + every > totalMin;
        _text(
          canvas,
          last && m > 0 ? '$m ${labels.minutes}' : '$m',
          style.tick,
          Offset(x, axis + 15),
          align: m == 0 ? TextAlign.left : (last ? TextAlign.right : TextAlign.center),
        );
      }
    }

    if (scrub case final i?) {
      final x = g.xAt(i);
      canvas.drawLine(
        Offset(x, top),
        Offset(x, g.axisY ?? bottom),
        Paint()
          ..color = style.ink.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      void dot(double? v, double Function(num) y, Color c) {
        if (v == null) return;
        canvas.drawCircle(Offset(x, y(v)), 5, Paint()..color = style.card);
        canvas.drawCircle(Offset(x, y(v)), 4, Paint()..color = c);
      }

      if (g.powerTop case final pTop?) {
        final p = i < chart.power.length ? chart.power[i] : null;
        dot(p?.toDouble(), (v) => pTop + g.powerHeight! - (v / g.powerMax).clamp(0, 1) * g.powerHeight!, style.accent);
      }
      if (g.heartTop case final hTop?) {
        final h = i < chart.heartRate.length ? chart.heartRate[i] : null;
        dot(
          h?.toDouble(),
          (v) => hTop + g.heartHeight! - ((v - g.heartMin) / (g.heartMax - g.heartMin)).clamp(0, 1) * g.heartHeight!,
          style.heart,
        );
      }
    }
  }

  void _series(
    Canvas canvas,
    List<int?> values,
    double Function(num) y, {
    required double baseline,
    required Color color,
    required bool fill,
  }) {
    final g = geometry;
    final line = Path();
    final area = Path();
    var pen = false;
    double? segStartX;
    double lastX = 0;
    void closeArea() {
      if (segStartX != null) {
        area
          ..lineTo(lastX, baseline)
          ..lineTo(segStartX!, baseline)
          ..close();
      }
      segStartX = null;
    }

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final x = g.xAt(i);
      if (v == null || (!fill && v <= 0)) {
        pen = false;
        closeArea();
        continue;
      }
      final py = y(v);
      if (!pen) {
        line.moveTo(x, py);
        area.moveTo(x, baseline);
        area.lineTo(x, py);
        segStartX = x;
      } else {
        line.lineTo(x, py);
        area.lineTo(x, py);
      }
      lastX = x;
      pen = true;
    }
    closeArea();
    if (fill) canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.16));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RideChartPainter old) =>
      old.chart != chart ||
      old.scrub != scrub ||
      old.style.accent != style.accent ||
      old.geometry.width != geometry.width;
}
