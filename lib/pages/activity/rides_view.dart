import 'dart:async';
import 'dart:math' as math;

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/activity/activity_log.dart' show ActivityGroupCaption;
import 'package:bike_control/pages/rides/ride_details_page.dart';
import 'package:bike_control/pages/shell/app_shell.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/units.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/rides/ride_export.dart';
import 'package:bike_control/widgets/ui/app_theme.dart' show BkBrandColors;
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/bk_touch_target.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart' as intl;
import 'package:bike_control/widgets/menu.dart' show SectionMenuButton;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// One calendar week (Monday start) of rides, newest first.
class RideWeek {
  RideWeek({required this.monday, required this.rides});

  final DateTime monday;
  final List<PastWorkout> rides;

  int get count => rides.length;

  /// Moving time of the week's rides.
  Duration get total => rides.fold(Duration.zero, (sum, r) => sum + (r.summary?.activeDuration ?? Duration.zero));
}

DateTime _mondayOf(DateTime d) {
  final local = d.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Rides grouped by calendar week, newest week and ride first.
List<RideWeek> groupRidesByWeek(List<PastWorkout> rides) {
  final sorted = [...rides]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final weeks = <RideWeek>[];
  for (final ride in sorted) {
    final monday = _mondayOf(ride.startedAt);
    if (weeks.isEmpty || weeks.last.monday != monday) {
      weeks.add(RideWeek(monday: monday, rides: []));
    }
    weeks.last.rides.add(ride);
  }
  return weeks;
}

/// "Diese Woche", "Letzte Woche", else the week's dates ("22.–28. Sept.").
String rideWeekLabel(RideWeek week, AppLocalizations l10n, String locale, {DateTime? now}) {
  final thisMonday = _mondayOf(now ?? DateTime.now());
  if (week.monday == thisMonday) return l10n.ridesThisWeek;
  if (week.monday == thisMonday.subtract(const Duration(days: 7))) return l10n.ridesLastWeek;
  final sunday = week.monday.add(const Duration(days: 6));
  final monthFirst = intl.DateFormat.MMMd(locale).pattern?.trimLeft().startsWith('M') ?? false;
  if (week.monday.month == sunday.month) {
    return monthFirst
        ? '${intl.DateFormat.MMMd(locale).format(week.monday)}–${intl.DateFormat.d(locale).format(sunday)}'
        // The day as this locale writes it before the month ("21.", "21").
        : '${intl.DateFormat.MMMd(locale).format(week.monday).split(' ').first}–${intl.DateFormat.MMMd(locale).format(sunday)}';
  }
  return '${intl.DateFormat.MMMd(locale).format(week.monday)} – ${intl.DateFormat.MMMd(locale).format(sunday)}';
}

/// Activity → Rides: the saved rides by week, with week totals; a row per
/// ride (when, duration · distance · Ø W, a power sparkline, where it already
/// went). Tap opens Details; swipe left (phone) or the row's ⋯ / a long press
/// deletes.
class RidesView extends StatefulWidget {
  const RidesView({super.key, this.desktop = false});

  /// Rows carry a ⋯ menu on hover instead of the swipe.
  final bool desktop;

  @override
  State<RidesView> createState() => _RidesViewState();
}

class _RidesViewState extends State<RidesView> {
  late Future<List<PastWorkout>> _rides = core.rides.list();

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

  void _reload() {
    if (!mounted) return;
    setState(() {
      _rides = core.rides.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PastWorkout>>(
      future: _rides,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          unawaited(recordError(snapshot.error!, snapshot.stackTrace ?? StackTrace.current, context: 'RidesView.list'));
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        final rides = snapshot.data!;
        if (rides.isEmpty) return const RidesEmptyState();
        final l10n = AppLocalizations.of(context);
        final locale = intl.Intl.getCurrentLocale();
        final weeks = groupRidesByWeek(rides);
        return Column(
          key: const ValueKey('rides-list'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, week) in weeks.indexed) ...[
              if (i > 0) const Gap(20),
              BkGroupedSection(
                key: ValueKey('rides-week-${week.monday.toIso8601String()}'),
                header: rideWeekLabel(week, l10n, locale),
                headerTrailing: Text(
                  '${l10n.ridesCount(week.count)} · ${formatRideTotal(week.total)}',
                  style: context.typography.small.copyWith(
                    color: Theme.of(context).colorScheme.mutedForeground,
                    fontFeatures: BkNumerals.tabular,
                  ),
                ),
                dividerIndent: BkGroupedSection.inset,
                children: [for (final ride in week.rides) _RideRow(ride: ride, desktop: widget.desktop)],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RideRow extends StatefulWidget {
  const _RideRow({required this.ride, required this.desktop});

  final PastWorkout ride;
  final bool desktop;

  @override
  State<_RideRow> createState() => _RideRowState();
}

class _RideRowState extends State<_RideRow> {
  bool _hovered = false;

  PastWorkout get ride => widget.ride;

  void _open() => unawaited(context.push(RideDetailsPage(ride: ride)));

  Future<bool> _delete() async {
    if (!await confirmRideDelete(context)) return false;
    try {
      await core.rides.delete(ride);
      return true;
    } catch (e, s) {
      await recordError(e, s, context: 'Rides.delete');
      return false;
    }
  }

  void _menu(BuildContext anchor) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDropdown(
      context: anchor,
      builder: (_) => DropdownMenu(
        children: [
          MenuButton(
            leading: const Icon(LucideIcons.arrowRight, size: 16),
            onPressed: (_) => _open(),
            child: Text(l10n.ridesDetails),
          ),
          MenuButton(
            leading: const Icon(LucideIcons.share, size: 16),
            onPressed: (_) => unawaited(showRideExportSheet(context, ride)),
            child: Text(l10n.ridesExport),
          ),
          const MenuDivider(),
          MenuButton(
            key: const ValueKey('ride-row-delete'),
            leading: Icon(LucideIcons.trash2, size: 16, color: cs.destructive),
            onPressed: (_) => unawaited(_delete()),
            child: Text(l10n.delete, style: TextStyle(color: cs.destructive)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final locale = intl.Intl.getCurrentLocale();
    final units = unitSystemOf(context);
    final s = ride.summary;
    final start = ride.startedAt.toLocal();
    final clock = intl.DateFormat.Hm(locale).format(start);
    final day = rideDayLabel(ride.startedAt, l10n, locale);
    final relative = day == l10n.ridesToday || day == l10n.ridesYesterday;
    final title = relative ? '$day, $clock' : '$day · $clock';
    final sub = s == null
        ? null
        : [
            formatRideDuration(s.activeDuration),
            if (s.shownDistanceKm case final km?) '${formatRideDistance(km, units, locale)} ${units.distanceSymbol}',
            if (s.avgPowerW > 0) 'Ø ${s.avgPowerW} W',
          ].join(' · ');
    final muted = context.typography.small.copyWith(color: cs.mutedForeground, fontFeatures: BkNumerals.tabular);

    final row = BkTappable(
      key: ValueKey('ride-row-${ride.fileName}'),
      onPressed: _open,
      onLongPress: widget.desktop ? null : () => _menu(context),
      onHover: (h) => setState(() => _hovered = h),
      label: [title, ?sub].join(', '),
      child: Container(
        color: _hovered ? bkCardHover(context) : cs.card,
        constraints: BoxConstraints(minHeight: widget.desktop ? 52 : 58),
        padding: EdgeInsets.fromLTRB(16, 10, widget.desktop ? 8 : 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: context.typography.base.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.16,
                      fontFeatures: BkNumerals.tabular,
                    ),
                  ),
                  if (sub != null) ...[const Gap(3), Text(sub, style: muted)],
                ],
              ),
            ),
            const Gap(12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s?.chart?.power case final power? when power.any((v) => v != null))
                  ExcludeSemantics(
                    child: CustomPaint(size: const Size(64, 22), painter: _Spark(power, cs.primary)),
                  ),
                if (_badges(context) case final badges?) ...[const Gap(5), badges],
              ],
            ),
            if (widget.desktop)
              Visibility.maintain(
                visible: _hovered,
                child: Builder(
                  builder: (anchor) => BkIconButton.ghost(
                    key: ValueKey('ride-row-more-${ride.fileName}'),
                    icon: const Icon(LucideIcons.ellipsis, size: 17),
                    label: l10n.a11yMoreOptions,
                    tooltip: false,
                    onPressed: () => _menu(anchor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (widget.desktop) return row;
    return Dismissible(
      key: ValueKey('ride-swipe-${ride.fileName}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _delete(),
      background: Container(
        color: cs.destructive,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The theme's ink on destructive fills (white in both themes).
            // ignore: deprecated_member_use
            Icon(LucideIcons.trash2, size: 19, color: cs.destructiveForeground),
            const Gap(4),
            Text(
              l10n.delete,
              // ignore: deprecated_member_use
              style: context.typography.small.copyWith(color: cs.destructiveForeground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      child: row,
    );
  }

  Widget? _badges(BuildContext context) {
    final s = ride.summary;
    if (s == null || (!s.savedToHealth && !s.fitExported)) return null;
    final cs = Theme.of(context).colorScheme;
    final style = context.typography.xSmall.copyWith(color: cs.mutedForeground, fontWeight: FontWeight.w500);
    Widget badge(IconData icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.mutedForeground),
        const Gap(3),
        Text(label, style: style),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (s.savedToHealth) badge(LucideIcons.heart, AppLocalizations.of(context).ridesBadgeHealth),
        if (s.fitExported) badge(LucideIcons.share, '.fit'),
      ],
    );
  }
}

/// Power over the ride as shape only: one accent line, no axes (the numbers
/// are in the row).
class _Spark extends CustomPainter {
  _Spark(this.power, this.color);

  final List<int?> power;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const points = 40;
    final step = math.max(1, (power.length / points).ceil());
    final buckets = <double?>[];
    for (var i = 0; i < power.length; i += step) {
      final slice = power.sublist(i, math.min(power.length, i + step)).whereType<int>();
      buckets.add(slice.isEmpty ? null : slice.reduce((a, b) => a + b) / slice.length);
    }
    final values = buckets.whereType<double>();
    if (values.isEmpty) return;
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final span = hi - lo == 0 ? 1 : hi - lo;
    final path = Path();
    var pen = false;
    for (var i = 0; i < buckets.length; i++) {
      final v = buckets[i];
      if (v == null) {
        pen = false;
        continue;
      }
      final x = buckets.length == 1 ? 0.0 : i / (buckets.length - 1) * size.width;
      final y = size.height - 2 - (v - lo) / span * (size.height - 4);
      pen ? path.lineTo(x, y) : path.moveTo(x, y);
      pen = true;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Spark old) => old.power != power || old.color != color;
}

/// Before the first ride: how it works ("just pedal"), or with automatic
/// recording off, the manual start.
class RidesEmptyState extends StatelessWidget {
  const RidesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final brand = BkBrandColors.of(context);
    return ListenableBuilder(
      listenable: core.rides.changes,
      builder: (context, _) {
        final rides = core.rides;
        final manual = !rides.autoRecord;
        return Padding(
          key: const ValueKey('rides-empty'),
          padding: EdgeInsets.fromLTRB(28, isCompactWindow(context) ? 64 : 40, 28, 24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: brand.tileWash, borderRadius: BorderRadius.circular(18)),
                child: Icon(LucideIcons.bike, size: 30, color: brand.tileInk),
              ),
              const Gap(20),
              Text(
                l10n.ridesEmptyTitle,
                textAlign: TextAlign.center,
                style: context.typography.large.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
              ),
              const Gap(8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  manual ? l10n.ridesEmptyBodyManual : l10n.ridesEmptyBody,
                  textAlign: TextAlign.center,
                  style: context.typography.base.copyWith(color: cs.mutedForeground),
                ),
              ),
              if (manual) ...[
                const Gap(24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: BkPillButton.secondary(
                    key: const ValueKey('rides-empty-start'),
                    leading: const Icon(LucideIcons.circleDot, size: 18),
                    onPressed: rides.canStartManually
                        ? () {
                            if (rides.startManual()) ShellScope.maybeOf(context)?.select(AppSection.ride);
                          }
                        : null,
                    child: Text(l10n.miniWorkoutStart),
                  ),
                ),
                if (!rides.canStartManually) ...[
                  const Gap(8),
                  Text(
                    l10n.miniWorkoutNoTrainerConnected,
                    textAlign: TextAlign.center,
                    style: context.typography.small.copyWith(color: cs.mutedForeground),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Activity's ⋯ on the Rides segment (phone) / "Alle löschen" beside the
/// pane tabs (desktop): delete every ride, after saying what stays in Health.
Future<void> confirmDeleteAllRides(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final rides = await core.rides.list();
  if (rides.isEmpty || !context.mounted) return;
  final store = core.rides.healthStore;
  final body = [
    l10n.ridesDeleteAllBodyNoHealth(rides.length),
    if (store != null) l10n.ridesHealthStaysNote(healthStoreName(store, l10n)),
  ].join(' ');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.ridesDeleteAllTitle),
      content: Text(body),
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
            key: const ValueKey('rides-delete-all-confirm'),
            alignment: Alignment.center,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.ridesDeleteAll),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await core.rides.deleteAll();
  } catch (e, s) {
    await recordError(e, s, context: 'Rides.deleteAll');
  }
}

/// The phone's ⋮ in Activity's top bar while Rides shows: the folder (on a
/// desktop-sized phone layout) and "Alle löschen", plus the developer tools
/// in debug builds, all in the bar's one menu.
class RidesMenuButton extends StatelessWidget {
  const RidesMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;
    final cs = Theme.of(context).colorScheme;
    return SectionMenuButton(
      key: const ValueKey('rides-menu'),
      items: (context) => [
        if (RideExportActions.isDesktop) ...[
          MenuButton(
            leading: const Icon(LucideIcons.folder, size: 16),
            onPressed: (_) => unawaited(RideExportActions.openRidesFolder()),
            child: Text(l10n.miniWorkoutOpenFolder),
          ),
          const MenuDivider(),
        ],
        MenuButton(
          key: const ValueKey('rides-delete-all'),
          leading: Icon(LucideIcons.trash2, size: 16, color: cs.destructive),
          onPressed: (_) => unawaited(confirmDeleteAllRides(context)),
          child: Text(l10n.ridesDeleteAll, style: TextStyle(color: cs.destructive)),
        ),
      ],
    );
  }
}

/// The desktop pane's caption tabs: FAHRTEN · NEUIGKEITEN, the same caps on
/// the same baseline as the log's caption, "Alle löschen" trailing on Rides.
class ActivityPaneTabs extends StatelessWidget {
  const ActivityPaneTabs({super.key, required this.shell});

  final ShellController shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<ActivityTab>(
      valueListenable: shell.paneTab,
      builder: (context, tab, _) {
        Widget tabLabel(ActivityTab value, String text) {
          final on = tab == value;
          return BkTappable(
            key: ValueKey('activity-pane-tab-${value.name}'),
            label: text,
            selected: on,
            inMutuallyExclusiveGroup: true,
            excludeChildSemantics: true,
            onPressed: () => shell.paneTab.value = value,
            child: Stack(
              children: [
                ActivityGroupCaption(title: text, color: on ? cs.foreground : cs.mutedForeground),
                // The indicator sits inside the caption's own bottom space, so
                // the tabs are exactly as tall as the log's caption.
                if (on)
                  Positioned(
                    left: BkGroupedSection.inset,
                    right: BkGroupedSection.inset,
                    bottom: 0,
                    height: 2,
                    child: ColoredBox(color: cs.primary),
                  ),
              ],
            ),
          );
        }

        return Stack(
          key: const ValueKey('activity-pane-tabs'),
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 0, right: 0, bottom: 0, height: 1, child: ColoredBox(color: cs.border)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                tabLabel(ActivityTab.rides, l10n.ridesTab),
                tabLabel(ActivityTab.news, l10n.activityTabNews),
                const Spacer(),
              ],
            ),
            if (tab == ActivityTab.rides)
              Positioned(
                right: 0,
                bottom: -6,
                child: Button.ghost(
                  key: const ValueKey('rides-delete-all-pane'),
                  onPressed: () => unawaited(confirmDeleteAllRides(context)),
                  child: Text(
                    l10n.ridesDeleteAll,
                    style: context.typography.small.copyWith(color: cs.destructive, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
