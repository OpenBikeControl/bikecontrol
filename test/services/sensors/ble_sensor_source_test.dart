import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

BleSensorSource _source() => BleSensorSource(
  id: 'AA:BB:CC',
  displayName: 'TICKR 1234',
  provides: {SensorQuantity.heartRate},
);

void main() {
  test('parses a uint8 measurement', () {
    final source = _source();
    source.ingestHeartRateMeasurement([0x00, 150]);

    expect(source.readingFor(SensorQuantity.heartRate).value!.value, 150);
  });

  test('parses a uint16 measurement when the flag is set', () {
    final source = _source();
    source.ingestHeartRateMeasurement([0x01, 0x2C, 0x01]);

    expect(source.readingFor(SensorQuantity.heartRate).value!.value, 300);
  });

  test('stamps the reading with the ingest time', () {
    final source = _source();
    final at = DateTime.utc(2026, 9, 4, 12);

    source.ingestHeartRateMeasurement([0x00, 140], at: at);

    expect(source.readingFor(SensorQuantity.heartRate).value!.timestamp, at);
  });

  test('ignores a truncated frame rather than publishing garbage', () {
    final source = _source();
    source.ingestHeartRateMeasurement([0x00]);

    expect(source.readingFor(SensorQuantity.heartRate).value, isNull);
  });

  test('ignores a uint16-flagged frame that is too short', () {
    final source = _source();
    source.ingestHeartRateMeasurement([0x01, 0x2C]);

    expect(source.readingFor(SensorQuantity.heartRate).value, isNull);
  });
}
