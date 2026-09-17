import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

/// V3 (wave 3): before this, the Pro check lived only in
/// `SensorQuantitySelector._handleChanged` — a one-shot gate at the moment
/// the rider taps the dropdown. `loadSelections` restores a persisted
/// selection with no check at all, and nothing re-evaluates afterwards, so a
/// rider who selects a sensor while subscribed and then lapses keeps it
/// resolving indefinitely. `SensorHub._publish` is the hub's actual "serve"
/// step — the moment a resolved value becomes visible to
/// `SensorBridgeBinding`/the standalone emulator — so the gate belongs there,
/// as a runtime callback consulted every time, not a one-shot.
void main() {
  FakeSensorSource strap() => FakeSensorSource(
    id: 'strap',
    displayName: 'Strap',
    provides: {SensorQuantity.heartRate},
  );

  test('a lapsed subscription stops resolving immediately, without clearing the selection', () {
    var isPro = true;
    final hub = SensorHub()..isProEnabled = () => isPro;
    final source = strap();
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    source.emit(SensorQuantity.heartRate, 155);
    expect(hub.resolved(SensorQuantity.heartRate).value, 155);

    isPro = false;
    hub.tick();

    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);
    // The rider's choice is untouched — no re-selecting once they resubscribe.
    expect(hub.selectionFor(SensorQuantity.heartRate), 'strap');
  });

  test('resolution resumes the moment the subscription is restored, with no reselection', () {
    var isPro = false;
    final hub = SensorHub()..isProEnabled = () => isPro;
    final source = strap();
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    source.emit(SensorQuantity.heartRate, 140);
    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);

    isPro = true;
    hub.tick();

    expect(hub.resolved(SensorQuantity.heartRate).value, 140);
  });

  // `loadSelections` runs during connection setup and calls `select()`
  // directly — the exact path the bug report calls out ("loadSelections ->
  // select() restores a lapsed subscriber's selection with no check"). Prove
  // the gate applies there too, not only after a later `tick()`.
  test('a restored selection does not resolve for a lapsed subscriber even on the very first publish', () {
    final hub = SensorHub()..isProEnabled = () => false;
    final source = strap();
    hub.register(source);
    source.emit(SensorQuantity.heartRate, 160);

    hub.select(SensorQuantity.heartRate, 'strap');

    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);
  });

  // Dozens of existing hub tests construct `SensorHub()` and never touch
  // `isProEnabled` at all. Changing the default to fail-closed would silently
  // break every one of them (and worse, silently fail-closed on a wiring bug
  // in production, where "no callback set" must never look like "no data").
  // Mirrors `DirconEmulator.shouldAdvertise`'s own documented default.
  test('an unwired gate defaults to allowed, matching every pre-existing hub test', () {
    final hub = SensorHub();
    final source = strap();
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    source.emit(SensorQuantity.heartRate, 150);

    expect(hub.resolved(SensorQuantity.heartRate).value, 150);
  });
}
