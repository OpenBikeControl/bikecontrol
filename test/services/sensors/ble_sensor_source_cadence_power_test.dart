import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';
import 'package:flutter_test/flutter_test.dart';

BleSensorSource _cadenceSource() => BleSensorSource(
  id: 'csc-1',
  displayName: 'Cadence sensor',
  provides: {SensorQuantity.cadence},
);

BleSensorSource _powerSource() => BleSensorSource(
  id: 'cps-1',
  displayName: 'Power meter',
  provides: {SensorQuantity.cadence, SensorQuantity.power},
);

/// CSC frame with crank data only: flags 0x02, uint16 cum revs, uint16 event time.
List<int> _csc(int revs, int t1024) => [0x02, revs & 0xFF, (revs >> 8) & 0xFF, t1024 & 0xFF, (t1024 >> 8) & 0xFF];

/// CPS frame: flags uint16, sint16 power, then optional fields.
/// Flags 0x20 = crank revolution data present.
List<int> _cpsWithCrank(int watts, int revs, int t1024) => [
  0x20,
  0x00,
  watts & 0xFF,
  (watts >> 8) & 0xFF,
  revs & 0xFF,
  (revs >> 8) & 0xFF,
  t1024 & 0xFF,
  (t1024 >> 8) & 0xFF,
];

List<int> _cpsPowerOnly(int watts) => [0x00, 0x00, watts & 0xFF, (watts >> 8) & 0xFF];

void main() {
  group('CSC cadence', () {
    test('the first frame alone yields no cadence', () {
      final source = _cadenceSource();

      source.ingestCscMeasurement(_csc(100, 1024));

      expect(source.readingFor(SensorQuantity.cadence).value, isNull);
    });

    test('two frames one second and one revolution apart give 60 rpm', () {
      final source = _cadenceSource();

      source.ingestCscMeasurement(_csc(100, 1024));
      source.ingestCscMeasurement(_csc(101, 2048));

      expect(source.readingFor(SensorQuantity.cadence).value!.value, 60);
    });

    test('handles the 16-bit event-time wrap', () {
      final source = _cadenceSource();

      source.ingestCscMeasurement(_csc(100, 65535));
      // 1024 ticks later, wrapped: (1023 - 65535) & 0xFFFF == 1024
      source.ingestCscMeasurement(_csc(101, 1023));

      expect(source.readingFor(SensorQuantity.cadence).value!.value, 60);
    });

    test('a zero time delta is dropped rather than dividing by zero', () {
      final source = _cadenceSource();

      source.ingestCscMeasurement(_csc(100, 1024));
      source.ingestCscMeasurement(_csc(101, 1024));

      expect(source.readingFor(SensorQuantity.cadence).value, isNull);
    });

    test('a malformed frame does not corrupt the retained previous sample', () {
      final source = _cadenceSource();
      source.ingestCscMeasurement(_csc(100, 1024));

      source.ingestCscMeasurement([0x02, 0x01]); // truncated
      source.ingestCscMeasurement(_csc(101, 2048));

      expect(source.readingFor(SensorQuantity.cadence).value!.value, 60);
    });

    // Review finding, Task 1: the mirror of the CPS group's own
    // "does not claim cadence" guard test below, but for CSC ingestion —
    // provides gates ingestCscMeasurement just as it gates ingestCpsMeasurement.
    test('a source that does not claim cadence never publishes it', () {
      final source = BleSensorSource(
        id: 'csc-2',
        displayName: 'Cadence not claimed',
        provides: const {},
      );

      source.ingestCscMeasurement(_csc(100, 1024));
      source.ingestCscMeasurement(_csc(101, 2048));

      expect(source.readingFor(SensorQuantity.cadence).value, isNull);
    });
  });

  group('CPS power', () {
    test('publishes instantaneous power from a single frame', () {
      final source = _powerSource();

      source.ingestCpsMeasurement(_cpsPowerOnly(250));

      expect(source.readingFor(SensorQuantity.power).value!.value, 250);
    });

    test('negative power is decoded as signed, not as a huge positive', () {
      final source = _powerSource();

      source.ingestCpsMeasurement(_cpsPowerOnly(-5 & 0xFFFF));

      expect(source.readingFor(SensorQuantity.power).value!.value, -5);
    });

    test('two crank frames also yield cadence', () {
      final source = _powerSource();

      source.ingestCpsMeasurement(_cpsWithCrank(200, 10, 1024));
      source.ingestCpsMeasurement(_cpsWithCrank(210, 11, 2048));

      expect(source.readingFor(SensorQuantity.power).value!.value, 210);
      expect(source.readingFor(SensorQuantity.cadence).value!.value, 60);
    });

    test('a source that does not claim cadence never publishes it', () {
      final source = BleSensorSource(
        id: 'cps-2',
        displayName: 'Power only',
        provides: {SensorQuantity.power},
      );

      source.ingestCpsMeasurement(_cpsWithCrank(200, 10, 1024));
      source.ingestCpsMeasurement(_cpsWithCrank(210, 11, 2048));

      expect(source.readingFor(SensorQuantity.cadence).value, isNull);
    });

    // Review finding, Task 1: the missing counterpart of the test above —
    // provides gates the power publish too, not just the cadence one.
    test('a source that does not claim power never publishes it', () {
      final source = BleSensorSource(
        id: 'cps-3',
        displayName: 'Cadence only',
        provides: {SensorQuantity.cadence},
      );

      source.ingestCpsMeasurement(_cpsPowerOnly(250));

      expect(source.readingFor(SensorQuantity.power).value, isNull);
    });
  });

  // Fix round 1, Finding 2: nothing exercised stop()'s clearing of _prevCsc/
  // _prevCps. Without it, a reconnect's first post-gap frame would diff
  // against the pre-disconnect sample and publish a cadence computed across
  // however long the sensor was gone — e.g. a few RPM if the gap was long,
  // or an enormous spike if it was short and revolutions jumped a lot. Both
  // cases below prove the retained sample is actually gone, not just the
  // published reading (stop() clears both, but they are independent bugs).
  group('stop() clears retained samples', () {
    test('CSC: a reconnect cannot diff a cadence across the gap', () async {
      final source = _cadenceSource();
      source.ingestCscMeasurement(_csc(100, 1024));
      source.ingestCscMeasurement(_csc(101, 2048));
      expect(source.readingFor(SensorQuantity.cadence).value!.value, 60);

      await source.stop();

      // A huge, arbitrary jump: if _prevCsc were not cleared, this would
      // diff against (101, 2048) and publish some cadence value instead of
      // being treated as the first frame again (see "the first frame alone
      // yields no cadence" above).
      source.ingestCscMeasurement(_csc(5000, 50000));

      expect(source.readingFor(SensorQuantity.cadence).value, isNull);
    });

    test('CPS: a reconnect cannot diff a cadence across the gap, though power still publishes immediately', () async {
      final source = _powerSource();
      source.ingestCpsMeasurement(_cpsWithCrank(200, 10, 1024));
      source.ingestCpsMeasurement(_cpsWithCrank(210, 11, 2048));
      expect(source.readingFor(SensorQuantity.cadence).value!.value, 60);

      await source.stop();

      source.ingestCpsMeasurement(_cpsWithCrank(220, 5000, 50000));

      // Power needs no delta, so it publishes from this single frame...
      expect(source.readingFor(SensorQuantity.power).value!.value, 220);
      // ...but cadence does, and must not diff against the pre-stop sample.
      expect(source.readingFor(SensorQuantity.cadence).value, isNull);
    });
  });
}
