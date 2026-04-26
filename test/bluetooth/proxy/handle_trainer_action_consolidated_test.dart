import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
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
      final result = device.handleTrainerAction(InGameAction.shiftUp);
      expect(result, isA<Success>());
      expect(def.currentGear.value, 6);
    });

    test('trainerUp in erg mode raises power', () {
      def.setManualErgPower(150);
      final result = device.handleTrainerAction(InGameAction.shiftUp);
      expect(result, isA<Success>());
      expect(def.ergTargetPower.value, 160);
    });

    test('trainerDown in sim mode shifts down', () {
      def.setTargetGear(5);
      final result = device.handleTrainerAction(InGameAction.shiftDown);
      expect(result, isA<Success>());
      expect(def.currentGear.value, 4);
    });

    test('trainerDown in erg mode lowers power', () {
      def.setManualErgPower(150);
      final result = device.handleTrainerAction(InGameAction.shiftDown);
      expect(result, isA<Success>());
      expect(def.ergTargetPower.value, 140);
    });

    test('trainerSwitchMode toggles from sim to erg', () {
      def.exitErgMode(); // start in sim
      final result = device.handleTrainerAction(InGameAction.trainerSwitchMode);
      expect(result, isA<Success>());
      expect(def.trainerMode.value, TrainerMode.ergMode);
    });

    test('trainerSwitchMode toggles from erg back to sim', () {
      def.setManualErgPower(150); // now in erg
      final result = device.handleTrainerAction(InGameAction.trainerSwitchMode);
      expect(result, isA<Success>());
      expect(def.trainerMode.value, isNot(TrainerMode.ergMode));
    });
  });
}
