import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake source publishes an emitted reading for a provided quantity', () {
    final source = FakeSensorSource(
      id: 'fake-1',
      displayName: 'Fake Strap',
      provides: {SensorQuantity.heartRate},
    );
    final at = DateTime.utc(2026, 9, 4, 12);

    expect(source.readingFor(SensorQuantity.heartRate).value, isNull);

    source.emit(SensorQuantity.heartRate, 142, at: at);

    final reading = source.readingFor(SensorQuantity.heartRate).value;
    expect(reading!.value, 142);
    expect(reading.timestamp, at);
  });

  test('a quantity the source does not provide stays null after emit', () {
    final source = FakeSensorSource(
      id: 'fake-2',
      displayName: 'HR only',
      provides: {SensorQuantity.heartRate},
    );

    source.emit(SensorQuantity.power, 250);

    expect(source.readingFor(SensorQuantity.power).value, isNull);
  });

  test('stop() clears published readings so a restart cannot serve stale data', () async {
    final source = FakeSensorSource(
      id: 'fake-3',
      displayName: 'Fake Strap',
      provides: {SensorQuantity.heartRate},
    );
    source.emit(SensorQuantity.heartRate, 130);

    await source.stop();

    expect(source.readingFor(SensorQuantity.heartRate).value, isNull);
  });
}
