import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/companion/companion_layout.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/gear_readout.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The name a ride-data tile goes by in the add list.
String companionTileName(AppLocalizations l, CompanionTileKind kind) => switch (kind) {
  CompanionTileKind.action || CompanionTileKind.music => '',
  CompanionTileKind.gear => l.rideGear,
  CompanionTileKind.power => l.sensorQuantityPower,
  CompanionTileKind.cadence => l.sensorQuantityCadence,
  CompanionTileKind.ratio => l.rideRatio,
  CompanionTileKind.ergTarget => l.overlayFieldErgTarget,
  CompanionTileKind.mode => l.companionTileMode,
  CompanionTileKind.rideCard => l.companionTileRideCard,
};

IconData companionTileIcon(CompanionTileKind kind) => switch (kind) {
  CompanionTileKind.action => LucideIcons.squareMousePointer,
  CompanionTileKind.gear => LucideIcons.cog,
  CompanionTileKind.power => LucideIcons.zap,
  CompanionTileKind.cadence => LucideIcons.rotateCw,
  CompanionTileKind.ratio => LucideIcons.chartSpline,
  CompanionTileKind.ergTarget => LucideIcons.target,
  CompanionTileKind.mode => LucideIcons.toggleLeft,
  CompanionTileKind.rideCard => LucideIcons.panelTop,
  CompanionTileKind.music => LucideIcons.music,
};

/// A ride-data tile: one reading of [definition], its label above and the
/// value as big as the tile allows. Nothing on it can be tapped. With no
/// virtual shifting session it shows "--".
class CompanionInfoTile extends StatelessWidget {
  const CompanionInfoTile({super.key, required this.kind, required this.definition});

  final CompanionTileKind kind;
  final FitnessBikeDefinition? definition;

  @override
  Widget build(BuildContext context) {
    final def = definition;
    if (kind == CompanionTileKind.rideCard) {
      return def == null ? _frame(context, companionTileName(context.l, kind), '--') : _RideCard(definition: def);
    }
    if (def == null) return _frame(context, _label(context, null), '--');
    return AnimatedBuilder(
      animation: Listenable.merge([
        def.currentGear,
        def.trainerMode,
        def.ergTargetPower,
        def.powerW,
        def.cadenceRpm,
        def.gearRatio,
        def.frontRing,
      ]),
      builder: (context, _) => _frame(context, _label(context, def), _value(def)),
    );
  }

  String _label(BuildContext context, FitnessBikeDefinition? def) {
    final l = context.l;
    final erg = def?.trainerMode.value == TrainerMode.ergMode;
    return switch (kind) {
      // The mode rides along with the gear: "GEAR · SIM", or "ERG" while the
      // number is the target.
      CompanionTileKind.gear => erg ? l.ergMode : '${l.rideGear} · ${l.simMode}',
      _ => companionTileName(l, kind),
    };
  }

  String _value(FitnessBikeDefinition def) {
    final erg = def.trainerMode.value == TrainerMode.ergMode;
    final target = def.ergTargetPower.value;
    return switch (kind) {
      CompanionTileKind.gear =>
        erg
            ? (target == null ? '--' : '$target W')
            : formatGearReadout(
                currentGear: def.currentGear.value,
                maxGear: def.maxGear,
                frontShiftEnabled: def.frontShiftEnabled,
                largeRing: def.frontRing.value == FrontRing.large,
              ),
      CompanionTileKind.power => def.powerW.value == null ? '-- W' : '${def.powerW.value} W',
      CompanionTileKind.cadence => def.cadenceRpm.value == null ? '-- rpm' : '${def.cadenceRpm.value} rpm',
      CompanionTileKind.ratio => erg ? '--' : formatGearRatio(def.gearRatio.value),
      CompanionTileKind.ergTarget => target == null ? '--' : '$target W',
      CompanionTileKind.mode => erg ? 'ERG' : 'SIM',
      _ => '',
    };
  }

  Widget _frame(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
          boxShadow: bkCardShadow(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A narrow tile shrinks the label rather than cut "GEAR · SIM".
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: context.typography.caption.copyWith(
                    color: cs.mutedForeground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    value,
                    key: ValueKey('companion-info-${kind.name}'),
                    style: kind == CompanionTileKind.gear
                        ? BkNumerals.gear(64, color: cs.foreground, height: 1.0)
                        : BkNumerals.display(56, color: cs.foreground, height: 1.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gear overlay's card, live, scaled to its tile. The −/+ stay off: the
/// page has its own buttons.
class _RideCard extends StatefulWidget {
  const _RideCard({required this.definition});

  final FitnessBikeDefinition definition;

  @override
  State<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<_RideCard> {
  late final ValueNotifier<TrainerOverlayState> _state = ValueNotifier(_read());
  late Listenable _live;

  FitnessBikeDefinition get _def => widget.definition;

  Listenable _listenTo(FitnessBikeDefinition d) => Listenable.merge([
    d.currentGear,
    d.gearRatio,
    d.trainerMode,
    d.ergTargetPower,
    d.powerW,
    d.cadenceRpm,
    d.frontRing,
  ]);

  @override
  void initState() {
    super.initState();
    _live = _listenTo(_def)..addListener(_refresh);
  }

  @override
  void didUpdateWidget(_RideCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition != widget.definition) {
      _live.removeListener(_refresh);
      _live = _listenTo(_def)..addListener(_refresh);
      _refresh();
    }
  }

  @override
  void dispose() {
    _live.removeListener(_refresh);
    _state.dispose();
    super.dispose();
  }

  TrainerOverlayState _read() => TrainerOverlayState(
    gear: _def.currentGear.value,
    maxGear: _def.maxGear,
    gearRatio: _def.gearRatio.value,
    mode: _def.trainerMode.value,
    powerW: _def.powerW.value,
    cadenceRpm: _def.cadenceRpm.value,
    ergTargetW: _def.ergTargetPower.value,
    fields: {...core.settings.getOverlayFields()}..remove(OverlayField.controls),
    frontShiftEnabled: _def.frontShiftEnabled,
    frontRingLarge: _def.frontRing.value == FrontRing.large,
  );

  void _refresh() => _state.value = _read();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: ValueListenableBuilder<TrainerOverlayState>(
          valueListenable: _state,
          builder: (context, s, child) =>
              SizedBox(width: TrainerOverlayView.fitWindowSizeOf(context, s, drag: false).width, child: child),
          child: TrainerOverlayView(state: _state, pill: true),
        ),
      ),
    );
  }
}

extension on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
}
