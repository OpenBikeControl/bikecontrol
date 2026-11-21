import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/pedalling_simulation.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs without Pro: a trial or Base install hides real sensors, not the simulation', () {
    fakeAsync((async) {
      final hub = SensorHub(now: () => async.getClock(DateTime(2026)).now())..isProEnabled = () => false;
      final sim = PedallingSimulation(hub);

      sim.start();
      async.elapse(const Duration(seconds: 1));

      expect(hub.resolved(SensorQuantity.power).value, isNotNull);
      expect(hub.resolved(SensorQuantity.cadence).value, isNotNull);
      sim.stop();
    });
  });

  test('feeds power, cadence and heart rate while running, then restores the selection', () {
    fakeAsync((async) {
      final hub = SensorHub(now: () => async.getClock(DateTime(2026)).now());
      final strap = FakeSensorSource(id: 'strap', displayName: 'Strap', provides: {SensorQuantity.heartRate});
      hub.register(strap);
      hub.select(SensorQuantity.heartRate, 'strap');
      final sim = PedallingSimulation(hub);

      sim.start();
      expect(sim.isRunning.value, isTrue);
      final powers = <int>{};
      for (var i = 0; i < 30; i++) {
        async.elapse(const Duration(seconds: 1));
        powers.add(hub.resolved(SensorQuantity.power).value!);
        expect(hub.resolved(SensorQuantity.cadence).value, inInclusiveRange(78, 98));
        expect(hub.resolved(SensorQuantity.heartRate).value, inInclusiveRange(119, 151));
      }
      expect(powers.every((w) => w >= 130 && w <= 270), isTrue);
      expect(powers.length, greaterThan(5), reason: 'power should vary');

      sim.stop();
      expect(sim.isRunning.value, isFalse);
      expect(hub.selectionFor(SensorQuantity.heartRate), 'strap');
      expect(hub.selectionFor(SensorQuantity.power), isNull);
      expect(hub.resolved(SensorQuantity.power).value, isNull);
      async.elapse(const Duration(seconds: 5));
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('rides a hilly route an incline device can follow, and stops it with the ride', () {
    fakeAsync((async) {
      final hub = SensorHub(now: () => async.getClock(DateTime(2026)).now());
      final sim = PedallingSimulation(hub);
      expect(sim.grade.value, isNull);

      sim.start();
      final grades = <int>[];
      for (var i = 0; i < 180; i++) {
        async.elapse(const Duration(seconds: 1));
        grades.add(sim.grade.value!);
      }
      expect(grades.every((g) => g % 50 == 0), isTrue, reason: '0.5% steps');
      expect(grades.reduce((a, b) => a < b ? a : b), lessThan(0), reason: 'descends');
      expect(grades.reduce((a, b) => a > b ? a : b), greaterThan(800), reason: 'climbs');
      var changes = 0;
      for (var i = 1; i < grades.length; i++) {
        if (grades[i] != grades[i - 1]) changes++;
      }
      expect(changes, lessThan(grades.length ~/ 2), reason: 'holds a grade for a while, not a new one every second');

      sim.stop();
      expect(sim.grade.value, isNull);
    });
  });
}
