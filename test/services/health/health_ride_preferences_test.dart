import 'package:bike_control/services/health/health_ride_preferences.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  bool resolve({
    bool platformSupported = true,
    bool isPro = true,
    bool? explicitChoice,
    SupportedApp? app,
    Target? target,
  }) => resolveSaveRidesToHealth(
    platformSupported: platformSupported,
    isPro: isPro,
    explicitChoice: explicitChoice,
    trainerApp: app,
    target: target,
  );

  group('resolveSaveRidesToHealth defaults', () {
    test('off for Zwift and Rouvy on this device — they may write the ride themselves', () {
      expect(resolve(app: Zwift(), target: Target.thisDevice), isFalse);
      expect(resolve(app: Rouvy(), target: Target.thisDevice), isFalse);
    });

    test('on for Zwift and Rouvy running on another device', () {
      expect(resolve(app: Zwift(), target: Target.otherDevice), isTrue);
      expect(resolve(app: Rouvy(), target: Target.otherDevice), isTrue);
    });

    test('on for every other app, whatever the target', () {
      for (final target in [Target.thisDevice, Target.otherDevice, null]) {
        expect(resolve(app: MyWhoosh(), target: target), isTrue, reason: '$target');
        expect(resolve(app: BikeControl(), target: target), isTrue, reason: '$target');
      }
      expect(resolve(app: null, target: null), isTrue);
    });

    test('Zwift with no target chosen yet defaults on (only this-device is excluded)', () {
      expect(resolve(app: Zwift(), target: null), isTrue);
    });
  });

  group('resolveSaveRidesToHealth overrides', () {
    test('an explicit choice beats the per-app default both ways', () {
      expect(resolve(app: Zwift(), target: Target.thisDevice, explicitChoice: true), isTrue);
      expect(resolve(app: MyWhoosh(), target: Target.thisDevice, explicitChoice: false), isFalse);
    });

    test('never on without Pro, even when explicitly chosen', () {
      expect(resolve(isPro: false, app: MyWhoosh()), isFalse);
      expect(resolve(isPro: false, explicitChoice: true), isFalse);
    });

    test('never on an unsupported platform', () {
      expect(resolve(platformSupported: false, app: MyWhoosh()), isFalse);
      expect(resolve(platformSupported: false, explicitChoice: true), isFalse);
    });
  });

  test('mayAlreadySaveToHealth flags only Zwift and Rouvy', () {
    expect(mayAlreadySaveToHealth(Zwift()), isTrue);
    expect(mayAlreadySaveToHealth(Rouvy()), isTrue);
    expect(mayAlreadySaveToHealth(MyWhoosh()), isFalse);
    expect(mayAlreadySaveToHealth(null), isFalse);
  });

  group('HealthRidePreferences', () {
    late HealthRidePreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = HealthRidePreferences(await SharedPreferences.getInstance());
    });

    test('undecided by default, and remembers an explicit choice', () async {
      expect(prefs.explicitChoice, isNull);
      await prefs.setExplicitChoice(true);
      expect(prefs.explicitChoice, isTrue);
      await prefs.setExplicitChoice(false);
      expect(prefs.explicitChoice, isFalse);
    });

    test('prompt card flags persist', () async {
      expect(prefs.rideDetected, isFalse);
      expect(prefs.promptDismissed, isFalse);
      await prefs.setRideDetected();
      await prefs.setPromptDismissed();
      expect(prefs.rideDetected, isTrue);
      expect(prefs.promptDismissed, isTrue);
    });

    test('changes notify listeners', () async {
      var calls = 0;
      prefs.addListener(() => calls++);
      await prefs.setExplicitChoice(true);
      await prefs.setRideDetected();
      await prefs.setPromptDismissed();
      expect(calls, 3);
    });
  });
}
