import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/utils/ble.dart';
import 'package:swift_control/utils/crypto/local_key_provider.dart';
import 'package:swift_control/utils/devices/zwift_click.dart';
import 'package:swift_control/utils/devices/zwift_play.dart';
import 'package:swift_control/utils/devices/zwift_ride.dart';
import 'package:universal_ble/universal_ble.dart';

import '../crypto/zap_crypto.dart';
import '../messages/notification.dart';

abstract class BaseDevice {
  final BleDevice scanResult;
  final zapEncryption = ZapCrypto(LocalKeyProvider());

  bool isConnected = false;

  bool supportsEncryption = true;

  BaseDevice(this.scanResult);

  static BaseDevice? fromScanResult(BleDevice scanResult) {
    if (scanResult.name == 'Zwift Ride') {
      return ZwiftRide(scanResult);
    }
    if (kIsWeb) {
      // manufacturer data is not available on web
      if (scanResult.name == 'Zwift Play') {
        return ZwiftPlay(scanResult);
      } else if (scanResult.name == 'Zwift Click') {
        return ZwiftClick(scanResult);
      }
    }
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
      _ => null,
    };
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
  Stream<BaseNotification> get actionStream => actionStreamInternal.stream;

  Future<void> connect() async {
    await UniversalBle.connect(device.deviceId, connectionTimeout: const Duration(seconds: 3));

    /*var filteredStateStream = await device.connectionState;

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothConnectionState> futureState = filteredStateStream.first;

    // wait for connection
    await futureState.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Failed to connect in time.');
      },
    );*/

    if (!kIsWeb && Platform.isAndroid) {
      //await UniversalBle.requestMtu(device.deviceId, 256);
    }

    final services = await UniversalBle.discoverServices(device.deviceId);
    await handleServices(services);
  }

  Future<void> handleServices(List<BleService> services);
}
