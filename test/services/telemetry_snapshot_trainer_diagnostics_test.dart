// The structured trainer diagnostics (`self_test_result`, `self_test_passed`,
// `ble_services`) sent alongside each support message, so the server never has
// to read the free-text debug dump to learn how a trainer model behaves.
import 'dart:convert';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/services/trainer_self_test/self_test_result.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.devices.clear();
  });

  tearDown(() => core.connection.devices.clear());

  ProxyDevice trainer({
    String name = 'KICKR CORE',
    bool connected = true,
    List<BleService>? services,
  }) {
    final device = ProxyDevice(
      BleDevice(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        name: name,
        services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID],
      ),
    )..services = services;
    device.isConnected = connected;
    return device;
  }

  final ftmsAndZwift = [
    BleService('00001800-0000-1000-8000-00805f9b34fb', []),
    BleService(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, []),
    BleService('00000001-19CA-4651-86E5-FA29DCDD09D1', []),
  ];

  SelfTestResult result(SelfTestVerdict verdict, {List<String> stepLog = const []}) => SelfTestResult(
    at: DateTime.utc(2026, 9, 30, 18, 42, 11),
    verdict: verdict,
    ergStepsPassed: 3,
    ergStepsTotal: 3,
    shiftStepsPassed: verdict == SelfTestVerdict.pass ? 4 : 0,
    shiftStepsTotal: 4,
    vsMode: 'trackResistance',
    protocol: 'ftms',
    stepLog: stepLog,
  );

  Future<void> storeSelfTest(String trainerKey, SelfTestResult r) =>
      core.settings.setSelfTestResultJson(trainerKey, r.toJsonString());

  Map<String, dynamic> generalJson() => TelemetrySnapshot.general(freetext: 'dump').toJson();

  group('no trainer connected', () {
    test('omits all three trainer diagnostic keys', () {
      final json = generalJson();

      expect(json.containsKey('self_test_result'), isFalse);
      expect(json.containsKey('self_test_passed'), isFalse);
      expect(json.containsKey('ble_services'), isFalse);
      expect(json.containsKey('bluetooth_name'), isFalse);
      expect(json.containsKey('hardware_manufacturer'), isFalse);
      expect(json.containsKey('firmware_version'), isFalse);
    });

    test('a disconnected trainer does not count', () async {
      core.connection.devices.add(trainer(connected: false, services: ftmsAndZwift));
      await storeSelfTest('KICKR CORE', result(SelfTestVerdict.pass));

      expect(generalJson().containsKey('self_test_result'), isFalse);
    });

    test('a connected controller is never reported as a trainer', () {
      core.connection.devices.add(
        ZwiftClickV2(BleDevice(deviceId: 'c2', name: 'Zwift Click'))
          ..isConnected = true
          ..services = ftmsAndZwift
          ..deviceName = 'Zwift Click'
          ..hardwareRevision = 'B'
          ..manufacturerName = 'Zwift'
          ..firmwareVersion = '1.3.0',
      );

      final json = generalJson();
      expect(json.containsKey('ble_services'), isFalse);
      expect(json.containsKey('self_test_result'), isFalse);
      expect(json.containsKey('bluetooth_name'), isFalse);
      expect(json.containsKey('hardware_manufacturer'), isFalse);
      expect(json.containsKey('firmware_version'), isFalse);
    });
  });

  group('trainer connected', () {
    test('no stored self-test: result and passed are explicit nulls', () {
      core.connection.devices.add(trainer(services: ftmsAndZwift));

      final json = generalJson();

      expect(json.containsKey('self_test_result'), isTrue);
      expect(json['self_test_result'], isNull);
      expect(json.containsKey('self_test_passed'), isTrue);
      expect(json['self_test_passed'], isNull);
    });

    test('ble_services lists the non-standard service UUIDs, lowercased', () {
      core.connection.devices.add(trainer(services: ftmsAndZwift));

      expect(generalJson()['ble_services'], [
        FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase(),
        '00000001-19ca-4651-86e5-fa29dcdd09d1',
      ]);
    });

    test('ble_services is null before services are discovered', () {
      core.connection.devices.add(trainer());

      final json = generalJson();
      expect(json.containsKey('ble_services'), isTrue);
      expect(json['ble_services'], isNull);
    });

    test('passed self-test', () async {
      core.connection.devices.add(trainer(services: ftmsAndZwift));
      await storeSelfTest('KICKR CORE', result(SelfTestVerdict.pass, stepLog: ['phase: shift sweep']));

      final json = generalJson();

      expect(json['self_test_passed'], isTrue);
      expect(json['self_test_result'], {
        'at': '2026-09-30',
        'verdict': 'pass',
        'ergStepsPassed': 3,
        'ergStepsTotal': 3,
        'shiftStepsPassed': 4,
        'shiftStepsTotal': 4,
        'vsMode': 'trackResistance',
        'protocol': 'ftms',
        'cadenceless': false,
        'stepLog': ['phase: shift sweep'],
      });
      // Must survive the request body's JSON encoding untouched.
      expect(jsonDecode(jsonEncode(json))['self_test_result']['verdict'], 'pass');
    });

    test('failed self-test', () async {
      core.connection.devices.add(trainer(services: ftmsAndZwift));
      await storeSelfTest('KICKR CORE', result(SelfTestVerdict.noControl));

      final json = generalJson();

      expect(json['self_test_passed'], isFalse);
      expect((json['self_test_result'] as Map)['verdict'], 'noControl');
    });

    test('partial verdicts are not a pass', () async {
      core.connection.devices.add(trainer());
      await storeSelfTest('KICKR CORE', result(SelfTestVerdict.ergOkVsFail));

      expect(generalJson()['self_test_passed'], isFalse);
    });

    test('a self-test stored for another trainer is not attached', () async {
      core.connection.devices.add(trainer());
      await storeSelfTest('Some Other Trainer', result(SelfTestVerdict.pass));

      expect(generalJson()['self_test_result'], isNull);
    });

    test('unparseable stored self-test degrades to null', () async {
      core.connection.devices.add(trainer());
      await core.settings.setSelfTestResultJson('KICKR CORE', '{not json');

      final json = generalJson();
      expect(json['self_test_result'], isNull);
      expect(json['self_test_passed'], isNull);
    });

    test('carries the trainer identity exactly as fromDevice builds it', () {
      final device = trainer(services: ftmsAndZwift)
        ..deviceName = 'KICKR CORE 1EB7'
        ..hardwareRevision = '2'
        ..manufacturerName = 'Wahoo Fitness'
        ..firmwareVersion = '4.3.2';
      core.connection.devices.add(device);

      final json = generalJson();

      expect(json['bluetooth_name'], 'KICKR CORE 1EB7 (HW: 2)');
      expect(json['hardware_manufacturer'], 'Wahoo Fitness');
      expect(json['firmware_version'], '4.3.2');
      final fromDevice = TelemetrySnapshot.fromDevice(device: device).toJson();
      for (final key in ['bluetooth_name', 'hardware_manufacturer', 'firmware_version']) {
        expect(json[key], fromDevice[key], reason: key);
      }
    });

    test('identity falls back like fromDevice when the device info is unread', () {
      core.connection.devices.add(trainer());

      final json = generalJson();

      expect(json['bluetooth_name'], 'KICKR CORE');
      expect(json.containsKey('hardware_manufacturer'), isFalse);
      expect(json.containsKey('firmware_version'), isFalse);
    });

    test('freetext is unchanged', () {
      core.connection.devices.add(trainer(services: ftmsAndZwift));

      expect(generalJson()['freetext'], 'dump');
    });
  });

  group('self-test result is stripped of identifying data', () {
    test('keeps only known fields and the date of the run', () {
      final sanitized = sanitizeSelfTestResultJson({
        ...result(SelfTestVerdict.pass).toJson(),
        'deviceId': 'AA:BB:CC:DD:EE:FF',
        'userId': 'abc',
      });

      expect(sanitized.keys, isNot(contains('deviceId')));
      expect(sanitized.keys, isNot(contains('userId')));
      expect(sanitized['at'], '2026-09-30');
    });

    test('redacts addresses and error details from step log lines', () {
      final sanitized = sanitizeSelfTestResultJson(
        result(
          SelfTestVerdict.aborted,
          stepLog: [
            'start: vs=trackResistance protocol=ftms gear=12 erg=false',
            'aborted: engine error (SocketException: Connection reset, address = 192.168.1.20, port = 36866)',
            'note AA:BB:CC:DD:EE:FF fe80::1c2b:3aff:fe4d:5e6f',
            'device 6F1A2B3C-4D5E-6F70-8192-A3B4C5D6E7F8 gone',
          ],
        ).toJson(),
      );

      final log = (sanitized['stepLog'] as List).cast<String>();
      expect(log.first, 'start: vs=trackResistance protocol=ftms gear=12 erg=false');
      expect(log[1], 'aborted: engine error');
      final joined = log.join('\n');
      expect(joined, isNot(contains('192.168.1.20')));
      expect(joined, isNot(contains('AA:BB:CC:DD:EE:FF')));
      expect(joined, isNot(contains('fe80::1c2b')));
      expect(joined, isNot(contains('6F1A2B3C-4D5E')));
    });
  });

  test('fromDevice carries the same three keys for its trainer', () async {
    final device = trainer(services: ftmsAndZwift, connected: false);
    await storeSelfTest('KICKR CORE', result(SelfTestVerdict.pass));

    final json = TelemetrySnapshot.fromDevice(device: device).toJson();

    expect(json['self_test_passed'], isTrue);
    expect((json['self_test_result'] as Map)['verdict'], 'pass');
    expect(json['ble_services'], hasLength(2));
  });
}
