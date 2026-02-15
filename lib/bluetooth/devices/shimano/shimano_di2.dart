import 'dart:typed_data';

import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:prop/prop.dart';
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

  final _lastButtons = <int, ({int value, _Di2State type})>{};
  bool _isInitialized = false;

  @override
  String get buttonExplanation => 'Click a D-Fly button to configure them.';

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    Logger.info('Received data from $characteristic: ${bytesToReadableHex(bytes)}');
    if (characteristic.toLowerCase() == ShimanoDi2Constants.D_FLY_CHANNEL_UUID) {
      final channels = bytes.sublist(1);

      // On first data reception, just initialize the state without triggering buttons
      if (!_isInitialized) {
        channels.forEachIndexed((int value, int index) {
          final readableIndex = index + 1;
          _lastButtons[index] = (value: value, type: _Di2State.released);

          getOrAddButton(
            'D-Fly Channel $readableIndex',
            () => ControllerButton('D-Fly Channel $readableIndex', sourceDeviceId: device.deviceId),
          );
        });
        _isInitialized = true;
        return Future.value();
      }

      var actualChange = false;
      channels.forEachIndexed((int value, int index) {
        final didChange = _lastButtons[index]?.value != value;

        final readableIndex = index + 1;

        if (didChange) {
          if ((value & 0x10) != 0) {
            if (_lastButtons[index]?.type == _Di2State.longPress || _lastButtons[index]?.type == _Di2State.keep) {
              // short press is triggered after long press, until it's released later on
              _lastButtons[index] = (value: value, type: _Di2State.keep);
              Logger.info('Button $readableIndex still long pressed');
            } else {
              _lastButtons[index] = (value: value, type: _Di2State.shortPress);
              actualChange = true;
              Logger.info('Button $readableIndex short pressed');
            }
          } else if ((value & 0x20) != 0) {
            _lastButtons[index] = (value: value, type: _Di2State.longPress);
            actualChange = true;
            Logger.info('Button $readableIndex long pressed');
          } else if ((value & 0x40) != 0) {
            _lastButtons[index] = (value: value, type: _Di2State.doublePress);
            actualChange = true;
            Logger.info('Button $readableIndex double pressed');
          } else {
            _lastButtons[index] = (value: value, type: _Di2State.released);
            actualChange = true;
            Logger.info('Button $readableIndex released');
          }
        }
      });

      if (actualChange) {
        final buttonsToTrigger = _lastButtons.entries
            .where((entry) {
              final type = entry.value.type;
              return type != _Di2State.released;
            })
            .map((entry) => availableButtons.firstWhere((button) => button.name == 'D-Fly Channel ${entry.key + 1}'))
            .toList();

        Logger.debug('Buttons to trigger: ${buttonsToTrigger.map((b) => b.name).join(', ')}');
        handleButtonsClicked(buttonsToTrigger);

        final doublePress = _lastButtons.entries
            .filter((entry) => entry.value.type == _Di2State.doublePress)
            .map((entry) => availableButtons.firstWhere((button) => button.name == 'D-Fly Channel ${entry.key + 1}'))
            .toList();
        if (doublePress.isNotEmpty) {
          Logger.debug('Buttons to still trigger: ${doublePress.map((b) => b.name).join(', ')}');
          handleButtonsClicked(doublePress);
        }
      }
    }
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

enum _Di2State {
  shortPress,
  longPress,
  keep,
  doublePress,
  released,
}
