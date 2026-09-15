import 'package:bike_control/services/sensors/fake_health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime clock;
  late SensorHub hub;
  late FakeHealthKitChannel channel;
  late HealthKitSensorSource source;

  setUp(() async {
    clock = DateTime.utc(2026, 9, 15, 9);
    hub = SensorHub(now: () => clock);
    channel = FakeHealthKitChannel();
    source = HealthKitSensorSource(channel: channel);
    hub.register(source);
    hub.select(SensorQuantity.heartRate, HealthKitSensorSource.sourceId);
    await source.start();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a 20 s gap is NOT a drop-out for HealthKit (would be for a strap)', () async {
    channel.emitSample(140, at: clock);
    await settle();
    clock = clock.add(const Duration(seconds: 20));
    hub.tick();

    expect(hub.resolved(SensorQuantity.heartRate).value, 140);
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isFalse);
  });

  test('a 35 s gap IS a drop-out — falls back to the trainer', () async {
    channel.emitSample(140, at: clock);
    await settle();
    clock = clock.add(const Duration(seconds: 35));
    hub.tick();

    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);
    expect(hub.droppedOut(SensorQuantity.heartRate).value, isTrue);
  });

  test('a batched, already-old sample is stale on arrival', () async {
    // Passive delivery: the sample's own time is 40 s ago even though it
    // reached us just now.
    channel.emitSample(140, at: clock.subtract(const Duration(seconds: 40)), mode: HealthKitMode.passive);
    await settle();
    hub.tick();

    expect(hub.resolved(SensorQuantity.heartRate).value, isNull);
  });

  test('a persisted selection binds the moment the source registers (cold launch order)', () async {
    final lateHub = SensorHub(now: () => clock);
    lateHub.select(SensorQuantity.heartRate, HealthKitSensorSource.sourceId); // from loadSelections
    expect(lateHub.resolved(SensorQuantity.heartRate).value, isNull);

    lateHub.register(source);
    channel.emitSample(99, at: clock);
    await settle();
    expect(lateHub.resolved(SensorQuantity.heartRate).value, 99);
  });

  test('unregister leaves the selection so a re-register rebinds', () async {
    hub.unregister(HealthKitSensorSource.sourceId);
    expect(hub.selectionFor(SensorQuantity.heartRate), HealthKitSensorSource.sourceId);
    hub.register(source);
    channel.emitSample(101, at: clock);
    await settle();
    expect(hub.resolved(SensorQuantity.heartRate).value, 101);
  });
}
