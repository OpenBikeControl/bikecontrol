import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/services/sensors/sensor_reading.dart';
import 'package:bike_control/services/sensors/sensor_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

FakeSensorSource _hrSource(String id) => FakeSensorSource(
  id: id,
  displayName: 'Strap $id',
  provides: {SensorQuantity.heartRate},
);

class _ProbeNotifier extends ValueNotifier<SensorReading?> {
  _ProbeNotifier() : super(null);
  bool get isListenedTo => hasListeners;
}

class _ProbeSource extends SensorSource {
  _ProbeSource({this.id = 'probe'});

  final _notifier = _ProbeNotifier();

  @override
  final String id;

  @override
  String get displayName => 'Probe';

  @override
  Set<SensorQuantity> get provides => {SensorQuantity.heartRate};

  @override
  ValueListenable<SensorReading?> readingFor(SensorQuantity quantity) => _notifier;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

void main() {
  test('defaults to the trainer, so resolved() is null', () {
    final hub = SensorHub();
    hub.register(_hrSource('a'));

    expect(hub.selectionFor(SensorQuantity.heartRate), isNull);
    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);
  });

  test('a selected source publishes its value', () {
    final hub = SensorHub();
    final source = _hrSource('a');
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'a');

    source.emit(SensorQuantity.heartRate, 155);

    expect(hub.resolved(SensorQuantity.heartRate).value, 155);
  });

  test('reselecting the trainer drops back to null', () {
    final hub = SensorHub();
    final source = _hrSource('a');
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'a');
    source.emit(SensorQuantity.heartRate, 155);

    hub.select(SensorQuantity.heartRate, null);

    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);
  });

  test('sourcesFor only offers sources providing that quantity', () {
    final hub = SensorHub();
    hub.register(_hrSource('a'));
    hub.register(
      FakeSensorSource(
        id: 'p',
        displayName: 'Meter',
        provides: {SensorQuantity.power},
      ),
    );

    expect(hub.sourcesFor(SensorQuantity.heartRate).map((s) => s.id), ['a']);
    expect(hub.sourcesFor(SensorQuantity.power).map((s) => s.id), ['p']);
  });

  // Fix-wave-1 round 2: `unregister` used to clear the selection
  // unconditionally, via the same path as an explicit "trainer" pick. That
  // meant a transient BLE drop (unregister, then a fresh instance registers
  // moments later — see the tests below) permanently reverted the rider to
  // the trainer's own heart rate for the rest of the session, because
  // `register`'s rebind loop only fires when the selection still points at
  // the id. `unregister` cannot tell a transient drop from the rider
  // forgetting the device, so it must assume the recoverable case; only
  // `Connection` clears the selection for good, and only when the rider
  // actually forgot the device (see connection.dart's `_unregisterSensorSource`).
  test('unregistering the selected source retains the selection and flips droppedOut', () {
    final hub = SensorHub();
    final source = _hrSource('a');
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'a');
    source.emit(SensorQuantity.heartRate, 155);

    hub.unregister('a');

    expect(hub.selectionFor(SensorQuantity.heartRate), 'a');
    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);
    // Flips immediately, not just on the next tick() — the source is gone
    // right now, so the UI must show that right now.
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isTrue);
  });

  test('unregister leaves no listener stranded on the removed source', () {
    final hub = SensorHub();
    final source = _ProbeSource();
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'probe');
    expect(source._notifier.isListenedTo, isTrue);

    hub.unregister('probe');

    // Fails if `unregister` removes the source before dropping the selection:
    // `_detachListener` would then look up a source that is already gone and
    // silently no-op through `?.`.
    expect(source._notifier.isListenedTo, isFalse);
  });

  // Fix-wave-1 (F3): `BluetoothDevice.fromScanResult` builds a brand new
  // device — and therefore a brand new `BleSensorSource` with new notifiers —
  // every time a strap is rediscovered, which happens constantly as straps
  // drop in and out of BLE range. `register` must notice it is replacing an
  // already-selected id and rebind, or the hub is left listening to a
  // notifier that will never fire again.
  test('register replacing a selected id detaches the old notifier and attaches the new one', () {
    final hub = SensorHub();
    final v1 = _ProbeSource(id: 'strap');
    hub.register(v1);
    hub.select(SensorQuantity.heartRate, 'strap');
    expect(v1._notifier.isListenedTo, isTrue);

    final v2 = _ProbeSource(id: 'strap');
    hub.register(v2);

    // The outgoing instance must not be left with a stranded listener — its
    // device is gone and it will never emit again.
    expect(v1._notifier.isListenedTo, isFalse);
    expect(v2._notifier.isListenedTo, isTrue);
  });

  test('register replacing a selected id publishes values from the fresh instance', () {
    final hub = SensorHub();
    final v1 = _hrSource('strap');
    hub.register(v1);
    hub.select(SensorQuantity.heartRate, 'strap');
    v1.emit(SensorQuantity.heartRate, 150);
    expect(hub.resolved(SensorQuantity.heartRate).value, 150);

    // A fresh instance under the same id (a rediscovered strap) replaces it.
    final v2 = _hrSource('strap');
    hub.register(v2);
    v2.emit(SensorQuantity.heartRate, 160);

    expect(hub.resolved(SensorQuantity.heartRate).value, 160);
  });

  // Fix-wave-1 round 2 repro: this is the exact bug the retained-selection
  // fix above exists for. Under the old `unregister` (clears the selection
  // unconditionally), this failed because `register`'s rebind loop tests
  // `_selection[quantity] == source.id`, which no longer matched once
  // `unregister` had nulled it — v2 would register but never get selected,
  // so the emitted value below would never reach `resolved()`.
  test('a fresh instance registering after unregister is picked back up by the retained selection', () {
    final hub = SensorHub();
    final v1 = _hrSource('strap');
    hub.register(v1);
    hub.select(SensorQuantity.heartRate, 'strap');
    v1.emit(SensorQuantity.heartRate, 150);
    expect(hub.resolved(SensorQuantity.heartRate).value, 150);

    hub.unregister('strap');

    final v2 = _hrSource('strap');
    hub.register(v2);
    v2.emit(SensorQuantity.heartRate, 160);

    expect(hub.resolved(SensorQuantity.heartRate).value, 160);
  });

  // `onSelectionChanged` is a single slot owned by the sink/broadcast chain,
  // so a UI that merely needs to know "the selection moved" (the Sensors
  // page's switch-enabled state) listens to this counter instead of
  // competing for the hook.
  test('selectionVersion bumps on every select, including the fall-back-to-null paths', () {
    final hub = SensorHub();
    hub.register(_hrSource('a'));
    final before = hub.selectionVersion.value;

    hub.select(SensorQuantity.heartRate, 'a');
    expect(hub.selectionVersion.value, before + 1);

    hub.select(SensorQuantity.heartRate, 'not-registered');
    expect(hub.selectionVersion.value, before + 2);

    hub.select(SensorQuantity.heartRate, null);
    expect(hub.selectionVersion.value, before + 3);
  });
}
