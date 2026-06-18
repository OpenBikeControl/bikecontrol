import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/keymap_explanation.dart' show SplitByUppercase;
import 'package:flutter_test/flutter_test.dart';

import 'harness/test_env.dart';

/// Real [BaseActions.performAction] — only [cleanup] is stubbed, so the
/// keymap → pro-guard → connection-routing logic under test runs for real.
class _RealChainActions extends BaseActions {
  _RealChainActions() : super(supportedModes: const [SupportedMode.keyboard, SupportedMode.touch]);

  @override
  void cleanup() {}
}

/// Regression for issue #367: when the trainer app (Zwift) has disconnected,
/// pressing a virtual-shifting button reported the misleading
/// "Could not perform <key>: No action assigned" instead of saying the trainer
/// app is not connected.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  core.connection.initialize();

  late _RealChainActions actions;

  setUp(() async {
    // A Zwift mDNS connection is enabled (so a connection method exists) but
    // nothing is connected to it — exactly the "Zwift was closed" state.
    await env.resetState(prefs: {
      'trainer_app': 'Zwift',
      'zwift_mdns_emulator_enabled': true,
    });
    actions = _RealChainActions()..supportedApp = Zwift();
    core.actionHandler = actions;
  });

  tearDown(() async {
    await env.resetConnection();
  });

  Future<ActionResult> press(ControllerButton button) =>
      actions.performAction(button, isKeyDown: true, isKeyUp: true);

  test('a virtual-shifting press with no connected trainer names the trainer app', () async {
    final result = await press(ZwiftButtons.shiftUpRight);

    expect(result, isA<Error>());
    expect((result as Error).type, ErrorType.trainerNotConnected);
    // The real reason — not the misleading "No action assigned".
    expect(result.message, contains('Zwift'));
    expect(result.message, contains('not connected'));
    expect(result.message, isNot(contains('No action assigned')));
  });

  test('still fires when local control is enabled (the exact #367 trigger)', () async {
    // Local keyboard control makes isTrainerConnected() true, which previously
    // let the press slip through to the "no action assigned" keyboard fallback.
    await env.resetState(prefs: {
      'trainer_app': 'Zwift',
      'zwift_mdns_emulator_enabled': true,
      'local_control_enabled': true,
    });
    actions = _RealChainActions()..supportedApp = Zwift();
    core.actionHandler = actions;

    final result = await press(ZwiftButtons.shiftUpRight);

    expect(result, isA<Error>());
    expect((result as Error).type, ErrorType.trainerNotConnected);
    expect(result.message, isNot(contains('No action assigned')));
  });

  test('localized message matches the new ARB string', () async {
    final result = await press(ZwiftButtons.shiftUpRight);

    expect(
      result.message,
      AppLocalizations.current.trainerAppNotConnectedForButton(
        ZwiftButtons.shiftUpRight.name.splitByUpperCase(),
        'Zwift',
      ),
    );
  });
}
