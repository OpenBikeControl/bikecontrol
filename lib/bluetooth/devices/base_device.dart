import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:swift_control/bluetooth/devices/zwift/constants.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:swift_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../utils/keymap/buttons.dart';
import '../messages/notification.dart';
import 'elite/elite_square.dart';
import 'elite/elite_sterzo.dart';

abstract class BaseDevice {
  final BleDevice scanResult;
  final bool isBeta;
  final List<ControllerButton> availableButtons;

  BaseDevice(this.scanResult, {required this.availableButtons, this.isBeta = false});

  bool isConnected = false;
  int? batteryLevel;
  String? firmwareVersion;

  Timer? _longPressTimer;
  Set<ControllerButton> _previouslyPressedButtons = <ControllerButton>{};

  static List<String> servicesToScan = [
    ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID,
    ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID,
    SquareConstants.SERVICE_UUID,
    WahooKickrBikeShiftConstants.SERVICE_UUID,
    SterzoConstants.SERVICE_UUID,
  ];

  static BaseDevice? fromScanResult(BleDevice scanResult) {
    // Use the name first as the "System Devices" and Web (android sometimes Windows) don't have manufacturer data
    BaseDevice? device;
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
      
      if (scanResult.name != null && scanResult.name!.toUpperCase().startsWith('STERZO')) {
        device = EliteSterzo(scanResult);
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
    } else if (scanResult.services.contains(WahooKickrBikeShiftConstants.SERVICE_UUID)) {
      if (scanResult.name != null && !scanResult.name!.toUpperCase().contains('KICKR BIKE SHIFT')) {
        return WahooKickrBikeShift(scanResult);
      } else if (kIsWeb && scanResult.name == null) {
        // some devices don't broadcast the name, so we must rely on the service UUID
        return WahooKickrBikeShift(scanResult);
      } else {
        return null;
      }
    } else {
      return null;
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

  Stream<BaseNotification> get actionStream => actionStreamInternal.stream;

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

  Future<void> handleButtonsClicked(List<ControllerButton>? buttonsClicked) async {
    if (buttonsClicked == null) {
      // ignore, no changes
    } else if (buttonsClicked.isEmpty) {
      actionStreamInternal.add(LogNotification('Buttons released'));
      _longPressTimer?.cancel();

      // Handle release events for long press keys
      final buttonsReleased = _previouslyPressedButtons.toList();
      final isLongPress =
          buttonsReleased.singleOrNull != null &&
          actionHandler.supportedApp?.keymap.getKeyPair(buttonsReleased.single)?.isLongPress == true;
      if (buttonsReleased.isNotEmpty && isLongPress) {
        await performRelease(buttonsReleased);
      }
      _previouslyPressedButtons.clear();
    } else {
      actionStreamInternal.add(ButtonNotification(buttonsClicked: buttonsClicked));

      // Handle release events for buttons that are no longer pressed
      final buttonsReleased = _previouslyPressedButtons.difference(buttonsClicked.toSet()).toList();
      final wasLongPress =
          buttonsReleased.singleOrNull != null &&
          actionHandler.supportedApp?.keymap.getKeyPair(buttonsReleased.single)?.isLongPress == true;
      if (buttonsReleased.isNotEmpty && wasLongPress) {
        await performRelease(buttonsReleased);
      }

      final isLongPress =
          buttonsClicked.singleOrNull != null &&
          actionHandler.supportedApp?.keymap.getKeyPair(buttonsClicked.single)?.isLongPress == true;

      if (!isLongPress &&
          !(buttonsClicked.singleOrNull == ControllerButton.onOffLeft ||
              buttonsClicked.singleOrNull == ControllerButton.onOffRight)) {
        // we don't want to trigger the long press timer for the on/off buttons, also not when it's a long press key
        _longPressTimer?.cancel();
        _longPressTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) async {
          performClick(buttonsClicked);
        });
      }
      // Update currently pressed buttons
      _previouslyPressedButtons = buttonsClicked.toSet();

      if (isLongPress) {
        return performDown(buttonsClicked);
      } else {
        return performClick(buttonsClicked);
      }
    }
  }

  Future<void> performDown(List<ControllerButton> buttonsClicked) async {
    for (final action in buttonsClicked) {
      // For repeated actions, don't trigger key down/up events (useful for long press)
      actionStreamInternal.add(
        LogNotification(await actionHandler.performAction(action, isKeyDown: true, isKeyUp: false)),
      );
    }
  }

  Future<void> performClick(List<ControllerButton> buttonsClicked) async {
    for (final action in buttonsClicked) {
      actionStreamInternal.add(
        LogNotification(await actionHandler.performAction(action, isKeyDown: true, isKeyUp: true)),
      );
    }
  }

  Future<void> performRelease(List<ControllerButton> buttonsReleased) async {
    for (final action in buttonsReleased) {
      actionStreamInternal.add(
        LogNotification(await actionHandler.performAction(action, isKeyDown: false, isKeyUp: true)),
      );
    }
  }

  Future<void> disconnect() async {
    _longPressTimer?.cancel();
    // Release any held keys in long press mode
    if (actionHandler is DesktopActions) {
      await (actionHandler as DesktopActions).releaseAllHeldKeys(_previouslyPressedButtons.toList());
    }
    _previouslyPressedButtons.clear();
    await UniversalBle.disconnect(device.deviceId);
    isConnected = false;
  }
}
