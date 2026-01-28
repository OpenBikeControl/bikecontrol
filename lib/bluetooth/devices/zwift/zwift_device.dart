import 'dart:async';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/single_line_exception.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

abstract class ZwiftDevice extends BluetoothDevice {
  ZwiftDevice(super.scanResult, {required super.availableButtons, super.isBeta});

  BleCharacteristic? syncRxCharacteristic;

  List<ControllerButton>? _lastButtonsClicked;

  BleService? customService;

  String get latestFirmwareVersion;
  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK;
  bool get canVibrate => false;

  @override
  Future<void> handleServices(List<BleService> services) async {
    customService =
        services.firstOrNullWhere(
          (service) => service.uuid == ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID.toLowerCase(),
        ) ??
        services.firstOrNullWhere(
          (service) => service.uuid == ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase(),
        );

    if (customService == null) {
      actionStreamInternal.add(
        AlertNotification(
          LogLevel.LOGLEVEL_ERROR,
          'You may need to update the firmware of ${scanResult.name} in Zwift Companion app',
        ),
      );
      throw Exception(
        'Custom service ${[ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID, ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID]} not found for device $this ${device.name ?? device.rawName}.\nYou may need to update the firmware in Zwift Companion app.\nWe found: ${services.joinToString(transform: (s) => s.uuid)}',
      );
    }

    final asyncCharacteristic = customService!.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID.toLowerCase(),
    );
    final syncTxCharacteristic = customService!.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID.toLowerCase(),
    );
    syncRxCharacteristic = customService!.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID.toLowerCase(),
    );

    if (asyncCharacteristic == null || syncTxCharacteristic == null || syncRxCharacteristic == null) {
      throw Exception('Characteristics not found');
    }

    await UniversalBle.subscribeNotifications(device.deviceId, customService!.uuid, asyncCharacteristic.uuid);
    await UniversalBle.subscribeIndications(device.deviceId, customService!.uuid, syncTxCharacteristic.uuid);

    await setupHandshake();

    if (firmwareVersion != latestFirmwareVersion && firmwareVersion != null) {
      actionStreamInternal.add(
        AlertNotification(
          LogLevel.LOGLEVEL_WARNING,
          'A new firmware version is available for ${device.name ?? device.rawName}: $latestFirmwareVersion (current: $firmwareVersion). Please update it in Zwift Companion app.',
        ),
      );
    }
  }

  Future<void> setupHandshake() async {
    await UniversalBle.write(
      device.deviceId,
      customService!.uuid,
      syncRxCharacteristic!.uuid,
      ZwiftConstants.RIDE_ON,
      withoutResponse: true,
    );
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (kDebugMode && false) {
      actionStreamInternal.add(
        LogNotification(
          "Received data on $characteristic: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}",
        ),
      );
    }
    if (bytes.isEmpty) {
      return;
    }

    try {
      if (bytes.startsWith(startCommand)) {
        processDevicePublicKeyResponse(bytes);
      } else {
        processData(bytes);
      }
    } catch (e, stackTrace) {
      print("Error processing data: $e");
      print("Stack Trace: $stackTrace");
      if (e is SingleLineException) {
        actionStreamInternal.add(LogNotification(e.message));
      } else {
        actionStreamInternal.add(LogNotification("$e\n$stackTrace"));
      }
    }
  }

  void processDevicePublicKeyResponse(Uint8List bytes) {
    final devicePublicKeyBytes = bytes.sublist(
      ZwiftConstants.RIDE_ON.length + ZwiftConstants.RESPONSE_START_CLICK.length,
    );
    if (kDebugMode) {
      print("Device Public Key - ${devicePublicKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
  }

  Future<void> processData(Uint8List bytes) async {
    int type = bytes[0];
    Uint8List message = bytes.sublist(1);

    switch (type) {
      case ZwiftConstants.EMPTY_MESSAGE_TYPE:
        //print("Empty Message"); // expected when nothing happening
        break;
      case ZwiftConstants.BATTERY_LEVEL_TYPE:
        if (batteryLevel != message[1]) {
          batteryLevel = message[1];
          core.connection.signalChange(this);
        }
        break;
      case ZwiftConstants.CLICK_NOTIFICATION_MESSAGE_TYPE:
      case ZwiftConstants.PLAY_NOTIFICATION_MESSAGE_TYPE:
      case ZwiftConstants.RIDE_NOTIFICATION_MESSAGE_TYPE:
        try {
          final buttonsClicked = processClickNotification(message);
          handleButtonsClicked(buttonsClicked);
        } catch (e) {
          actionStreamInternal.add(LogNotification(e.toString()));
        }
        break;
    }
  }

  @override
  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked, {bool longPress = false}) async {
    // the same messages are sent multiple times, so ignore
    if (_lastButtonsClicked == null || _lastButtonsClicked?.contentEquals(buttonsClicked ?? []) == false) {
      super.handleButtonsClicked(buttonsClicked, longPress: longPress);
    }
    _lastButtonsClicked = buttonsClicked;
  }

  List<ControllerButton> processClickNotification(Uint8List message);

  @override
  Future<void> performDown(List<ControllerButton> buttonsClicked) async {
    if (buttonsClicked.any(((e) => e.action == InGameAction.shiftDown || e.action == InGameAction.shiftUp)) &&
        core.settings.getVibrationEnabled()) {
      await _vibrate();
    }
    return super.performDown(buttonsClicked);
  }

  @override
  Future<void> performClick(List<ControllerButton> buttonsClicked) async {
    if (buttonsClicked.any(((e) => e.action == InGameAction.shiftDown || e.action == InGameAction.shiftUp)) &&
        core.settings.getVibrationEnabled() &&
        canVibrate) {
      await _vibrate();
    }
    return super.performClick(buttonsClicked);
  }

  Future<void> _vibrate() async {
    final vibrateCommand = Uint8List.fromList([...ZwiftConstants.VIBRATE_PATTERN, 0x20]);
    await UniversalBle.write(
      device.deviceId,
      customService!.uuid,
      syncRxCharacteristic!.uuid,
      vibrateCommand,
      withoutResponse: true,
    );
  }

  @override
  Widget showInformation(BuildContext context) {
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        super.showInformation(context),

        if (canVibrate)
          Checkbox(
            trailing: Expanded(child: Text(context.i18n.enableVibrationFeedback)),
            state: core.settings.getVibrationEnabled() ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: (value) async {
              await core.settings.setVibrationEnabled(value == CheckboxState.checked);
            },
          ),
      ],
    );
  }
}
