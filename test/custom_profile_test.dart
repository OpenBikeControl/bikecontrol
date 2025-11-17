import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/settings/settings.dart';

void main() {
  group('Custom Profile Tests', () {
    setUp(() async {
      // Initialize SharedPreferences with in-memory storage for testing
      SharedPreferences.setMockInitialValues({});
      await settings.init();
    });

    test('Should create custom app with default profile name', () {
      final customApp = CustomApp();
      expect(customApp.profileName, 'Other');
      expect(customApp.name, 'Other');
    });

    test('Should create custom app with custom profile name', () {
      final customApp = CustomApp(profileName: 'Workout');
      expect(customApp.profileName, 'Workout');
      expect(customApp.name, 'Workout');
    });

    test('Should save and retrieve custom profile', () async {
      final customApp = CustomApp(profileName: 'Race');
      await settings.setKeyMap(customApp);

      final profiles = settings.getCustomAppProfiles();
      expect(profiles.contains('Race'), true);
    });

    test('Should list multiple custom profiles', () async {
      final workout = CustomApp(profileName: 'Workout');
      final race = CustomApp(profileName: 'Race');
      final event = CustomApp(profileName: 'Event');

      await settings.setKeyMap(workout);
      await settings.setKeyMap(race);
      await settings.setKeyMap(event);

      final profiles = settings.getCustomAppProfiles();
      expect(profiles.contains('Workout'), true);
      expect(profiles.contains('Race'), true);
      expect(profiles.contains('Event'), true);
      expect(profiles.length, 3);
    });

    test('Should duplicate custom profile', () async {
      await settings.reset();
      final original = CustomApp(profileName: 'Original');
      await settings.setKeyMap(original);

      await settings.duplicateCustomAppProfile('Original', 'Copy');

      final profiles = settings.getCustomAppProfiles();
      expect(profiles.contains('Original'), true);
      expect(profiles.contains('Copy'), true);
      expect(profiles.length, 2);
    });

    test('Should delete custom profile', () async {
      final customApp = CustomApp(profileName: 'ToDelete');
      await settings.setKeyMap(customApp);

      var profiles = settings.getCustomAppProfiles();
      expect(profiles.contains('ToDelete'), true);

      await settings.deleteCustomAppProfile('ToDelete');

      profiles = settings.getCustomAppProfiles();
      expect(profiles.contains('ToDelete'), false);
    });

    test('Should not duplicate migration if already migrated', () async {
      SharedPreferences.setMockInitialValues({
        'customapp': ['old_data'],
        'customapp_Custom': ['new_data'],
        'app': 'Custom',
      });

      final newSettings = Settings();
      await newSettings.init();

      // Old key should still exist because new key already existed
      expect(newSettings.getCustomAppKeymap('customapp'), null);
      final customKeymap = newSettings.getCustomAppKeymap('Custom');
      expect(customKeymap, isNotNull);
    });

    test('Should export custom profile as JSON', () async {
      final customApp = CustomApp(profileName: 'TestProfile');
      await settings.setKeyMap(customApp);

      final jsonData = settings.exportCustomAppProfile('TestProfile');
      expect(jsonData, isNotNull);
      expect(jsonData, contains('version'));
      expect(jsonData, contains('profileName'));
      expect(jsonData, contains('keymap'));
    });

    test('Should import custom profile from JSON', () async {
      // First export a profile
      final customApp = CustomApp(profileName: 'ExportTest');
      await settings.setKeyMap(customApp);
      final jsonData = settings.exportCustomAppProfile('ExportTest');

      // Import with a new name
      final success = await settings.importCustomAppProfile(jsonData!, newProfileName: 'ImportTest');

      expect(success, true);
      final profiles = settings.getCustomAppProfiles();
      expect(profiles.contains('ImportTest'), true);
    });

    test('Should fail to import invalid JSON', () async {
      final success = await settings.importCustomAppProfile('invalid json');
      expect(success, false);
    });

    test('Should fail to import JSON with missing fields', () async {
      final invalidJson = '{"version": 1}';
      final success = await settings.importCustomAppProfile(invalidJson);
      expect(success, false);
    });
  });
}
