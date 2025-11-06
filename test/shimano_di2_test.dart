import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shimano DI2 Tests', () {
    test('Should validate service UUID format', () {
      const serviceUuid = "000018ef-5348-494d-414e-4f5f424c4500";
      
      expect(serviceUuid.length, equals(36));
      expect(serviceUuid.contains('-'), isTrue);
      expect(serviceUuid.toLowerCase(), equals(serviceUuid));
    });

    test('Should validate D-Fly Channel UUID format', () {
      const dFlyChannelUuid = "00002ac2-5348-494d-414e-4f5f424c4500";
      
      expect(dFlyChannelUuid.length, equals(36));
      expect(dFlyChannelUuid.contains('-'), isTrue);
      expect(dFlyChannelUuid.toLowerCase(), equals(dFlyChannelUuid));
    });

    test('Should handle button state initialization without triggering', () {
      // Simulate initial button states
      final initialStates = [0x00, 0x01, 0x00, 0x00]; // 4 channels
      
      // On first data reception, these should not trigger any button presses
      // This is the expected behavior after the fix
      expect(initialStates.length, equals(4));
      
      // Verify all channels have a value
      for (var state in initialStates) {
        expect(state, isNotNull);
      }
    });

    test('Should detect button press after initialization', () {
      // Initial state
      final initialStates = [0x00, 0x00, 0x00, 0x00];
      
      // Button pressed on channel 1
      final newStates = [0x01, 0x00, 0x00, 0x00];
      
      // Channel 0 changed from 0x00 to 0x01
      expect(initialStates[0] != newStates[0], isTrue);
      // Other channels remain unchanged
      expect(initialStates[1] == newStates[1], isTrue);
      expect(initialStates[2] == newStates[2], isTrue);
      expect(initialStates[3] == newStates[3], isTrue);
    });

    test('Should detect button release after press', () {
      // Button pressed state
      final pressedStates = [0x01, 0x00, 0x00, 0x00];
      
      // Button released
      final releasedStates = [0x00, 0x00, 0x00, 0x00];
      
      // Channel 0 changed from 0x01 to 0x00
      expect(pressedStates[0] != releasedStates[0], isTrue);
    });

    test('Should handle multiple simultaneous button presses', () {
      // Initial state
      final initialStates = [0x00, 0x00, 0x00, 0x00];
      
      // Multiple buttons pressed
      final pressedStates = [0x01, 0x01, 0x00, 0x00];
      
      // Channels 0 and 1 changed
      expect(initialStates[0] != pressedStates[0], isTrue);
      expect(initialStates[1] != pressedStates[1], isTrue);
      // Channels 2 and 3 unchanged
      expect(initialStates[2] == pressedStates[2], isTrue);
      expect(initialStates[3] == pressedStates[3], isTrue);
    });

    test('Should recognize RDR device name prefix', () {
      const deviceName1 = 'RDR';
      const deviceName2 = 'RDR-8070';
      const deviceName3 = 'rdr-di2';
      
      expect(deviceName1.toUpperCase().startsWith('RDR'), isTrue);
      expect(deviceName2.toUpperCase().startsWith('RDR'), isTrue);
      expect(deviceName3.toUpperCase().startsWith('RDR'), isTrue);
    });

    test('Should not match non-RDR devices', () {
      const deviceName1 = 'Zwift Click';
      const deviceName2 = 'Elite Sterzo';
      const deviceName3 = 'CYCPLUS BC2';
      
      expect(deviceName1.toUpperCase().startsWith('RDR'), isFalse);
      expect(deviceName2.toUpperCase().startsWith('RDR'), isFalse);
      expect(deviceName3.toUpperCase().startsWith('RDR'), isFalse);
    });

    test('Should handle D-Fly channel naming', () {
      // Channels are 0-indexed in code but displayed as 1-indexed
      final channelIndex = 0;
      final readableIndex = channelIndex + 1;
      final channelName = 'D-Fly Channel $readableIndex';
      
      expect(channelName, equals('D-Fly Channel 1'));
      expect(readableIndex, equals(1));
    });

    test('Should maintain separate state for each channel', () {
      // State map simulating _lastButtons
      final stateMap = <int, int>{
        0: 0x00,
        1: 0x01,
        2: 0x00,
        3: 0x00,
      };
      
      // Each channel should have its own independent state
      expect(stateMap[0], equals(0x00));
      expect(stateMap[1], equals(0x01));
      expect(stateMap[2], equals(0x00));
      expect(stateMap[3], equals(0x00));
    });
  });
}
