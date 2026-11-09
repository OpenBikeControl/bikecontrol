import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/training_peaks.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/dircon/dircon_framing.dart';
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/utils/constants.dart';

import '../../../integration/harness/test_env.dart';
import '../../../services/network_self_test/recording_advertiser.dart';

List<int> _uuidBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  return [for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
}

final _appInfo = Uint8List.fromList([
  OpenBikeProtocolParser.MSG_TYPE_APP_INFO,
  0x01,
  4,
  ...'game'.codeUnits,
  1,
  ...'1'.codeUnits,
  1,
  0x01,
]);

/// An app that takes the controller over DirCon stays on its connecting state
/// until a first notification arrives, so one follows its App Info.
Future<void> main() async {
  await IntegrationEnv.setUp();

  late RecordingAdvertiser advertiser;
  Socket? socket;
  late List<int> received;

  Future<void> connect() async {
    advertiser = RecordingAdvertiser();
    ServiceAdvertiser.instance = advertiser;
    await core.obpMdnsEmulator.startServer();
    socket = await Socket.connect(InternetAddress.loopbackIPv4, advertiser.services.single.port);
    received = [];
    socket!.listen(received.addAll);
  }

  tearDown(() async {
    socket?.destroy();
    await core.obpMdnsEmulator.stopServer();
    ServiceAdvertiser.instance = NsdServiceAdvertiser();
  });

  test('DirCon: App Info is answered, then followed by a button state naming no buttons', () async {
    core.settings.setTrainerApp(TrainingPeaks());
    await connect();
    final appInfoUuid = _uuidBytes(OpenBikeControlConstants.APPINFO_CHARACTERISTIC_UUID);
    socket!.add(
      DirconMessage(
        version: 1,
        msgId: FtmsMdnsConstants.DC_MESSAGE_WRITE_CHARACTERISTIC,
        seqNum: 7,
        respCode: 0,
        body: [...appInfoUuid, ..._appInfo],
      ).encode(),
    );
    await socket!.flush();
    await IntegrationEnv.waitFor(() => core.obpMdnsEmulator.connectedApp.value != null, description: 'app info');

    final frames = <DirconMessage>[];
    await IntegrationEnv.waitFor(() {
      frames
        ..clear()
        ..addAll(DirconFrameAccumulator().addBytes(received));
      return frames.length >= 2;
    }, description: 'write response and notification');

    expect(frames, hasLength(2));
    expect(frames[0].msgId, FtmsMdnsConstants.DC_MESSAGE_WRITE_CHARACTERISTIC);
    expect(frames[1].msgId, FtmsMdnsConstants.DC_MESSAGE_CHARACTERISTIC_NOTIFICATION);
    expect(frames[1].body, [
      ..._uuidBytes(OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID),
      OpenBikeProtocolParser.MSG_TYPE_BUTTON_STATE,
    ]);
  });

  test('raw TCP: App Info gets no frame back', () async {
    core.settings.setTrainerApp(Zwift());
    await connect();
    socket!.add(_appInfo);
    await socket!.flush();
    await IntegrationEnv.waitFor(() => core.obpMdnsEmulator.connectedApp.value != null, description: 'app info');
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(received, isEmpty);
  });
}
