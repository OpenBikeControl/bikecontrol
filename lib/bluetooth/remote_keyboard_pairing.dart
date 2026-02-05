import 'dart:io';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prop/prop.dart';

import '../utils/keymap/keymap.dart';

class RemoteKeyboardPairing extends TrainerConnection {
  bool get isLoading => _isLoading;

  late final _peripheralManager = PeripheralManager();
  bool _isLoading = false;
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;

  Central? _central;
  GATTCharacteristic? _inputReport;

  static const String connectionTitle = 'Keyboard Remote Control';

  RemoteKeyboardPairing()
    : super(
        title: connectionTitle,
        supportedActions: InGameAction.values,
      );

  Future<void> reconnect() async {
    await _peripheralManager.stopAdvertising();
    await _peripheralManager.removeAllServices();
    _isServiceAdded = false;
    startAdvertising().catchError((e) {
      core.settings.setRemoteControlEnabled(false);
      core.connection.signalNotification(
        AlertNotification(LogLevel.LOGLEVEL_WARNING, 'Failed to start Remote Control pairing: $e'),
      );
    });
  }

  Future<void> startAdvertising() async {
    _isLoading = true;
    isStarted.value = true;

    _peripheralManager.stateChanged.forEach((state) {
      print('Peripheral manager state: ${state.state}');
    });

    if (!kIsWeb && Platform.isAndroid) {
      _peripheralManager.connectionStateChanged.forEach((state) {
        print('Peripheral connection state: ${state.state} of ${state.central.uuid}');
        if (state.state == ConnectionState.connected) {
        } else if (state.state == ConnectionState.disconnected) {
          _central = null;
          isConnected.value = false;
          core.connection.signalNotification(
            AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.disconnected),
          );
        }
      });

      final status = await Permission.bluetoothAdvertise.request();
      if (!status.isGranted) {
        print('Bluetooth advertise permission not granted');
        isStarted.value = false;
        return;
      }
    }

    while (_peripheralManager.state != BluetoothLowEnergyState.poweredOn && core.settings.getRemoteControlEnabled()) {
      print('Waiting for peripheral manager to be powered on...');
      if (core.settings.getLastTarget() == Target.thisDevice) {
        return;
      }
      await Future.delayed(Duration(seconds: 1));
    }
    final inputReport = GATTCharacteristic.mutable(
      uuid: UUID.fromString('2A4D'),
      permissions: [GATTCharacteristicPermission.read],
      properties: [GATTCharacteristicProperty.notify, GATTCharacteristicProperty.read],
      descriptors: [
        GATTDescriptor.immutable(
          // Report Reference: ID=1, Type=Input(1)
          uuid: UUID.fromString('2908'),
          value: Uint8List.fromList([0x01, 0x01]),
        ),
      ],
    );

    if (!_isServiceAdded) {
      await Future.delayed(Duration(seconds: 1));

      final reportMapDataAbsolute = Uint8List.fromList([
        // Keyboard Report (Report ID 1)
        0x05, 0x01, // Usage Page (Generic Desktop)
        0x09, 0x06, // Usage (Keyboard)
        0xA1, 0x01, // Collection (Application)
        0x85, 0x01, //   Report ID (1)
        0x05, 0x07, //   Usage Page (Keyboard/Keypad)
        0x19, 0xE0, //   Usage Minimum (Left Control)
        0x29, 0xE7, //   Usage Maximum (Right GUI)
        0x15, 0x00, //   Logical Minimum (0)
        0x25, 0x01, //   Logical Maximum (1)
        0x75, 0x01, //   Report Size (1)
        0x95, 0x08, //   Report Count (8)
        0x81, 0x02, //   Input (Data,Var,Abs) - Modifier byte
        0x95, 0x01, //   Report Count (1)
        0x75, 0x08, //   Report Size (8)
        0x81, 0x01, //   Input (Const) - Reserved byte
        0x95, 0x06, //   Report Count (6)
        0x75, 0x08, //   Report Size (8)
        0x15, 0x00, //   Logical Minimum (0)
        0x25, 0x65, //   Logical Maximum (101)
        0x05, 0x07, //   Usage Page (Keyboard/Keypad)
        0x19, 0x00, //   Usage Minimum (0)
        0x29, 0x65, //   Usage Maximum (101)
        0x81, 0x00, //   Input (Data,Array) - Key array (6 keys)
        0xC0, // End Collection
      ]);

      // 1) Build characteristics
      final hidInfo = GATTCharacteristic.immutable(
        uuid: UUID.fromString('2A4A'),
        value: Uint8List.fromList([0x11, 0x01, 0x00, 0x02]),
        descriptors: [], // HID v1.11, country=0, flags=2
      );

      final reportMap = GATTCharacteristic.immutable(
        uuid: UUID.fromString('2A4B'),
        //properties: [GATTCharacteristicProperty.read],
        //permissions: [GATTCharacteristicPermission.read],
        value: reportMapDataAbsolute,
        descriptors: [
          GATTDescriptor.immutable(uuid: UUID.fromString('2908'), value: Uint8List.fromList([0x0, 0x0])),
        ],
      );

      final protocolMode = GATTCharacteristic.mutable(
        uuid: UUID.fromString('2A4E'),
        properties: [GATTCharacteristicProperty.read, GATTCharacteristicProperty.writeWithoutResponse],
        permissions: [GATTCharacteristicPermission.read, GATTCharacteristicPermission.write],
        descriptors: [],
      );

      final hidControlPoint = GATTCharacteristic.mutable(
        uuid: UUID.fromString('2A4C'),
        properties: [GATTCharacteristicProperty.writeWithoutResponse],
        permissions: [GATTCharacteristicPermission.write],
        descriptors: [],
      );

      // 2) HID service
      final hidService = GATTService(
        uuid: UUID.fromString(Platform.isIOS ? '1812' : '00001812-0000-1000-8000-00805F9B34FB'),
        isPrimary: true,
        characteristics: [
          hidInfo,
          reportMap,
          protocolMode,
          hidControlPoint,
          inputReport,
        ],
        includedServices: [],
      );

      if (!_isSubscribedToEvents) {
        _isSubscribedToEvents = true;
        _peripheralManager.characteristicReadRequested.forEach((char) {
          print('Read request for characteristic: ${char}');
          // You can respond to read requests here if needed
        });

        _peripheralManager.characteristicNotifyStateChanged.forEach((char) {
          // Check if this is the input report characteristic (2A4D)
          if (char.characteristic.uuid == inputReport.uuid) {
            if (char.state) {
              _central = char.central;
              _inputReport = char.characteristic;
              isConnected.value = true;
              print('Input report subscribed');
            } else {
              _inputReport = null;
              _central = null;
              isConnected.value = false;
              print('Input report unsubscribed');
            }
          }
          print('Notify state changed for characteristic: ${char.characteristic.uuid}: ${char.state}');
        });
      }
      await _peripheralManager.addService(hidService);

      // 3) Optional Battery service
      await _peripheralManager.addService(
        GATTService(
          uuid: UUID.fromString('180F'),
          isPrimary: true,
          characteristics: [
            GATTCharacteristic.immutable(
              uuid: UUID.fromString('2A19'),
              value: Uint8List.fromList([100]),
              descriptors: [],
            ),
          ],
          includedServices: [],
        ),
      );
      _isServiceAdded = true;
    }

    final advertisement = Advertisement(
      name:
          'BikeControl ${Platform.isIOS
              ? 'iOS'
              : Platform.isAndroid
              ? 'Android'
              : ''}',
      serviceUUIDs: [UUID.fromString(Platform.isIOS ? '1812' : '00001812-0000-1000-8000-00805F9B34FB')],
    );
    print('Starting advertising with Remote service...');

    try {
      await _peripheralManager.startAdvertising(advertisement);
    } catch (e) {
      if (e.toString().contains("Advertising has already started")) {
        print('Advertising already started, ignoring error');
        return;
      } else {
        rethrow;
      }
    }
    _isLoading = false;
  }

  Future<void> stopAdvertising() async {
    await _peripheralManager.removeAllServices();
    _isServiceAdded = false;
    await _peripheralManager.stopAdvertising();
    isStarted.value = false;
    isConnected.value = false;
    _isLoading = false;
  }

  Future<void> notifyCharacteristic(Uint8List value) async {
    if (_inputReport != null && _central != null) {
      await _peripheralManager.notifyCharacteristic(_central!, _inputReport!, value: value);
    }
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    if (isKeyDown && isKeyUp) {
      await sendKeyPress(keyPair);
      return Success('Key ${keyPair.toString()} press sent');
    } else if (isKeyDown) {
      await sendKeyDown(keyPair);
      return Success('Key ${keyPair.toString()} down sent');
    } else if (isKeyUp) {
      await sendKeyUp();
      return Success('Key ${keyPair.toString()} up sent');
    }
    return NotHandled('Illegal combination');
  }

  /// USB HID Keyboard scan codes for common keys
  static const Map<String, int> hidKeyCodes = {
    'a': 0x04,
    'b': 0x05,
    'c': 0x06,
    'd': 0x07,
    'e': 0x08,
    'f': 0x09,
    'g': 0x0A,
    'h': 0x0B,
    'i': 0x0C,
    'j': 0x0D,
    'k': 0x0E,
    'l': 0x0F,
    'm': 0x10,
    'n': 0x11,
    'o': 0x12,
    'p': 0x13,
    'q': 0x14,
    'r': 0x15,
    's': 0x16,
    't': 0x17,
    'u': 0x18,
    'v': 0x19,
    'w': 0x1A,
    'x': 0x1B,
    'y': 0x1C,
    'z': 0x1D,
    '1': 0x1E,
    '2': 0x1F,
    '3': 0x20,
    '4': 0x21,
    '5': 0x22,
    '6': 0x23,
    '7': 0x24,
    '8': 0x25,
    '9': 0x26,
    '0': 0x27,
    'enter': 0x28,
    'escape': 0x29,
    'backspace': 0x2A,
    'tab': 0x2B,
    'space': 0x2C,
    'minus': 0x2D,
    'equals': 0x2E,
    'leftbracket': 0x2F,
    'rightbracket': 0x30,
    'backslash': 0x31,
    'semicolon': 0x33,
    'quote': 0x34,
    'grave': 0x35,
    'comma': 0x36,
    'period': 0x37,
    'slash': 0x38,
    'capslock': 0x39,
    'f1': 0x3A,
    'f2': 0x3B,
    'f3': 0x3C,
    'f4': 0x3D,
    'f5': 0x3E,
    'f6': 0x3F,
    'f7': 0x40,
    'f8': 0x41,
    'f9': 0x42,
    'f10': 0x43,
    'f11': 0x44,
    'f12': 0x45,
    'printscreen': 0x46,
    'scrolllock': 0x47,
    'pause': 0x48,
    'insert': 0x49,
    'home': 0x4A,
    'pageup': 0x4B,
    'delete': 0x4C,
    'end': 0x4D,
    'pagedown': 0x4E,
    'right': 0x4F,
    'left': 0x50,
    'down': 0x51,
    'up': 0x52,
  };

  /// Modifier key bit masks
  static const int modLeftCtrl = 0x01;
  static const int modLeftShift = 0x02;
  static const int modLeftAlt = 0x04;
  static const int modLeftGui = 0x08;
  static const int modRightCtrl = 0x10;
  static const int modRightShift = 0x20;
  static const int modRightAlt = 0x40;
  static const int modRightGui = 0x80;

  /// Create a keyboard HID report
  /// [modifiers] - bit mask for modifier keys (Ctrl, Shift, Alt, GUI)
  /// [keyCodes] - list of up to 6 key codes to send
  Uint8List keyboardReport(int modifiers, List<int> keyCodes) {
    final keys = List<int>.filled(6, 0);
    for (var i = 0; i < keyCodes.length && i < 6; i++) {
      keys[i] = keyCodes[i];
    }
    // Report format: [modifiers, reserved, key1, key2, key3, key4, key5, key6]
    return Uint8List.fromList([modifiers, 0x00, ...keys]);
  }

  /// Send a keyboard key press and release
  /// [key] - the key name (e.g., 'a', 'enter', 'space', 'f1', 'up', 'down')
  /// [modifiers] - optional modifier keys (use modLeftCtrl, modLeftShift, etc.)
  Future<void> sendKeyPress(KeyPair keyPair, {int modifiers = 0}) async {
    final usbHidUsage = keyPair.physicalKey!.usbHidUsage;
    final keyCode = usbHidUsage & 0xFF;

    // Send key down
    final downReport = keyboardReport(modifiers, [keyCode]);
    if (kDebugMode) {
      print(
        'Sending keyboard key down: $keyPair (0x${keyCode.toRadixString(16)}) with modifiers: 0x${modifiers.toRadixString(16)}',
      );
    }
    await notifyCharacteristic(downReport);

    await Future.delayed(Duration(milliseconds: 20));

    // Send key up (empty report)
    final upReport = keyboardReport(0, []);
    if (kDebugMode) {
      print('Sending keyboard key up');
    }
    await notifyCharacteristic(upReport);

    await Future.delayed(Duration(milliseconds: 10));
  }

  /// Send a key down event only (for holding keys)
  Future<void> sendKeyDown(KeyPair keyPair, {int modifiers = 0}) async {
    final usbHidUsage = keyPair.physicalKey!.usbHidUsage;
    final keyCode = usbHidUsage & 0xFF;

    final report = keyboardReport(modifiers, [keyCode]);
    await notifyCharacteristic(report);
  }

  /// Send a key up event (release all keys)
  Future<void> sendKeyUp() async {
    final report = keyboardReport(0, []);
    await notifyCharacteristic(report);
  }
}
