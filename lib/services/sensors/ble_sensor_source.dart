import 'package:flutter/foundation.dart';
import 'package:prop/utils/csc_measurement.dart';
import 'package:prop/utils/cps_measurement.dart';

import 'sensor_quantity.dart';
import 'sensor_reading.dart';
import 'sensor_source.dart';

/// A standards-compliant BLE sensor paired directly to BikeControl.
///
/// Parsing only. The transport (connect, subscribe, reconnect) is the
/// `BleHeartRateDevice` half; everything above this is the hub's business.
class BleSensorSource extends SensorSource {
  BleSensorSource({
    required this.id,
    required this.displayName,
    required this.provides,
  });

  static const heartRateServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  static const heartRateMeasurementUuid = '00002a37-0000-1000-8000-00805f9b34fb';
  static const cscServiceUuid = '00001816-0000-1000-8000-00805f9b34fb';
  static const cscMeasurementUuid = '00002a5b-0000-1000-8000-00805f9b34fb';
  static const cyclingPowerServiceUuid = '00001818-0000-1000-8000-00805f9b34fb';
  static const cyclingPowerMeasurementUuid = '00002a63-0000-1000-8000-00805f9b34fb';

  @override
  final String id;

  @override
  final String displayName;

  @override
  final Set<SensorQuantity> provides;

  final Map<SensorQuantity, ValueNotifier<SensorReading?>> _readings = {};

  @override
  ValueListenable<SensorReading?> readingFor(SensorQuantity quantity) => _notifierFor(quantity);

  ValueNotifier<SensorReading?> _notifierFor(SensorQuantity quantity) =>
      _readings.putIfAbsent(quantity, () => ValueNotifier<SensorReading?>(null));

  // CSC and CPS report CUMULATIVE crank revolutions, so a cadence needs two
  // samples and their delta. The first frame after connect therefore yields
  // nothing — that is correct, not a dropped reading.
  CscMeasurement? _prevCsc;
  CpsMeasurement? _prevCps;

  /// Heart Rate Measurement (0x2A37). Bit 0 of the flags byte selects uint16
  /// over uint8. A short frame is dropped rather than guessed at: a wrong
  /// heart rate is worse than none.
  void ingestHeartRateMeasurement(List<int> bytes, {DateTime? at}) {
    if (bytes.length < 2) return;
    final is16Bit = (bytes[0] & 0x01) != 0;
    if (is16Bit && bytes.length < 3) return;
    final bpm = is16Bit ? (bytes[1] | (bytes[2] << 8)) : bytes[1];
    _notifierFor(SensorQuantity.heartRate).value = SensorReading(bpm, at ?? DateTime.now());
  }

  /// CSC Measurement (0x2A5B). Cadence only comes from the delta between two
  /// samples, so the previous parse is retained across calls. A malformed
  /// frame is dropped without touching the retained sample, so a single bad
  /// notification between two good ones cannot poison the next cadence.
  void ingestCscMeasurement(List<int> bytes, {DateTime? at}) {
    final cur = CscMeasurement.parse(bytes);
    if (cur == null) return;
    final prev = _prevCsc;
    _prevCsc = cur;
    if (prev == null) return;
    if (!provides.contains(SensorQuantity.cadence)) return;
    final rpm = cscCadenceRpm(prev, cur);
    if (rpm == null) return;
    _notifierFor(SensorQuantity.cadence).value = SensorReading(rpm, at ?? DateTime.now());
  }

  /// Cycling Power Measurement (0x2A63). Power publishes from a single frame;
  /// cadence — when present and claimed — needs the delta against the
  /// retained previous sample, same as CSC.
  void ingestCpsMeasurement(List<int> bytes, {DateTime? at}) {
    final cur = CpsMeasurement.parse(bytes);
    if (cur == null) return;
    final prev = _prevCps;
    _prevCps = cur;
    final stamp = at ?? DateTime.now();

    if (provides.contains(SensorQuantity.power)) {
      _notifierFor(SensorQuantity.power).value = SensorReading(cur.powerWatts, stamp);
    }
    if (prev != null && provides.contains(SensorQuantity.cadence)) {
      final rpm = cpsCadenceRpm(prev, cur);
      if (rpm != null) {
        _notifierFor(SensorQuantity.cadence).value = SensorReading(rpm, stamp);
      }
    }
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    _prevCsc = null;
    _prevCps = null;
    for (final notifier in _readings.values) {
      notifier.value = null;
    }
  }
}
