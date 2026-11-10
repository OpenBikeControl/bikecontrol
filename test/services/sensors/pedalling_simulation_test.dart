import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/pedalling_simulation.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
