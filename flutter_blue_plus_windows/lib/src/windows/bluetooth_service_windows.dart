part of 'windows.dart';

class BluetoothServiceWindows extends BluetoothService {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final bool isPrimary;
  final List<BluetoothCharacteristic> characteristics;
  final List<BluetoothService> includedServices;

  BluetoothServiceWindows({
    required this.remoteId,
    required this.serviceUuid,
    required this.isPrimary,
    required this.characteristics,
    required this.includedServices,
  }) : super.fromProto(
          BmBluetoothService(
            remoteId: DeviceIdentifier(remoteId.str),
            serviceUuid: serviceUuid,
            characteristics: [for (final c in characteristics) c.toProto()],
            primaryServiceUuid: null,
          ),
        );
}
