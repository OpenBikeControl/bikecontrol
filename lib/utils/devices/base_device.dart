import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:swift_control/utils/ble.dart';
import 'package:swift_control/utils/crypto/local_key_provider.dart';
import 'package:swift_control/utils/devices/zwift_click.dart';
import 'package:swift_control/utils/devices/zwift_play.dart';
import 'package:swift_control/utils/devices/zwift_ride.dart';

import '../crypto/zap_crypto.dart';
import '../messages/notification.dart';

abstract class BaseDevice {
  final ScanResult scanResult;
  final zapEncryption = ZapCrypto(LocalKeyProvider());

  bool supportsEncryption = true;

  BaseDevice(this.scanResult);

  static BaseDevice? fromScanResult(ScanResult scanResult) {
    if (scanResult.device.platformName == 'Zwift Ride') {
      return ZwiftRide(scanResult);
    }
    if (kIsWeb) {
      // manufacturer data is not available on web
      if (scanResult.device.platformName == 'Zwift Play') {
        return ZwiftPlay(scanResult);
      } else if (scanResult.device.platformName == 'Zwift Click') {
        return ZwiftClick(scanResult);
      }
    }
    final manufacturerData = scanResult.advertisementData.manufacturerData;
    final data = manufacturerData[Constants.ZWIFT_MANUFACTURER_ID];
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

  BluetoothDevice get device => scanResult.device;
  final StreamController<BaseNotification> actionStreamInternal = StreamController<BaseNotification>.broadcast();
  Stream<BaseNotification> get actionStream => actionStreamInternal.stream;

  Future<void> connect() async {
    await device.connect(autoConnect: false).timeout(const Duration(seconds: 3));

    var filteredStateStream = device.connectionState.where((s) => s == BluetoothConnectionState.connected);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothConnectionState> futureState = filteredStateStream.first;

    // wait for connection
    await futureState.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Failed to connect in time.');
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      await device.requestMtu(256);
    }
    final services = await device.discoverServices();

    if (device.isConnected) {
      await handleServices(services);
    }
  }

  Future<void> handleServices(List<BluetoothService> services);
}
