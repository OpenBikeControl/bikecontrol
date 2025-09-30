import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/utils/settings/settings.dart';

void main() {
  group('Vibration Setting Tests', () {
    late Settings settings;

    setUp(() async {
      // Initialize SharedPreferences with in-memory storage for testing
      SharedPreferences.setMockInitialValues({});
      settings = Settings();
      await settings.init();
    });

    test('Vibration setting should default to true', () {
      expect(settings.getVibrationEnabled(), true);
    });

    test('Vibration setting should persist when set to false', () async {
      await settings.setVibrationEnabled(false);
      expect(settings.getVibrationEnabled(), false);
    });

    test('Vibration setting should persist when set to true', () async {
      await settings.setVibrationEnabled(true);
      expect(settings.getVibrationEnabled(), true);
    });

    test('Vibration setting should toggle correctly', () async {
      // Start with default (true)
      expect(settings.getVibrationEnabled(), true);
      
      // Toggle to false
      await settings.setVibrationEnabled(false);
      expect(settings.getVibrationEnabled(), false);
      
      // Toggle back to true
      await settings.setVibrationEnabled(true);
      expect(settings.getVibrationEnabled(), true);
    });

    test('Vibration setting should persist across Settings instances', () async {
      // Set vibration to false
      await settings.setVibrationEnabled(false);
      expect(settings.getVibrationEnabled(), false);

      // Create a new Settings instance
      final newSettings = Settings();
      await newSettings.init();
      
      // Should still be false
      expect(newSettings.getVibrationEnabled(), false);
    });
  });
}
