// An app connected over OpenBikeControl's network transport that never sends
// the (optional) App Information message: the connection still counts as
// connected, and buttons still reach it — the protocol asks devices to assume
// every button is supported then.
import 'dart:io';

import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/mdns/service_advertiser.dart';

import '../../../integration/harness/test_env.dart';
import '../../../services/network_self_test/recording_advertiser.dart';

Future<void> main() async {
  await IntegrationEnv.setUp();

  late RecordingAdvertiser advertiser;
  Socket? socket;
  late List<int> received;

  setUp(() async {
    advertiser = RecordingAdvertiser();
    ServiceAdvertiser.instance = advertiser;
    await core.obpMdnsEmulator.startServer();
    socket = await Socket.connect(InternetAddress.loopbackIPv4, advertiser.services.single.port);
    received = [];
    socket!.listen(received.addAll);
  });

  tearDown(() async {
    socket?.destroy();
    await core.obpMdnsEmulator.stopServer();
    ServiceAdvertiser.instance = NsdServiceAdvertiser();
  });

  test('connected once the app is on the line, App Info or not', () async {
    await IntegrationEnv.waitFor(() => core.obpMdnsEmulator.isConnected.value, description: 'connected');
    expect(core.obpMdnsEmulator.connectedApp.value, isNull, reason: 'nothing was sent');
  });

  test('a button press still goes out, as if every button were supported', () async {
    await IntegrationEnv.waitFor(() => core.obpMdnsEmulator.isConnected.value, description: 'connected');
    final button = ControllerButton('noAppInfoShiftUp', action: InGameAction.shiftUp);
    final result = await core.obpMdnsEmulator.sendAction(
      KeyPair(buttons: [button], physicalKey: null, logicalKey: null, inGameAction: InGameAction.shiftUp),
      isKeyDown: true,
      isKeyUp: false,
    );
    expect(result, isA<Success>());
    await IntegrationEnv.waitFor(() => received.length >= 3, description: 'the press');
    expect(received.sublist(0, 3), [0x01, 0x01, 0x01]);
  });

  test('the app leaving: not connected any more', () async {
    await IntegrationEnv.waitFor(() => core.obpMdnsEmulator.isConnected.value, description: 'connected');
    socket!.destroy();
    socket = null;
    await IntegrationEnv.waitFor(() => !core.obpMdnsEmulator.isConnected.value, description: 'disconnected');
  });
}
