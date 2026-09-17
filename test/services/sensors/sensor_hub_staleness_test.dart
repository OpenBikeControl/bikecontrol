import 'package:bike_control/bluetooth/support_log_buffer.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime clock;
  late SensorHub hub;
  late FakeSensorSource source;
  late SupportLogBuffer log;

  setUp(() {
    clock = DateTime.utc(2026, 9, 4, 12);
    log = SupportLogBuffer(50);
    hub = SensorHub(now: () => clock, log: log);
    source = FakeSensorSource(
      id: 'strap',
      displayName: 'Strap',
      provides: {SensorQuantity.heartRate},
    );
    hub.register(source);
    hub.select(SensorQuantity.heartRate, 'strap');
  });

  test('a reading inside the TTL resolves to its value', () {
    source.emit(SensorQuantity.heartRate, 150, at: clock);
    clock = clock.add(const Duration(seconds: 4));
    hub.tick();

    expect(hub.resolved(SensorQuantity.heartRate).value, 150);
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isFalse);
  });

  test('a reading past the TTL falls back to the trainer', () {
    source.emit(SensorQuantity.heartRate, 150, at: clock);
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();

    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isTrue);
  });

  test('the drop-out is logged exactly once, not once per tick', () {
    source.emit(SensorQuantity.heartRate, 150, at: clock);
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();
    hub.tick();
    hub.tick();

    final drops = log.entries.where((e) => e.entry.contains('sensor drop-out'));
    expect(drops.length, 1);
  });

  test('one fresh reading re-acquires the source', () {
    source.emit(SensorQuantity.heartRate, 150, at: clock);
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isTrue);

    source.emit(SensorQuantity.heartRate, 148, at: clock);

    expect(hub.resolved(SensorQuantity.heartRate).value, 148);
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isFalse);
  });

  test('switching back to the trainer clears the drop-out flag', () {
    source.emit(SensorQuantity.heartRate, 150, at: clock);
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isTrue);

    hub.select(SensorQuantity.heartRate, null);

    expect(hub.droppedOut(SensorQuantity.heartRate).value, isFalse);
  });

  test('a second drop-out logs again after a recovery', () {
    source.emit(SensorQuantity.heartRate, 150, at: clock);
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();
    source.emit(SensorQuantity.heartRate, 148, at: clock);
    clock = clock.add(const Duration(seconds: 6));
    hub.tick();

    final drops = log.entries.where((e) => e.entry.contains('sensor drop-out'));
    expect(drops.length, 2);
  });
}
