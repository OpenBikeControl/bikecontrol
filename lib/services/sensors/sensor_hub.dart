import 'package:flutter/foundation.dart';

import 'package:bike_control/bluetooth/support_log_buffer.dart';
import 'package:bike_control/utils/settings/settings.dart';

import 'sensor_quantity.dart';
import 'sensor_source.dart';

/// Owns every decision about where a rider metric comes from.
///
/// `prop` deliberately knows none of this: the hub publishes a resolved value
/// per quantity, or `null` meaning "trainer, use your own". Keeping the policy
/// here is what makes it testable without any of the hardware it supports.
class SensorHub {
  SensorHub({DateTime Function()? now, this.log}) : now = now ?? DateTime.now;

  /// TUNABLE. BLE heart rate / CSC / power sensors notify at about 1 Hz.
  static const bleSensorTtl = Duration(seconds: 5);

  /// TUNABLE. HealthKit passive delivery is batched and can lag far behind a
  /// BLE strap; a 5 s window here would flap continuously.
  static const healthKitTtl = Duration(seconds: 30);

  /// The clock readings are aged by. Settable so tests on a fake clock can
  /// point the app's own hub there.
  DateTime Function() now;

  /// Attached during wiring rather than construction: the buffer lives on
  /// `Connection`, which is built after `core`.
  SupportLogBuffer? log;

  /// Invoked whenever [select] settles a quantity's source — including the
  /// no-op-looking paths where it falls back to `null`. Wiring-only hook, not
  /// an event system: there is exactly one listener in practice (the thing
  /// that decides whether a sink should be standalone), and it needs to
  /// re-run whenever the rider's selection changes, not just when the bridge
  /// does.
  VoidCallback? onSelectionChanged;

  /// Bumped every time [select] settles — the same moments
  /// [onSelectionChanged] fires. That hook is a single wiring slot the
  /// sink/broadcast chain owns; a widget that only needs to know "the
  /// selection moved" (the Sensors page, whose Broadcast switch is enabled
  /// iff anything is selected) listens here instead of competing for it.
  ValueListenable<int> get selectionVersion => _selectionVersion;
  final _selectionVersion = ValueNotifier<int>(0);

  /// Consulted on every [_publish] — i.e. at serve time, each time a
  /// quantity's value is about to become visible to whatever reads
  /// [resolved], not once when the rider picks a source. A one-shot check at
  /// selection time (the tap-time Pro gate `SensorQuantitySelector` already
  /// has) cannot catch a subscription lapsing later: `loadSelections` also
  /// calls `select()` directly on every cold launch, with no tap involved at
  /// all. Gating here instead means a lapsed subscriber's external reading
  /// stops resolving on the very next tick — without ever touching
  /// [_selection], so it resumes instantly, with no re-picking, the moment
  /// the subscription is restored.
  ///
  /// Defaults to "allowed" when unset, matching
  /// `DirconEmulator.shouldAdvertise`'s own convention: most tests (and every
  /// context that predates this feature) exercise resolution without wiring
  /// Pro state at all, and a wiring bug here must never silently look like
  /// "no data" in production either.
  bool Function()? isProEnabled;

  final Map<String, SensorSource> _sources = {};
  final Map<SensorQuantity, String?> _selection = {};
  final Map<SensorQuantity, ValueNotifier<int?>> _resolved = {};
  final Map<SensorQuantity, ValueNotifier<bool>> _droppedOut = {};
  final Map<SensorQuantity, VoidCallback> _listeners = {};

  List<SensorSource> get sources => List.unmodifiable(_sources.values);

  /// A fresh instance replacing an already-registered id — `fromScanResult`
  /// builds a new device, and therefore a new `BleSensorSource` with new
  /// notifiers, every time a strap is rediscovered, which happens constantly
  /// as straps drop in and out of BLE range. Detach BEFORE overwriting
  /// [_sources], while it still resolves to the outgoing instance: detaching
  /// after would look the "current" source up via the map and find the
  /// incoming one instead, silently no-op on it, and strand the listener on
  /// the dead notifier — a permanent drop-out plus a leaked listener.
  ///
  /// The second loop then (re)binds every quantity currently pointing at this
  /// id — covering both that replacement and a persisted selection that
  /// arrived before this source ever existed (see `select`'s not-found
  /// branch): this is the moment such a selection can finally go live.
  void register(SensorSource source) {
    for (final quantity in SensorQuantity.values) {
      if (_selection[quantity] == source.id) _detachListener(quantity);
    }
    _sources[source.id] = source;
    for (final quantity in SensorQuantity.values) {
      if (_selection[quantity] == source.id) select(quantity, source.id);
    }
  }

  /// Deliberately does NOT clear the selection. `unregister` cannot tell "this
  /// sensor went away" (a transient BLE drop, about to be rediscovered as a
  /// fresh instance under the same id — see `register`'s doc comment) from
  /// "the rider forgot this device" — only the caller knows that. `Connection`
  /// clears the selection itself, via [select], when the rider actually
  /// forgot the device; every other case leaves it retained here as a pending
  /// selection, exactly the state `select`'s not-found branch already made
  /// valid — `register` rebinds it the moment a matching id reappears.
  void unregister(String id) {
    // Detach BEFORE removing the source: `_detachListener` resolves "the
    // current source" by looking it up in `_sources`, so removing it first
    // would strand the listener on a notifier nothing ever cleans up.
    for (final quantity in SensorQuantity.values) {
      if (_selection[quantity] == id) _detachListener(quantity);
    }
    _sources.remove(id);
    // Publish immediately rather than waiting for the next `tick()`: the
    // selection still points at `id`, but its source is gone, so this
    // quantity must read as dropped out right away, not up to a tick period
    // late.
    for (final quantity in SensorQuantity.values) {
      if (_selection[quantity] == id) _publish(quantity);
    }
  }

  List<SensorSource> sourcesFor(SensorQuantity quantity) =>
      _sources.values.where((s) => s.provides.contains(quantity)).toList();

  String? selectionFor(SensorQuantity quantity) => _selection[quantity];

  ValueListenable<int?> resolved(SensorQuantity quantity) => _resolvedNotifier(quantity);

  ValueNotifier<int?> _resolvedNotifier(SensorQuantity quantity) =>
      _resolved.putIfAbsent(quantity, () => ValueNotifier<int?>(null));

  ValueListenable<bool> droppedOut(SensorQuantity quantity) => _droppedOutNotifier(quantity);

  ValueNotifier<bool> _droppedOutNotifier(SensorQuantity quantity) =>
      _droppedOut.putIfAbsent(quantity, () => ValueNotifier<bool>(false));

  /// Re-evaluates freshness for every quantity. Called on a timer by the
  /// owner and directly by tests.
  void tick() {
    for (final quantity in SensorQuantity.values) {
      if (_selection[quantity] != null) _publish(quantity);
    }
  }

  void select(SensorQuantity quantity, String? sourceId) {
    try {
      _detachListener(quantity);
      _selection[quantity] = sourceId;

      if (sourceId == null) {
        _resolvedNotifier(quantity).value = null;
        // The trainer cannot drop out.
        _droppedOutNotifier(quantity).value = false;
        return;
      }

      final source = _sources[sourceId];
      if (source == null) {
        // Deliberately NOT resetting `_selection[quantity]` to null here:
        // `sourceId` is kept as the rider's intent rather than discarded.
        // `loadSelections` runs during connection setup, before any scan has
        // even started, so this branch fires on every cold launch for a
        // perfectly valid source that simply has not registered YET —
        // `register` re-runs this same binding the moment it does. Nulling
        // here would also make a later `persistSelections` overwrite the
        // rider's stored choice with nothing before that ever gets a chance.
        _resolvedNotifier(quantity).value = null;
        // A persisted source id that no longer resolves should not leave the
        // drop-out flag stuck from a previous session.
        _droppedOutNotifier(quantity).value = false;
        return;
      }

      final reading = source.readingFor(quantity);
      void listener() => _publish(quantity);
      reading.addListener(listener);
      _listeners[quantity] = listener;
      _publish(quantity);
    } finally {
      // Every exit path above is "the selection settled," including the two
      // fall-back-to-null ones — a listener deciding whether to stand up a
      // standalone sink cares about all of them equally.
      _selectionVersion.value++;
      onSelectionChanged?.call();
    }
  }

  void _publish(SensorQuantity quantity) {
    final sourceId = _selection[quantity];
    final source = sourceId == null ? null : _sources[sourceId];
    // A lapsed subscriber's reading is treated exactly like "nothing to
    // read yet" — never surfaced, but [_selection] itself is untouched, so
    // resolution resumes with no rider action the moment Pro comes back.
    final allowed = isProEnabled?.call() ?? true;
    final reading = (source != null && allowed) ? source.readingFor(quantity).value : null;

    final stale = reading == null || now().difference(reading.timestamp) > (source?.ttl ?? bleSensorTtl);

    final wasDropped = _droppedOutNotifier(quantity).value;
    if (stale && !wasDropped && reading != null) {
      log?.add('sensor drop-out: ${source?.displayName} for ${quantity.name}');
    }
    _droppedOutNotifier(quantity).value = stale;

    // `null` hands the quantity back to the trainer; in standalone mode it
    // simply means there is no value to notify.
    _resolvedNotifier(quantity).value = stale ? null : reading.value;
  }

  void _detachListener(SensorQuantity quantity) {
    final listener = _listeners.remove(quantity);
    if (listener == null) return;
    final previousId = _selection[quantity];
    final previous = previousId == null ? null : _sources[previousId];
    previous?.readingFor(quantity).removeListener(listener);
  }

  void dispose() {
    for (final quantity in SensorQuantity.values) {
      _detachListener(quantity);
    }
    for (final notifier in _resolved.values) {
      notifier.dispose();
    }
    _resolved.clear();
    for (final notifier in _droppedOut.values) {
      notifier.dispose();
    }
    _droppedOut.clear();
    // `_selectionVersion` is deliberately left alive: `dispose` clears the
    // per-quantity notifier maps so a later `select` still works against
    // fresh ones, and a disposed counter would be the one thing to throw.
  }

  /// Restores persisted selections. This runs before any scan has happened,
  /// so a stored id almost never has a matching source registered yet —
  /// `select` keeps it as a pending selection rather than discarding it (see
  /// its not-found branch), and `register` binds it live the moment a
  /// matching source shows up.
  void loadSelections(Settings settings) {
    for (final quantity in SensorQuantity.values) {
      select(quantity, settings.getSensorSelection(quantity.name));
    }
  }

  Future<void> persistSelections(Settings settings) async {
    for (final quantity in SensorQuantity.values) {
      await settings.setSensorSelection(quantity.name, _selection[quantity]);
    }
  }
}
