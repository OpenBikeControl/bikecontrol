import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

FitnessBikeDefinition _def() => FitnessBikeDefinition(
  connectedDevice: BleDevice(deviceId: 't', name: 'T'),
  connectedDeviceServices: const <BleService>[],
  data: ValueNotifier<String>(''),
);

void main() {
  group('ERG step', () {
    test('defaults to 5 W', () {
      final def = _def()..setManualErgPower(150);
      expect(def.ergStepW, ErgPowerStepping.defaultStepW);
      expect(def.stepManualErgPower(up: true), 155);
    });

    test('follows the configured step, both ways', () {
      final def = _def()..setErgPreferences(stepW: 25);
      def.setManualErgPower(150);
      expect(def.stepManualErgPower(up: true), 175);
      expect(def.stepManualErgPower(up: false), 150);
      def.setErgPreferences(stepW: 1);
      expect(def.stepManualErgPower(up: false), 149);
    });

    test('still stops at the manual ceiling and at 0', () {
      final def = _def()..setErgPreferences(stepW: 25);
      def.setManualErgPower(490);
      expect(def.stepManualErgPower(up: true), ErgPowerStepping.maxManualW);
      def.setManualErgPower(10);
      expect(def.stepManualErgPower(up: false), 0);
    });

    test('a step that is not one of the choices is ignored', () {
      final def = _def()..setErgPreferences(stepW: 7);
      expect(def.ergStepW, ErgPowerStepping.defaultStepW);
    });

    test('preferences are per definition', () {
      final a = _def()..setErgPreferences(stepW: 25);
      final b = _def();
      expect(a.ergStepW, 25);
      expect(b.ergStepW, ErgPowerStepping.defaultStepW);
    });
  });

  group('ERG start power', () {
    test('with nothing known it is 150 W', () {
      expect(_def().ergStartPower(), ErgPowerStepping.fallbackStartW);
      final def = _def()..setErgPreferences(startSource: ErgStartSource.currentPower);
      expect(def.ergStartPower(), ErgPowerStepping.fallbackStartW);
    });

    test('Last target resumes the last target after leaving ERG', () {
      final def = _def()..setManualErgPower(215);
      def.exitErgMode();
      def.setExternalPower(180);
      expect(def.ergStartPower(), 215);
    });

    test('Last target falls back to the current power, rounded to the step', () {
      final def = _def()..setExternalPower(183);
      expect(def.ergStartPower(), 185);
      def.setErgPreferences(stepW: 10);
      expect(def.ergStartPower(), 180);
    });

    test('Current power uses the live power, rounded to the step', () {
      final def = _def()
        ..setErgPreferences(startSource: ErgStartSource.currentPower, stepW: 25)
        ..setManualErgPower(215);
      def.exitErgMode();
      def.setExternalPower(238);
      expect(def.ergStartPower(), 250);
    });

    test('Current power falls back to the last target when the power is 0 or unknown', () {
      final def = _def()
        ..setErgPreferences(startSource: ErgStartSource.currentPower)
        ..setManualErgPower(215);
      def.exitErgMode();
      expect(def.ergStartPower(), 215);
      def.setExternalPower(0);
      expect(def.ergStartPower(), 215);
    });

    test('a current power above the manual ceiling starts at the ceiling', () {
      final def = _def()
        ..setErgPreferences(startSource: ErgStartSource.currentPower)
        ..setExternalPower(900);
      expect(def.ergStartPower(), ErgPowerStepping.maxManualW);
    });

    test('enterManualErg enters ERG at the start power and returns it', () {
      final def = _def()..setManualErgPower(240);
      def.exitErgMode();
      expect(def.enterManualErg(), 240);
      expect(def.trainerMode.value, TrainerMode.ergMode);
      expect(def.ergTargetPower.value, 240);
    });
  });
}
