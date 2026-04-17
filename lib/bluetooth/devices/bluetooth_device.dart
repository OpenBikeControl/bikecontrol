import 'dart:async';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_pro.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import 'cycplus/cycplus_bc2.dart';
import 'elite/elite_square.dart';
import 'elite/elite_sterzo.dart';
import 'thinkrider/thinkrider_vs200.dart';

abstract class BluetoothDevice extends BaseDevice {
  final BleDevice scanResult;

  BluetoothDevice(
    this.scanResult, {
    required List<ControllerButton> availableButtons,
    bool allowMultiple = false,
    bool isBeta = false,
    bool supportsLongPress = true,
    String? buttonPrefix,
  }) : super(
         scanResult.name,
         icon: LucideIcons.gamepad,
         uniqueId: scanResult.deviceId,
         availableButtons: allowMultiple
             ? availableButtons.toList().map((b) => b.copyWith(sourceDeviceId: scanResult.deviceId)).toList()
             : availableButtons.toList(),
         isBeta: isBeta,
         supportsLongPress: supportsLongPress,
         buttonPrefix: buttonPrefix,
       ) {
    rssi = scanResult.rssi;
  }

  int? batteryLevel;
  String? firmwareVersion;
  int? rssi;

  static List<String> servicesToScan = [
    ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID,
    ZwiftConstants.ZWIFT_CUSTOM_SERVICE_SHORT_UUID,
    ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID,
    SquareConstants.SERVICE_UUID,
    WahooKickrBikeShiftConstants.SERVICE_UUID,
    WahooKickrHeadwindConstants.SERVICE_UUID,
    SterzoConstants.SERVICE_UUID,
    CycplusBc2Constants.SERVICE_UUID,
    ShimanoDi2Constants.SERVICE_UUID,
    ShimanoDi2Constants.SERVICE_UUID_ALTERNATIVE,
    OpenBikeControlConstants.SERVICE_UUID,
    ThinkRiderVs200Constants.SERVICE_UUID,
  ];

  static final List<String> _ignoredNames = ['ASSIOMA', 'QUARQ', 'POWERCRANK'];

  List<BleService>? services;

  static BluetoothDevice? fromScanResult(BleDevice scanResult) {
    // skip devices with ignored names
    if (scanResult.name != null &&
        _ignoredNames.any((ignoredName) => scanResult.name!.toUpperCase().startsWith(ignoredName))) {
      return null;
    }

    // Use the name first as the "System Devices" and Web (android sometimes Windows) don't have manufacturer data
    BluetoothDevice? device;
    if (kIsWeb) {
      device = switch (scanResult.name) {
        'Zwift Ride' => ZwiftRide(scanResult),
        'Zwift Play' => ZwiftPlay(scanResult, deviceType: ZwiftDeviceType.playLeft),
        'Zwift Click' => ZwiftClickV2(scanResult),
        'SQUARE' => EliteSquare(scanResult),
        'OpenBike' => OpenBikeControlDevice(scanResult),
        null => null,
        _ when scanResult.name!.toUpperCase().startsWith('HEADWIND') => WahooKickrHeadwind(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('STERZO') => EliteSterzo(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE SHIFT') => WahooKickrBikeShift(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE PRO') => WahooKickrBikePro(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE') => WahooKickrBike(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('CYCPLUS') && scanResult.name!.toUpperCase().contains('BC2') =>
          CycplusBc2(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('THINK VS') => ThinkRiderVs200(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('RDR') => ShimanoDi2(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('SRAM') => SramAxs(scanResult),
        _ => null,
      };
    } else {
      device = switch (scanResult.name) {
        null => null,
        //'Zwift Ride' => ZwiftRide(scanResult), special case for Zwift Ride: we must only connect to the left controller
        // https://www.makinolo.com/blog/2024/07/26/zwift-ride-protocol/
        //'Zwift Play' => ZwiftPlay(scanResult),
        //'Zwift Click' => ZwiftClick(scanResult), special case for Zwift Click v2: we must only connect to the left controller
        _ when scanResult.name!.toUpperCase().startsWith('HEADWIND') => WahooKickrHeadwind(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('SQUARE') => EliteSquare(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('STERZO') => EliteSterzo(scanResult),
        _ when scanResult.name!.toUpperCase().contains('KICKR BIKE SHIFT') => WahooKickrBikeShift(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE PRO') => WahooKickrBikePro(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE') => WahooKickrBike(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('CYCPLUS') && scanResult.name!.toUpperCase().contains('BC2') =>
          CycplusBc2(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('THINK VS') => ThinkRiderVs200(scanResult),
        //_ when scanResult.services.contains(CycplusBc2Constants.SERVICE_UUID.toLowerCase()) => CycplusBc2(scanResult),
        _ when scanResult.services.contains(ShimanoDi2Constants.SERVICE_UUID.toLowerCase()) => ShimanoDi2(scanResult),
        _ when scanResult.services.contains(ShimanoDi2Constants.SERVICE_UUID_ALTERNATIVE.toLowerCase()) => ShimanoDi2(
          scanResult,
        ),
        _ when scanResult.services.containsAny(ProxyDevice.proxyServiceUUIDs) => ProxyDevice(scanResult),
        _ when scanResult.services.contains(SramAxsConstants.SERVICE_UUID.toLowerCase()) => SramAxs(
          scanResult,
        ),
        _ when scanResult.services.contains(OpenBikeControlConstants.SERVICE_UUID.toLowerCase()) =>
          OpenBikeControlDevice(scanResult),
        _ when scanResult.services.contains(WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase()) =>
          WahooKickrHeadwind(scanResult),
        // otherwise the service UUIDs will be used
        _ => null,
      };
    }

    if (device != null) {
      return device;
    } else if (scanResult.services.containsAny([
      ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase(),
      ZwiftConstants.ZWIFT_CUSTOM_SERVICE_SHORT_UUID.toLowerCase(),
      ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID.toLowerCase(),
    ])) {
      // otherwise use the manufacturer data to identify the device
      final manufacturerData = scanResult.manufacturerDataList;
      final data = manufacturerData
          .firstOrNullWhere((e) => e.companyId == ZwiftConstants.ZWIFT_MANUFACTURER_ID)
          ?.payload;

      if (data == null || data.isEmpty) {
      } else {
        final type = ZwiftDeviceType.fromManufacturerData(data.first);
        device = switch (type) {
          ZwiftDeviceType.click => ZwiftClick(scanResult),
          ZwiftDeviceType.playRight => ZwiftPlay(scanResult, deviceType: type!),
          ZwiftDeviceType.playLeft => ZwiftPlay(scanResult, deviceType: type!),
          ZwiftDeviceType.rideLeft => ZwiftRide(scanResult),
          //DeviceType.rideRight => ZwiftRide(scanResult), // see comment above
          ZwiftDeviceType.clickV2Left => ZwiftClickV2(scanResult),
          //DeviceType.clickV2Right => ZwiftClickV2(scanResult), // see comment above
          _ => null,
        };
      }
    }

    if (scanResult.name == 'Zwift Ride' &&
        device == null &&
        core.connection.controllerDevices.none((d) => d is ZwiftRide)) {
      // Fallback for Zwift Ride if nothing else matched => old firmware
      buildToast(
        title: 'You may need to update your Zwift Ride firmware.',
        duration: Duration(seconds: 6),
      );
    }
    return device;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice && runtimeType == other.runtimeType && scanResult.deviceId == other.scanResult.deviceId;

  @override
  int get hashCode => scanResult.deviceId.hashCode;

  BleDevice get device => scanResult;

  @override
  Future<void> connect() async {
    try {
      await UniversalBle.connect(device.deviceId);
    } catch (e) {
      isConnected = false;
      rethrow;
    }

    if (!kIsWeb) {
      await UniversalBle.requestMtu(device.deviceId, 517);
    }

    services = await UniversalBle.discoverServices(device.deviceId);

    final deviceInformationService = services!.firstOrNullWhere(
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

      core.connection.signalChange(this);
    }

    final batteryService = services!.firstOrNullWhere(
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
        core.connection.signalChange(this);
      }
    }

    await handleServices(services!);
  }

  Future<void> handleServices(List<BleService> services);
  Future<void> processCharacteristic(String characteristic, Uint8List bytes);

  @override
  Future<void> disconnect() async {
    services?.clear();
    await UniversalBle.disconnect(device.deviceId);
    super.disconnect();
  }

  String? serviceUuidForCharacteristic(String characteristicUuid) {
    return services
        ?.firstOrNullWhere((service) => service.characteristics.any((c) => c.uuid == characteristicUuid.toLowerCase()))
        ?.uuid;
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    final foregroundColor = Theme.of(context).colorScheme.mutedForeground;
    const fontSize = 11.0;
    return [
      // metaRow: battery + signal
      if (batteryLevel != null || rssi != null) ...[
        const Gap(4),
        if (batteryLevel != null) ...[
          Icon(
            switch (batteryLevel!) {
              >= 80 => LucideIcons.batteryFull,
              >= 60 => LucideIcons.batteryFull,
              >= 50 => LucideIcons.batteryMedium,
              >= 25 => LucideIcons.batteryLow,
              >= 10 => LucideIcons.batteryLow,
              _ => LucideIcons.batteryWarning,
            },
            size: 14,
            color: batteryLevel! < 20 ? Theme.of(context).colorScheme.destructive : foregroundColor,
          ),
          Text(
            '$batteryLevel%',
            style: TextStyle(
              fontSize: fontSize,
              color: foregroundColor,
            ),
          ),
          if (firmwareVersion != null || rssi != null) const Gap(16),
        ],
        if (firmwareVersion != null &&
            (showFull || (this is ZwiftDevice && firmwareVersion != (this as ZwiftDevice).latestFirmwareVersion))) ...[
          if (this is ZwiftDevice && firmwareVersion != (this as ZwiftDevice).latestFirmwareVersion)
            Icon(
              Icons.warning,
              size: fontSize,
            )
          else
            Text('FW', style: TextStyle(fontSize: 10, color: foregroundColor)).inlineCode,
          Text(
            firmwareVersion!,
            style: TextStyle(
              fontSize: fontSize,
              color: foregroundColor,
            ),
          ),
          if (this is ZwiftDevice &&
              firmwareVersion != (this as ZwiftDevice).latestFirmwareVersion &&
              (this as ZwiftDevice).latestFirmwareVersion != null)
            Text(
              ' (${context.i18n.latestVersion((this as ZwiftDevice).latestFirmwareVersion!)})',
              style: TextStyle(color: foregroundColor, fontSize: fontSize),
            ),
          if (rssi != null) const Gap(16),
        ],
        if (rssi != null)
          StreamBuilder(
            stream: core.connection.rssiConnectionStream.where((device) => device == this).map((event) => event.rssi),
            builder: (context, rssiValue) {
              final currentRssi = rssiValue.data ?? rssi!;
              if (showFull || currentRssi < -70) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.signal, size: 14, color: foregroundColor),
                    const Gap(4),
                    Text(
                      switch (currentRssi) {
                        >= -50 => 'Strong',
                        >= -70 => 'Good',
                        >= -85 => 'Fair',
                        _ => 'Weak',
                      },
                      style: TextStyle(fontSize: fontSize, color: foregroundColor),
                    ),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
      ],
    ];
  }

  void debugSubscribeToAll(List<BleService> services) {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.properties.contains(CharacteristicProperty.indicate)) {
          debugPrint('Subscribing to indications for ${service.uuid} / ${characteristic.uuid}');
          UniversalBle.subscribeIndications(device.deviceId, service.uuid, characteristic.uuid);
        }
        if (characteristic.properties.contains(CharacteristicProperty.notify)) {
          debugPrint('Subscribing to notifications for ${service.uuid} / ${characteristic.uuid}');
          UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
        }
      }
    }
  }
}
