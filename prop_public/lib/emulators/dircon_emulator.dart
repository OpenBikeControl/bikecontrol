import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/src/models/ble_device.dart';
import 'package:universal_ble/src/models/ble_service.dart';

import 'ble_definition.dart';

enum RetrofitMode {
  proxy,
  wifi,
  bluetooth
  ;

  String get label => switch (this) {
    RetrofitMode.proxy => 'Proxy',
    RetrofitMode.wifi => 'Virtual Shifting (WiFi)',
    RetrofitMode.bluetooth => 'Virtual Shifting (Bluetooth)',
  };
}

class DirconEmulator {
  final ValueNotifier<bool> isStarted = ValueNotifier(false);
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<bool> isUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> alreadyUnlocked = ValueNotifier(false);
  final ValueNotifier<bool> waiting = ValueNotifier(false);
  final ValueNotifier<String> data = ValueNotifier('');

  final ValueNotifier<RetrofitMode> retrofitMode = ValueNotifier(RetrofitMode.proxy);

  DateTime? connectionDate;

  BleDefinition? get activeDefinition => null;

  String get advertisementName => 'null';

  List<BleService>? get services => [];

  set trainerName(String Function() trainerName) {}

  set shouldAdvertise(bool Function() shouldAdvertise) {}

  set isTrial(bool Function() isTrial) {}

  set onFitnessBikeDefinitionCreated(void Function(FitnessBikeDefinition def) onFitnessBikeDefinitionCreated) {}

  Future<void>? pauseAdvertising() async {}

  void setScanResult(BleDevice scanResult) {}

  void handleServices(List<BleService> services) {}

  Future<void> startServer() async {}

  bool processCharacteristic(String characteristic, Uint8List bytes) {
    return false;
  }

  void stop() {}

  void setRetrofitMode(RetrofitMode savedMode) {}

  Future<void> switchRetrofitMode(RetrofitMode next) async {}

  void debugSetActiveDefinition(FitnessBikeDefinition def) {}
}
