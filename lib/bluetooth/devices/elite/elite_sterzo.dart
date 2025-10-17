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
  int? _latestChallenge;
  String? _serviceUuid;

  @override
  Future<void> handleServices(List<BleService> services) async {
    final service = services.firstOrNullWhere(
      (e) => e.uuid.toLowerCase().startsWith('347b0'),
    );
    if (service == null) {
      throw Exception('Elite Sterzo service not found');
    }
    
    _serviceUuid = service.uuid;
    
    // Find characteristics
    final challengeChar = service.characteristics.firstOrNullWhere(
      (e) => e.uuid == SterzoConstants.CHALLENGE_CODE_CHARACTERISTIC_UUID,
    );
    final measurementChar = service.characteristics.firstOrNullWhere(
      (e) => e.uuid == SterzoConstants.MEASUREMENT_CHARACTERISTIC_UUID,
    );
    final controlChar = service.characteristics.firstOrNullWhere(
      (e) => e.uuid == SterzoConstants.CONTROL_POINT_CHARACTERISTIC_UUID,
    );

    if (challengeChar == null || measurementChar == null || controlChar == null) {
      throw Exception('Required Sterzo characteristics not found');
    }

    // Subscribe to challenge code indications
    await UniversalBle.subscribeNotifications(
      device.deviceId,
      service.uuid,
      challengeChar.uuid,
    );

    // Subscribe to measurement notifications
    await UniversalBle.subscribeNotifications(
      device.deviceId,
      service.uuid,
      measurementChar.uuid,
    );

    // Request to start challenge
    await UniversalBle.write(
      device.deviceId,
      service.uuid,
      controlChar.uuid,
      Uint8List.fromList([0x03, 0x10]),
      withoutResponse: false,
    );

    actionStreamInternal.add(LogNotification('Elite Sterzo: Initialization started'));
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    if (characteristic == SterzoConstants.CHALLENGE_CODE_CHARACTERISTIC_UUID) {
      _handleChallengeCode(bytes);
    } else if (characteristic == SterzoConstants.MEASUREMENT_CHARACTERISTIC_UUID) {
      _handleSteeringMeasurement(bytes);
    }
  }

  Future<void> _handleChallengeCode(Uint8List bytes) async {
    if (bytes.length >= 4) {
      // Challenge is in bytes 2-3 (big-endian)
      final challenge = (bytes[2] << 8) | bytes[3];
      _latestChallenge = challenge;
      
      actionStreamInternal.add(LogNotification('Elite Sterzo: Received challenge code: $challenge'));

      // Respond to challenge
      await _activateSteeringMeasurements();
    }
  }

  Future<void> _activateSteeringMeasurements() async {
    if (_latestChallenge == null || _serviceUuid == null) {
      return;
    }

    // Get response codes for the challenge
    final challengeCodes = _getChallengeResponse(_latestChallenge!);
    
    // Send challenge response
    await UniversalBle.write(
      device.deviceId,
      _serviceUuid!,
      SterzoConstants.CONTROL_POINT_CHARACTERISTIC_UUID,
      Uint8List.fromList([0x03, 0x11, challengeCodes[0], challengeCodes[1]]),
      withoutResponse: false,
    );

    await Future.delayed(const Duration(seconds: 1));

    // Activate measurements
    await UniversalBle.write(
      device.deviceId,
      _serviceUuid!,
      SterzoConstants.CONTROL_POINT_CHARACTERISTIC_UUID,
      Uint8List.fromList([0x02, 0x02]),
      withoutResponse: false,
    );

    actionStreamInternal.add(LogNotification('Elite Sterzo: Steering measurements activated'));
  }

  void _handleSteeringMeasurement(Uint8List bytes) {
    if (bytes.length >= 4) {
      // Steering angle is a 32-bit float (little-endian)
      final angle = ByteData.sublistView(bytes).getFloat32(0, Endian.little);
      
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

  ControllerButton? _getSteeringButton(double angle) {
    // Use a threshold to avoid jitter around center
    if (angle < -SterzoConstants.STEERING_THRESHOLD) {
      return ControllerButton.navigationLeft;
    } else if (angle > SterzoConstants.STEERING_THRESHOLD) {
      return ControllerButton.navigationRight;
    }
    return null;
  }

  List<int> _getChallengeResponse(int challenge) {
    // This is a simplified challenge-response lookup
    // The full implementation would use a 128KB lookup table
    // For now, using a subset of common challenge codes
    final index = challenge * 2;
    if (index < _challengeCodes.length - 1) {
      return [_challengeCodes[index], _challengeCodes[index + 1]];
    }
    // Fallback for unknown challenges
    return [0x96, 0x96];
  }
}

class SterzoConstants {
  static const String DEVICE_NAME = "STERZO";
  
  // Elite Sterzo Smart characteristic UUIDs
  static const String MEASUREMENT_CHARACTERISTIC_UUID = "347b0030-7635-408b-8918-8ff3949ce592";
  static const String CONTROL_POINT_CHARACTERISTIC_UUID = "347b0031-7635-408b-8918-8ff3949ce592";
  static const String CHALLENGE_CODE_CHARACTERISTIC_UUID = "347b0032-7635-408b-8918-8ff3949ce592";
  
  // Service UUID pattern (matches Elite devices)
  static const String SERVICE_UUID = "347b0001-7635-408b-8918-8ff3949ce592";
  
  // Steering angle threshold in degrees to trigger steering action
  static const double STEERING_THRESHOLD = 5.0;
  
  static const int RECONNECT_DELAY = 5; // seconds between reconnection attempts
}

// Subset of challenge-response codes from sterzo-challenge-codes.dat
// This is a simplified version - the full table is 128KB
const List<int> _challengeCodes = [
  0x96, 0x96, 0x96, 0x9f, 0x96, 0x18, 0x90, 0x99, 0x96, 0x92, 0x96, 0xcb, 0x95, 0x9c, 0x8a, 0x9d,
  0x96, 0xbe, 0x97, 0xbf, 0x9c, 0xa0, 0x96, 0xaa, 0x96, 0xc2, 0x95, 0xe3, 0x8a, 0xa4, 0x96, 0xbb,
  0x97, 0xa6, 0x9e, 0x27, 0xde, 0xa8, 0x96, 0xe5, 0x94, 0x2a, 0x83, 0xab, 0x96, 0xba, 0x96, 0x15,
  0x90, 0xae, 0xa4, 0xaf, 0x96, 0x84, 0x97, 0x01, 0x98, 0xb2, 0xe2, 0xb3, 0x96, 0xcc, 0x95, 0x55,
  0xb6, 0xb6, 0x96, 0x96, 0x97, 0xa8, 0x9e, 0x79, 0xde, 0xba, 0x96, 0xf1, 0x94, 0xdc, 0x85, 0x3d,
  0x36, 0xbe, 0x96, 0x1b, 0x93, 0x80, 0xbd, 0xc1, 0x96, 0xee, 0x97, 0xab, 0x9d, 0x44, 0xc8, 0xc5,
  0x96, 0xa6, 0x95, 0xd7, 0x8f, 0xc8, 0x5a, 0xc9, 0x96, 0x1a, 0x90, 0x6b, 0xa0, 0xcc, 0x96, 0xfa,
  0x97, 0x0e, 0x98, 0x8f, 0xe2, 0xd0, 0x96, 0xa7, 0x95, 0x12, 0x88, 0x53, 0x6e, 0xd4, 0x96, 0x29,
  0x9e, 0xd6, 0xd7, 0xd7, 0x96, 0x9a, 0x94, 0xc1, 0x87, 0xda, 0x1c, 0xdb, 0x96, 0x50, 0x92, 0xad,
  0xb2, 0xde, 0xb2, 0xde, 0x97, 0xc8, 0x9f, 0x81, 0xda, 0xe2, 0x96, 0xae, 0x94, 0x94, 0x85, 0x25,
  0x36, 0xe6, 0x96, 0x45, 0x93, 0xc8, 0xbf, 0x69, 0xc6, 0xeb, 0x97, 0xbf, 0x9c, 0x2c, 0xc1, 0xed,
  0x96, 0xb6, 0x94, 0x27, 0x80, 0x70, 0x20, 0xf1, 0x96, 0x4a, 0x93, 0x23, 0xb9, 0xf4, 0xea, 0xf4,
  0x97, 0x76, 0x9a, 0xd7, 0xf4, 0xf8, 0x96, 0x9a, 0x95, 0xda, 0x8f, 0xbb, 0x5a, 0xfc, 0x96, 0x33,
  0x90, 0x7e, 0xa2, 0x7f, 0x3e, 0x01, 0x97, 0xad, 0x9b, 0x82, 0xfb, 0x03, 0x96, 0x6a, 0x95, 0x7d,
  0x8a, 0x06, 0x74, 0x07, 0x96, 0xec, 0x91, 0x39, 0xac, 0x0a, 0x42, 0x0a, 0x97, 0xd4, 0x98, 0xed,
  0xee, 0x0e, 0x96, 0x76, 0x95, 0xc0, 0x88, 0xd1, 0x6e, 0x12, 0x96, 0xe9, 0x91, 0xf4, 0xa9, 0x95,
];
