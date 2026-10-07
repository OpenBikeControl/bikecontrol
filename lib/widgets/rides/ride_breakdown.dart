import 'dart:math' as math;

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/rides/ride_zones.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkComponentThemes;
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Time in each gear ridden, lowest gear first. Nothing without gears.
class RideGearTime extends StatelessWidget {
  const RideGearTime({super.key, required this.chart});

  final RideChart chart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gears = chart.gearSeconds.keys.toList()..sort();
    if (gears.isEmpty) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return _Breakdown(
      key: const ValueKey('ride-details-gears'),
      header: BkGroupedHeader(l10n.ridesTimeInGear),
      rows: [
        for (final g in gears)
          _Bar(key: ValueKey('ride-gear-$g'), lead: l10n.gearNumber(g), seconds: chart.gearSeconds[g]!, color: accent),
      ],
    );
  }
}

/// Time in Coggan's seven power zones at [ftpWatts]; tapping the header's FTP
/// swaps it for [editor] in place.
class RidePowerZones extends StatelessWidget {
  const RidePowerZones({super.key, required this.chart, required this.ftpWatts, required this.editor});

  final RideChart chart;
  final int ftpWatts;

  /// Builds the FTP field; it calls back once the edit is through.
  final Widget Function(VoidCallback onDone) editor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = powerZoneSeconds(chart.powerSeconds, ftpWatts: ftpWatts);
    final accent = Theme.of(context).colorScheme.primary;
    return _Breakdown(
      key: const ValueKey('ride-details-power-zones'),
      header: _ZoneHeader(title: l10n.ridesPowerZones, reference: l10n.ridesFtpValue(ftpWatts), editor: editor),
      rows: [
        for (final z in PowerZone.values)
          _Bar(
            key: ValueKey('ride-power-zone-${z.index + 1}'),
            lead: 'Z${z.index + 1}',
            name: _powerZoneName(z, l10n),
            seconds: seconds[z.index],
            color: _ramp(accent, z.index, PowerZone.values.length),
          ),
      ],
    );
  }
}

/// Time in the five heart rate zones at [maxHeartRateBpm]; the header's max
/// is swapped for [editor] in place.
class RideHeartRateZones extends StatelessWidget {
  const RideHeartRateZones({super.key, required this.chart, required this.maxHeartRateBpm, required this.editor});

  final RideChart chart;
  final int maxHeartRateBpm;

  /// Builds the max heart rate field; it calls back once the edit is through.
  final Widget Function(VoidCallback onDone) editor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = heartRateZoneSeconds(chart.heartRateSeconds, maxHeartRateBpm: maxHeartRateBpm);
    // Heart rate keeps its secondary ink from the chart.
    final ink = Theme.of(context).colorScheme.mutedForeground;
    return _Breakdown(
      key: const ValueKey('ride-details-heart-rate-zones'),
      header: _ZoneHeader(
        title: l10n.ridesHeartRateZones,
        reference: l10n.ridesMaxHeartRateValue(maxHeartRateBpm),
        editor: editor,
      ),
      rows: [
        for (final z in HeartRateZone.values)
          _Bar(
            key: ValueKey('ride-heart-rate-zone-${z.index + 1}'),
            lead: 'Z${z.index + 1}',
            name: _heartRateZoneName(z, l10n),
            seconds: seconds[z.index],
            color: _ramp(ink, z.index, HeartRateZone.values.length),
          ),
      ],
    );
  }
}

/// The quiet line in place of zones until their reference value is set,
/// with the [field] to type it right there.
class RideZonePrompt extends StatelessWidget {
  const RideZonePrompt({super.key, required this.label, required this.field});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BkGroupedSection.inset, vertical: 4),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.typography.small.copyWith(color: Theme.of(context).colorScheme.mutedForeground),
            ),
          ),
          field,
        ],
      ),
    );
  }
}

String _powerZoneName(PowerZone z, AppLocalizations l10n) => switch (z) {
  PowerZone.activeRecovery => l10n.ridesPowerZoneActiveRecovery,
  PowerZone.endurance => l10n.ridesPowerZoneEndurance,
  PowerZone.tempo => l10n.ridesPowerZoneTempo,
  PowerZone.threshold => l10n.ridesPowerZoneThreshold,
  PowerZone.vo2max => l10n.ridesPowerZoneVo2max,
  PowerZone.anaerobic => l10n.ridesPowerZoneAnaerobic,
  PowerZone.neuromuscular => l10n.ridesPowerZoneNeuromuscular,
};

String _heartRateZoneName(HeartRateZone z, AppLocalizations l10n) => switch (z) {
  HeartRateZone.veryLight => l10n.ridesHeartRateZoneVeryLight,
  HeartRateZone.light => l10n.ridesHeartRateZoneLight,
  HeartRateZone.moderate => l10n.ridesHeartRateZoneModerate,
  HeartRateZone.hard => l10n.ridesHeartRateZoneHard,
  HeartRateZone.maximum => l10n.ridesHeartRateZoneMaximum,
};

/// The series colour, fainter for easy zones and full for the hardest: the
/// zone is always named too, never told by colour alone.
Color _ramp(Color c, int i, int n) => c.withValues(alpha: 0.35 + 0.65 * i / math.max(1, n - 1));

/// A grouped header and one card of bars, as the chart's card.
class _Breakdown extends StatelessWidget {
  const _Breakdown({super.key, required this.header, required this.rows});

  final Widget header;
  final List<_Bar> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = rows.fold<int>(0, (sum, r) => sum + r.seconds);
    final most = rows.fold<int>(0, (m, r) => math.max(m, r.seconds));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 0, BkGroupedSection.inset, 6),
          child: header,
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: cs.card,
            borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
            boxShadow: bkCardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [for (final r in rows) r._build(context, total: total, most: most)],
          ),
        ),
      ],
    );
  }
}

/// A zone header with the value it is measured against at the end; tapping
/// the value swaps it for its field until the edit is through.
class _ZoneHeader extends StatefulWidget {
  const _ZoneHeader({required this.title, required this.reference, required this.editor});

  final String title, reference;
  final Widget Function(VoidCallback onDone) editor;

  @override
  State<_ZoneHeader> createState() => _ZoneHeaderState();
}

class _ZoneHeaderState extends State<_ZoneHeader> {
  bool _editing = false;

  void _done() {
    if (mounted && _editing) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: BkGroupedHeader(widget.title)),
        if (_editing)
          widget.editor(_done)
        else
          Button.ghost(
            style: const ButtonStyle.ghost().withPadding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
            onPressed: () => setState(() => _editing = true),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(
                  widget.reference,
                  style: context.typography.small.copyWith(
                    color: cs.mutedForeground,
                    fontFeatures: BkNumerals.tabular,
                  ),
                ),
                Icon(LucideIcons.pencil, size: 12, color: cs.mutedForeground),
              ],
            ),
          ),
      ],
    );
  }
}

/// One row: what (Z2 Endurance, Gear 12), then its time and share, then a
/// bar as long as its share of the longest row.
class _Bar {
  const _Bar({required this.key, required this.lead, this.name, required this.seconds, required this.color});

  final Key key;
  final String lead;
  final String? name;
  final int seconds;
  final Color color;

  Widget _build(BuildContext context, {required int total, required int most}) {
    final cs = Theme.of(context).colorScheme;
    final share = total == 0 ? 0.0 : seconds / total;
    final fraction = most == 0 ? 0.0 : seconds / most;
    final percent = NumberFormat.percentPattern(Intl.getCurrentLocale()).format(share);
    final numbers = context.typography.small.copyWith(fontFeatures: BkNumerals.tabular);
    return MergeSemantics(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(lead, style: numbers.copyWith(fontWeight: FontWeight.w600)),
              if (name case final n?) ...[
                const Gap(6),
                Expanded(
                  child: Text(
                    n,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.small.copyWith(color: cs.mutedForeground),
                  ),
                ),
              ] else
                const Spacer(),
              const Gap(8),
              Text(
                formatRideDuration(Duration(seconds: seconds)),
                style: numbers.copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  percent,
                  textAlign: TextAlign.end,
                  style: numbers.copyWith(color: cs.mutedForeground),
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: cs.muted),
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: ColoredBox(color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
