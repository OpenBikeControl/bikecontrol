import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:swift_control/bluetooth/ble.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:swift_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/widgets/beta_pill.dart';
import 'package:universal_ble/universal_ble.dart';

import 'cycplus/cycplus_bc2.dart';
import 'elite/elite_square.dart';
import 'elite/elite_sterzo.dart';

abstract class BluetoothDevice extends BaseDevice {
  final BleDevice scanResult;

  BluetoothDevice(this.scanResult, {required super.availableButtons, super.isBeta = false})
    : super(scanResult.name ?? 'Unknown Device') {
    rssi = scanResult.rssi;
  }

  int? batteryLevel;
  String? firmwareVersion;
  int? rssi;

  static List<String> servicesToScan = [
    ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID,
    ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID,
    SquareConstants.SERVICE_UUID,
    WahooKickrBikeShiftConstants.SERVICE_UUID,
    SterzoConstants.SERVICE_UUID,
    CycplusBc2Constants.SERVICE_UUID,
    ShimanoDi2Constants.SERVICE_UUID,
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
        null => null,
        _ when scanResult.name!.toUpperCase().startsWith('STERZO') => EliteSterzo(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE SHIFT') => WahooKickrBikeShift(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('CYCPLUS') && scanResult.name!.toUpperCase().contains('BC2') =>
          CycplusBc2(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('RDR') => ShimanoDi2(scanResult),
        _ => null,
      };
    } else {
      device = switch (scanResult.name) {
        null => null,
        //'Zwift Ride' => ZwiftRide(scanResult), special case for Zwift Ride: we must only connect to the left controller
        // https://www.makinolo.com/blog/2024/07/26/zwift-ride-protocol/
        'Zwift Play' => ZwiftPlay(scanResult),
        //'Zwift Click' => ZwiftClick(scanResult), special case for Zwift Click v2: we must only connect to the left controller
        _ when scanResult.name!.toUpperCase().startsWith('SQUARE') => EliteSquare(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('STERZO') => EliteSterzo(scanResult),
        _ when scanResult.name!.toUpperCase().contains('KICKR BIKE SHIFT') => WahooKickrBikeShift(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('CYCPLUS') && scanResult.name!.toUpperCase().contains('BC2') =>
          CycplusBc2(scanResult),
        _ when scanResult.services.contains(CycplusBc2Constants.SERVICE_UUID.toLowerCase()) => CycplusBc2(scanResult),
        _ when scanResult.services.contains(ShimanoDi2Constants.SERVICE_UUID.toLowerCase()) => ShimanoDi2(scanResult),
        // otherwise the service UUIDs will be used
        _ => null,
      };
    }

    if (device != null) {
      return device;
    } else if (scanResult.services.containsAny([
      ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase(),
      ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID.toLowerCase(),
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
    } else {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice && runtimeType == other.runtimeType && scanResult.deviceId == other.scanResult.deviceId;

  @override
  int get hashCode => scanResult.deviceId.hashCode;

  @override
  String toString() {
    return name + (firmwareVersion != null ? ' v$firmwareVersion' : '');
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
    final deviceInformationService = services.firstOrNullWhere(
      (service) => service.uuid == BleUuid.DEVICE_INFORMATION_SERVICE_UUID.toLowerCase(),
    );
    final firmwareCharacteristic = deviceInformationService?.characteristics.firstOrNullWhere(
      (c) => c.uuid == BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_FIRMWARE_REVISION.toLowerCase(),
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

    final batteryService = services.firstOrNullWhere(
      (service) => service.uuid == BleUuid.DEVICE_BATTERY_SERVICE_UUID.toLowerCase(),
    );

    final batteryCharacteristic = batteryService?.characteristics.firstOrNullWhere(
      (c) => c.uuid == BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL.toLowerCase(),
    );
    if (batteryCharacteristic != null) {
      final batteryData = await UniversalBle.read(
        device.deviceId,
        batteryService!.uuid,
        batteryCharacteristic.uuid,
      );
      if (batteryData.isNotEmpty) {
        batteryLevel = batteryData.first;
        connection.signalChange(this);
      }
    }

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
          device.name?.screenshot ?? runtimeType.toString(),
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
        if (firmwareVersion != null) Text(' - v$firmwareVersion'),
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
        if (rssi != null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Tooltip(
              message: 'Signal Strength: $rssi dBm',
              child: Icon(
                switch (rssi!) {
                  >= -50 => Icons.signal_cellular_4_bar,
                  >= -60 => Icons.signal_cellular_alt_2_bar,
                  >= -70 => Icons.signal_cellular_alt_1_bar,
                  _ => Icons.signal_cellular_alt,
                },
                size: 18,
              ),
            ),
          ),
        Expanded(child: SizedBox()),
        PopupMenuButton(
          itemBuilder: (c) => [
            PopupMenuItem(
              child: Text('Disconnect and Forget'),
              onTap: () {
                connection.disconnect(this, forget: true);
              },
            ),
          ],
        ),
      ],
    );
  }
}
