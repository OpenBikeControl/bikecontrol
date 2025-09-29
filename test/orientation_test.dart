import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swift_control/pages/touch_area.dart';

void main() {
  group('TouchAreaSetupPage Orientation Tests', () {
    testWidgets('TouchAreaSetupPage should force landscape orientation on init', (WidgetTester tester) async {
      // Track system chrome method calls
      final List<MethodCall> systemChromeCalls = [];
      
      // Mock SystemChrome.setPreferredOrientations
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
        systemChromeCalls.add(methodCall);
        return null;
      });

      // Build the TouchAreaSetupPage
      await tester.pumpWidget(
        const MaterialApp(
          home: TouchAreaSetupPage(),
        ),
      );

      // Verify that setPreferredOrientations was called with landscape orientations
      final orientationCalls = systemChromeCalls
          .where((call) => call.method == 'SystemChrome.setPreferredOrientations')
          .toList();
      
      expect(orientationCalls, isNotEmpty);
      
      // Check if landscape orientations were set
      final lastOrientationCall = orientationCalls.last;
      final orientations = lastOrientationCall.arguments as List<String>;
      
      expect(orientations, contains('DeviceOrientation.landscapeLeft'));
      expect(orientations, contains('DeviceOrientation.landscapeRight'));
      expect(orientations, hasLength(2)); // Only landscape orientations
    });

    test('DeviceOrientation enum values are accessible', () {
      // Test that we can access the DeviceOrientation enum values
      final orientations = [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ];
      
      expect(orientations, hasLength(4));
      expect(orientations, contains(DeviceOrientation.landscapeLeft));
      expect(orientations, contains(DeviceOrientation.landscapeRight));
      expect(orientations, contains(DeviceOrientation.portraitUp));
      expect(orientations, contains(DeviceOrientation.portraitDown));
    });
  });
}