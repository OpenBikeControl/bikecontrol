// The virtual-shifting branch of ProxyDevice.handleTrainerAction is the one
// place that knows whether a shift actually moved the drivetrain — the
// ActionResult can't say (a successful VS shift is reported as `Ignored`).
// It must report the outcome to core.shiftFeedback, in both sim and ERG mode.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:universal_ble/universal_ble.dart';

import '../../helpers/recording_shift_feedback.dart';

Future<void> main() async {
  await AppLocalizations.load(const Locale('en'));

  late ProxyDevice device;
  late FitnessBikeDefinition def;
  late RecordingShiftFeedback feedback;

  setUp(() {
    core.actionHandler = StubActions();
    feedback = RecordingShiftFeedback();
    core.shiftFeedback = feedback;
    device = ProxyDevice(BleDevice(deviceId: 'x', name: 'KICKR'));
    def = FitnessBikeDefinition(
      connectedDevice: device.scanResult,
      connectedDeviceServices: const [],
      data: ValueNotifier<String>(''),
    );
    device.emulator.debugSetActiveDefinition(def);
  });

  test('sim mode: a shift that moves the gear reports up / down', () {
    def.setTargetGear(5);
    device.handleTrainerAction(ZwiftButtons.shiftUpRight, InGameAction.shiftUp);
    device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftDown);

    expect(feedback.cues, [ShiftCue.up, ShiftCue.down]);
  });

  test('sim mode: top and bottom of the cassette report the limit', () {
    def.setTargetGear(def.gearRatios.value.length);
    device.handleTrainerAction(ZwiftButtons.shiftUpRight, InGameAction.shiftUp);
    def.setTargetGear(1);
    device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftDown);

    expect(feedback.cues, [ShiftCue.limit, ShiftCue.limit]);
  });

  test('erg mode: stepping the target counts as a shift, the clamp as the limit', () {
    def.setManualErgPower(150);
    device.handleTrainerAction(ZwiftButtons.shiftUpRight, InGameAction.shiftUp);
    device.handleTrainerAction(ZwiftButtons.shiftDownLeft, InGameAction.shiftDown);
    def.setManualErgPower(500);
    device.handleTrainerAction(ZwiftButtons.shiftUpRight, InGameAction.shiftUp);

    expect(feedback.cues, [ShiftCue.up, ShiftCue.down, ShiftCue.limit]);
  });

  test('non-shift trainer actions stay silent', () {
    device.handleTrainerAction(ZwiftButtons.shiftUpRight, InGameAction.trainerSwitchMode);
    expect(feedback.cues, isEmpty);
  });
}
