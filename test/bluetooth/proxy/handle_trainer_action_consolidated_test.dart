import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/erg_power_stepping.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

Future<void> main() async {
  // handleTrainerAction reads AppLocalizations.current for its result
  // messages, so we initialise the EN bundle once before any test runs.
  await AppLocalizations.load(const Locale('en'));

  group('ProxyDevice.handleTrainerAction (consolidated)', () {
    late ProxyDevice device;
    late FitnessBikeDefinition def;

    setUp(() {
      core.actionHandler = StubActions();
      device = ProxyDevice(BleDevice(deviceId: 'x', name: 'KICKR'));
      // Force an active FitnessBikeDefinition for the test by invoking the
      // emulator factory directly — in a real session the emulator creates one
      // when started.
      def = FitnessBikeDefinition(
        connectedDevice: device.scanResult,
        connectedDeviceServices: const [],
        data: ValueNotifier<String>(''),
      );
      // Stub the emulator's active definition via the test seam.
      device.emulator.debugSetActiveDefinition(def);
    });

    test('trainerUp in sim mode shifts up', () {
      def.setTargetGear(5);
      final result = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftUp);
      // Sim-mode shifts report Ignored (with the gear message) — the shift is
      // fully handled here and nothing must be forwarded to the trainer app.
      expect(result, isA<Ignored>());
      expect(def.currentGear.value, 6);
    });

    test('trainerUp in erg mode raises power', () {
      def.setManualErgPower(150);
      final result = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftUp);
      expect(result, isA<Success>());
      expect(def.ergTargetPower.value, 155);
      // The result must carry the pressed button — overview.dart drops
      // null-button ActionNotifications, which silently hid all +5W feedback.
      expect(result.button, isNotNull);
    });

    test('trainerUp in erg mode is a no-op at the 500W manual ceiling', () {
      def.setManualErgPower(500);
      final result = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftUp);
      expect(result, isA<Ignored>());
      expect(def.ergTargetPower.value, 500);
    });

    test('trainerUp never yanks a >500W game-set target down to the manual ceiling', () {
      // FTMS setTargetPower can legitimately set targets above the manual
      // 500W cap (the definition accepts up to 2000W). A press must not
      // slash it — up is a no-op there, down steps relative.
      def.setManualErgPower(600);
      expect(def.ergTargetPower.value, 600);

      final up = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftUp);
      expect(up, isA<Ignored>());
      expect(def.ergTargetPower.value, 600);

      final down = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftDown);
      expect(down, isA<Success>());
      expect(def.ergTargetPower.value, 595);
    });

    test('trainerDown in erg mode is a no-op at 0W', () {
      def.setManualErgPower(0);
      final result = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftDown);
      expect(result, isA<Ignored>());
      expect(def.ergTargetPower.value, 0);
    });

    test('trainerDown in sim mode shifts down', () {
      def.setTargetGear(5);
      final result = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftDown);
      expect(result, isA<Ignored>());
      expect(def.currentGear.value, 4);
    });

    test('trainerDown in erg mode lowers power', () {
      def.setManualErgPower(150);
      final result = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftDown);
      expect(result, isA<Success>());
      expect(def.ergTargetPower.value, 145);
    });

    test('trainerSwitchMode toggles from sim to erg', () {
      def.exitErgMode(); // start in sim
      final result = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.trainerSwitchMode);
      expect(result, isA<Success>());
      expect(def.trainerMode.value, TrainerMode.ergMode);
    });

    test('trainerSwitchMode re-enters ERG at the last target', () {
      def.setManualErgPower(230);
      device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.trainerSwitchMode); // → sim
      final result = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.trainerSwitchMode);
      expect(result, isA<Success>());
      expect(def.ergTargetPower.value, 230);
      expect(result.message, AppLocalizations.current.trainerSwitchedToErg(230));
    });

    test('trainerSwitchMode enters ERG at the current power when configured', () {
      def.setErgPreferences(startSource: ErgStartSource.currentPower, stepW: 10);
      def.setManualErgPower(230);
      def.exitErgMode();
      def.setExternalPower(176);
      device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.trainerSwitchMode);
      expect(def.ergTargetPower.value, 180);
    });

    test('trainerUp in erg mode steps by the configured step', () {
      def.setErgPreferences(stepW: 10);
      def.setManualErgPower(150);
      device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftUp);
      expect(def.ergTargetPower.value, 160);
    });

    test('trainerSwitchMode toggles from erg back to sim', () {
      def.setManualErgPower(150); // now in erg
      final result = device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.trainerSwitchMode);
      expect(result, isA<Success>());
      expect(def.trainerMode.value, isNot(TrainerMode.ergMode));
    });

    group('frontShift', () {
      setUp(() {
        // Enable front-shift on the definition, put it in sim mode.
        def.setChainringTeeth(34, 50);
        def.setFrontShiftEnabled(true);
        def.setTargetGear(12); // sim mode (non-ERG)
      });

      test('sim mode: first call shifts to large ring and returns Success', () {
        expect(def.frontRing.value, FrontRing.small); // precondition
        final result = device.handleTrainerAction(
          ZwiftButtons.shiftDownLeft,
          InGameAction.frontShift,
        );
        expect(result, isA<Success>());
        expect(def.frontRing.value, FrontRing.large);
      });

      test('sim mode: second call shifts back to small ring and returns Success', () {
        // First toggle → large
        device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.frontShift);
        expect(def.frontRing.value, FrontRing.large);

        // Second toggle → small
        final result = device.handleTrainerAction(
          ZwiftButtons.shiftDownLeft,
          InGameAction.frontShift,
        );
        expect(result, isA<Success>());
        expect(def.frontRing.value, FrontRing.small);
      });

      test('erg mode: returns Ignored and does not change ring', () {
        def.setManualErgPower(150); // switch to ERG
        expect(def.trainerMode.value, TrainerMode.ergMode);
        final ringBefore = def.frontRing.value;

        final result = device.handleTrainerAction(
          ZwiftButtons.shiftDownLeft,
          InGameAction.frontShift,
        );
        expect(result, isA<Ignored>());
        expect(def.frontRing.value, ringBefore); // unchanged
      });

      test('returns Ignored when front-shift is disabled', () {
        def.setFrontShiftEnabled(false);
        final ringBefore = def.frontRing.value;

        final result = device.handleTrainerAction(
          ZwiftButtons.shiftDownLeft,
          InGameAction.frontShift,
        );
        expect(result, isA<Ignored>());
        expect((result as Ignored).message, AppLocalizations.current.trainerFrontShiftNotEnabled);
        expect(def.frontRing.value, ringBefore);
      });
    });
  });
}
