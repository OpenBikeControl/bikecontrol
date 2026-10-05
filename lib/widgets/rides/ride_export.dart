import 'dart:async';
import 'dart:typed_data';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/rides/ride_files.dart';
import 'package:bike_control/services/rides/ride_format.dart';
import 'package:bike_control/services/workout/past_workout.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/units.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_pill_button.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The ways a ride leaves BikeControl, no Pro: the Health store (Apple
/// Health / Health Connect, where it exists), sharing the .fit, saving the
/// .fit, and on desktop the rides folder. The same actions back the Details
/// page's Export rows, the phone's export sheet and the desktop menu.
class RideExportActions {
  RideExportActions(this.context, this.ride, {this.onChanged});

  final BuildContext context;
  final PastWorkout ride;

  /// The ride after an export changed its bookkeeping.
  final ValueChanged<PastWorkout>? onChanged;

  static bool get isDesktop => HostPlatform.isMacOS || HostPlatform.isWindows || HostPlatform.isLinux;

  Future<void> toHealth() async {
    final rides = core.rides;
    if (!rides.healthReady) {
      await rides.installHealth();
      return;
    }
    onChanged?.call(await rides.exportToHealth(ride));
  }

  Future<void> share({Rect? origin}) async {
    try {
      final bytes = Uint8List.fromList(await core.rides.repository.readBytes(ride));
      if (await RideFileActions.instance.share(ride, bytes, origin: origin)) {
        onChanged?.call(await core.rides.markFitExported(ride));
      }
    } catch (e, s) {
      await recordError(e, s, context: 'RideExport.share');
    }
  }

  Future<void> save() async {
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = Uint8List.fromList(await core.rides.repository.readBytes(ride));
      final path = await RideFileActions.instance.save(ride, bytes, dialogTitle: l10n.ridesSaveFit);
      if (path == null) return;
      buildToast(title: l10n.ridesFitSaved);
      onChanged?.call(await core.rides.markFitExported(ride));
    } catch (e, s) {
      await recordError(e, s, context: 'RideExport.save');
    }
  }

  Future<void> openFolder() => openRidesFolder();

  /// The folder the rides' .fit files live in (desktop).
  static Future<void> openRidesFolder() async {
    try {
      await RideFileActions.instance.openFolder(await core.rides.repository.rootDirectory());
    } catch (e, s) {
      await recordError(e, s, context: 'RideExport.openFolder');
    }
  }
}

/// The Export rows: Health (a status once written, else the action or the
/// install), share and save the .fit, and on desktop the folder.
class RideExportRows extends StatelessWidget {
  const RideExportRows({super.key, required this.ride, this.onChanged, this.inSheet = false, this.header});

  final PastWorkout ride;
  final ValueChanged<PastWorkout>? onChanged;

  /// In the export sheet: the Health status row explains that deleting here
  /// leaves Health alone.
  final bool inSheet;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = RideExportActions(context, ride, onChanged: onChanged);
    final store = core.rides.healthStore;
    final saved = ride.summary?.savedToHealth ?? false;
    final storeName = store == null ? null : healthStoreName(store, l10n);
    return BkGroupedSection(
      key: const ValueKey('ride-export'),
      header: header,
      children: [
        if (store != null && storeName != null)
          if (saved)
            BkGroupedRow(
              key: const ValueKey('ride-export-health'),
              icon: LucideIcons.heart,
              title: storeName,
              subtitle: inSheet ? l10n.ridesHealthKeptNote : null,
              trailing: BkStatusDot(label: l10n.ridesInHealth(storeName)),
            )
          else
            BkGroupedRow(
              key: const ValueKey('ride-export-health'),
              icon: LucideIcons.heart,
              title: l10n.ridesSaveToHealth(storeName),
              subtitle: core.rides.healthReady ? l10n.ridesHealthFields : l10n.ridesHealthConnectNotInstalled,
              chevron: true,
              onPressed: () => unawaited(actions.toHealth()),
            ),
        Builder(
          builder: (rowContext) => BkGroupedRow(
            key: const ValueKey('ride-export-share'),
            icon: LucideIcons.share,
            title: l10n.miniWorkoutShareFit,
            subtitle: l10n.ridesShareFitSub,
            chevron: true,
            onPressed: () {
              final box = rowContext.findRenderObject() as RenderBox?;
              final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
              unawaited(actions.share(origin: origin));
            },
          ),
        ),
        BkGroupedRow(
          key: const ValueKey('ride-export-save'),
          icon: LucideIcons.download,
          title: l10n.ridesSaveFit,
          subtitle: HostPlatform.isIOS
              ? l10n.ridesSaveFitIos
              : HostPlatform.isAndroid
              ? l10n.ridesSaveFitAndroid
              : null,
          chevron: true,
          onPressed: () => unawaited(actions.save()),
        ),
        if (RideExportActions.isDesktop)
          BkGroupedRow(
            key: const ValueKey('ride-export-folder'),
            icon: LucideIcons.folder,
            title: l10n.miniWorkoutOpenFolder,
            chevron: true,
            onPressed: () => unawaited(actions.openFolder()),
          ),
      ],
    );
  }
}

/// "Exportieren" on a phone: the ride's line, the rows, Abbrechen.
Future<void> showRideExportSheet(BuildContext context, PastWorkout ride) {
  return openSheet(
    context: context,
    draggable: true,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => _RideExportSheet(ride: ride),
  );
}

class _RideExportSheet extends StatefulWidget {
  const _RideExportSheet({required this.ride});

  final PastWorkout ride;

  @override
  State<_RideExportSheet> createState() => _RideExportSheetState();
}

class _RideExportSheetState extends State<_RideExportSheet> {
  late PastWorkout _ride = widget.ride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.ridesExport,
                      style: context.typography.xLarge.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
                    ),
                  ),
                  const Gap(4),
                  Text(
                    rideOneLine(context, _ride),
                    style: context.typography.small.copyWith(
                      color: cs.mutedForeground,
                      fontFeatures: BkNumerals.tabular,
                    ),
                  ),
                ],
              ),
            ),
            RideExportRows(ride: _ride, inSheet: true, onChanged: (r) => setState(() => _ride = r)),
            const Gap(12),
            BkPillButton.secondary(onPressed: () => closeSheet(context), child: Text(l10n.cancel)),
          ],
        ),
      ),
    );
  }
}

/// "Heute · 42:18 · 29,4 km".
String rideOneLine(BuildContext context, PastWorkout ride) {
  final l10n = AppLocalizations.of(context);
  final locale = intl.Intl.getCurrentLocale();
  final s = ride.summary;
  final units = unitSystemOf(context);
  return [
    rideDayLabel(ride.startedAt, l10n, locale),
    if (s != null) formatRideDuration(s.activeDuration),
    if (s?.shownDistanceKm case final km?) '${formatRideDistance(km, units, locale)} ${units.distanceSymbol}',
  ].join(' · ');
}

/// "Exportieren ▾" on desktop: save, share and the folder in a menu (no
/// Health store on macOS or Windows).
class RideExportMenuButton extends StatelessWidget {
  const RideExportMenuButton({super.key, required this.ride, this.onChanged});

  final PastWorkout ride;
  final ValueChanged<PastWorkout>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;
    return Button.secondary(
      key: const ValueKey('ride-export-menu'),
      trailing: const Icon(LucideIcons.chevronDown, size: 16),
      onPressed: () {
        final actions = RideExportActions(context, ride, onChanged: onChanged);
        showDropdown(
          context: context,
          builder: (_) => DropdownMenu(
            children: [
              if (core.rides.healthStore != null && !(ride.summary?.savedToHealth ?? false))
                MenuButton(
                  leading: const Icon(LucideIcons.heart, size: 16),
                  onPressed: (_) => unawaited(actions.toHealth()),
                  child: Text(l10n.ridesSaveToHealth(healthStoreName(core.rides.healthStore!, l10n))),
                ),
              MenuButton(
                leading: const Icon(LucideIcons.download, size: 16),
                onPressed: (_) => unawaited(actions.save()),
                child: Text('${l10n.ridesSaveFit} …'),
              ),
              MenuButton(
                leading: const Icon(LucideIcons.share, size: 16),
                onPressed: (_) => unawaited(actions.share()),
                child: Text(l10n.miniWorkoutShareFit),
              ),
              if (RideExportActions.isDesktop) ...[
                const MenuDivider(),
                MenuButton(
                  leading: const Icon(LucideIcons.folder, size: 16),
                  onPressed: (_) => unawaited(actions.openFolder()),
                  child: Text(l10n.miniWorkoutOpenFolder),
                ),
              ],
            ],
          ),
        );
      },
      child: Text(l10n.ridesExport),
    );
  }
}
