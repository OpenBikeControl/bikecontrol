import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/utils/units.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkComponentThemes;
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One number in the display face with its unit smaller and muted, and an
/// optional muted prefix ("Ø"). [scale] is of `x2Large`.
TextSpan rideNumber(BuildContext context, String value, {String? unit, String? prefix, double scale = 1.25}) {
  final cs = Theme.of(context).colorScheme;
  final big = (context.typography.x2Large.fontSize ?? 24) * scale;
  return TextSpan(
    children: [
      if (prefix != null)
        TextSpan(
          text: '$prefix ',
          style: BkNumerals.display(big * 0.63, color: cs.mutedForeground, fontWeight: FontWeight.w600),
        ),
      TextSpan(
        text: value,
        style: BkNumerals.display(big, color: cs.foreground).copyWith(fontFeatures: BkNumerals.tabular),
      ),
      if (unit != null)
        TextSpan(
          // A hair of space, as the display face sets "29,4 km".
          text: '\u2009$unit',
          style: BkNumerals.display(big * 0.57, color: cs.mutedForeground, fontWeight: FontWeight.w600),
        ),
    ],
  );
}

/// The Details page's "Werte": moving and total time full width, then
/// distance (only with a speed source), work with kcal, Ø/max power, Ø/max
/// cadence, Ø/max heart rate and gear changes, two to a row. A value the ride
/// never had is left out rather than shown as zero.
class RideStatGrid extends StatelessWidget {
  const RideStatGrid({super.key, required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final locale = Intl.getCurrentLocale();
    final units = unitSystemOf(context);
    final s = summary;
    final muted = context.typography.small.copyWith(color: cs.mutedForeground);
    final unitStyle = BkNumerals.display(
      (context.typography.x2Large.fontSize ?? 24) * 1.15 * 0.57,
      color: cs.mutedForeground,
      fontWeight: FontWeight.w600,
    );

    final duration = _Cell(
      key: 'duration',
      label: l10n.miniWorkoutSummaryDuration,
      value: TextSpan(
        children: [
          rideNumber(context, formatRideDuration(s.activeDuration), scale: 1.15),
          TextSpan(text: ' ${l10n.ridesMoving}', style: unitStyle),
          if (s.elapsedDuration - s.activeDuration >= const Duration(seconds: 30)) ...[
            TextSpan(text: '  ·  ', style: unitStyle),
            rideNumber(context, formatRideDuration(s.elapsedDuration), scale: 1.15),
            TextSpan(text: ' ${l10n.ridesTotal}', style: unitStyle),
          ],
        ],
      ),
    );
    final cells = <_Cell>[
      if (s.shownDistanceKm case final km?)
        _Cell(
          key: 'distance',
          label: l10n.miniWorkoutSummaryDistance,
          value: rideNumber(context, formatRideDistance(km, units, locale), unit: units.distanceSymbol, scale: 1.15),
        ),
      if (s.workKj > 0)
        _Cell(
          key: 'work',
          label: l10n.ridesWork,
          value: rideNumber(context, formatInt(s.workKj, locale), unit: 'kJ', scale: 1.15),
          extra: '≈ ${formatInt(s.energyKcal, locale)} kcal',
        ),
      if (s.avgPowerW > 0)
        _Cell(
          key: 'power',
          label: l10n.miniWorkoutSummaryAvgPower,
          value: rideNumber(context, '${s.avgPowerW}', unit: 'W', scale: 1.15),
          extra: '${l10n.miniWorkoutSummaryMaxPower} ${s.maxPowerW} W',
        ),
      if (s.avgCadenceRpm > 0)
        _Cell(
          key: 'cadence',
          label: l10n.miniWorkoutSummaryAvgCadence,
          value: rideNumber(context, '${s.avgCadenceRpm}', unit: 'rpm', scale: 1.15),
          extra: s.maxCadenceRpm > 0 ? '${l10n.ridesMaxCadence} ${s.maxCadenceRpm} rpm' : null,
        ),
      if (s.avgHeartRateBpm > 0)
        _Cell(
          key: 'heart',
          label: l10n.miniWorkoutSummaryAvgHeartRate,
          value: rideNumber(context, '${s.avgHeartRateBpm}', unit: 'bpm', scale: 1.15),
          extra: '${l10n.miniWorkoutSummaryMaxHeartRate} ${s.maxHeartRateBpm} bpm',
        ),
      if (s.gearChanges case final g?)
        _Cell(key: 'gears', label: l10n.ridesGearChangesLabel, value: rideNumber(context, '$g', scale: 1.15)),
    ];

    final rows = <Widget>[_cell(context, duration, muted)];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(_divider(context));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _cell(context, cells[i], muted)),
              VerticalDivider(width: 1, thickness: 1, indent: 12, endIndent: 12, color: cs.border),
              Expanded(child: i + 1 < cells.length ? _cell(context, cells[i + 1], muted) : const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return DecoratedBox(
      key: const ValueKey('ride-stat-grid'),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        boxShadow: bkCardShadow(context),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  Widget _divider(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 16),
    child: SizedBox(height: 1, child: ColoredBox(color: Theme.of(context).colorScheme.border)),
  );

  Widget _cell(BuildContext context, _Cell c, TextStyle muted) {
    return Semantics(
      key: ValueKey('ride-stat-${c.key}'),
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.label, style: muted),
            const Gap(6),
            Text.rich(c.value, maxLines: 2),
            if (c.extra case final extra?) ...[
              const Gap(4),
              Text(extra, style: muted.copyWith(fontFeatures: BkNumerals.tabular)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cell {
  const _Cell({required this.key, required this.label, required this.value, this.extra});

  final String key;
  final String label;
  final InlineSpan value;
  final String? extra;
}
