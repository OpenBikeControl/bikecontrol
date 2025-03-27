import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

extension BluetoothServiceExtension on BluetoothService {
  BmBluetoothService toProto() {
    return BmBluetoothService(
      serviceUuid: serviceUuid,
      remoteId: DeviceIdentifier(remoteId.str),
      characteristics: [for (final c in characteristics) c.toProto()],
      primaryServiceUuid: null, // TODO:  API changes
    );
  }
}
