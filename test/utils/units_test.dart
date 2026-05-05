import 'dart:ui';

import 'package:bike_control/utils/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('unitSystemFor', () {
    test('en_US is imperial', () {
      expect(unitSystemFor(const Locale('en', 'US')), UnitSystem.imperial);
    });

    test('en_LR (Liberia) is imperial', () {
      expect(unitSystemFor(const Locale('en', 'LR')), UnitSystem.imperial);
    });

    test('my_MM (Myanmar) is imperial', () {
      expect(unitSystemFor(const Locale('my', 'MM')), UnitSystem.imperial);
    });

    test('de_DE is metric', () {
      expect(unitSystemFor(const Locale('de', 'DE')), UnitSystem.metric);
    });

    test('en_GB is metric (UK uses km internally despite mph on roads)', () {
      expect(unitSystemFor(const Locale('en', 'GB')), UnitSystem.metric);
    });

    test('locale without country code defaults to metric', () {
      expect(unitSystemFor(const Locale('en')), UnitSystem.metric);
    });
  });

  group('UnitSystem conversions', () {
    test('metric is identity', () {
      expect(UnitSystem.metric.fromKph(40), 40);
      expect(UnitSystem.metric.fromKm(10), 10);
      expect(UnitSystem.metric.fromKg(75), 75);
    });

    test('imperial converts kph to mph', () {
      expect(UnitSystem.imperial.fromKph(40), closeTo(24.85, 0.01));
    });

    test('imperial converts km to miles', () {
      expect(UnitSystem.imperial.fromKm(10), closeTo(6.21, 0.01));
    });

    test('imperial converts kg to pounds', () {
      expect(UnitSystem.imperial.fromKg(75), closeTo(165.35, 0.01));
    });

    test('imperial round-trips weight back to kg', () {
      const kg = 75.0;
      final lb = UnitSystem.imperial.fromKg(kg);
      expect(UnitSystem.imperial.toKgFromDisplay(lb), closeTo(kg, 0.0001));
    });

    test('symbols match unit system', () {
      expect(UnitSystem.metric.speedSymbol, 'km/h');
      expect(UnitSystem.imperial.speedSymbol, 'mph');
      expect(UnitSystem.metric.distanceSymbol, 'km');
      expect(UnitSystem.imperial.distanceSymbol, 'mi');
      expect(UnitSystem.metric.weightSymbol, 'kg');
      expect(UnitSystem.imperial.weightSymbol, 'lb');
    });
  });
}
