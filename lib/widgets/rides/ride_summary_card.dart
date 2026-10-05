import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/rides/ride_details_page.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/units.dart';
import 'package:bike_control/widgets/rides/ride_chart.dart';
import 'package:bike_control/widgets/rides/ride_export.dart';
import 'package:bike_control/widgets/rides/ride_recording_line.dart' show confirmRideDiscard;
import 'package:bike_control/widgets/rides/ride_stats.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkComponentThemes;
import 'package:bike_control/widgets/ui/bk_grouped_section.dart' show BkIconTile;
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The last ride, at the top of Ride: data only ("Heute · 17:56–18:40",
/// trainer and app), the four numbers, power and heart rate on one time axis
/// with the pause hatched, the gear changes, then Details, Export and
/// Verwerfen. On the first ride it also asks, once, whether rides go to Apple
/// Health / Health Connect. Stays until dismissed or the next ride starts,
/// across restarts.
///
/// [wide] is the desktop layout: bigger numbers, Verwerfen as text and Export
/// as a menu.
class RideSummaryCard extends StatelessWidget {
  const RideSummaryCard({super.key, this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: core.rides.changes,
      builder: (context, _) {
        final ride = core.rides.summaryRide.value;
        final summary = ride?.summary;
        if (ride == null || summary == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Card(key: ValueKey('ride-summary-${ride.fileName}'), ride: ride, summary: summary, wide: wide),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.ride, required this.summary, required this.wide});

  final PastWorkout ride;
  final WorkoutSummary summary;
  final bool wide;

  Future<void> _discard(BuildContext context) async {
    final rides = core.rides;
    final confirmed = summary.savedToHealth ? await confirmRideDelete(context) : await confirmRideDiscard(context);
    if (!confirmed) return;
    try {
      await rides.delete(ride);
    } catch (e, s) {
      await recordError(e, s, context: 'RideSummary.discard');
    }
  }

  void _details(BuildContext context) => unawaited(context.push(RideDetailsPage(ride: ride)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final locale = intl.Intl.getCurrentLocale();
    final typography = context.typography;
    final sources = [?summary.trainerName, ?summary.appName];

    return Container(
      key: const ValueKey('ride-summary-card'),
      padding: EdgeInsets.fromLTRB(16, 14, wide ? 12 : 8, 16),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        boxShadow: bkCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rideDayLabel(ride.startedAt, l10n, locale)} · ${formatRideClockRange(summary, locale)}',
                        style: typography.base.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.16,
                          fontFeatures: BkNumerals.tabular,
                        ),
                      ),
                      if (sources.isNotEmpty) ...[
                        const Gap(3),
                        Text(sources.join(' · '), style: typography.small.copyWith(color: cs.mutedForeground)),
                      ],
                    ],
                  ),
                ),
              ),
              BkIconButton.ghost(
                key: const ValueKey('ride-summary-dismiss'),
                icon: Icon(LucideIcons.x, size: 20, color: cs.mutedForeground),
                label: l10n.a11yDismiss,
                onPressed: () => unawaited(core.rides.dismissSummary()),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(right: wide ? 4 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(12),
                _Numbers(summary: summary, scale: wide ? 1.4 : 1.25),
                if (summary.chart case final chart? when chart.hasPower || chart.hasHeartRate) ...[
                  const Gap(14),
                  SizedBox(height: 1, child: ColoredBox(color: cs.border)),
                  const Gap(12),
                  RideChartView(summary: summary, compact: true),
                ],
                if (wide)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: [
                        Expanded(child: _GearChanges(summary: summary)),
                        Button.ghost(
                          key: const ValueKey('ride-summary-discard'),
                          onPressed: () => _discard(context),
                          child: Text(l10n.healthRideDiscard, style: TextStyle(color: cs.mutedForeground)),
                        ),
                        const Gap(8),
                        RideExportMenuButton(ride: ride),
                        const Gap(8),
                        Button.secondary(
                          key: const ValueKey('ride-summary-details'),
                          onPressed: () => _details(context),
                          child: Text(l10n.ridesDetails),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (summary.gearChanges != null) ...[const Gap(10), _GearChanges(summary: summary)],
                ],
                if (core.rides.asksHealthQuestion) ...[const Gap(14), const _HealthQuestion()],
                if (!wide) ...[
                  const Gap(14),
                  Row(
                    children: [
                      Expanded(
                        child: BkPillButton.secondary(
                          key: const ValueKey('ride-summary-details'),
                          onPressed: () => _details(context),
                          child: Text(l10n.ridesDetails),
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: BkPillButton.secondary(
                          key: const ValueKey('ride-summary-export'),
                          onPressed: () => unawaited(showRideExportSheet(context, ride)),
                          child: Text(l10n.ridesExport),
                        ),
                      ),
                      const Gap(8),
                      BkTouchTarget(
                        child: BkIconButton.secondary(
                          key: const ValueKey('ride-summary-discard'),
                          icon: const Icon(LucideIcons.trash2, size: 19),
                          label: l10n.healthRideDiscard,
                          shape: ButtonShape.circle,
                          onPressed: () => _discard(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dauer · Distanz · Ø Leistung · Arbeit; Distanz only with a speed source.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.summary, required this.scale});

  final WorkoutSummary summary;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final locale = intl.Intl.getCurrentLocale();
    final units = unitSystemOf(context);
    final label = context.typography.xSmall.copyWith(color: cs.mutedForeground);
    Widget cell(String key, InlineSpan value, String caption, {int flex = 10}) => Expanded(
      flex: flex,
      child: Semantics(
        key: ValueKey('ride-summary-$key'),
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(value, maxLines: 1),
            ),
            const Gap(6),
            Text(caption, style: label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
    final km = summary.shownDistanceKm;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell(
          'duration',
          rideNumber(context, formatRideDuration(summary.activeDuration), scale: scale),
          l10n.miniWorkoutSummaryDuration,
          flex: 11,
        ),
        if (km != null)
          cell(
            'distance',
            rideNumber(context, formatRideDistance(km, units, locale), unit: units.distanceSymbol, scale: scale),
            l10n.miniWorkoutSummaryDistance,
          ),
        if (summary.avgPowerW > 0)
          cell(
            'power',
            rideNumber(context, '${summary.avgPowerW}', unit: 'W', prefix: 'Ø', scale: scale),
            l10n.sensorQuantityPower,
          ),
        cell('work', rideNumber(context, formatInt(summary.workKj, locale), unit: 'kJ', scale: scale), l10n.ridesWork),
      ],
    );
  }
}

class _GearChanges extends StatelessWidget {
  const _GearChanges({required this.summary});

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final count = summary.gearChanges;
    if (count == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final style = context.typography.small.copyWith(color: cs.mutedForeground);
    return Row(
      key: const ValueKey('ride-summary-gears'),
      children: [
        Icon(LucideIcons.arrowDownUp, size: 15, color: cs.mutedForeground),
        const Gap(6),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.foreground,
                    fontFeatures: BkNumerals.tabular,
                  ),
                ),
                TextSpan(text: ' ${context.i18n.ridesGearChangesNoun(count)}'),
              ],
            ),
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// "Fahrten in Apple Health speichern?" — asked once, on the first ride's
/// card. "Nein" is the filled default when the trainer app on this device
/// may already write the ride itself, with the duplicate hint.
class _HealthQuestion extends StatelessWidget {
  const _HealthQuestion();

  @override
  Widget build(BuildContext context) {
    final rides = core.rides;
    final store = rides.healthStore;
    if (store == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final name = healthStoreName(store, l10n);
    final defaultNo = rides.healthQuestionDefaultsToNo;
    final muted = context.typography.small.copyWith(color: cs.mutedForeground);

    Widget answer({required bool yes}) {
      final filled = yes != defaultNo;
      final text = Text(yes ? l10n.yes : l10n.no);
      void onPressed() => unawaited(rides.answerHealthQuestion(yes: yes));
      return Expanded(
        child: filled
            ? BkPillButton(key: ValueKey('ride-health-${yes ? 'yes' : 'no'}'), onPressed: onPressed, child: text)
            : BkPillButton.secondary(
                key: ValueKey('ride-health-${yes ? 'yes' : 'no'}'),
                onPressed: onPressed,
                child: text,
              ),
      );
    }

    return Container(
      key: const ValueKey('ride-health-question'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BkIconTile(icon: LucideIcons.heart),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ridesAskHealth(name),
                      style: context.typography.small.copyWith(fontWeight: FontWeight.w600, color: cs.foreground),
                    ),
                    const Gap(3),
                    Text(l10n.ridesAskHealthBody, style: muted),
                    if (rides.showsDuplicateHint) ...[
                      const Gap(8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(LucideIcons.info, size: 15, color: cs.mutedForeground),
                          ),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              l10n.ridesHealthDuplicateHint(rides.trainerApp()?.name ?? '', name),
                              style: muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Gap(12),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Row(
              children: defaultNo
                  ? [answer(yes: true), const Gap(8), answer(yes: false)]
                  : [answer(yes: false), const Gap(8), answer(yes: true)],
            ),
          ),
        ],
      ),
    );
  }
}
