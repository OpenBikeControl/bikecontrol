import 'dart:typed_data';

import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

import '../bluetooth_device.dart';

class ShimanoDi2 extends BluetoothDevice {
  ShimanoDi2(super.scanResult) : super(availableButtons: [], buttonPrefix: 'D-Fly Channel ');

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
  }

  final _lastButtons = <int, int>{};
  bool _isInitialized = false;

  @override
  String get buttonExplanation => 'Click a D-Fly button to configure them.';

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic.toLowerCase() == ShimanoDi2Constants.D_FLY_CHANNEL_UUID) {
      final channels = bytes.sublist(1);

      // On first data reception, just initialize the state without triggering buttons
      if (!_isInitialized) {
        channels.forEachIndexed((int value, int index) {
          final readableIndex = index + 1;
          _lastButtons[index] = value;

          getOrAddButton(
            'D-Fly Channel $readableIndex',
            () => ControllerButton('D-Fly Channel $readableIndex', sourceDeviceId: device.deviceId),
          );
        });
        _isInitialized = true;
        return Future.value();
      }

      final clickedButtons = <ControllerButton>[];

      channels.forEachIndexed((int value, int index) {
        final didChange = _lastButtons[index] != value;
        _lastButtons[index] = value;

        final readableIndex = index + 1;

        final button = getOrAddButton(
          'D-Fly Channel $readableIndex',
          () => ControllerButton('D-Fly Channel $readableIndex', sourceDeviceId: device.deviceId),
        );
        if (didChange) {
          clickedButtons.add(button);
        }
      });

      if (clickedButtons.isNotEmpty) {
        await handleButtonsClickedWithoutLongPressSupport(clickedButtons);
      }
    }
    return Future.value();
  }

  @override
  Widget showInformation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        super.showInformation(context),
        if (!core.settings.getShowOnboarding())
          Text(
            'Make sure to set your Di2 buttons to D-Fly channels in the Shimano E-TUBE app.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }
}

class ShimanoDi2Constants {
  static const String SERVICE_UUID = "000018ef-5348-494d-414e-4f5f424c4500";
  static const String SERVICE_UUID_ALTERNATIVE = "000018ff-5348-494d-414e-4f5f424c4500";

  static const String D_FLY_CHANNEL_UUID = "00002ac2-5348-494d-414e-4f5f424c4500";
}
