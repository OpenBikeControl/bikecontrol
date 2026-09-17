import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a selection survives a hub restart', () async {
    final settings = Settings()..prefs = await SharedPreferences.getInstance();

    final first = SensorHub();
    first.register(FakeSensorSource(
      id: 'strap',
      displayName: 'Strap',
      provides: {SensorQuantity.heartRate},
    ));
    first.select(SensorQuantity.heartRate, 'strap');
    await first.persistSelections(settings);

    final second = SensorHub();
    second.register(FakeSensorSource(
      id: 'strap',
      displayName: 'Strap',
      provides: {SensorQuantity.heartRate},
    ));
    second.loadSelections(settings);

    expect(second.selectionFor(SensorQuantity.heartRate), 'strap');
  });

  // Fix-wave-1 (F4): `loadSelections` runs during connection setup, before any
  // scan has even started, so a persisted id NEVER has a matching source
  // registered yet — the old "degrades to the trainer" behavior this test
  // used to assert would throw the rider's choice away on every single cold
  // launch. `select`'s not-found branch now keeps the id as a pending
  // selection instead; `register` (see its own tests) binds it live the
  // moment a matching source actually shows up.
  test('a persisted source that has not registered yet stays pending, not cleared', () async {
    final settings = Settings()..prefs = await SharedPreferences.getInstance();
    await settings.setSensorSelection(SensorQuantity.heartRate.name, 'ghost');

    final hub = SensorHub();
    hub.loadSelections(settings);

    expect(hub.selectionFor(SensorQuantity.heartRate), 'ghost');
    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isFalse);
  });

  // Guards the exact wave-3 danger the fix above exists for: once
  // `persistSelections` is wired to run automatically (e.g. on every
  // `onSelectionChanged`), it must not have anything to erase just because a
  // selected source has not registered yet.
  test('persisting while the selection is still pending never erases it', () async {
    final settings = Settings()..prefs = await SharedPreferences.getInstance();
    await settings.setSensorSelection(SensorQuantity.heartRate.name, 'strap');

    final hub = SensorHub();
    hub.loadSelections(settings);
    await hub.persistSelections(settings);

    expect(settings.getSensorSelection(SensorQuantity.heartRate.name), 'strap');
  });

  // V2's actual production caller (`SensorQuantitySelector._handleChanged`)
  // persists ALL quantities on every change, not just the one the rider
  // touched — that is what makes wiring one call site enough for every
  // quantity. Prove the ordering that makes that safe: a change to one
  // quantity must not stomp a DIFFERENT quantity's selection while that one
  // is still pending (source not registered), which is exactly the state a
  // rider opening the page before their strap connects leaves it in.
  test('persisting after a change to one quantity leaves a different still-pending quantity untouched', () async {
    final settings = Settings()..prefs = await SharedPreferences.getInstance();
    await settings.setSensorSelection(SensorQuantity.heartRate.name, 'strap-pending');

    final hub = SensorHub();
    hub.loadSelections(settings); // heartRate: pending 'strap-pending'; others: null.

    // Mirrors what the widget does for its OWN quantity on a rider action —
    // here, a different quantity, to isolate the cross-quantity hazard.
    hub.select(SensorQuantity.power, null);
    await hub.persistSelections(settings);

    expect(settings.getSensorSelection(SensorQuantity.heartRate.name), 'strap-pending');
  });

  test('a restored-but-missing source leaves droppedOut false', () async {
    late DateTime clock;
    clock = DateTime.utc(2026, 9, 4, 12);

    final hub = SensorHub(now: () => clock);
    final source = FakeSensorSource(
      id: 'strap',
      displayName: 'Strap',
      provides: {SensorQuantity.heartRate},
    );
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    source.emit(SensorQuantity.heartRate, 155, at: clock);

    // Advance clock past TTL and tick to drive drop-out flag true (precondition)
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isTrue);

    // Now directly select a non-existent source with the flag already true.
    // The unknown-source branch should clear the flag even though it was
    // true, even though (fix-wave-1, F4) it no longer clears the selection
    // itself — see the pending-selection tests above.
    hub.select(SensorQuantity.heartRate, 'ghost');

    expect(hub.selectionFor(SensorQuantity.heartRate), 'ghost');
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isFalse);
  });

  // Fix-wave-1 (F4 + F3 together): the id a rider persisted last session
  // survives `loadSelections` finding no source for it, and goes live the
  // moment the matching source registers — without ever touching the value
  // on disk in between.
  test('a pending selection goes live when its source registers, without ever clearing storage', () async {
    final settings = Settings()..prefs = await SharedPreferences.getInstance();
    await settings.setSensorSelection(SensorQuantity.heartRate.name, 'strap');

    // Restart with no sources: exactly what happens during real connection
    // setup, since `loadSelections` runs before any BLE scan.
    final hub = SensorHub();
    hub.loadSelections(settings);
    expect(settings.getSensorSelection(SensorQuantity.heartRate.name), 'strap');

    final source = FakeSensorSource(
      id: 'strap',
      displayName: 'Strap',
      provides: {SensorQuantity.heartRate},
    );
    hub.register(source);

    expect(hub.selectionFor(SensorQuantity.heartRate), 'strap');
    source.emit(SensorQuantity.heartRate, 162);
    expect(hub.resolved(SensorQuantity.heartRate).value, 162);
    expect(settings.getSensorSelection(SensorQuantity.heartRate.name), 'strap');
  });
}
