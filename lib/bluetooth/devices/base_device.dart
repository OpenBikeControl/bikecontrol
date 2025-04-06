import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/ble.dart';
import 'package:swift_control/bluetooth/devices/zwift_click.dart';
import 'package:swift_control/bluetooth/devices/zwift_play.dart';
import 'package:swift_control/bluetooth/devices/zwift_ride.dart';
import 'package:swift_control/utils/crypto/local_key_provider.dart';
import 'package:swift_control/utils/crypto/zap_crypto.dart';
import 'package:swift_control/utils/single_line_exception.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../utils/crypto/encryption_utils.dart';
import '../messages/notification.dart';

abstract class BaseDevice {
  final BleDevice scanResult;
  BaseDevice(this.scanResult);

  final zapEncryption = ZapCrypto(LocalKeyProvider());

  bool isConnected = false;

  bool supportsEncryption = true;

  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_CLICK;
  String get customServiceId => BleUuid.ZWIFT_CUSTOM_SERVICE_UUID;

  static BaseDevice? fromScanResult(BleDevice scanResult) {
    // Use the name first as the "System Devices" and Web (android sometimes Windows) don't have manufacturer data
    final device = switch (scanResult.name) {
      //'Zwift Ride' => ZwiftRide(scanResult), special case for Zwift Ride: we must only connect to the left controller
      // https://www.makinolo.com/blog/2024/07/26/zwift-ride-protocol/
      'Zwift Play' => ZwiftPlay(scanResult),
      'Zwift Click' => ZwiftClick(scanResult),
      _ => null,
    };

    if (device != null) {
      return device;
    } else {
      // otherwise use the manufacturer data to identify the device
      final manufacturerData = scanResult.manufacturerDataList;
      final data = manufacturerData.firstOrNullWhere((e) => e.companyId == Constants.ZWIFT_MANUFACTURER_ID)?.payload;

      if (data == null || data.isEmpty) {
        return null;
      }

      final type = DeviceType.fromManufacturerData(data.first);
      return switch (type) {
        DeviceType.click => ZwiftClick(scanResult),
        DeviceType.playRight => ZwiftPlay(scanResult),
        DeviceType.playLeft => ZwiftPlay(scanResult),
        //DeviceType.rideRight => ZwiftRide(scanResult), // see comment above
        DeviceType.rideLeft => ZwiftRide(scanResult),
        _ => null,
      };
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseDevice && runtimeType == other.runtimeType && scanResult == other.scanResult;

  @override
  int get hashCode => scanResult.hashCode;

  @override
  String toString() {
    return runtimeType.toString();
  }

  BleDevice get device => scanResult;
  final StreamController<BaseNotification> actionStreamInternal = StreamController<BaseNotification>.broadcast();

  int? batteryLevel;
  Stream<BaseNotification> get actionStream => actionStreamInternal.stream;

  Future<void> connect() async {
    await UniversalBle.connect(device.deviceId);

    if (!kIsWeb && Platform.isAndroid) {
      //await UniversalBle.requestMtu(device.deviceId, 256);
    }

    final services = await UniversalBle.discoverServices(device.deviceId);
    await _handleServices(services);
  }

  Future<void> _handleServices(List<BleService> services) async {
    final customService = services.firstOrNullWhere((service) => service.uuid == customServiceId);

    if (customService == null) {
      throw Exception(
        'Custom service $customServiceId not found for device $this ${device.name ?? device.rawName}.\nYou may need to update the firmware in Zwift Companion app.\nWe found: ${services.joinToString(transform: (s) => s.uuid)}',
      );
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

    await UniversalBle.setNotifiable(
      device.deviceId,
      customService.uuid,
      asyncCharacteristic.uuid,
      BleInputProperty.notification,
    );
    await UniversalBle.setNotifiable(
      device.deviceId,
      customService.uuid,
      syncTxCharacteristic.uuid,
      BleInputProperty.indication,
    );

    await _setupHandshake(syncRxCharacteristic);
  }

  Future<void> _setupHandshake(BleCharacteristic syncRxCharacteristic) async {
    if (supportsEncryption) {
      await UniversalBle.writeValue(
        device.deviceId,
        customServiceId,
        syncRxCharacteristic.uuid,
        Uint8List.fromList([
          ...Constants.RIDE_ON,
          ...Constants.REQUEST_START,
          ...zapEncryption.localKeyProvider.getPublicKeyBytes(),
        ]),
        BleOutputProperty.withoutResponse,
      );
    } else {
      await UniversalBle.writeValue(
        device.deviceId,
        customServiceId,
        syncRxCharacteristic.uuid,
        Constants.RIDE_ON,
        BleOutputProperty.withoutResponse,
      );
    }
  }

  void processCharacteristic(String characteristic, Uint8List bytes) {
    if (kDebugMode && false) {
      print('Received $characteristic: ${bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
      print('Received $characteristic: ${String.fromCharCodes(bytes)}');
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
    zapEncryption.initialise(devicePublicKeyBytes);
    if (kDebugMode) {
      print("Device Public Key - ${devicePublicKeyBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}");
    }
  }

  void _processData(Uint8List bytes) {
    int type;
    Uint8List message;

    if (supportsEncryption) {
      final counter = bytes.sublist(0, 4); // Int.SIZE_BYTES is 4
      final payload = bytes.sublist(4);

      if (zapEncryption.encryptionKeyBytes == null) {
        actionStreamInternal.add(LogNotification('Encryption not initialized, yet.'));
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
        batteryLevel = message[1];
        break;
      case Constants.CLICK_NOTIFICATION_MESSAGE_TYPE:
      case Constants.PLAY_NOTIFICATION_MESSAGE_TYPE:
      case Constants.RIDE_NOTIFICATION_MESSAGE_TYPE: // untested
        processClickNotification(message);
        break;
    }
  }

  void processClickNotification(Uint8List message);
}
