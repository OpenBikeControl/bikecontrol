import 'package:bike_control/services/rides/ride_preferences.dart';
import 'package:bike_control/utils/keymap/apps/bike_control.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('mayAlreadySaveToHealth flags only Zwift and Rouvy', () {
    expect(mayAlreadySaveToHealth(Zwift()), isTrue);
    expect(mayAlreadySaveToHealth(Rouvy()), isTrue);
    expect(mayAlreadySaveToHealth(MyWhoosh()), isFalse);
    expect(mayAlreadySaveToHealth(null), isFalse);
  });

  group('healthDefaultsToNo', () {
    test('Zwift and Rouvy on this device: they may write the ride themselves', () {
      expect(healthDefaultsToNo(Zwift(), Target.thisDevice), isTrue);
      expect(healthDefaultsToNo(Rouvy(), Target.thisDevice), isTrue);
    });

    test('on another device, or any other app, the default is yes', () {
      expect(healthDefaultsToNo(Zwift(), Target.otherDevice), isFalse);
      expect(healthDefaultsToNo(Rouvy(), null), isFalse);
      expect(healthDefaultsToNo(MyWhoosh(), Target.thisDevice), isFalse);
      expect(healthDefaultsToNo(BikeControl(), Target.thisDevice), isFalse);
    });
  });

  group('RidePreferences', () {
    late RidePreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = RidePreferences(await SharedPreferences.getInstance());
    });

    test('automatic recording is on by default', () async {
      expect(prefs.autoRecord, isTrue);
      await prefs.setAutoRecord(false);
      expect(prefs.autoRecord, isFalse);
    });

    test('Health: undecided by default, remembers the answer', () async {
      expect(prefs.saveToHealth, isNull);
      expect(prefs.healthQuestionAnswered, isFalse);
      await prefs.setSaveToHealth(true);
      await prefs.setHealthQuestionAnswered();
      expect(prefs.saveToHealth, isTrue);
      expect(prefs.healthQuestionAnswered, isTrue);
    });

    test('keeps the answer given to the old Health toggle', () async {
      SharedPreferences.setMockInitialValues({'health_rides_enabled': true});
      final upgraded = RidePreferences(await SharedPreferences.getInstance());
      expect(upgraded.saveToHealth, isTrue);
    });

    test('the summary card ride persists until cleared', () async {
      expect(prefs.summaryRide, isNull);
      await prefs.setSummaryRide('workout-1.fit');
      expect(prefs.summaryRide, 'workout-1.fit');
      await prefs.setSummaryRide(null);
      expect(prefs.summaryRide, isNull);
    });

    test('changes notify listeners', () async {
      var calls = 0;
      prefs.addListener(() => calls++);
      await prefs.setAutoRecord(false);
      await prefs.setSaveToHealth(true);
      await prefs.setHealthQuestionAnswered();
      await prefs.setSummaryRide('x.fit');
      expect(calls, 4);
    });
  });
}
