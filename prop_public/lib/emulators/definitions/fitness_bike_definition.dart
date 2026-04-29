import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:prop/emulators/ble_definition.dart';
import 'package:universal_ble/universal_ble.dart';

/// FitnessDircon implements a virtual Fitness Machine (bike) that apps like
/// Zwift and MyWhoosh can connect to via the DirCon (Direct Connect) protocol.
///
/// Architecture mirrors SHIFTR's `DirConManager` (DirConManager.cpp):
/// - Exposes FTMS, Cycling Power and Zwift Custom services as the source of
///   truth (it is not a passthrough).
/// - Translates FTMS Control Point and Zwift Sync (`ZWIFT_SYNC_RX`) writes
///   into FTMS Control Point writes on the connected physical trainer.
/// - Implements proper Zwift virtual shifting (Sync command 0x04/0x2A) using
///   gear ratios + `Calculations` physics, not slope-byte rewriting.
/// - Pushes synthetic `ZWIFT_ASYNC` (LEB128) and `INDOOR_BIKE_DATA`
///   notifications to the connected client at 1 Hz.
class FitnessBikeDefinition extends BleDefinition {
  final BleDevice connectedDevice;
  final List<BleService> connectedDeviceServices;
  final ValueNotifier<String> data;

  /// When true, the Zwift Play custom service is included in [serviceUUIDs]
  /// and thus advertised alongside FTMS / Cycling Power. The outer app sets
  /// this to true only when the user-selected trainer app is Zwift — other
  /// apps don't consume the Zwift service, and advertising it would just add
  /// noise to their scan results and occasionally confuse their pairing flows.
  final bool shouldAdvertiseZwift;

  FitnessBikeDefinition({
    required this.connectedDevice,
    required this.connectedDeviceServices,
    required this.data,
    this.shouldAdvertiseZwift = false,
  });

  // ===========================================================================
  // BLE Service / characteristic UUIDs
  // ===========================================================================

  static const String FITNESS_MACHINE_SERVICE_UUID = '00001826-0000-1000-8000-00805f9b34fb';
  static const String CYCLING_POWER_SERVICE_UUID = '00001818-0000-1000-8000-00805f9b34fb';

  static const String FITNESS_MACHINE_FEATURE_UUID = '00002acc-0000-1000-8000-00805f9b34fb';
  static const String INDOOR_BIKE_DATA_UUID = '00002ad2-0000-1000-8000-00805f9b34fb';
  static const String SUPPORTED_INCLINATION_RANGE_UUID = '00002ad5-0000-1000-8000-00805f9b34fb';
  static const String SUPPORTED_RESISTANCE_LEVEL_RANGE_UUID = '00002ad6-0000-1000-8000-00805f9b34fb';
  static const String SUPPORTED_POWER_RANGE_UUID = '00002ad8-0000-1000-8000-00805f9b34fb';
  static const String FITNESS_MACHINE_CONTROL_POINT_UUID = '00002ad9-0000-1000-8000-00805f9b34fb';
  static const String FITNESS_MACHINE_STATUS_UUID = '00002ada-0000-1000-8000-00805f9b34fb';
  static const String TRAINING_STATUS_UUID = '00002ad3-0000-1000-8000-00805f9b34fb';

  static const String DEVICE_INFORMATION_CHARACTERISTIC_MANUFACTURER_NAME = "00002a29-0000-1000-8000-00805f9b34fb";
  static const String DEVICE_INFORMATION_CHARACTERISTIC_FIRMWARE_REVISION = "00002a26-0000-1000-8000-00805f9b34fb";
  static const String DEVICE_INFORMATION_CHARACTERISTIC_SERIAL_NUMBER = "00002a25-0000-1000-8000-00805f9b34fb";

  static const String CYCLING_POWER_MEASUREMENT_UUID = '00002a63-0000-1000-8000-00805f9b34fb';
  static const String CYCLING_POWER_FEATURE_UUID = '00002a64-0000-1000-8000-00805f9b34fb';

  /// Kept for external consumers (e.g. ProxyDircon) — this class no longer
  /// exposes a Heart Rate service itself.
  static const String HEART_RATE_MEASUREMENT_UUID = '00002a37-0000-1000-8000-00805f9b34fb';

  ValueListenable<double> bicycleWeightKg = ValueNotifier(10.0);

  ValueListenable<double> riderWeightKg = ValueNotifier(70.0);

  static List<double> defaultGearRatios = [];

  @override
  // TODO: implement advertiseServiceUUIDs
  List<String> get advertiseServiceUUIDs => throw UnimplementedError();

  @override
  List<BleCharacteristic> getCharacteristics(String serviceUUID) {
    // TODO: implement getCharacteristics
    throw UnimplementedError();
  }

  @override
  void onNotification(String characteristic, Uint8List bytes) {
    // TODO: implement onNotification
  }

  @override
  void onWriteRequest(String characteristicUUID, List<int> characteristicData) {
    // TODO: implement onWriteRequest
  }

  @override
  // TODO: implement serviceUUIDs
  List<String> get serviceUUIDs => throw UnimplementedError();

  int get maxGear => 13;

  get cadenceRpm => null;

  get speedKph => null;

  get powerW => null;

  get heartRateBpm => null;

  get trainerMode => null;

  get ergTargetPower => null;

  get currentGear => null;

  get targetPowerW => null;

  get gearRatio => null;

  ValueNotifier<List<double>> get gearRatios => ValueNotifier([]);

  ValueNotifier get virtualShiftingMode => ValueNotifier(false);

  ValueNotifier get trainerFeature => ValueNotifier(false);

  ValueListenable<bool> get gradeSmoothingEnabled => ValueNotifier(false);

  int get neutralGear => 0;

  List<String>? get trainerFtmsMachineFeatureFlagNames => null;

  List<String>? get trainerFtmsTargetSettingFlagNames => null;

  Future<void>? probeTrainerFeatures() async {}

  void setMaxGear(int maxGear) {}

  void setBicycleWeightKg(double bikeWeightKg) {}

  void setRiderWeightKg(double riderWeightKg) {}

  void setGradeSmoothingEnabled(bool gradeSmoothing) {}

  void setVirtualShiftingMode(VirtualShiftingMode mode) {}

  void setGearRatios(List<double> list) {}

  void setManualErgPower(param0) {}

  bool shiftUp() {
    return false;
  }

  bool shiftDown() {
    return false;
  }

  void exitErgMode() {}

  void adjustIntensity(double d) {}

  bool supportsVirtualShiftingMode(VirtualShiftingMode value) {
    return false;
  }

  static List<double> defaultGearRatiosFor(int count) {
    return [];
  }

  void setGearRatio(int gear, double v) {}

  void resetGearRatios() {}

  void setTargetGear(int i) {}
}

enum TrainerMode { ergMode, simMode, simModeVirtualShifting }

enum VirtualShiftingMode { targetPower, trackResistance, basicResistance }
