import 'dart:typed_data';

import 'package:dartx/dartx.dart';
import 'package:swift_control/bluetooth/devices/base_device.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../messages/notification.dart';

class EliteSterzo extends BaseDevice {
  EliteSterzo(super.scanResult)
    : super(
        availableButtons: [
          ControllerButton.navigationLeft,
          ControllerButton.navigationRight,
        ],
        isBeta: true,
      );

  double _lastAngle = 0.0;

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstOrNullWhere(
      (e) => e.uuid == SterzoConstants.SERVICE_UUID,
    );
    if (service == null) {
      throw Exception('Service not found: ${SterzoConstants.SERVICE_UUID}');
    }
    final characteristic = service.characteristics.firstOrNullWhere(
      (e) => e.uuid == SterzoConstants.CHARACTERISTIC_UUID,
    );
    if (characteristic == null) {
      throw Exception('Characteristic not found: ${SterzoConstants.CHARACTERISTIC_UUID}');
    }

    await UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic == SterzoConstants.CHARACTERISTIC_UUID) {
      if (bytes.length >= 3) {
        // Parse steering angle from bytes
        // The Elite Sterzo Smart sends steering angle data in a specific format
        // Bytes 1-2 contain the angle as a signed 16-bit integer (little-endian)
        final angleRaw = ByteData.sublistView(bytes).getInt16(1, Endian.little);
        
        // Convert to degrees (typically ranges from -400 to +400, representing -40 to +40 degrees)
        final angle = angleRaw / 10.0;
        
        actionStreamInternal.add(LogNotification('Steering angle: ${angle.toStringAsFixed(1)}°'));

        // Determine steering direction based on angle threshold
        final button = _getSteeringButton(angle);
        
        if (button != null) {
          handleButtonsClicked([button]);
        } else if (_getSteeringButton(_lastAngle) != null) {
          // Release button if we were steering but now we're centered
          handleButtonsClicked([]);
        }
        
        _lastAngle = angle;
      }
    }
  }

  ControllerButton? _getSteeringButton(double angle) {
    // Use a threshold to avoid jitter around center
    if (angle < -SterzoConstants.STEERING_THRESHOLD) {
      return ControllerButton.navigationLeft;
    } else if (angle > SterzoConstants.STEERING_THRESHOLD) {
      return ControllerButton.navigationRight;
    }
    return null;
  }
}

class SterzoConstants {
  static const String DEVICE_NAME = "STERZO";
  
  // Elite Sterzo Smart uses the Fitness Machine Service
  static const String SERVICE_UUID = "00001826-0000-1000-8000-00805f9b34fb";
  
  // Steering Angle characteristic
  static const String CHARACTERISTIC_UUID = "00002ad9-0000-1000-8000-00805f9b34fb";
  
  // Steering angle threshold in degrees to trigger steering action
  static const double STEERING_THRESHOLD = 5.0;
  
  static const int RECONNECT_DELAY = 5; // seconds between reconnection attempts
}
