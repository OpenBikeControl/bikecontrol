import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/bluetooth/peripheral_server.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/widgets/keyboard_pair_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

import '../utils/keymap/keymap.dart';

class RemoteKeyboardPairing extends TrainerConnection {
  bool get isLoading => _isLoading;

  final _server = PeripheralServer();
  bool _isLoading = false;
  bool _isServiceAdded = false;
  bool _isSubscribedToEvents = false;

  String? _currentDeviceId;
  static const _inputReportUuid = '2A4D';
  static const _hidServiceUuid = '1812';

  RemoteKeyboardPairing()
    : super(
        title: AppLocalizations.current.actAsBluetoothKeyboard,
        type: ConnectionMethodType.bluetooth,
        supportedActions: InGameAction.values,
      );

  Future<void> reconnect() async {
    await _server.stopAdvertising();
    await _server.clearServices();
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

    _server.onConnectionChanged((deviceId, connected) {
      print('Peripheral connection state: ${connected ? "connected" : "disconnected"} of $deviceId');
      if (!connected) {
        _currentDeviceId = null;
        isConnected.value = false;
        core.connection.signalNotification(
          AlertNotification(LogLevel.LOGLEVEL_INFO, AppLocalizations.current.disconnected),
        );
      }
    });

    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.bluetoothAdvertise.request();
      if (!status.isGranted) {
        print('Bluetooth advertise permission not granted');
        isStarted.value = false;
        return;
      }
    }

    while (!(await _server.isReady) && core.settings.getRemoteControlEnabled()) {
      print('Waiting for peripheral manager to be ready...');
      if (core.settings.getLastTarget() == Target.thisDevice) {
        return;
      }
      await Future.delayed(Duration(seconds: 1));
    }

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

      // HID characteristics
      final hidInfo = BlePeripheralCharacteristic(
        uuid: '2A4A',
        properties: [CharacteristicProperty.read],
        permissions: [PeripheralAttributePermission.readable],
        value: Uint8List.fromList([0x11, 0x01, 0x00, 0x02]),
      );

      final reportMap = BlePeripheralCharacteristic(
        uuid: '2A4B',
        properties: [CharacteristicProperty.read],
        permissions: [PeripheralAttributePermission.readable],
        value: reportMapDataAbsolute,
        descriptors: [
          BlePeripheralDescriptor(uuid: '2908', value: Uint8List.fromList([0x0, 0x0])),
        ],
      );

      final protocolMode = BlePeripheralCharacteristic(
        uuid: '2A4E',
        properties: [CharacteristicProperty.read, CharacteristicProperty.writeWithoutResponse],
        permissions: [PeripheralAttributePermission.readable, PeripheralAttributePermission.writeable],
      );

      final hidControlPoint = BlePeripheralCharacteristic(
        uuid: '2A4C',
        properties: [CharacteristicProperty.writeWithoutResponse],
        permissions: [PeripheralAttributePermission.writeable],
      );

      final inputReport = BlePeripheralCharacteristic(
        uuid: _inputReportUuid,
        permissions: [PeripheralAttributePermission.readable],
        properties: [CharacteristicProperty.notify, CharacteristicProperty.read],
        descriptors: [
          // Report Reference: ID=1, Type=Input(1)
          BlePeripheralDescriptor(uuid: '2908', value: Uint8List.fromList([0x01, 0x01])),
        ],
      );

      if (!_isSubscribedToEvents) {
        _isSubscribedToEvents = true;
        _server.onSubscriptionChanged((deviceId, characteristicId, isSubscribed) {
          if (characteristicId.toLowerCase() == _inputReportUuid.toLowerCase()) {
            if (isSubscribed) {
              _currentDeviceId = deviceId;
              isConnected.value = true;
              print('Input report subscribed');
            } else {
              _currentDeviceId = null;
              isConnected.value = false;
              print('Input report unsubscribed');
            }
          }
          print('Notify state changed for $characteristicId: $isSubscribed');
        });
      }

      await _server.addService(
        BlePeripheralService(
          uuid: Platform.isIOS ? _hidServiceUuid : '00001812-0000-1000-8000-00805F9B34FB',
          characteristics: [
            hidInfo,
            reportMap,
            protocolMode,
            hidControlPoint,
            inputReport,
          ],
        ),
      );

      // Optional Battery service
      await _server.addService(
        BlePeripheralService(
          uuid: '180F',
          characteristics: [
            BlePeripheralCharacteristic(
              uuid: '2A19',
              properties: [CharacteristicProperty.read],
              permissions: [PeripheralAttributePermission.readable],
              value: Uint8List.fromList([100]),
            ),
          ],
        ),
      );
      _isServiceAdded = true;
    }

    print('Starting advertising with Remote service...');

    try {
      await _server.startAdvertising(
        services: [Platform.isIOS ? _hidServiceUuid : '00001812-0000-1000-8000-00805F9B34FB'],
        localName:
            'BikeControl ${Platform.isIOS
                ? 'iOS'
                : Platform.isAndroid
                ? 'Android'
                : ''}',
      );
    } catch (e) {
      if (e.toString().contains("Advertising has already started") || e.toString().contains("already")) {
        print('Advertising already started, ignoring error');
        return;
      } else {
        rethrow;
      }
    }
    _isLoading = false;
  }

  Future<void> stopAdvertising() async {
    await _server.clearServices();
    _isServiceAdded = false;
    await _server.stopAdvertising();
    isStarted.value = false;
    isConnected.value = false;
    _isLoading = false;
  }

  Future<void> notifyCharacteristic(Uint8List value) async {
    if (_currentDeviceId != null) {
      await _server.notify(
        characteristicId: _inputReportUuid,
        value: value,
        deviceId: _currentDeviceId,
      );
    }
  }

  @override
  Future<ActionResult> sendAction(KeyPair keyPair, {required bool isKeyDown, required bool isKeyUp}) async {
    if (isKeyDown && isKeyUp) {
      await sendKeyPress(keyPair);
      return Success(
        'Key ${keyPair.toString()} press sent',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (isKeyDown) {
      await sendKeyDown(keyPair);
      return Success(
        'Key ${keyPair.toString()} down sent',
        button: keyPair.buttons.firstOrNull,
      );
    } else if (isKeyUp) {
      await sendKeyUp();
      return Success(
        'Key ${keyPair.toString()} up sent',
        button: keyPair.buttons.firstOrNull,
      );
    }
    return NotHandled(
      'Illegal combination',
      button: keyPair.buttons.firstOrNull,
    );
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

  @override
  Widget getTile({bool small = false}) => RemoteKeyboardPairingWidget(small: small);
}
