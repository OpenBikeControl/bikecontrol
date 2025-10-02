import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:swift_control/bluetooth/ble.dart';
import 'package:swift_control/bluetooth/devices/zwift_click.dart';
import 'package:swift_control/bluetooth/devices/zwift_clickv2.dart';
import 'package:swift_control/bluetooth/devices/zwift_play.dart';
import 'package:swift_control/bluetooth/devices/zwift_ride.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/crypto/local_key_provider.dart';
import 'package:swift_control/utils/crypto/zap_crypto.dart';
import 'package:swift_control/utils/single_line_exception.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../utils/crypto/encryption_utils.dart';
import '../../utils/keymap/buttons.dart';
import '../messages/notification.dart';

abstract class BaseDevice {
  final BleDevice scanResult;
  final List<ZwiftButton> availableButtons;

  BaseDevice(this.scanResult, {required this.availableButtons});

  final zapEncryption = ZapCrypto(LocalKeyProvider());

  bool isConnected = false;
  bool _isInited = false;
  int? batteryLevel;
  String? firmwareVersion;

  bool supportsEncryption = true;

  BleCharacteristic? syncRxCharacteristic;
  Timer? _longPressTimer;
  Set<ZwiftButton> _previouslyPressedButtons = <ZwiftButton>{};

  List<int> get startCommand => Constants.RIDE_ON + Constants.RESPONSE_START_CLICK;
  String get customServiceId => BleUuid.ZWIFT_CUSTOM_SERVICE_UUID;

  static BaseDevice? fromScanResult(BleDevice scanResult) {
    // Use the name first as the "System Devices" and Web (android sometimes Windows) don't have manufacturer data
    final device =
        kIsWeb
            ? switch (scanResult.name) {
              'Zwift Ride' => ZwiftRide(scanResult),
              'Zwift Play' => ZwiftPlay(scanResult),
              'Zwift Click' => ZwiftClickV2(scanResult),
              _ => null,
            }
            : switch (scanResult.name) {
              //'Zwift Ride' => ZwiftRide(scanResult), special case for Zwift Ride: we must only connect to the left controller
              // https://www.makinolo.com/blog/2024/07/26/zwift-ride-protocol/
              'Zwift Play' => ZwiftPlay(scanResult),
              //'Zwift Click' => ZwiftClick(scanResult), special case for Zwift Click v2: we must only connect to the left controller
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
        DeviceType.rideLeft => ZwiftRide(scanResult),
        //DeviceType.rideRight => ZwiftRide(scanResult), // see comment above
        DeviceType.clickV2Left => ZwiftClickV2(scanResult),
        //DeviceType.clickV2Right => ZwiftClickV2(scanResult), // see comment above
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
    await _handleServices(services);
  }

  Future<void> _handleServices(List<BleService> services) async {
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

  Future<List<ZwiftButton>?> processClickNotification(Uint8List message);

  Future<void> handleButtonsClicked(List<ZwiftButton>? buttonsClicked) async {
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
        await _performRelease(buttonsReleased);
      }
      _previouslyPressedButtons.clear();
    } else {
      // Handle release events for buttons that are no longer pressed
      final buttonsReleased = _previouslyPressedButtons.difference(buttonsClicked.toSet()).toList();
      final wasLongPress =
          buttonsReleased.singleOrNull != null &&
          actionHandler.supportedApp?.keymap.getKeyPair(buttonsReleased.single)?.isLongPress == true;
      if (buttonsReleased.isNotEmpty && wasLongPress) {
        await _performRelease(buttonsReleased);
      }

      final isLongPress =
          buttonsClicked.singleOrNull != null &&
          actionHandler.supportedApp?.keymap.getKeyPair(buttonsClicked.single)?.isLongPress == true;

      if (!isLongPress &&
          !(buttonsClicked.singleOrNull == ZwiftButton.onOffLeft ||
              buttonsClicked.singleOrNull == ZwiftButton.onOffRight)) {
        // we don't want to trigger the long press timer for the on/off buttons, also not when it's a long press key
        _longPressTimer?.cancel();
        _longPressTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) async {
          _performClick(buttonsClicked);
        });
      }
      // Update currently pressed buttons
      _previouslyPressedButtons = buttonsClicked.toSet();

      if (isLongPress) {
        return _performDown(buttonsClicked);
      } else {
        return _performClick(buttonsClicked);
      }
    }
  }

  Future<void> _performDown(List<ZwiftButton> buttonsClicked) async {
    if (buttonsClicked.any(((e) => e.action == InGameAction.shiftDown || e.action == InGameAction.shiftUp)) &&
        settings.getVibrationEnabled()) {
      await _vibrate();
    }
    for (final action in buttonsClicked) {
      // For repeated actions, don't trigger key down/up events (useful for long press)
      actionStreamInternal.add(
        LogNotification(await actionHandler.performAction(action, isKeyDown: true, isKeyUp: false)),
      );
    }
  }

  Future<void> _performClick(List<ZwiftButton> buttonsClicked) async {
    if (buttonsClicked.any(((e) => e.action == InGameAction.shiftDown || e.action == InGameAction.shiftUp)) &&
        settings.getVibrationEnabled()) {
      await _vibrate();
    }
    for (final action in buttonsClicked) {
      actionStreamInternal.add(
        LogNotification(await actionHandler.performAction(action, isKeyDown: true, isKeyUp: true)),
      );
    }
  }

  Future<void> _performRelease(List<ZwiftButton> buttonsReleased) async {
    for (final action in buttonsReleased) {
      actionStreamInternal.add(
        LogNotification(await actionHandler.performAction(action, isKeyDown: false, isKeyUp: true)),
      );
    }
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

  Future<void> disconnect() async {
    _isInited = false;
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
