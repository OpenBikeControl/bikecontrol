//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation drives the Zwift Click/Play unlock handshake. This
// stub keeps the public surface so the app compiles.

import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:prop/utils/constants.dart';
import 'package:universal_ble/universal_ble.dart';

class ZwiftClickDefinition extends ProxyBikeDefinition {
  final DateTime connectionDate;
  final Uint8List? vendorMessage;
  final ValueNotifier<bool> isUnlocked;
  final ValueNotifier<bool> alreadyUnlocked;
  final ValueNotifier<bool> waiting;
  final ValueNotifier<bool> isStarted;

  /// Prefix of the prefs keys this controller's unlock state is stored under.
  final String unlockKeyPrefix;

  ZwiftClickDefinition({
    required super.services,
    required this.isUnlocked,
    required this.alreadyUnlocked,
    required this.waiting,
    required this.isStarted,
    required this.connectionDate,
    required this.vendorMessage,
    required super.device,
    required super.data,
    this.unlockKeyPrefix = 'clickV2',
  });

  @override
  List<String> get serviceUUIDs => [FtmsMdnsConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID];

  @override
  List<String> get advertiseServiceUUIDs => const [];

  @override
  List<BleCharacteristic> getCharacteristics(String serviceUUID) {
    if (serviceUUID == FtmsMdnsConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID) {
      return [
        BleCharacteristic(FtmsMdnsConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, [CharacteristicProperty.write], []),
        BleCharacteristic(FtmsMdnsConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, [CharacteristicProperty.notify], []),
        BleCharacteristic(FtmsMdnsConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID, [CharacteristicProperty.notify], []),
      ];
    }
    return const [];
  }

  @override
  void onWriteRequest(String characteristicUUID, List<int> characteristicData) {}
}
