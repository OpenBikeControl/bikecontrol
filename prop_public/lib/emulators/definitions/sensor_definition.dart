//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation serves rider metrics BikeControl itself sourced
// (heart rate, cadence, power) as a virtual BLE peripheral. This stub keeps
// the public shape only; it neither advertises nor notifies anything.

import 'dart:typed_data';

import 'package:prop/emulators/ble_definition.dart';
import 'package:universal_ble/universal_ble.dart';

/// Serves rider metrics that BikeControl itself sourced, rather than ones
/// relayed from the trainer.
class SensorDefinition extends BleDefinition {
  static const String HEART_RATE_SERVICE_UUID = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String HEART_RATE_MEASUREMENT_UUID = '00002a37-0000-1000-8000-00805f9b34fb';

  static const String CYCLING_SPEED_CADENCE_SERVICE_UUID = '00001816-0000-1000-8000-00805f9b34fb';
  static const String CSC_MEASUREMENT_UUID = '00002a5b-0000-1000-8000-00805f9b34fb';
  static const String CSC_FEATURE_UUID = '00002a5c-0000-1000-8000-00805f9b34fb';

  static const String CYCLING_POWER_SERVICE_UUID = '00001818-0000-1000-8000-00805f9b34fb';
  static const String CYCLING_POWER_MEASUREMENT_UUID = '00002a63-0000-1000-8000-00805f9b34fb';
  static const String CYCLING_POWER_FEATURE_UUID = '00002a65-0000-1000-8000-00805f9b34fb';

  static const String SENSOR_LOCATION_UUID = '00002a5d-0000-1000-8000-00805f9b34fb';

  bool get exposesHeartRate => false;

  bool get exposesCadence => false;

  bool get exposesPower => false;

  /// Chooses which services this definition advertises and notifies.
  void exposeServices({required bool heartRate, required bool cadence, required bool power}) {}

  /// Publishes [bpm], or stops notifying when null.
  void setHeartRate(int? bpm) {}

  int? get heartRateBpm => null;

  /// Publishes [rpm], or stops notifying when null.
  void setCadence(int? rpm) {}

  int? get cadenceRpm => null;

  /// Publishes [watts], or stops notifying when null.
  void setPower(int? watts) {}

  int? get powerWatts => null;

  void retractCadenceAndPowerForBridge() {}

  void restoreCadenceAndPower() {}

  set crankRevsForTesting(int value) {}

  set crankEventTime1024ForTesting(int value) {}

  @override
  List<String> get serviceUUIDs => const [];

  @override
  List<String> get advertiseServiceUUIDs => const [];

  @override
  List<BleCharacteristic> getCharacteristics(String serviceUUID) => const [];

  @override
  void onWriteRequest(String characteristicUUID, List<int> characteristicData) {}

  @override
  void onNotification(String characteristic, Uint8List bytes) {}
}
