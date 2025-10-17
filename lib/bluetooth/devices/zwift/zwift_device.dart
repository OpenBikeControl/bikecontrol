import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/ble.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/single_line_exception.dart';
import 'package:universal_ble/universal_ble.dart';

abstract class ZwiftDevice extends BaseDevice {
  ZwiftDevice(super.scanResult, {required super.availableButtons, super.isBeta});

  BleCharacteristic? syncRxCharacteristic;

  List<ControllerButton>? _lastButtonsClicked;

  List<int> get startCommand => ZwiftConstants.RIDE_ON + ZwiftConstants.RESPONSE_START_CLICK;
  String get customServiceId => ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID;

  @override
  Future<void> handleServices(List<BleService> services) async {
    final customService = services.firstOrNullWhere((service) => service.uuid == customServiceId);

    if (customService == null) {
      throw Exception(
        'Custom service $customServiceId not found for device $this ${device.name ?? device.rawName}.\nYou may need to update the firmware in Zwift Companion app.\nWe found: ${services.joinToString(transform: (s) => s.uuid)}',
      );
    }

    final deviceInformationService = services.firstOrNullWhere(
      (service) => service.uuid == BleUuid.DEVICE_INFORMATION_SERVICE_UUID,
    );
    final firmwareCharacteristic = deviceInformationService?.characteristics.firstOrNullWhere(
      (c) => c.uuid == BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_FIRMWARE_REVISION,
    );
    if (firmwareCharacteristic != null) {
      final firmwareData = await UniversalBle.read(
        device.deviceId,
        deviceInformationService!.uuid,
        firmwareCharacteristic.uuid,
      );
      firmwareVersion = String.fromCharCodes(firmwareData);
      connection.signalChange(this);
    }

    final asyncCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
    );
    final syncTxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == ZwiftConstants.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID,
    );
    syncRxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == ZwiftConstants.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID,
    );

    if (asyncCharacteristic == null || syncTxCharacteristic == null || syncRxCharacteristic == null) {
      throw Exception('Characteristics not found');
    }

    await UniversalBle.subscribeNotifications(device.deviceId, customService.uuid, asyncCharacteristic.uuid);
    await UniversalBle.subscribeIndications(device.deviceId, customService.uuid, syncTxCharacteristic.uuid);

    await setupHandshake();
  }

  Future<void> setupHandshake() async {
    await UniversalBle.write(
      device.deviceId,
      customServiceId,
      syncRxCharacteristic!.uuid,
      ZwiftConstants.RIDE_ON,
      withoutResponse: true,
    );
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (kDebugMode && false) {
      print(
        "${DateTime.now().toString().split(" ").last} Received data on $characteristic: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}",
      );
    }
    if (bytes.isEmpty) {
      return;
    }

    try {
      if (bytes.startsWith(startCommand)) {
        _processDevicePublicKeyResponse(bytes);
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

  void _processDevicePublicKeyResponse(Uint8List bytes) {
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
          connection.signalChange(this);
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
  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked) async {
    // the same messages are sent multiple times, so ignore
    if (_lastButtonsClicked?.contentEquals(buttonsClicked ?? []) == false) {
      super.handleButtonsClicked(buttonsClicked);
    }
    _lastButtonsClicked = buttonsClicked;
  }

  List<ControllerButton> processClickNotification(Uint8List message);

  @override
  Future<void> performDown(List<ControllerButton> buttonsClicked) async {
    if (buttonsClicked.any(((e) => e.action == InGameAction.shiftDown || e.action == InGameAction.shiftUp)) &&
        settings.getVibrationEnabled()) {
      await _vibrate();
    }
    return super.performDown(buttonsClicked);
  }

  @override
  Future<void> performClick(List<ControllerButton> buttonsClicked) async {
    if (buttonsClicked.any(((e) => e.action == InGameAction.shiftDown || e.action == InGameAction.shiftUp)) &&
        settings.getVibrationEnabled()) {
      await _vibrate();
    }
    return super.performClick(buttonsClicked);
  }

  Future<void> _vibrate() async {
    final vibrateCommand = Uint8List.fromList([...ZwiftConstants.VIBRATE_PATTERN, 0x20]);
    await UniversalBle.write(
      device.deviceId,
      customServiceId,
      syncRxCharacteristic!.uuid,
      vibrateCommand,
      withoutResponse: true,
    );
  }
}
