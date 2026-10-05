import 'package:bike_control/services/rides/ride_sources.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5, 18);

  FakeSensorSource sensor(String id, Set<SensorQuantity> provides) =>
      FakeSensorSource(id: id, displayName: 'Sensor $id', provides: provides);

  test('a heart-rate strap alone is nothing to record from', () {
    final hr = sensor('hr', {SensorQuantity.heartRate})..emit(SensorQuantity.heartRate, 130, at: now);
    expect(metricsFromSensors([hr], now: () => now), isNull);
  });

  test('a power meter is a source; its heart-rate neighbour rides along', () {
    final pm = sensor('pm', {SensorQuantity.power, SensorQuantity.cadence})
      ..emit(SensorQuantity.power, 210, at: now)
      ..emit(SensorQuantity.cadence, 88, at: now);
    final hr = sensor('hr', {SensorQuantity.heartRate})..emit(SensorQuantity.heartRate, 140, at: now);
    final m = metricsFromSensors([hr, pm], now: () => now)!;
    expect(m.powerW.value, 210);
    expect(m.cadenceRpm.value, 88);
    expect(m.heartRateBpm.value, 140);
    // No speed sensor: no distance will be invented.
    expect(m.speedKph.value, isNull);
    expect(m.sourceName, 'Sensor pm');
    expect(m.gear, isNull);
  });

  test('a cadence sensor alone is a source', () {
    final cad = sensor('cad', {SensorQuantity.cadence})..emit(SensorQuantity.cadence, 80, at: now);
    expect(metricsFromSensors([cad], now: () => now)!.cadenceRpm.value, 80);
  });

  test('stale readings read as nothing, so a dead sensor is a standstill', () {
    final pm = sensor('pm', {SensorQuantity.power})
      ..emit(SensorQuantity.power, 210, at: now.subtract(const Duration(seconds: 30)));
    final m = metricsFromSensors([pm], now: () => now)!;
    expect(m.powerW.value, isNull);
  });

  test("the rider's chosen sensor wins over another one", () {
    final a = sensor('a', {SensorQuantity.power})..emit(SensorQuantity.power, 100, at: now);
    final b = sensor('b', {SensorQuantity.power})..emit(SensorQuantity.power, 300, at: now);
    final m = metricsFromSensors([a, b], selected: (q) => q == SensorQuantity.power ? 'b' : null, now: () => now)!;
    expect(m.powerW.value, 300);
  });
}
