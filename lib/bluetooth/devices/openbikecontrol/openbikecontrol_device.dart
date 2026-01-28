import 'dart:typed_data';

import 'package:prop/prop.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';
import 'protocol_parser.dart';

class OpenBikeControlDevice extends BluetoothDevice {
  OpenBikeControlDevice(super.scanResult)
    : super(
        availableButtons: OpenBikeProtocolParser.BUTTON_NAMES.values.toList(),
      );

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid.toLowerCase() == OpenBikeControlConstants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${OpenBikeControlConstants.SERVICE_UUID}'),
    );

    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID.toLowerCase(),
      orElse: () =>
          throw Exception('Characteristic not found: ${OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID}'),
    );

    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);

    final appInfoCharacteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID.toLowerCase(),
      orElse: () =>
          throw Exception('Characteristic not found: ${OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID}'),
    );

    await UniversalBle.write(
      device.deviceId,
      service.uuid,
      appInfoCharacteristic.uuid,
      OpenBikeProtocolParser.encodeAppInfo(
        appId: 'BikeControl',
        appVersion: packageInfoValue!.version,
        supportedButtons: OpenBikeProtocolParser.BUTTON_NAMES.values.toList(),
      ),
    );
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    final charLower = characteristic.toLowerCase();

    if (charLower == OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID.toLowerCase()) {
      try {
        final parsed = OpenBikeProtocolParser.parseButtonState(bytes);

        final buttonsToPress = parsed.where((e) => e.state == 1).map((e) => e.button).toList();

        await handleButtonsClicked(buttonsToPress);
      } catch (e) {
        actionStreamInternal.add(AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Error parsing OpenBike message: $e'));
      }
    }
  }
}

class OpenBikeControlConstants {
  // OpenBikeControl BLE service and characteristic UUIDs (see BLE.md)
  static const String SERVICE_UUID = 'd273f680-d548-419d-b9d1-fa0472345229';

  // Button State Characteristic (Notify)
  static const String BUTTON_STATE_CHARACTERISTIC_UUID = 'd273f681-d548-419d-b9d1-fa0472345229';

  // Haptic Feedback Characteristic (Write)
  static const String HAPTIC_CHARACTERISTIC_UUID = 'd273f682-d548-419d-b9d1-fa0472345229';

  // App Info Characteristic (Write)
  static const String APPINFO_CHARACTERISTIC_UUID = 'd273f683-d548-419d-b9d1-fa0472345229';
}
