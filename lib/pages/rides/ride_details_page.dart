import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/services/workout/workout_summary.dart';
import 'package:bike_control/main.dart' show navigatorKey, recordError;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/rides/ride_breakdown.dart';
import 'package:bike_control/widgets/rides/ride_chart.dart';
import 'package:bike_control/widgets/rides/ride_export.dart';
import 'package:bike_control/widgets/rides/ride_stats.dart';
import 'package:bike_control/widgets/rides/ride_zone_settings.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkComponentThemes;
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One ride: when, its values, power, heart rate, cadence and gear over
/// time, time in each gear, power and heart rate zones (once FTP / max heart
/// rate are set), and the ways it leaves BikeControl. Delete sits in the ⋯
/// menu, not under Export.
class RideDetailsPage extends StatefulWidget {
  const RideDetailsPage({super.key, required this.ride});

  final PastWorkout ride;

  @override
  State<RideDetailsPage> createState() => _RideDetailsPageState();
}

class _RideDetailsPageState extends State<RideDetailsPage> {
  late PastWorkout _ride = widget.ride;

  @override
  void initState() {
    super.initState();
    core.rides.ridesVersion.addListener(_reload);
  }

  @override
  void dispose() {
    core.rides.ridesVersion.removeListener(_reload);
    super.dispose();
  }

  /// An export elsewhere (the summary card's sheet) changed the ride.
  Future<void> _reload() async {
    try {
      final fresh = await core.rides.repository.find(_ride.fileName);
      if (fresh != null && mounted) setState(() => _ride = fresh);
    } catch (e, s) {
      await recordError(e, s, context: 'RideDetails.reload');
    }
  }

  Future<void> _delete() async {
    if (!await confirmRideDelete(context)) return;
    try {
      await core.rides.delete(_ride);
    } catch (e, s) {
      await recordError(e, s, context: 'RideDetails.delete');
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final summary = _ride.summary;
    final locale = Intl.getCurrentLocale();
    // The ⋯ menu and the export sheet open as drawers on a phone: they need
    // a DrawerOverlay, and the context under it.
    return DrawerOverlay(child: Builder(builder: (context) => _page(context, l10n, cs, summary, locale)));
  }

  Widget _page(BuildContext context, AppLocalizations l10n, ColorScheme cs, WorkoutSummary? summary, String locale) {
    return Scaffold(
      headers: [
        BkPageHeader(
          title: l10n.ridesRideTitle,
          actions: [
            // The button's own context: the dropdown anchors to it.
            Builder(
              builder: (anchor) => BkIconButton.ghost(
                key: const ValueKey('ride-details-more'),
                icon: const Icon(LucideIcons.ellipsisVertical, size: 22),
                label: l10n.a11yMoreOptions,
                tooltip: false,
                onPressed: () => showDropdown(
                  context: anchor,
                  builder: (_) => DropdownMenu(
                    children: [
                      MenuButton(
                        key: const ValueKey('ride-details-delete'),
                        leading: Icon(LucideIcons.trash2, size: 16, color: cs.destructive),
                        onPressed: (_) => unawaited(_delete()),
                        child: Text(l10n.delete, style: TextStyle(color: cs.destructive)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: BkPageColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rideDayTitle(_ride.startedAt, l10n, locale),
                      style: context.typography.xLarge.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.4),
                    ),
                    if (summary != null) ...[
                      const Gap(4),
                      Text(
                        '${formatRideClockRange(summary, locale)} · '
                        '${formatRideDuration(summary.activeDuration)} ${l10n.ridesMoving}',
                        style: context.typography.base.copyWith(
                          color: cs.mutedForeground,
                          fontFeatures: BkNumerals.tabular,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (summary != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 0, BkGroupedSection.inset, 6),
                  child: BkGroupedHeader(l10n.ridesValues),
                ),
                RideStatGrid(summary: summary),
                if (summary.chart case final chart?
                    when chart.hasPower || chart.hasHeartRate || chart.hasCadence || chart.hasGear) ...[
                  const Gap(24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 0, BkGroupedSection.inset, 6),
                    child: BkGroupedHeader(l10n.ridesTimeline),
                  ),
                  Container(
                    key: const ValueKey('ride-details-chart'),
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                    decoration: BoxDecoration(
                      color: cs.card,
                      borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
                      boxShadow: bkCardShadow(context),
                    ),
                    child: RideChartView(summary: summary),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(BkGroupedSection.inset, 6, BkGroupedSection.inset, 0),
                    child: Text(
                      l10n.ridesChartLegend,
                      style: context.typography.caption.copyWith(color: cs.mutedForeground),
                    ),
                  ),
                  if (chart.hasGear) ...[const Gap(24), RideGearTime(chart: chart)],
                  _zones(context, l10n, chart),
                ],
                const Gap(24),
              ],
              RideExportRows(
                ride: _ride,
                header: l10n.ridesExport,
                onChanged: (r) => setState(() => _ride = r),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Power and heart rate zones, for the series the ride has: the zones once
/// the FTP / max heart rate is set (redrawn when it changes), else one quiet
/// line that opens the setting.
Widget _zones(BuildContext context, AppLocalizations l10n, RideChart chart) {
  final prefs = core.rides.prefs;
  return ListenableBuilder(
    listenable: prefs,
    builder: (context, _) {
      final ftp = prefs.ftpWatts;
      final maxHr = prefs.maxHeartRateBpm;
      final prompts = [
        if (chart.hasPower && ftp == null)
          RideZonePrompt(
            key: const ValueKey('ride-zone-prompt-ftp'),
            label: l10n.ridesSetFtpForZones,
            field: const RideFtpField(),
          ),
        if (chart.hasHeartRate && maxHr == null)
          RideZonePrompt(
            key: const ValueKey('ride-zone-prompt-max-heart-rate'),
            label: l10n.ridesSetMaxHeartRateForZones,
            field: const RideMaxHeartRateField(),
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chart.hasPower && ftp != null) ...[
            const Gap(24),
            RidePowerZones(
              chart: chart,
              ftpWatts: ftp,
              editor: (onDone) => RideFtpField(autofocus: true, onDone: onDone),
            ),
          ],
          if (chart.hasHeartRate && maxHr != null) ...[
            const Gap(24),
            RideHeartRateZones(
              chart: chart,
              maxHeartRateBpm: maxHr,
              editor: (onDone) => RideMaxHeartRateField(autofocus: true, onDone: onDone),
            ),
          ],
          if (prompts.isNotEmpty) ...[const Gap(16), ...prompts],
        ],
      );
    },
  );
}

/// "Fahrt löschen?": true when the rider confirmed. Says that what is
/// already in Health stays there.
Future<bool> confirmRideDelete(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final store = core.rides.healthStore;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.ridesDeleteTitle),
      content: Text(
        store == null ? l10n.ridesDeleteBodyNoHealth : l10n.ridesDeleteBody(healthStoreName(store, l10n)),
      ),
      actions: [
        BkTouchTarget(
          child: Button.secondary(
            alignment: Alignment.center,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
        ),
        BkTouchTarget(
          child: Button.destructive(
            alignment: Alignment.center,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// A ride's notification was tapped: its Details, over whatever is open.
/// Other notifications (and a ride deleted since) are ignored.
Future<void> openRideFromNotification(String? payload, {NavigatorState? navigator}) async {
  final name = rideFileFromPayload(payload);
  if (name == null) return;
  try {
    final ride = await core.rides.repository.find(name);
    final nav = navigator ?? navigatorKey.currentState;
    if (ride == null || nav == null) return;
    unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => RideDetailsPage(ride: ride))));
  } catch (e, s) {
    await recordError(e, s, context: 'RideDetails.fromNotification');
  }
}
