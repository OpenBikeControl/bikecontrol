import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/ble.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/crypto/local_key_provider.dart';
import 'package:swift_control/utils/crypto/zap_crypto.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/single_line_exception.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../../utils/crypto/encryption_utils.dart';

abstract class ZwiftDevice extends BaseDevice {
  final zapEncryption = ZapCrypto(LocalKeyProvider());

  ZwiftDevice(super.scanResult, {required super.availableButtons, super.isBeta});

  bool supportsEncryption = false;

  BleCharacteristic? syncRxCharacteristic;

  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_CLICK;
  String get customServiceId => BleUuid.ZWIFT_CUSTOM_SERVICE_UUID;

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
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
    );
    final syncTxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID,
    );
    syncRxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID,
    );

    if (asyncCharacteristic == null || syncTxCharacteristic == null || syncRxCharacteristic == null) {
      throw Exception('Characteristics not found');
    }

    await UniversalBle.subscribeNotifications(device.deviceId, customService.uuid, asyncCharacteristic.uuid);
    await UniversalBle.subscribeIndications(device.deviceId, customService.uuid, syncTxCharacteristic.uuid);

    await setupHandshake();
  }

  Future<void> setupHandshake() async {
    if (supportsEncryption) {
      await UniversalBle.write(
        device.deviceId,
        customServiceId,
        syncRxCharacteristic!.uuid,
        Uint8List.fromList([
          ...Constants.RIDE_ON,
          ...Constants.REQUEST_START,
          ...zapEncryption.localKeyProvider.getPublicKeyBytes(),
        ]),
        withoutResponse: true,
      );
    } else {
      await UniversalBle.write(
        device.deviceId,
        customServiceId,
        syncRxCharacteristic!.uuid,
        Constants.RIDE_ON,
        withoutResponse: true,
      );
    }
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
      } else if (!supportsEncryption || (bytes.length > Int32List.bytesPerElement + EncryptionUtils.MAC_LENGTH)) {
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
    final devicePublicKeyBytes = bytes.sublist(Constants.RIDE_ON.length + Constants.RESPONSE_START_CLICK.length);
    if (kDebugMode) {
      print("Device Public Key - ${devicePublicKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
    zapEncryption.initialise(devicePublicKeyBytes);
  }

  Future<void> processData(Uint8List bytes) async {
    int type;
    Uint8List message;

    if (supportsEncryption) {
      final counter = bytes.sublist(0, 4); // Int.SIZE_BYTES is 4
      final payload = bytes.sublist(4);

      if (zapEncryption.encryptionKeyBytes == null) {
        actionStreamInternal.add(
          LogNotification(
            'Encryption not initialized, yet. You may need to update the firmware of your device with the Zwift Companion app.',
          ),
        );
        return;
      }

      final data = zapEncryption.decrypt(counter, payload);
      type = data[0];
      message = data.sublist(1);
    } else {
      type = bytes[0];
      message = bytes.sublist(1);
    }

    switch (type) {
      case Constants.EMPTY_MESSAGE_TYPE:
        //print("Empty Message"); // expected when nothing happening
        break;
      case Constants.BATTERY_LEVEL_TYPE:
        if (batteryLevel != message[1]) {
          batteryLevel = message[1];
          connection.signalChange(this);
        }
        break;
      case Constants.CLICK_NOTIFICATION_MESSAGE_TYPE:
      case Constants.PLAY_NOTIFICATION_MESSAGE_TYPE:
      case Constants.RIDE_NOTIFICATION_MESSAGE_TYPE:
        processClickNotification(message)
            .then((buttonsClicked) async {
              return handleButtonsClicked(buttonsClicked);
            })
            .catchError((e) {
              actionStreamInternal.add(LogNotification(e.toString()));
            });
        break;
    }
  }

  Future<List<ControllerButton>?> processClickNotification(Uint8List message);

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
    final vibrateCommand = Uint8List.fromList([...Constants.VIBRATE_PATTERN, 0x20]);
    await UniversalBle.write(
      device.deviceId,
      customServiceId,
      syncRxCharacteristic!.uuid,
      supportsEncryption ? zapEncryption.encrypt(vibrateCommand) : vibrateCommand,
      withoutResponse: true,
    );
  }
}
