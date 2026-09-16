// The home screen tells a trainer app that disconnected from one that never
// connected by a session latch. The session keeps that latch current itself,
// through Connection.initialize, whether or not the home page is mounted to
// look — the shell's tab pager disposes it on every swipe. Nothing here builds
// a page or calls the latch's sync(): only the connection and the settings
// change, the way they do while the rider is on another tab.
import 'package:bike_control/pages/home/chain_builder.dart';
import 'package:bike_control/pages/home/chain_inputs.dart';
import 'package:bike_control/pages/home/chain_state.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/my_whoosh.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/test_env.dart';

Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  core.connection.initialize();

  Future<void> start({required Map<String, Object> prefs}) async {
    await env.resetState(prefs: prefs);
    core.actionHandler = StubActions();
    core.appConnectionLatch.reset();
  }

  setUp(() async {
    await start(prefs: {'trainer_app': 'MyWhoosh', 'openbikeprotocol_mdns_enabled': true});
  });

  tearDown(() async {
    core.obpMdnsEmulator.isConnected.value = false;
    core.local.isConnected.value = false;
    await env.resetConnection();
  });

  /// The app card as the home page would build it right now.
  ChainLink appCard() {
    final app = core.settings.getTrainerApp()!.name;
    return buildChain(
      ChainInputs(
        app: AppInput(
          name: app,
          hasEnabledConnection: core.logic.enabledTrainerConnections.isNotEmpty,
          isConnected: core.logic.appFacingConnections.isNotEmpty,
          wasConnectedThisSession: core.appConnectionLatch.wasConnected(app),
        ),
      ),
    ).firstWhere((link) => link.key == ChainLinkKey.app);
  }

  test('an app that connects and drops reads as dropped for that app', () {
    expect(appCard().dropped, isFalse);

    core.obpMdnsEmulator.isConnected.value = true;
    core.obpMdnsEmulator.isConnected.value = false;

    expect(core.appConnectionLatch.wasConnected('MyWhoosh'), isTrue);
    expect(appCard().dropped, isTrue);
  });

  test('an app picked after the drop has connected to nothing', () {
    core.obpMdnsEmulator.isConnected.value = true;
    core.obpMdnsEmulator.isConnected.value = false;

    core.settings.setTrainerApp(TrainingPeaks());

    expect(core.appConnectionLatch.wasConnected(TrainingPeaks().name), isFalse);
    expect(appCard().dropped, isFalse);
  });

  test('an app picked while the connection stays up takes it over', () {
    core.obpMdnsEmulator.isConnected.value = true;
    core.settings.setTrainerApp(TrainingPeaks());
    core.obpMdnsEmulator.isConnected.value = false;

    expect(core.appConnectionLatch.wasConnected(TrainingPeaks().name), isTrue);
    expect(appCard().dropped, isTrue);
  });

  // Local reports connected the moment it is switched on, and the card counts
  // it when it is the only method — but it says nothing about the app.
  test('a session on Local alone latches nothing', () async {
    await start(prefs: {'trainer_app': 'MyWhoosh', 'local_control_enabled': true});
    core.local.isConnected.value = true;
    expect(core.logic.appFacingConnections, isNotEmpty);

    // Something the session watches changes while Local is up.
    core.settings.setTrainerApp(MyWhoosh());

    expect(core.appConnectionLatch.wasConnected('MyWhoosh'), isFalse);
  });
}
