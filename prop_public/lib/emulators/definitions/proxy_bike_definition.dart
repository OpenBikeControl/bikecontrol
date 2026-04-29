import 'package:flutter/foundation.dart';
import 'package:prop/emulators/ble_definition.dart';
import 'package:universal_ble/universal_ble.dart';

class ProxyBikeDefinition extends BleDefinition {
  final BleDevice device;
  final List<BleService> services;
  final ValueNotifier<String> data;

  ProxyBikeDefinition({
    required this.services,
    required this.device,
    required this.data,
  });

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

  get powerW => null;

  get heartRateBpm => null;

  get cadenceRpm => null;

  get speedKph => null;
}
