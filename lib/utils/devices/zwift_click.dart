import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/devices/base_device.dart';
import 'package:swift_control/utils/messages/notification.dart';

import '../ble.dart';
import '../crypto/encryption_utils.dart';
import '../messages/click_notification.dart';

class ZwiftClick extends BaseDevice {
  ZwiftClick(super.scanResult);

  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_CLICK;
  Guid get customServiceId => BleUuid.ZWIFT_CUSTOM_SERVICE_UUID;

  @override
  Future<void> handleServices(List<BluetoothService> services) async {
    final customService = services.firstOrNullWhere((service) => service.uuid == customServiceId);

    if (customService == null) {
      throw Exception('Custom service not found');
    }

    final asyncCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
    );
    final syncTxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_SYNC_TX_CHARACTERISTIC_UUID,
    );
    final syncRxCharacteristic = customService.characteristics.firstOrNullWhere(
      (characteristic) => characteristic.uuid == BleUuid.ZWIFT_SYNC_RX_CHARACTERISTIC_UUID,
    );

    if (asyncCharacteristic == null || syncTxCharacteristic == null || syncRxCharacteristic == null) {
      throw Exception('Characteristics not found');
    }

    if (!asyncCharacteristic.isNotifying) {
      await asyncCharacteristic.setNotifyValue(true);
    }
    final asyncSubscription = asyncCharacteristic.lastValueStream.listen((onData) {
      _processCharacteristic('async', Uint8List.fromList(onData));
    });
    device.cancelWhenDisconnected(asyncSubscription);

    if (!syncTxCharacteristic.isNotifying) {
      await syncTxCharacteristic.setNotifyValue(true, forceIndications: !kIsWeb && Platform.isAndroid);
    }
    final syncSubscription = syncTxCharacteristic.lastValueStream.listen((onData) {
      _processCharacteristic('sync', Uint8List.fromList(onData));
    });
    device.cancelWhenDisconnected(syncSubscription);

    await _setupHandshake(syncRxCharacteristic);
  }

  Future<void> _setupHandshake(BluetoothCharacteristic syncRxCharacteristic) async {
    if (supportsEncryption) {
      await syncRxCharacteristic.write([
        ...Constants.RIDE_ON,
        ...Constants.REQUEST_START,
        ...zapEncryption.localKeyProvider.getPublicKeyBytes(),
      ], withoutResponse: true);
    } else {
      await syncRxCharacteristic.write(Constants.RIDE_ON, withoutResponse: true);
    }
  }

  void _processCharacteristic(String tag, Uint8List bytes) {
    if (kDebugMode && false) {
      print('Received $tag: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
      print('Received $tag: ${String.fromCharCodes(bytes)}');
    }

    if (bytes.isEmpty) {
      return;
    }

    try {
      if (bytes.startsWith(startCommand)) {
        _processDevicePublicKeyResponse(bytes);
      } else if (bytes.startsWith(Constants.RIDE_ON)) {
        //print("Empty RideOn response - unencrypted mode");
      } else if (!supportsEncryption || (bytes.length > Int32List.bytesPerElement + EncryptionUtils.MAC_LENGTH)) {
        _processData(bytes);
      } else if (bytes[0] == Constants.DISCONNECT_MESSAGE_TYPE) {
        //print("Disconnect message");
      } else {
        //print("Unprocessed - Data Type: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
      }
    } catch (e, stackTrace) {
      print("Error processing data: $e");
      print("Stack Trace: $stackTrace");
      actionStreamInternal.add(LogNotification(e.toString()));
    }
  }

  ClickNotification? _lastClickNotification;

  void _processData(Uint8List bytes) {
    int type;
    Uint8List message;

    if (supportsEncryption) {
      final counter = bytes.sublist(0, 4); // Int.SIZE_BYTES is 4
      final payload = bytes.sublist(4);

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
        //print("Battery level update: $message");
        break;
      case Constants.CLICK_NOTIFICATION_MESSAGE_TYPE:
      case Constants.PLAY_NOTIFICATION_MESSAGE_TYPE:
      case Constants.RIDE_NOTIFICATION_MESSAGE_TYPE: // untested
        processClickNotification(message);
        break;
    }
  }

  void _processDevicePublicKeyResponse(Uint8List bytes) {
    final devicePublicKeyBytes = bytes.sublist(Constants.RIDE_ON.length + Constants.RESPONSE_START_CLICK.length);
    zapEncryption.initialise(devicePublicKeyBytes);
    if (kDebugMode) {
      print("Device Public Key - ${devicePublicKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
  }

  void processClickNotification(Uint8List message) {
    final ClickNotification clickNotification = ClickNotification(message);
    if (_lastClickNotification == null || _lastClickNotification != clickNotification) {
      _lastClickNotification = clickNotification;
      actionStreamInternal.add(clickNotification);

      if (clickNotification.buttonUp) {
        actionHandler.increaseGear();
      } else if (clickNotification.buttonDown) {
        actionHandler.decreaseGear();
      }
    }
  }
}
