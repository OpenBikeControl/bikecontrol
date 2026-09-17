import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_bridge_binding.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime clock;
  late SensorHub hub;
  late FakeSensorSource source;
  late List<int?> pushedHeartRate;
  late List<int?> pushedCadence;
  late List<int?> pushedPower;
  late SensorBridgeBinding binding;

  setUp(() {
    clock = DateTime.utc(2026, 9, 4, 12);
    hub = SensorHub(now: () => clock);
    source = FakeSensorSource(
      id: 'strap',
      displayName: 'Strap',
      provides: {SensorQuantity.heartRate, SensorQuantity.cadence, SensorQuantity.power},
    );
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
    hub.select(SensorQuantity.cadence, 'strap');
    hub.select(SensorQuantity.power, 'strap');
    pushedHeartRate = [];
    pushedCadence = [];
    pushedPower = [];
    binding = SensorBridgeBinding(
      hub: hub,
      onHeartRate: pushedHeartRate.add,
      onCadence: pushedCadence.add,
      onPower: pushedPower.add,
    )..start();
  });

  tearDown(() => binding.dispose());

  test('a resolved heart rate is pushed to the sink', () {
    source.emit(SensorQuantity.heartRate, 150, at: clock);

    expect(pushedHeartRate.last, 150);
  });

  test('a heart rate drop-out pushes null so the trainer takes back over', () {
    source.emit(SensorQuantity.heartRate, 150, at: clock);
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();

    expect(pushedHeartRate.last, isNull);
  });

  // T5-B: cadence and power must forward exactly like heart rate already
  // does — including null, which is how a stale sensor hands control back to
  // the trainer.
  test('a resolved cadence is pushed to the sink', () {
    source.emit(SensorQuantity.cadence, 90, at: clock);

    expect(pushedCadence.last, 90);
  });

  test('a cadence drop-out pushes null so the trainer takes back over', () {
    source.emit(SensorQuantity.cadence, 90, at: clock);
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();

    expect(pushedCadence.last, isNull);
  });

  test('a resolved power is pushed to the sink', () {
    source.emit(SensorQuantity.power, 220, at: clock);

    expect(pushedPower.last, 220);
  });

  test('a power drop-out pushes null so the trainer takes back over', () {
    source.emit(SensorQuantity.power, 220, at: clock);
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();

    expect(pushedPower.last, isNull);
  });

  test('each quantity is independent: only cadence changing does not push heart rate or power again', () {
    pushedHeartRate.clear();
    pushedPower.clear();

    source.emit(SensorQuantity.cadence, 95, at: clock);

    expect(pushedCadence.last, 95);
    expect(pushedHeartRate, isEmpty);
    expect(pushedPower, isEmpty);
  });

  test('dispose stops further pushes for all three quantities', () {
    binding.dispose();
    pushedHeartRate.clear();
    pushedCadence.clear();
    pushedPower.clear();

    source.emit(SensorQuantity.heartRate, 150, at: clock);
    source.emit(SensorQuantity.cadence, 90, at: clock);
    source.emit(SensorQuantity.power, 220, at: clock);

    expect(pushedHeartRate, isEmpty);
    expect(pushedCadence, isEmpty);
    expect(pushedPower, isEmpty);
  });
}
