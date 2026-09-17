// The non-VS shift path: a controller press forwarded to the trainer app over
// a direct connection (here the Zwift mDNS emulator). BaseActions.performAction
// is the only place that sees the delivery result, so it reports the shift to
// core.shiftFeedback on Success — and stays silent when delivery failed or the
// button wasn't a shifter.
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/services/shift_feedback/shift_feedback_service.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/recording_shift_feedback.dart';
import 'harness/test_env.dart';

class _RealChainActions extends BaseActions {
  _RealChainActions() : super(supportedModes: const [SupportedMode.keyboard, SupportedMode.touch]);

  @override
  void cleanup() {}
}

Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  core.connection.initialize();

  late _RealChainActions actions;
  late RecordingShiftFeedback feedback;

  setUp(() async {
    await env.resetState(
      prefs: {
        'trainer_app': 'Zwift',
        'zwift_mdns_emulator_enabled': true,
      },
    );
    feedback = RecordingShiftFeedback();
    core.shiftFeedback = feedback;
    actions = _RealChainActions()..supportedApp = Zwift();
    core.actionHandler = actions;
  });

  tearDown(() async {
    core.zwiftMdnsEmulator.isConnected.value = false;
    await env.resetConnection();
  });

  Future<ActionResult> press(ControllerButton button, {bool down = true, bool up = true}) =>
      actions.performAction(button, isKeyDown: down, isKeyUp: up);

  test('a delivered shift reports up / down', () async {
    core.zwiftMdnsEmulator.isConnected.value = true;

    expect(await press(ZwiftButtons.shiftUpRight), isA<Success>());
    expect(await press(ZwiftButtons.shiftDownLeft), isA<Success>());

    expect(feedback.cues, [ShiftCue.up, ShiftCue.down]);
  });

  test('a key-up-only delivery does not count as a second shift', () async {
    core.zwiftMdnsEmulator.isConnected.value = true;

    expect(await press(ZwiftButtons.shiftUpRight, down: true, up: false), isA<Success>());
    expect(await press(ZwiftButtons.shiftUpRight, down: false, up: true), isA<Success>());

    expect(feedback.cues, [ShiftCue.up]);
  });

  test('no feedback when the trainer app is not connected', () async {
    expect(await press(ZwiftButtons.shiftUpRight), isA<Error>());
    expect(feedback.cues, isEmpty);
  });

  test('non-shift buttons stay silent', () async {
    core.zwiftMdnsEmulator.isConnected.value = true;

    expect(await press(ZwiftButtons.a), isA<Success>());
    expect(feedback.cues, isEmpty);
  });
}
