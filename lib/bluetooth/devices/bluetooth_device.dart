import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/widgets/beta_pill.dart';
import 'package:universal_ble/universal_ble.dart';

import 'elite/elite_square.dart';
import 'elite/elite_sterzo.dart';

abstract class BluetoothDevice extends BaseDevice {
  final BleDevice scanResult;

  BluetoothDevice(this.scanResult, {required super.availableButtons, super.isBeta = false})
    : super(scanResult.name ?? 'Unknown Device');

  int? batteryLevel;
  String? firmwareVersion;

  static List<String> servicesToScan = [
    ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID,
    ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID,
    SquareConstants.SERVICE_UUID,
    WahooKickrBikeShiftConstants.SERVICE_UUID,
    SterzoConstants.SERVICE_UUID,
  ];

  static BluetoothDevice? fromScanResult(BleDevice scanResult) {
    // Use the name first as the "System Devices" and Web (android sometimes Windows) don't have manufacturer data
    BluetoothDevice? device;
    if (kIsWeb) {
      device = switch (scanResult.name) {
        'Zwift Ride' => ZwiftRide(scanResult),
        'Zwift Play' => ZwiftPlay(scanResult),
        'Zwift Click' => ZwiftClickV2(scanResult),
        'SQUARE' => EliteSquare(scanResult),
        _ => null,
      };

      if (scanResult.name != null && scanResult.name!.toUpperCase().startsWith('KICKR BIKE SHIFT')) {
        device = WahooKickrBikeShift(scanResult);
      }

      if (scanResult.name != null && scanResult.name!.toUpperCase().startsWith('STERZO')) {
        device = EliteSterzo(scanResult);
      }
    } else {
      device = switch (scanResult.name) {
        //'Zwift Ride' => ZwiftRide(scanResult), special case for Zwift Ride: we must only connect to the left controller
        // https://www.makinolo.com/blog/2024/07/26/zwift-ride-protocol/
        'Zwift Play' => ZwiftPlay(scanResult),
        //'Zwift Click' => ZwiftClick(scanResult), special case for Zwift Click v2: we must only connect to the left controller
        _ => null,
      };

      if (scanResult.name != null) {
        if (scanResult.name!.toUpperCase().startsWith('STERZO')) {
          device = EliteSterzo(scanResult);
        } else if (scanResult.name!.toUpperCase().startsWith('KICKR BIKE SHIFT')) {
          return WahooKickrBikeShift(scanResult);
        }
      }
    }

    if (device != null) {
      return device;
    } else if (scanResult.services.containsAny([
      ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID,
      ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID,
    ])) {
      // otherwise use the manufacturer data to identify the device
      final manufacturerData = scanResult.manufacturerDataList;
      final data = manufacturerData
          .firstOrNullWhere((e) => e.companyId == ZwiftConstants.ZWIFT_MANUFACTURER_ID)
          ?.payload;

      if (data == null || data.isEmpty) {
        return null;
      }

      final type = ZwiftDeviceType.fromManufacturerData(data.first);
      return switch (type) {
        ZwiftDeviceType.click => ZwiftClick(scanResult),
        ZwiftDeviceType.playRight => ZwiftPlay(scanResult),
        ZwiftDeviceType.playLeft => ZwiftPlay(scanResult),
        ZwiftDeviceType.rideLeft => ZwiftRide(scanResult),
        //DeviceType.rideRight => ZwiftRide(scanResult), // see comment above
        ZwiftDeviceType.clickV2Left => ZwiftClickV2(scanResult),
        //DeviceType.clickV2Right => ZwiftClickV2(scanResult), // see comment above
        _ => null,
      };
    } else if (scanResult.services.contains(SquareConstants.SERVICE_UUID)) {
      return EliteSquare(scanResult);
    } else if (scanResult.services.contains(SterzoConstants.SERVICE_UUID)) {
      return EliteSterzo(scanResult);
    } else {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice && runtimeType == other.runtimeType && scanResult == other.scanResult;

  @override
  int get hashCode => scanResult.hashCode;

  @override
  String toString() {
    return runtimeType.toString();
  }

  BleDevice get device => scanResult;

  @override
  Future<void> connect() async {
    actionStream.listen((message) {
      print("Received message: $message");
    });

    await UniversalBle.connect(device.deviceId);

    if (!kIsWeb) {
      await UniversalBle.requestMtu(device.deviceId, 517);
    }

    final services = await UniversalBle.discoverServices(device.deviceId);
    await handleServices(services);
  }

  Future<void> handleServices(List<BleService> services);
  Future<void> processCharacteristic(String characteristic, Uint8List bytes);

  @override
  Future<void> disconnect() async {
    await UniversalBle.disconnect(device.deviceId);
    super.disconnect();
  }

  @override
  Widget showInformation(BuildContext context) {
    return Row(
      children: [
        Text(
          device.name?.screenshot ?? device.runtimeType.toString(),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (isBeta) BetaPill(),
        if (batteryLevel != null) ...[
          Icon(switch (batteryLevel!) {
            >= 80 => Icons.battery_full,
            >= 60 => Icons.battery_6_bar,
            >= 50 => Icons.battery_5_bar,
            >= 25 => Icons.battery_4_bar,
            >= 10 => Icons.battery_2_bar,
            _ => Icons.battery_alert,
          }),
          Text('$batteryLevel%'),
        ],
        if (firmwareVersion != null) Text(' - Firmware: $firmwareVersion'),
        if (firmwareVersion != null &&
            this is ZwiftDevice &&
            firmwareVersion != (this as ZwiftDevice).latestFirmwareVersion) ...[
          SizedBox(width: 8),
          Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
          Text(
            ' (latest: ${(this as ZwiftDevice).latestFirmwareVersion})',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
