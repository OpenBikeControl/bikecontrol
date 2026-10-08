import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/gyroscope/gyroscope_steering.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_ble_emulator.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/obc_steering_angle.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/protocol_parser.dart';
import 'package:bike_control/bluetooth/devices/steering_device.dart';
import 'package:bike_control/bluetooth/peripheral_server.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/mdns/service_advertiser.dart';

import '../../../integration/harness/test_env.dart';
import '../../../services/network_self_test/recording_advertiser.dart';

class _FakeSteering implements SteeringDevice {
  @override
  final ValueNotifier<double> steeringAngle = ValueNotifier(0.0);
  @override
  final ValueNotifier<bool> steeringCalibrated = ValueNotifier(false);
  @override
  double get steeringThreshold => 5;
  @override
  final ControllerButton steerLeftButton = ControllerButton('transportLeftSteer', action: InGameAction.steerLeft);
  @override
  final ControllerButton steerRightButton = ControllerButton('transportRightSteer', action: InGameAction.steerRight);
}

class _RecordingPeripheralServer extends PeripheralServer {
  final notified = <(String, Uint8List, String?)>[];

  @override
  Future<void> notify({required String characteristicId, required Uint8List value, String? deviceId}) async {
    notified.add((characteristicId, value, deviceId));
  }
}

Uint8List _appInfo(List<int> ids) => Uint8List.fromList([
  OpenBikeProtocolParser.MSG_TYPE_APP_INFO,
  0x01,
  4,
  ...'game'.codeUnits,
  1,
  ...'1'.codeUnits,
  ids.length,
  ...ids,
]);

KeyPair _steerLeft(ControllerButton button) =>
    KeyPair(buttons: [button], physicalKey: null, logicalKey: null, inGameAction: InGameAction.steerLeft);

final _plainButton = ControllerButton('plainSteerButton', action: InGameAction.steerLeft);

Future<void> main() async {
  await IntegrationEnv.setUp();

  late _FakeSteering device;
  late ObcSteeringAngleBroadcaster previous;
  late ObcSteeringAngleBroadcaster broadcaster;
  late List<SteeringAngleSink> sinks;

  setUp(() async {
    device = _FakeSteering();
    sinks = [];
    previous = core.obcSteeringAngle;
    broadcaster = ObcSteeringAngleBroadcaster(sinks: () => sinks, isAllowed: (_) => true);
    core.obcSteeringAngle = broadcaster;
    broadcaster.attach(device);
    device.steeringCalibrated.value = true; // angle is live: 0x80
  });

  tearDown(() {
    broadcaster.dispose();
    core.obcSteeringAngle = previous;
  });

  group('BLE', () {
    late _RecordingPeripheralServer server;
    late OpenBikeControlBluetoothEmulator emulator;

    setUp(() {
      server = _RecordingPeripheralServer();
      emulator = OpenBikeControlBluetoothEmulator(server: server);
      sinks.add(emulator);
      broadcaster.watchApps([emulator]);
    });

    List<List<int>> sent() => [
      for (final n in server.notified)
        if (n.$1 == OpenBikeControlConstants.BUTTON_STATE_CHARACTERISTIC_UUID) n.$2.toList(),
    ];

    test('the angle goes out as [0x01, 0x1B, value] to the central', () async {
      emulator.onAppInfoWrite('central-1', _appInfo([0x18, 0x19, 0x1B]));
      await pumpEventQueue();
      expect(sent(), [
        [0x01, 0x1B, 0x80],
      ], reason: 'a newly connected app gets the current angle');

      device.steeringAngle.value = -10; // 10° right
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sent().last, [0x01, 0x1B, 0x94]);
      expect(server.notified.last.$3, 'central-1');
    });

    test('nothing is sent without a connected app', () async {
      expect(emulator.canSendSteeringAngle, isFalse);
      device.steeringAngle.value = -10;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sent(), isEmpty);
    });

    test('app without 0x1B: angle and Steer Left both go out', () async {
      emulator.onAppInfoWrite('central-1', _appInfo([0x18, 0x19]));
      final result = await emulator.sendAction(_steerLeft(device.steerLeftButton), isKeyDown: true, isKeyUp: false);
      expect(result, isA<Success>());
      expect(sent(), contains(equals([0x01, 0x18, 0x01])));
      expect(sent(), contains(equals([0x01, 0x1B, 0x80])));
    });

    test('app with 0x1B: the angle input steers by angle only, no Steer Left', () async {
      emulator.onAppInfoWrite('central-1', _appInfo([0x18, 0x19, 0x1B]));
      final result = await emulator.sendAction(_steerLeft(device.steerLeftButton), isKeyDown: true, isKeyUp: false);
      expect(result, isA<Success>());
      expect(sent().where((m) => m[1] == 0x18 || m[1] == 0x19), isEmpty);
    });

    test('app with 0x1B: a plain button mapped to Steer Left still sends 0x18', () async {
      emulator.onAppInfoWrite('central-1', _appInfo([0x18, 0x19, 0x1B]));
      await emulator.sendAction(_steerLeft(_plainButton), isKeyDown: true, isKeyUp: false);
      expect(sent(), contains(equals([0x01, 0x18, 0x01])));
    });
  });

  group('network (mDNS / TCP)', () {
    late RecordingAdvertiser advertiser;
    Socket? socket;
    late List<int> received;

    setUp(() async {
      advertiser = RecordingAdvertiser();
      ServiceAdvertiser.instance = advertiser;
      sinks.add(core.obpMdnsEmulator);
      broadcaster.watchApps([core.obpMdnsEmulator]);
      await core.obpMdnsEmulator.startServer();
      final port = advertiser.services.single.port;
      socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      received = [];
      socket!.listen(received.addAll);
    });

    tearDown(() async {
      socket?.destroy();
      await core.obpMdnsEmulator.stopServer();
      ServiceAdvertiser.instance = NsdServiceAdvertiser();
    });

    Future<void> connectApp(List<int> ids) async {
      socket!.add(_appInfo(ids));
      await socket!.flush();
      await IntegrationEnv.waitFor(() => core.obpMdnsEmulator.connectedApp.value != null, description: 'app info');
    }

    /// Splits the received byte stream into 3-byte button-state messages.
    List<List<int>> messages() => [
      for (var i = 0; i + 3 <= received.length; i += 3) received.sublist(i, i + 3),
    ];

    test('the angle goes out as [0x01, 0x1B, value] to the app', () async {
      await connectApp([0x18, 0x19, 0x1B]);
      await IntegrationEnv.waitFor(() => received.length >= 3, description: 'current angle');
      expect(messages().first, [0x01, 0x1B, 0x80]);

      device.steeringAngle.value = 4.5; // 4.5° left
      await IntegrationEnv.waitFor(() => received.length >= 6, description: 'new angle');
      expect(messages().last, [0x01, 0x1B, 0x77]);
    });

    test('app without 0x1B: angle and Steer Left both go out', () async {
      await connectApp([0x18, 0x19]);
      final result = await core.obpMdnsEmulator.sendAction(
        _steerLeft(device.steerLeftButton),
        isKeyDown: true,
        isKeyUp: false,
      );
      expect(result, isA<Success>());
      await IntegrationEnv.waitFor(() => received.length >= 6, description: 'angle + press');
      expect(
        messages(),
        containsAll([
          [0x01, 0x1B, 0x80],
          [0x01, 0x18, 0x01],
        ]),
      );
    });

    test('app with 0x1B: the angle input steers by angle only, no Steer Left', () async {
      await connectApp([0x18, 0x19, 0x1B]);
      final result = await core.obpMdnsEmulator.sendAction(
        _steerLeft(device.steerLeftButton),
        isKeyDown: true,
        isKeyUp: false,
      );
      expect(result, isA<Success>());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(messages().where((m) => m[1] == 0x18 || m[1] == 0x19), isEmpty);
    });
  });

  group('wiring', () {
    test(
      'phone steering: attached on connect, its angle (positive = left) goes out right-positive, 0x00 on disconnect',
      () async {
        final changes = StreamController<BaseDevice>.broadcast();
        final sink = _RecordingSink();
        final b = ObcSteeringAngleBroadcaster(sinks: () => [sink], isAllowed: (_) => true)
          ..watchDevices(changes.stream);
        addTearDown(() {
          b.dispose();
          changes.close();
        });

        final phone = GyroscopeSteering()..isConnected = true;
        changes.add(phone);
        await pumpEventQueue();
        phone.isCalibratedNotifier.value = true;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        phone.steeringAngle.value = 10; // phone steering: positive = LEFT
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(sink.sent, [0x80, 0x6C], reason: '10° left = 0x80 - 20');

        phone.isConnected = false;
        changes.add(phone);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(sink.sent.last, 0x00);
      },
    );
  });

  group('gate (same conditions as Steer Left / Right)', () {
    final phone = GyroscopeSteering();

    void useKeymap(List<KeyPair> pairs) {
      final app = Zwift();
      app.keymap.keyPairs
        ..clear()
        ..addAll(pairs);
      core.actionHandler = _TestActions()..supportedApp = app;
    }

    setUp(() => IAPManager.instance.setProForTesting(enabled: true));

    test('steering buttons mapped to steering ⇒ allowed', () {
      useKeymap([
        KeyPair(
          buttons: [phone.steerLeftButton],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.steerLeft,
        ),
      ]);
      expect(obcSteeringAngleAllowed(phone), isTrue);
    });

    test('steering buttons remapped to something else ⇒ not allowed', () {
      useKeymap([
        KeyPair(
          buttons: [phone.steerLeftButton],
          physicalKey: null,
          logicalKey: null,
          inGameAction: InGameAction.shiftUp,
        ),
      ]);
      expect(obcSteeringAngleAllowed(phone), isFalse);
    });

    test('no mapping at all ⇒ not allowed', () {
      useKeymap([]);
      expect(obcSteeringAngleAllowed(phone), isFalse);
    });
  });
}

class _TestActions extends BaseActions {
  _TestActions() : super(supportedModes: const []);
  @override
  void cleanup() {}
}

class _RecordingSink implements SteeringAngleSink {
  @override
  final ValueNotifier<AppInfo?> connectedApp = ValueNotifier(
    OpenBikeProtocolParser.parseAppInfo(_appInfo([0x18, 0x19])),
  );
  @override
  bool get canSendSteeringAngle => true;
  final sent = <int>[];
  @override
  Future<void> sendSteeringAngle(int value) async => sent.add(value);
}
