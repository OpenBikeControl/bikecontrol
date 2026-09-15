import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/sensors/ble_sensor_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/proxy_device_details/metric_card.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/services/sensors/sensor_source.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/units.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:prop/prop.dart' show LogLevel;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The 2×2 live-metrics "signals grid" — POWER / HEART / CADENCE / SPEED —
/// and, per the Claude Design system spec, the app's ONE sensor surface: each
/// of the first three tiles grows an optional inline source control (see
/// `MetricSourceOption`) that both shows where the reading is coming from and
/// lets the rider pick a different one directly on the tile — no picker
/// sheet, no dropdown.
///
/// [device] is optional so this section also works in standalone mode — a
/// rider who has never bridged a trainer still needs somewhere to pick a
/// heart rate strap. When present, its own live telemetry is ONE input among
/// several: `core.sensors` (the external-sensor selection) always wins when
/// it resolves to a value, and the trainer is the fallback both when nothing
/// is selected and when a selection has gone stale — see `_quantityCard`.
///
/// A rider with no external sensors sees every tile render exactly as it did
/// before this feature existed: "--" and nothing else, no new affordance.
/// [_sourceOptionsFor] enforces this by returning null (no control at all)
/// whenever a quantity has no possible source besides the trainer. See
/// [hideWhenDeviceHasNoMetrics] for the one other pixel-fidelity case this
/// section has to preserve: a trainer present but not yet reporting anything.
class LiveMetricsSection extends StatefulWidget {
  final ProxyDevice? device;

  /// True on `ProxyDeviceDetailsPage`'s call site only — preserves this
  /// section's pre-existing behavior there exactly: a trainer that is
  /// present but has nothing to report yet (not connected, or connected
  /// without a parsed fitness definition) renders nothing at all, so a
  /// rider looking at THAT trainer's own page never sees a "--"-filled grid
  /// where there used to be nothing (see `build`).
  ///
  /// The home page's mount leaves this false: unlike a per-trainer page, it
  /// is reachable with no trainer bridged at all, so it is the only route
  /// standalone mode has to the source control — it must always render.
  final bool hideWhenDeviceHasNoMetrics;

  const LiveMetricsSection({super.key, this.device, this.hideWhenDeviceHasNoMetrics = false});

  @override
  State<LiveMetricsSection> createState() => _LiveMetricsSectionState();
}

class _LiveMetricsSectionState extends State<LiveMetricsSection> {
  late StreamSubscription<BaseDevice> _connectionSub;

  /// The exact `HealthKitSensorSource` instance [_onHealthKitModeChanged] is
  /// subscribed to — kept so [dispose] removes the listener from the SAME
  /// instance even if `core.connection.healthKitSource` gets swapped or
  /// cleared meanwhile (tests reassign it directly; production never does,
  /// but nothing here assumes that).
  HealthKitSensorSource? _healthKitModeListenerSource;

  @override
  void initState() {
    super.initState();
    // A source control's candidate list (registered + nearby sensors) and
    // "connecting" vs "connected" state can change independently of the
    // `ValueListenable`s the cards already bind to — e.g. a nearby strap
    // appearing makes an omitted control appear, and a fresh registration
    // flips "connecting" to "connected" without `droppedOut` ever changing
    // (it can already be false for both, per `SensorHub.select`'s not-found
    // branch). Mirrors the listener the deleted `SensorQuantitySelector` used
    // for the same reason.
    _connectionSub = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
    // `connectHealthKit`/HealthKit sample delivery do not emit on
    // `connectionStream` (that stream is BLE-device events only), so a mode
    // flip — session <-> passive, most importantly, which flips the passive
    // subtitle text on an already-selected row — needs its own listener.
    _healthKitModeListenerSource = core.connection.healthKitSource;
    _healthKitModeListenerSource?.mode.addListener(_onHealthKitModeChanged);
  }

  void _onHealthKitModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectionSub.cancel();
    _healthKitModeListenerSource?.mode.removeListener(_onHealthKitModeChanged);
    super.dispose();
  }

  _LiveMetrics? _metrics() {
    final device = widget.device;
    if (device == null) return null;
    final proxyDef = device.emulator.composite.firstOfType<ProxyBikeDefinition>();
    if (proxyDef != null) {
      return _LiveMetrics(
        power: proxyDef.powerW,
        heartRate: proxyDef.heartRateBpm,
        cadence: proxyDef.cadenceRpm,
        speed: proxyDef.speedKph,
      );
    }
    final fitnessDef = device.fitnessBike;
    if (fitnessDef != null) {
      return _LiveMetrics(
        power: fitnessDef.powerW,
        heartRate: fitnessDef.heartRateBpm,
        cadence: fitnessDef.cadenceRpm,
        speed: fitnessDef.speedKph,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final metrics = _metrics();
    // A device that is present but has nothing to report (not yet connected,
    // or connected without a parsed fitness definition) renders nothing at
    // all — exactly what this section rendered before it knew about sensors,
    // for exactly this case. Only [device] being entirely absent (standalone
    // mode; impossible under the old, non-nullable signature) is new: THAT
    // case always renders the grid, "--" placeholders and all, since it is
    // the only route standalone mode has to the source control at all.
    if (device != null && metrics == null && widget.hideWhenDeviceHasNoMetrics) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final units = unitSystemOf(context);

    return Column(
      spacing: 10,
      children: [
        _EqualHeightRow(
          spacing: 10,
          children: [
            _quantityCard(
              context: context,
              l10n: l10n,
              quantity: SensorQuantity.power,
              icon: LucideIcons.zap,
              iconColor: const Color(0xFFF59E0B),
              label: l10n.powerLabel,
              unit: 'W',
              trainerValue: metrics?.power,
            ),
            _quantityCard(
              context: context,
              l10n: l10n,
              quantity: SensorQuantity.heartRate,
              icon: LucideIcons.heart,
              iconColor: const Color(0xFFEF4444),
              label: l10n.heartLabel,
              unit: 'bpm',
              trainerValue: metrics?.heartRate,
            ),
          ],
        ),
        _EqualHeightRow(
          spacing: 10,
          children: [
            _quantityCard(
              context: context,
              l10n: l10n,
              quantity: SensorQuantity.cadence,
              icon: LucideIcons.rotateCw,
              iconColor: const Color(0xFF8B5CF6),
              label: l10n.cadenceLabel,
              unit: 'rpm',
              trainerValue: metrics?.cadence,
            ),
            _speedCard(context, l10n, units, metrics?.speed),
          ],
        ),
      ],
    );
  }

  /// POWER / HEART / CADENCE: value is the external-sensor selection when it
  /// resolves, else this trainer's own reading (present-but-no-device and
  /// no-selection both collapse to null, i.e. "--" — unchanged from before
  /// this feature). Also renders the optional inline source control for this
  /// quantity.
  Widget _quantityCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required SensorQuantity quantity,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String unit,
    required ValueListenable<int?>? trainerValue,
  }) {
    return ValueListenableBuilder<int?>(
      valueListenable: core.sensors.resolved(quantity),
      builder: (context, external, _) {
        Widget withDeviceValue(int? deviceReading) {
          final value = external ?? deviceReading;
          return ValueListenableBuilder<bool>(
            valueListenable: core.sensors.droppedOut(quantity),
            builder: (context, droppedOut, _) => MetricCard(
              key: Key('metric-card-${quantity.name}'),
              icon: icon,
              iconColor: iconColor,
              label: label,
              value: value?.toString(),
              unit: unit,
              sources: _sourceOptionsFor(l10n, quantity, droppedOut),
            ),
          );
        }

        if (trainerValue == null) return withDeviceValue(null);
        return ValueListenableBuilder<int?>(
          valueListenable: trainerValue,
          builder: (context, deviceReading, _) => withDeviceValue(deviceReading),
        );
      },
    );
  }

  /// SPEED never gets a source control: no sensor in this codebase provides
  /// it (see `BleSensorSource`'s fixed set of characteristics), so a control
  /// that could only ever say "Trainer" would be noise. Reads straight off
  /// the trainer, exactly as before this feature.
  Widget _speedCard(BuildContext context, AppLocalizations l10n, UnitSystem units, ValueListenable<double?>? speed) {
    if (speed == null) {
      return MetricCard(
        key: const Key('metric-card-speed'),
        icon: LucideIcons.gauge,
        iconColor: const Color(0xFF0EA5E9),
        label: l10n.speedLabel,
        value: null,
        unit: units.speedSymbol,
      );
    }
    return ValueListenableBuilder<double?>(
      valueListenable: speed,
      builder: (context, v, _) => MetricCard(
        key: const Key('metric-card-speed'),
        icon: LucideIcons.gauge,
        iconColor: const Color(0xFF0EA5E9),
        label: l10n.speedLabel,
        value: v == null ? null : units.fromKph(v).toStringAsFixed(1),
        unit: units.speedSymbol,
      ),
    );
  }

  /// [quantity]'s full source-list option set — Trainer first, then every
  /// sensor known to provide it, connected or not — or null to omit the
  /// control entirely: the tile-level invariant that a rider with no
  /// candidate sources at all (nothing registered, nothing nearby, nothing
  /// ever selected) must see no control, full stop. Once something HAS been
  /// selected the control stays, regardless of live candidate visibility, so
  /// the rider can always see what they picked and switch back to Trainer
  /// even if that sensor is currently out of range (the trailing "ghost"
  /// branch below).
  List<MetricSourceOption>? _sourceOptionsFor(AppLocalizations l10n, SensorQuantity quantity, bool droppedOut) {
    final selectedId = core.sensors.selectionFor(quantity);
    final candidates = _candidatesFor(quantity);
    if (selectedId == null && candidates.isEmpty) return null;

    final options = <MetricSourceOption>[
      MetricSourceOption(
        id: 'trainer',
        label: l10n.sensorSourceTrainer,
        subtitle: l10n.sensorSourceTrainerSubtitle,
        state: MetricSourceState.trainer,
        selected: selectedId == null,
        onSelect: () => _select(quantity, null),
      ),
    ];

    var selectionMatched = false;
    for (final candidate in candidates) {
      final isSelected = candidate.source.id == selectedId;
      if (isSelected) selectionMatched = true;
      final state = _candidateState(quantity, candidate, isSelected: isSelected, droppedOut: droppedOut);
      options.add(
        MetricSourceOption(
          id: candidate.source.id,
          label: candidate.source.displayName,
          subtitle: _subtitleFor(l10n, candidate, state, isSelected: isSelected),
          state: state,
          selected: isSelected,
          onSelect: () => _select(quantity, candidate),
          onDisconnect: isSelected && candidate.isConnected ? () => candidate.disconnect(forget: true) : null,
        ),
      );
    }

    // A persisted selection whose sensor has neither registered nor come
    // back into BLE range: the one case with no real candidate to attach a
    // name or a live state to. Ported unchanged from the deleted single-row
    // version's identical fallback.
    if (selectedId != null && !selectionMatched) {
      options.add(
        MetricSourceOption(
          id: selectedId,
          label: l10n.sensorConnecting,
          subtitle: l10n.sensorSourceConnectingGhostSubtitle,
          state: MetricSourceState.connecting,
          selected: true,
          onSelect: () async {},
        ),
      );
    }

    return options;
  }

  /// The plain-English "what does this row mean" line under each source's
  /// own name — the point of the redesigned list per direct author feedback
  /// ("use subtitles ... to explain what each entry means"). Kept next to
  /// [_candidateState] since the two together fully describe a row: the
  /// dot's colour and this text must never disagree.
  ///
  /// [MetricSourceState.connected] is the one state real-world meaning
  /// splits in two depending on [isSelected] — see `_candidateState`'s doc
  /// comment on why a "connected" candidate can be either this quantity's
  /// live source or a sensor already linked for something else entirely.
  String _candidateSubtitle(AppLocalizations l10n, MetricSourceState state, {required bool isSelected}) {
    return switch (state) {
      MetricSourceState.trainer => l10n.sensorSourceTrainerSubtitle,
      MetricSourceState.notConnected => l10n.sensorSourceNotConnectedSubtitle,
      MetricSourceState.connecting => l10n.sensorConnecting,
      MetricSourceState.waitingForFirstReading => l10n.sensorAwaitingFirstReading,
      MetricSourceState.lost => l10n.sensorDroppedOut,
      MetricSourceState.connected =>
        isSelected ? l10n.sensorSourceConnectedSubtitle : l10n.sensorSourceConnectedElsewhereSubtitle,
    };
  }

  /// [_candidateSubtitle], with one HealthKit-specific override: a
  /// selected, passive Apple Health source is only ever going to see
  /// another app's workout, and the rider needs to be told to start one.
  ///
  /// Deliberately keyed on [isSelected] alone, NOT `state ==
  /// MetricSourceState.connected`: a passive source that has not (yet)
  /// delivered a sample sits in `waitingForFirstReading` — droppedOut is
  /// `true` from the moment it registers, since `SensorHub._publish` only
  /// recalculates freshness off `readingFor`, and a `HealthKitModeEvent`
  /// carries no reading. "Waiting for first reading…" would be actively
  /// misleading there (it implies one is imminent); "explain passive mode"
  /// is the right message in every one of `connected` /
  /// `waitingForFirstReading` / `lost`, so long as this IS the rider's
  /// current pick.
  String _subtitleFor(AppLocalizations l10n, _SourceCandidate candidate, MetricSourceState state, {required bool isSelected}) {
    final source = candidate.source;
    if (isSelected && source is HealthKitSensorSource && source.mode.value == HealthKitMode.passive) {
      return l10n.sensorSourceHealthKitPassiveSubtitle;
    }
    if (state == MetricSourceState.notConnected && source is HealthKitSensorSource) {
      return l10n.sensorSourceHealthKitSubtitle;
    }
    return _candidateSubtitle(l10n, state, isSelected: isSelected);
  }

  /// Every selectable, non-trainer source for [quantity]: already-registered
  /// ones (connected — see [_SourceCandidate]'s doc comment) from the hub,
  /// plus nearby [BleSensorDevice]s that provide it and are not registered
  /// yet. `registeredIds` also protects against listing an already-connected
  /// device twice for the brief window where it is both registered in the
  /// hub AND still present in `core.connection.devices`.
  List<_SourceCandidate> _candidatesFor(SensorQuantity quantity) {
    final registered = core.sensors.sourcesFor(quantity);
    final registeredIds = registered.map((s) => s.id).toSet();
    final nearby = core.connection.devices.whereType<BleSensorDevice>().where(
      (d) => d.source.provides.contains(quantity) && !registeredIds.contains(d.source.id),
    );
    final healthKit = core.connection.healthKitSource;
    return [
      for (final source in registered)
        _SourceCandidate(
          source,
          isConnected: true,
          // Even an already-registered HealthKit source still routes through
          // `authorizeHealthKit` on (re)select — cheap once granted (no
          // sheet), and keeps this entry's ordering identical to the
          // not-yet-registered one below rather than special-casing which of
          // the two HealthKit ever skips authorization.
          authorize: source is HealthKitSensorSource ? core.connection.authorizeHealthKit : null,
          disconnect: source is HealthKitSensorSource
              ? _disconnectHealthKit
              : ({required bool forget}) => _disconnect(_connectedDeviceFor(source.id), forget: forget),
        ),
      for (final device in nearby)
        _SourceCandidate(
          device.source,
          isConnected: false,
          connect: () => _connectDevice(device),
          disconnect: ({required bool forget}) => _disconnect(device, forget: forget),
        ),
      // Apple Health: always a candidate where the source exists at all
      // (iOS with Health data), whether or not the rider has ever tapped it
      // — that tap is what asks for permission. Listed only once, so skip it
      // here while it is registered (it came through `registered` above).
      if (healthKit != null && quantity == SensorQuantity.heartRate && !registeredIds.contains(healthKit.id))
        _SourceCandidate(
          healthKit,
          isConnected: false,
          authorize: core.connection.authorizeHealthKit,
          connect: core.connection.connectHealthKit,
          disconnect: _disconnectHealthKit,
        ),
    ];
  }

  /// The BLE connect half, lifted out of `_select` unchanged: the consent
  /// flag MUST be persisted before `connectDevice` — `shouldAutoConnect`
  /// reads it and `connect()` early-returns otherwise. Do not reorder.
  Future<void> _connectDevice(BleSensorDevice device) async {
    await core.settings.setSensorAutoConnect(device.device.deviceId, true);
    await core.connection.connectDevice(device);
  }

  /// `core.connection.disconnectHealthKit` alone never reaches this
  /// section's own rebuild: unlike a BLE disconnect (`_disconnect`, which
  /// `setState`s explicitly, mirrored here) or a reading/mode change (which
  /// `_onHealthKitModeChanged` `setState`s off), the bare tear-off used to
  /// sit directly on `_SourceCandidate.disconnect` with nothing driving a
  /// repaint of its own — the ONLY reason the row ever visibly updated was
  /// `HealthKitSensorSource.stop()` flipping `mode` from non-null to null,
  /// which is a no-op (no listener fires) when `mode` was already null,
  /// e.g. the rider disconnects before any mode or sample event ever
  /// arrived. Explicit `setState` here closes that gap regardless of
  /// `mode`'s value.
  Future<void> _disconnectHealthKit({required bool forget}) async {
    await core.connection.disconnectHealthKit(forget: forget);
    if (mounted) setState(() {});
  }

  /// A candidate's own dot state, independent of whether it happens to be
  /// [quantity]'s active selection:
  ///  - not registered: `notConnected` (never linked — tap to connect), or —
  ///    when it IS the active selection — `connecting` (a connect is in
  ///    flight, or a persisted pick is waiting for its sensor to come back
  ///    into range);
  ///  - registered: `connected`, per `SensorHub.register`'s own invariant
  ///    that a registered source is — by construction — currently linked,
  ///    UNLESS it is the active selection and the hub's per-quantity
  ///    freshness flag says otherwise, in which case `waitingForFirstReading`
  ///    / `lost` exactly as the deleted single-row version computed.
  MetricSourceState _candidateState(
    SensorQuantity quantity,
    _SourceCandidate candidate, {
    required bool isSelected,
    required bool droppedOut,
  }) {
    if (!candidate.isConnected) {
      return isSelected ? MetricSourceState.connecting : MetricSourceState.notConnected;
    }
    if (!isSelected || !droppedOut) return MetricSourceState.connected;
    final everReported = candidate.source.readingFor(quantity).value != null;
    return everReported ? MetricSourceState.lost : MetricSourceState.waitingForFirstReading;
  }

  BleSensorDevice? _connectedDeviceFor(String sourceId) {
    for (final device in core.connection.devices.whereType<BleSensorDevice>()) {
      if (device.source.id == sourceId) return device;
    }
    return null;
  }

  /// Picking an external source is a Pro feature — gated ahead of everything
  /// else, since selection has a real side effect on OTHER apps' pairings.
  ///
  /// CRITICAL — ordering ported unchanged from the deleted
  /// `SensorSourcePicker`/`SensorQuantitySelector`, and load-bearing: the
  /// per-device consent flag is persisted BEFORE `connectDevice` is ever
  /// called — `shouldAutoConnect` reads it and `connect()` early-returns
  /// otherwise (`BleHeartRateDevice.shouldAutoConnect`'s doc comment). Do not
  /// reorder.
  ///
  /// ALSO CRITICAL, and new: [_SourceCandidate.authorize] runs AFTER the Pro
  /// gate but BEFORE `core.sensors.select` below — device-confirmed bug fix.
  /// `core.sensors.select` fires `SensorHub.onSelectionChanged` synchronously,
  /// which restarts the BLE/DIRCON bridge transport
  /// (`DirconEmulator._restartTransportAfterChildChange`); if that restart is
  /// still in flight when healthd tries to present the Health permission
  /// sheet in this process, the authorization session itself times out and
  /// the sheet never appears — reproduced as "first tap always fails, second
  /// tap always works" (the second tap's selection was already persisted, so
  /// nothing restarts). Authorizing before the selection changes means the
  /// sheet is shown, and answered, before the transport ever moves.
  Future<void> _select(SensorQuantity quantity, _SourceCandidate? candidate) async {
    try {
      final sourceId = candidate?.source.id;
      if (sourceId != null && !IAPManager.instance.isProEnabledForCurrentDevice) {
        final granted = await IAPManager.instance.ensureProForFeature(
          context,
          featureName: _quantityTitle(AppLocalizations.of(context), quantity),
        );
        if (!granted) {
          // Nothing changed in the hub — force a rebuild so the control
          // snaps back to the hub's actual selection instead of lingering on
          // the tapped-but-rejected value.
          if (mounted) setState(() {});
          return;
        }
      }

      final authorize = candidate?.authorize;
      if (authorize != null) {
        try {
          await authorize();
        } on HealthKitDeniedException {
          // Nothing in the hub has changed yet at this point — the
          // selection is still whatever it was before this tap — so there
          // is nothing to revert, unlike the old denial path that used to
          // live around `connect()` below. Just explain and bail.
          if (!mounted) return;
          buildToast(level: LogLevel.LOGLEVEL_WARNING, title: AppLocalizations.of(context).sensorHealthKitDenied);
          setState(() {});
          return;
        }
      }

      // Captured BEFORE `core.sensors.select` below overwrites it — only
      // meaningful in the "back to Trainer" case (`candidate == null`); a
      // pick of an actual sensor never disconnects anything here, so this
      // stays null for that path and the block at the bottom is skipped.
      final previousSourceId = candidate == null ? core.sensors.selectionFor(quantity) : null;
      // Also captured before `core.sensors.select` — see the back-to-Trainer
      // lookup below, which needs candidates keyed to the OLD registration
      // state (e.g. a HealthKit source `_candidatesFor` would otherwise skip
      // once it is no longer this quantity's selection).
      final previousCandidates = _candidatesFor(quantity);

      core.sensors.select(quantity, sourceId);
      // Persists every quantity's CURRENT selection, not just this one — see
      // `SensorHub.persistSelections`.
      await core.sensors.persistSelections(core.settings);

      // Authorization (if any) already succeeded above — see [authorize]'s
      // own block — so `connect()` can no longer throw
      // `HealthKitDeniedException`: the register+start half
      // (`Connection.connectHealthKit`) deliberately never authorizes. No
      // `on HealthKitDeniedException` catch here any more; any other failure
      // falls through to this method's own outer `catch`, which records and
      // rethrows.
      final connect = candidate?.connect;
      if (connect != null) await connect();

      // Direct author feedback: "when using 'Trainer' again, it should
      // disconnect the other sensor" — a sensor held connected but unused
      // still occupies the device (many straps/power meters accept only one
      // BLE connection at a time) and drains its battery for nothing.
      //
      // BUT a single sensor can serve MORE THAN ONE quantity — e.g.
      // `BlePowerDevice.provides` is `{power, cadence}` — so a rider who has
      // that meter selected for BOTH and switches only POWER back to
      // Trainer must NOT lose CADENCE too. The naive "sourceId was cleared,
      // disconnect it" version looks correct and silently breaks exactly
      // that rider. So: walk every `SensorQuantity` via `selectionFor` and
      // only disconnect if NONE of them still point at this source. This
      // check has to run AFTER `core.sensors.select` above has already
      // cleared THIS quantity's own pointer — otherwise it would always find
      // its own stale selection and conclude "still in use".
      if (previousSourceId != null) {
        final stillInUse = SensorQuantity.values.any((q) => core.sensors.selectionFor(q) == previousSourceId);
        if (!stillInUse) {
          // Reuses the exact same disconnect path the list's explicit
          // disconnect action uses, so the two cannot drift. For a BLE
          // candidate, `_disconnect` no-ops (does nothing, throws nothing)
          // when the id doesn't resolve to any `BleSensorDevice` still in
          // `core.connection.devices` — e.g. a persisted selection whose
          // sensor never actually connected, or one that has since dropped
          // out of range entirely. `disconnectHealthKit` similarly no-ops
          // when not connected. Deliberately unconditional on
          // `previous.isConnected`: a NEARBY strap that was selected but
          // never finished connecting (its own `connect` failed, or is
          // still in flight) is `isConnected == false` here, but it still
          // has its per-device auto-connect consent flag set from the tap
          // that picked it — `_disconnect` is what clears that flag, so
          // skipping it for an unregistered candidate would leave a
          // forgotten strap set to auto-connect on the next scan.
          //
          // `forget: false` here — unlike the explicit disconnect action
          // below (see `_disconnect`'s own doc comment): `core.sensors
          // .select(quantity, sourceId)` above already cleared THIS
          // quantity's pointer, and `stillInUse` just proved no OTHER
          // quantity points at it either, so `forget: true`'s own
          // selection-clearing walk (`Connection._unregisterSensorSource`)
          // would find nothing left to do — the reason it was chosen no
          // longer applies on this path.
          final previous = previousCandidates.where((c) => c.source.id == previousSourceId).firstOrNull;
          if (previous != null) await previous.disconnect(forget: false);
        }
      }

      if (mounted) setState(() {});
    } catch (e, s) {
      // Recorded here with a specific context AND rethrown: the enclosing
      // segment's `LoadingWidget` needs the exception too, to show its own
      // failure toast (see `_MetricSourceSegmentState.build`'s
      // `onErrorCallback`, metric_card.dart).
      await recordError(e, s, context: 'LiveMetricsSection._select');
      rethrow;
    }
  }

  /// A deliberate disconnect, not a transient drop — ordering ported
  /// unchanged from the deleted `SensorSourcePicker._disconnect`. The
  /// consent flag is cleared BEFORE calling `disconnect` so nothing can read
  /// a stale "yes" in the gap between the two calls.
  ///
  /// [forget] defaults to `true` — the list's own explicit disconnect action
  /// (`onDisconnect` above) calls this with no selection cleanup of its own,
  /// so it relies on `forget: true` to drop this quantity's (and any other
  /// quantity's) selection pointing at this source
  /// (`Connection._unregisterSensorSource`), falling back to Trainer. The
  /// Trainer-selection path in `_select` passes `forget: false` instead — it
  /// already cleared every pointer to this source itself before calling
  /// here, so `forget: true`'s selection walk would be a no-op there; see
  /// its own call site comment.
  ///
  /// `persistForget: false` always, deliberately: this is "I'm done with my
  /// strap for now", not "this was never mine" — `true` would hide it from
  /// every future scan via the permanent ignore list.
  ///
  /// `keepInList: true` always: per direct author feedback, a disconnected
  /// sensor must stay in the candidate list and be immediately selectable
  /// again — not vanish until the next scan happens to rediscover it. Reuses
  /// the exact same `Connection.disconnect(keepInList: true)` machinery the
  /// in-place "No connection" picker entry already relies on
  /// (`connection_card.dart`, `onboarding_page.dart`,
  /// `ProxyDevice.reconnectUpstream`) rather than inventing a parallel way to
  /// keep a device round after its own BLE link drops.
  Future<void> _disconnect(BleSensorDevice? device, {bool forget = true}) async {
    if (device == null) return;
    try {
      await core.settings.setSensorAutoConnect(device.device.deviceId, false);
      await core.connection.disconnect(device, forget: forget, persistForget: false, keepInList: true);
      if (mounted) setState(() {});
    } catch (e, s) {
      await recordError(e, s, context: 'LiveMetricsSection._disconnect');
      rethrow;
    }
  }
}

/// The tile's own quantity-scoped label, for the Pro-upgrade dialog's
/// `featureName` only. Kept local to this file rather than resurrecting the
/// deleted `SensorQuantitySelector`'s `SensorQuantityPresentation` extension:
/// nothing else in the surviving tree needs a title per [SensorQuantity] any
/// more.
String _quantityTitle(AppLocalizations l10n, SensorQuantity quantity) => switch (quantity) {
  SensorQuantity.heartRate => l10n.sensorQuantityHeartRate,
  SensorQuantity.cadence => l10n.sensorQuantityCadence,
  SensorQuantity.power => l10n.sensorQuantityPower,
  SensorQuantity.speed => l10n.sensorQuantitySpeed,
};

/// One selectable, non-trainer entry. [isConnected] means "registered in the
/// hub" (see `SensorHub.register`'s doc comment). [connect] is non-null only
/// while NOT connected — what a tap on it does; [disconnect] is what the
/// row's disconnect action and the back-to-Trainer walk call. Both are
/// closures rather than a `BleSensorDevice` so a HealthKit candidate and a
/// BLE one go through the same code below.
class _SourceCandidate {
  const _SourceCandidate(
    this.source, {
    required this.isConnected,
    this.authorize,
    this.connect,
    required this.disconnect,
  });

  final SensorSource source;
  final bool isConnected;

  /// Non-null only for the HealthKit candidate. `_select` awaits this BEFORE
  /// `core.sensors.select(...)` — see that method's own doc comment on why
  /// the ordering matters. `null` for every BLE candidate: a BLE connect has
  /// its own consent gate (`_connectDevice`'s auto-connect flag) and no
  /// permission sheet that can race anything.
  final Future<void> Function()? authorize;
  final Future<void> Function()? connect;
  final Future<void> Function({required bool forget}) disconnect;
}

class _LiveMetrics {
  final ValueListenable<int?> power;
  final ValueListenable<int?> heartRate;
  final ValueListenable<int?> cadence;
  final ValueListenable<double?> speed;

  const _LiveMetrics({
    required this.power,
    required this.heartRate,
    required this.cadence,
    required this.speed,
  });
}

/// A `Row` where every child ends up the row's own height — the shorter
/// card's `Container` stretches to match the taller one, per direct author
/// feedback on this grid ("let the left card have the same height as the
/// right card, otherwise it looks odd"): a metric with no source list (e.g.
/// POWER, with only one possible source) renders short next to one that has
/// grown an inline source list (e.g. HEART), and the mismatch reads as
/// broken.
///
/// Deliberately NOT `IntrinsicHeight` + `Row(crossAxisAlignment: stretch)` —
/// that is the obvious fix, and it is unsafe HERE for two independent
/// reasons:
///
///  1. `IntrinsicHeight` measures each child through Flutter's *intrinsic
///     dimensions* protocol (`RenderBox.getMaxIntrinsicHeight`), and
///     `MetricCard` uses a `LayoutBuilder` for its own width-reactive
///     side-by-side/stacked source-list switch. `LayoutBuilder` explicitly
///     refuses intrinsic queries — see its own source
///     (`_RenderLayoutBuilder._debugThrowIfNotCheckingIntrinsics`): "does
///     not support returning intrinsic dimensions", because answering would
///     mean running its builder speculatively against a hypothetical width.
///     So `IntrinsicHeight` here throws on EVERY tile that has grown a
///     source list — proven by pumping a minimal `IntrinsicHeight` +
///     `LayoutBuilder` reproduction under `flutter_test` before writing
///     this — not just under the unbounded-height page below.
///  2. Separately, `CrossAxisAlignment.stretch` needs the row's OWN
///     incoming height to be bounded (it tightens every child to
///     `constraints.maxHeight`), so it throws under an unbounded-height
///     parent — and this section renders inside a `SingleChildScrollView`
///     on both of its real call sites.
///
/// This class avoids both failure modes by never touching the intrinsics
/// protocol at all: [_RenderEqualHeightRow] runs the ordinary `RenderFlex`
/// layout once for real (exactly what a plain `Row` already does — safe for
/// `LayoutBuilder`, and safe unbounded, since nothing here needs the
/// incoming height to be finite), reads the row's own resulting height off
/// that, and then, only for a child shorter than that, lays that ONE child
/// out again for real with a tight height matching the row. Every layout
/// call is a genuine `RenderBox.layout()`, never an intrinsic-dimension
/// query, and the row's own height always comes from its children's real
/// (natural) sizes.
///
/// Subclasses shadcn_flutter's OWN `Row`/`RenderFlex` (`shadcn_flutter
/// .dart`'s barrel hides Flutter's stock `Row`/`Expanded`/`Flex` in favor of
/// its own paint-order-aware versions — see that file's "patched flex with
/// paint order" export), NOT Flutter's raw `Row`/`RenderFlex`: `MetricCard`'s
/// `Expanded` is shadcn's own `Expanded`, which requires shadcn's own
/// `FlexParentData` subtype on its render object, and throws "Incorrect use
/// of ParentDataWidget" against a plain `RenderFlex` that only knows how to
/// hand out Flutter's base `FlexParentData`.
class _EqualHeightRow extends Row {
  const _EqualHeightRow({required super.children, super.spacing});

  @override
  RenderFlex createRenderObject(BuildContext context) {
    return _RenderEqualHeightRow(textDirection: getEffectiveTextDirection(context), spacing: spacing);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderEqualHeightRow renderObject) {
    renderObject
      ..textDirection = getEffectiveTextDirection(context)
      ..spacing = spacing;
  }
}

/// See [_EqualHeightRow]'s doc comment for why this exists instead of
/// `IntrinsicHeight` + `CrossAxisAlignment.stretch` — and why it extends
/// shadcn_flutter's `RenderFlex`, not Flutter's own.
class _RenderEqualHeightRow extends RenderFlex {
  _RenderEqualHeightRow({required super.textDirection, required super.spacing})
    : super(
        direction: Axis.horizontal,
        // `start`, not the `RenderFlex` default `center`: once the second
        // pass below grows a shorter child to the row's own height, its
        // vertical position is moot (it now spans the whole row either
        // way) — but keeping it `start` for the (common, unaffected) case
        // where every child is already the same height costs nothing and
        // keeps this row's own semantics closest to "top-aligned, stretch
        // when needed" rather than momentarily centering during the first
        // pass.
        crossAxisAlignment: CrossAxisAlignment.start,
      );

  @override
  void performLayout() {
    // Pass 1: the ordinary, real `RenderFlex` algorithm (shadcn_flutter's
    // `super.performLayout()` runs Flutter's real single-pass Flex layout,
    // then its own paint-order bookkeeping) — every child is laid out for
    // real, at its own natural (loosely-constrained) height. This is
    // exactly what an unmodified `Row` does today, so it is exactly as safe
    // for a `LayoutBuilder` descendant and exactly as safe under an
    // unbounded incoming height. `size.height` afterward is the max of the
    // children's own real heights.
    super.performLayout();
    final rowHeight = size.height;
    // Pass 2: any child shorter than the row itself gets ONE more real
    // layout call, this time with a tight height equal to the row's own —
    // still a real `RenderBox.layout()`, not an intrinsic query, so it
    // stays safe for `MetricCard`'s `LayoutBuilder`. `MetricCard`'s
    // `Container` has no explicit height and no `alignment`, and its
    // `Column` defaults to `mainAxisSize.max` / `mainAxisAlignment.start`,
    // so the extra height lands as trailing space below the existing
    // content — the label/value/source-list stay top-aligned, they don't
    // re-centre into the middle of the taller box. Only the height changes
    // (the width, and therefore each child's `x` offset, is untouched), and
    // a child can only grow up to `rowHeight` — exactly the row's own size —
    // so this can never introduce overflow for shadcn's overflow check
    // above to catch.
    var child = firstChild;
    while (child != null) {
      final childParentData = child.parentData! as FlexParentData;
      if (child.size.height < rowHeight) {
        child.layout(
          BoxConstraints.tightFor(width: child.size.width, height: rowHeight),
          parentUsesSize: true,
        );
      }
      child = childParentData.nextSibling;
    }
  }
}
