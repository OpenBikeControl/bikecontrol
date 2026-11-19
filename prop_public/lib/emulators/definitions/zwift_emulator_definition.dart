//INFO: This is a stub - contact me if you need the full implementation.

import 'package:flutter/foundation.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:prop/utils/constants.dart';
import 'package:universal_ble/universal_ble.dart';

class ZwiftEmulatorDefinition extends ProxyBikeDefinition {
  /// Answers as a Zwift Ride instead of a Zwift Click while it returns true.
  final bool Function()? asRide;

  ZwiftEmulatorDefinition({
    required super.device,
    this.asRide,
  }) : super(
         data: ValueNotifier(''),
         services: [
           BleService(
             FtmsMdnsConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID,
             [
               BleCharacteristic(FtmsMdnsConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID, [CharacteristicProperty.write], []),
               BleCharacteristic(FtmsMdnsConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID, [CharacteristicProperty.notify], []),
               BleCharacteristic(FtmsMdnsConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID, [CharacteristicProperty.notify], []),
             ],
           ),
         ],
       );

  @override
  List<String> get serviceUUIDs => [FtmsMdnsConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID];

  @override
  List<String> get advertiseServiceUUIDs => const [];

  @override
  void onWriteRequest(String characteristicUUID, List<int> characteristicData) {}
}
