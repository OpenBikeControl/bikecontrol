import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class ShimanoDi2 extends BluetoothDevice {
  ShimanoDi2(super.scanResult) : super(availableButtons: []);

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstWhere(
      (e) => e.uuid.toLowerCase() == ShimanoDi2Constants.SERVICE_UUID.toLowerCase(),
      orElse: () => throw Exception('Service not found: ${ShimanoDi2Constants.SERVICE_UUID}'),
    );
    final characteristic = service.characteristics.firstWhere(
      (e) => e.uuid.toLowerCase() == ShimanoDi2Constants.D_FLY_CHANNEL_UUID.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: ${ShimanoDi2Constants.D_FLY_CHANNEL_UUID}'),
    );

    await UniversalBle.subscribeIndications(device.deviceId, service.uuid, characteristic.uuid);

    if (actionHandler.supportedApp is! CustomApp) {
      actionStreamInternal.add(LogNotification('Use a custom keymap to support ${scanResult.name}'));
    }
  }

  final _lastButtons = <int, int>{};

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) {
    if (characteristic.toLowerCase() == ShimanoDi2Constants.D_FLY_CHANNEL_UUID) {
      final channels = bytes.sublist(1);
      final clickedButtons = <ControllerButton>[];

      channels.forEachIndexed((int value, int index) {
        final didChange = _lastButtons.containsKey(index) && _lastButtons[index] != value;
        _lastButtons[index] = value;

        final readableIndex = index + 1;

        final button = getOrAddButton(
          'D-Fly Channel $readableIndex',
          () => ControllerButton('D-Fly Channel $readableIndex'),
        );
        if (didChange && button != null) {
          clickedButtons.add(button);
        }
      });

      if (clickedButtons.isNotEmpty) {
        handleButtonsClicked(clickedButtons);
        handleButtonsClicked([]);
      }
    }
    return Future.value();
  }
}

class ShimanoDi2Constants {
  static const String SERVICE_UUID = "000018ef-5348-494d-414e-4f5f424c4500";

  static const String D_FLY_CHANNEL_UUID = "00002ac2-5348-494d-414e-4f5f424c4500";
}
