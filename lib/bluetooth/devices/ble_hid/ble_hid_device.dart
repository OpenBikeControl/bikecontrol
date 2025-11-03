import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/devices/bluetooth_device.dart';
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

/// Support for cheap BT HID devices (Bluetooth Human Interface Devices)
/// These devices typically use HID over GATT Profile (HOGP) and report as
/// media control buttons or keyboard shortcuts.
class BleHidDevice extends BluetoothDevice {
  BleHidDevice(super.scanResult)
    : super(
        availableButtons: [],
        isBeta: false,
      );

  @override
  Future<void> handleServices(List<BleService> services) async {
    if (device.paired != true) {
      await UniversalBle.pair(device.deviceId);
    }

    final hidService = services.firstOrNullWhere(
      (e) => e.uuid.toLowerCase() == BleHidConstants.HID_SERVICE_UUID.toLowerCase(),
    );

    if (hidService == null) {
      throw Exception('HID Service not found: ${BleHidConstants.HID_SERVICE_UUID}');
    }

    // Find the Report characteristic (0x2A4D) for input reports
    final reportCharacteristic = hidService.characteristics.firstOrNullWhere(
      (e) => e.uuid.toLowerCase() == BleHidConstants.REPORT_CHARACTERISTIC_UUID.toLowerCase(),
    );

    if (reportCharacteristic != null) {
      actionStreamInternal.add(LogNotification('Subscribing to HID Report notifications'));
      await UniversalBle.subscribeNotifications(
        device.deviceId,
        hidService.uuid,
        reportCharacteristic.uuid,
      );
    } else {
      actionStreamInternal.add(LogNotification('Report characteristic not found, trying boot keyboard'));

      // Fallback: try Boot Keyboard Input Report (0x2A22)
      final bootKeyboardCharacteristic = hidService.characteristics.firstOrNullWhere(
        (e) => e.uuid.toLowerCase() == BleHidConstants.BOOT_KEYBOARD_INPUT_REPORT_UUID.toLowerCase(),
      );

      if (bootKeyboardCharacteristic != null) {
        actionStreamInternal.add(LogNotification('Subscribing to Boot Keyboard notifications'));
        await UniversalBle.subscribeNotifications(
          device.deviceId,
          hidService.uuid,
          bootKeyboardCharacteristic.uuid,
        );
      } else {
        throw Exception('No suitable HID input characteristics found');
      }
    }
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    final charUuidLower = characteristic.toLowerCase();

    // Handle both Report and Boot Keyboard characteristics
    if (charUuidLower == BleHidConstants.REPORT_CHARACTERISTIC_UUID.toLowerCase() ||
        charUuidLower == BleHidConstants.BOOT_KEYBOARD_INPUT_REPORT_UUID.toLowerCase()) {
      actionStreamInternal.add(LogNotification('HID Report: ${_bytesToHex(bytes)}'));

      // Parse the HID report to detect button presses
      final buttons = _parseHidReport(bytes);

      if (buttons.isNotEmpty) {
        actionStreamInternal.add(LogNotification('Buttons detected: $buttons'));
        await handleButtonsClicked(buttons);
      } else if (bytes.every((b) => b == 0)) {
        // All zeros means button released
        await handleButtonsClicked([]);
      }
    }
  }

  /// Parse HID report data to extract button presses
  /// Supports media control keys and common keyboard shortcuts
  List<ControllerButton> _parseHidReport(Uint8List bytes) {
    final buttons = <ControllerButton>[];

    if (bytes.isEmpty) {
      return buttons;
    }

    /*
    // For media control devices, check various report formats

    // Format 1: Simple consumer control (media keys)
    // Often uses 2-byte reports where specific bits represent media keys
    if (bytes.length >= 2) {
      final byte0 = bytes[0];
      final byte1 = bytes.length > 1 ? bytes[1] : 0;

      // Check for media key usage IDs (Consumer Page - 0x0C)
      // Common usage IDs for media controls:
      // 0xE9 = Volume Up, 0xEA = Volume Down
      // 0xB5 = Next Track, 0xB6 = Previous Track
      // 0xCD = Play/Pause

      // Volume Up (0xE9 or 0x00E9) -> Shift Up
      if ((byte0 == 0xE9) || (byte1 == 0xE9)) {
        buttons.add(ControllerButton.shiftUpRight);
      }
      // Volume Down (0xEA or 0x00EA) -> Shift Down
      else if ((byte0 == 0xEA) || (byte1 == 0xEA)) {
        buttons.add(ControllerButton.shiftDownRight);
      }
      // Next Track (0xB5 or 0x00B5) -> Shift Up
      else if ((byte0 == 0xB5) || (byte1 == 0xB5)) {
        buttons.add(ControllerButton.shiftUpRight);
      }
      // Previous Track (0xB6 or 0x00B6) -> Shift Down
      else if ((byte0 == 0xB6) || (byte1 == 0xB6)) {
        buttons.add(ControllerButton.shiftDownRight);
      }
      // Play/Pause (0xCD or 0x00CD) -> Toggle UI
      else if ((byte0 == 0xCD) || (byte1 == 0xCD)) {
        buttons.add(ControllerButton.onOffLeft);
      }
    }

    // Format 2: Keyboard boot protocol (8-byte report)
    // Byte 0: Modifier keys (Ctrl, Shift, Alt, etc.)
    // Byte 1: Reserved
    // Bytes 2-7: Up to 6 simultaneous key presses
    if (bytes.length >= 8) {
      final modifiers = bytes[0];

      // Check modifier keys
      final shiftPressed = (modifiers & 0x22) != 0; // Left or Right Shift
      final ctrlPressed = (modifiers & 0x11) != 0;  // Left or Right Ctrl

      // Check key codes in bytes 2-7
      for (int i = 2; i < 8 && i < bytes.length; i++) {
        final keyCode = bytes[i];
        if (keyCode == 0) continue;

        // Map common keys used for bike controls
        // Up Arrow (0x52) -> Shift Up
        if (keyCode == 0x52) {
          buttons.add(ControllerButton.shiftUpRight);
        }
        // Down Arrow (0x51) -> Shift Down
        else if (keyCode == 0x51) {
          buttons.add(ControllerButton.shiftDownRight);
        }
        // Left Arrow (0x50) -> Navigate Left
        else if (keyCode == 0x50) {
          buttons.add(ControllerButton.navigationLeft);
        }
        // Right Arrow (0x4F) -> Navigate Right
        else if (keyCode == 0x4F) {
          buttons.add(ControllerButton.navigationRight);
        }
        // Space (0x2C) or Enter (0x28) -> Toggle UI
        else if (keyCode == 0x2C || keyCode == 0x28) {
          buttons.add(ControllerButton.onOffLeft);
        }
      }
    }*/

    return buttons;
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
  }
}

class BleHidConstants {
  // Standard Bluetooth HID Service UUID (HOGP - HID over GATT Profile)
  static const String HID_SERVICE_UUID = '00001812-0000-1000-8000-00805f9b34fb';

  // HID Report Characteristic UUID
  static const String REPORT_CHARACTERISTIC_UUID = '00002a4d-0000-1000-8000-00805f9b34fb';

  // Boot Keyboard Input Report Characteristic UUID (fallback)
  static const String BOOT_KEYBOARD_INPUT_REPORT_UUID = '00002a22-0000-1000-8000-00805f9b34fb';

  // Available buttons that can be triggered by HID devices
  // Users can map any HID button to any controller button
}
