import 'dart:async';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_pro.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/pages/device.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/device_info.dart';
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
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
    String? buttonPrefix,
  }) : super(
         scanResult.name,
         uniqueId: scanResult.deviceId,
         availableButtons: allowMultiple
             ? availableButtons.toList().map((b) => b.copyWith(sourceDeviceId: scanResult.deviceId)).toList()
             : availableButtons.toList(),
         isBeta: isBeta,
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
        _ when scanResult.name!.toUpperCase().startsWith('CYCPLUS') && scanResult.name!.toUpperCase().contains('BC2') =>
          CycplusBc2(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('THINK VS') => ThinkRiderVs200(scanResult),
        //_ when scanResult.services.contains(CycplusBc2Constants.SERVICE_UUID.toLowerCase()) => CycplusBc2(scanResult),
        _ when scanResult.services.contains(ShimanoDi2Constants.SERVICE_UUID.toLowerCase()) => ShimanoDi2(scanResult),
        _ when scanResult.services.contains(ShimanoDi2Constants.SERVICE_UUID_ALTERNATIVE.toLowerCase()) => ShimanoDi2(
          scanResult,
        ),
        _ when scanResult.services.containsAny(ProxyDevice.proxyServiceUUIDs) && kDebugMode => ProxyDevice(scanResult),
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

      core.connection.signalChange(this);
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
        core.connection.signalChange(this);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 8,
          children: [
            Text(
              toString().screenshot ?? runtimeType.toString(),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isBeta) BetaPill(),
            Expanded(child: SizedBox()),
            Builder(
              builder: (context) {
                return LoadingWidget(
                  futureCallback: () async {
                    final completer = showDropdown<bool>(
                      context: context,
                      builder: (c) => DropdownMenu(
                        children: [
                          MenuButton(
                            child: Text('Disconnect and Forget for this session'),
                            onPressed: (context) {
                              closeOverlay(context, false);
                            },
                          ),
                          MenuButton(
                            child: Text('Disconnect and Forget'),
                            onPressed: (context) {
                              closeOverlay(context, true);
                            },
                          ),
                        ],
                      ),
                    );

                    final persist = await completer.future;
                    if (persist != null) {
                      await core.connection.disconnect(this, forget: true, persistForget: persist);
                    }
                  },
                  renderChild: (isLoading, tap) => IconButton(
                    variance: ButtonVariance.muted,
                    icon: isLoading ? SmallProgressIndicator() : Icon(Icons.clear),
                    onPressed: tap,
                  ),
                );
              },
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DeviceInfo(
              title: context.i18n.connection,
              icon: switch (isConnected) {
                true => Icons.bluetooth_connected_outlined,
                false => Icons.bluetooth_disabled_outlined,
              },
              value: isConnected ? context.i18n.connected : context.i18n.disconnected,
            ),

            if (batteryLevel != null)
              DeviceInfo(
                title: context.i18n.battery,
                icon: switch (batteryLevel!) {
                  >= 80 => Icons.battery_full,
                  >= 60 => Icons.battery_6_bar,
                  >= 50 => Icons.battery_5_bar,
                  >= 25 => Icons.battery_4_bar,
                  >= 10 => Icons.battery_2_bar,
                  _ => Icons.battery_alert,
                },
                value: '$batteryLevel%',
              ),
            if (firmwareVersion != null)
              DeviceInfo(
                title: context.i18n.firmware,
                icon: this is ZwiftDevice && firmwareVersion != (this as ZwiftDevice).latestFirmwareVersion
                    ? Icons.warning
                    : Icons.text_fields_sharp,
                value: firmwareVersion!,
                additionalInfo: (this is ZwiftDevice && firmwareVersion != (this as ZwiftDevice).latestFirmwareVersion)
                    ? Text(
                        ' (${context.i18n.latestVersion((this as ZwiftDevice).latestFirmwareVersion)})',
                        style: TextStyle(color: Theme.of(context).colorScheme.destructive, fontSize: 12),
                      )
                    : null,
              ),

            if (rssi != null)
              StreamBuilder(
                stream: core.connection.rssiConnectionStream
                    .where((device) => device == this)
                    .map((event) => event.rssi),
                builder: (context, rssiValue) {
                  return DeviceInfo(
                    title: context.i18n.signal,
                    icon: switch (rssiValue.data ?? rssi!) {
                      >= -50 => Icons.signal_cellular_4_bar,
                      >= -60 => Icons.signal_cellular_alt_2_bar,
                      >= -70 => Icons.signal_cellular_alt_1_bar,
                      _ => Icons.signal_cellular_alt,
                    },
                    value: '$rssi dBm',
                  );
                },
              ),
          ],
        ),
      ],
    );
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
