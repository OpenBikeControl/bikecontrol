import 'package:bike_control/services/sensors/fake_health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_channel.dart';
import 'package:bike_control/services/sensors/health_kit_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_hub.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeHealthKitChannel channel;
  late HealthKitSensorSource source;
  final t0 = DateTime.utc(2026, 9, 15, 9);

  setUp(() {
    channel = FakeHealthKitChannel();
    source = HealthKitSensorSource(channel: channel);
  });

  test('identity: fixed id, product display name, heart rate only, HealthKit TTL', () {
    expect(source.id, 'healthkit');
    expect(HealthKitSensorSource.sourceId, 'healthkit');
    expect(source.displayName, 'Apple Health');
    expect(source.provides, {SensorQuantity.heartRate});
    expect(source.ttl, SensorHub.healthKitTtl);
  });

  test('a sample becomes a reading stamped with the SAMPLE time, not receipt time', () async {
    await source.start();
    channel.emitSample(142, at: t0);
    await Future<void>.delayed(Duration.zero);

    final reading = source.readingFor(SensorQuantity.heartRate).value;
    expect(reading, isNotNull);
    expect(reading!.value, 142);
    expect(reading.timestamp, t0);
  });

  test('mode is null before start, follows the channel, and clears on stop', () async {
    expect(source.mode.value, isNull);
    await source.start();
    channel.emitMode(HealthKitMode.passive);
    await Future<void>.delayed(Duration.zero);
    expect(source.mode.value, HealthKitMode.passive);

    channel.emitSample(90, at: t0, mode: HealthKitMode.session);
    await Future<void>.delayed(Duration.zero);
    expect(source.mode.value, HealthKitMode.session, reason: 'a sample carries the live mode too');

    await source.stop();
    expect(source.mode.value, isNull);
  });

  test('start is idempotent: one native start, one subscription', () async {
    await source.start();
    await source.start();
    expect(channel.startCalls, 1);

    channel.emitSample(100, at: t0);
    await Future<void>.delayed(Duration.zero);
    // Would be delivered twice with two subscriptions; the notifier would still show 100,
    // so count via a listener instead.
    var notifications = 0;
    source.readingFor(SensorQuantity.heartRate).addListener(() => notifications++);
    channel.emitSample(101, at: t0.add(const Duration(seconds: 1)));
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 1);
  });

  test('stop clears the retained reading and ignores samples afterwards', () async {
    await source.start();
    channel.emitSample(120, at: t0);
    await Future<void>.delayed(Duration.zero);
    await source.stop();
    expect(channel.stopCalls, 1);
    expect(source.readingFor(SensorQuantity.heartRate).value, isNull);

    channel.emitSample(121, at: t0.add(const Duration(seconds: 1)));
    await Future<void>.delayed(Duration.zero);
    expect(source.readingFor(SensorQuantity.heartRate).value, isNull);
  });

  test('stop before start, and stop twice, are no-ops', () async {
    await source.stop();
    expect(channel.stopCalls, 0);
    await source.start();
    await source.stop();
    await source.stop();
    expect(channel.stopCalls, 1);
  });

  test('a stream error is recorded and does not kill the subscription', () async {
    await source.start();
    channel.emitError(StateError('session failed'));
    await Future<void>.delayed(Duration.zero);
    channel.emitSample(130, at: t0);
    await Future<void>.delayed(Duration.zero);
    expect(source.readingFor(SensorQuantity.heartRate).value?.value, 130);
  });

  test('authorize passes the channel verdict through', () async {
    channel.authorization = HealthKitAuthorization.denied;
    expect(await source.authorize(), HealthKitAuthorization.denied);
  });
}
