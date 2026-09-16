// Support pitfall: the same physical trainer is listed twice — once from the
// BLE scan, once from mDNS/DirCon — and both entries share one trainerKey, so
// one tap's consent auto-connected both. Two live upstream paths then fought
// over resistance. These tests pin the rule that only one path of a twin is
// ever up: auto-connect leaves the sibling alone while the other holds the
// trainer, and a manual connect on the sibling switches paths (disconnect
// first, then connect) instead of doubling up.
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

/// No-op local-notifications backend — `Connection._connect`'s connection
/// listener posts through the plugin, whose platform instance only real plugin
/// registration sets. Same scaffolding as connection_broadcast_test.dart.
class _FakeLocalNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

/// A trainer whose upstream connect/disconnect are recorded instead of run:
/// the rule under test is Connection's orchestration — who is started, who is
/// torn down, in which order — not the transport underneath.
class _FakeTrainer extends ProxyDevice {
  _FakeTrainer(super.scanResult, {required this.events, required this.tag});

  _FakeTrainer.wifi(super.scanResult, {required this.events, required this.tag, required super.host, required super.port})
    : super.wifi();

  final List<String> events;
  final String tag;

  int get startCalls => events.where((e) => e == '$tag.start').length;
  int get disconnectCalls => events.where((e) => e == '$tag.disconnect').length;

  @override
  Future<void> startProxy() async {
    events.add('$tag.start');
    isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    events.add('$tag.disconnect');
    isConnected = false;
    // A connect still in flight fails through the torn-down transport a
    // moment later; startProxy's finally then clears the flag.
    if (isStarting.value) {
      Future<void>.delayed(const Duration(milliseconds: 120)).then((_) => isStarting.value = false);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLocalizations.load(const Locale('en'));
    SharedPreferences.setMockInitialValues({});
    // IAP attribute refresh on a successful connect reaches Supabase.instance;
    // an offline dummy keeps that path from asserting. No session, no network.
    await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'proxy-twin-connect-test-anon-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });

  const trainerName = 'KICKR CORE 1EB7';
  late List<String> events;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    core.actionHandler = StubActions();
    core.connection.devices.clear();
    UniversalBle.setInstance(FakeUniversalBlePlatform());
    FlutterLocalNotificationsPlatform.instance = _FakeLocalNotificationsPlatform();
    IAPManager.instance.setProForTesting(enabled: true);
    events = [];
    // One tap's consent — stored under the shared key, so it covers both
    // entries of the twin. That is exactly how both used to auto-connect.
    await core.settings.setAutoConnect(trainerName, true);
  });

  tearDown(() async {
    core.connection.devices.clear();
    await core.connection.stop();
  });

  BleDevice scan(String id, {String name = trainerName}) =>
      BleDevice(deviceId: id, name: name, services: const [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID]);

  _FakeTrainer bleTrainer({String name = trainerName}) =>
      _FakeTrainer(scan('AA:BB:CC:DD:EE:FF', name: name), events: events, tag: 'ble');

  _FakeTrainer wifiTrainer({String name = trainerName, String tag = 'wifi'}) =>
      _FakeTrainer.wifi(scan('dircon://$name', name: name), events: events, tag: tag, host: '192.168.1.20', port: 36866);

  /// Lets the fire-and-forget connect queue behind [Connection.addDevices] run.
  Future<void> drainQueue() => Future<void>.delayed(const Duration(milliseconds: 50));

  group('twin detection', () {
    test('the same trainer over the other transport is the twin', () {
      final ble = bleTrainer();
      final wifi = wifiTrainer();
      core.connection.devices.addAll([ble, wifi]);

      expect(core.connection.twinOf(ble), same(wifi));
      expect(core.connection.twinOf(wifi), same(ble));
    });

    test('a different trainer, or the same transport twice, is not a twin', () {
      final ble = bleTrainer();
      final other = wifiTrainer(name: 'TACX NEO 9999');
      core.connection.devices.addAll([ble, other]);
      expect(core.connection.twinOf(ble), isNull);
      expect(core.connection.twinOf(other), isNull);

      // Two Bluetooth entries with one name are two trainers, not one path pair.
      final secondBle = _FakeTrainer(scan('11:22:33:44:55:66'), events: events, tag: 'ble2');
      core.connection.devices.add(secondBle);
      expect(core.connection.twinOf(ble), isNull);
    });
  });

  group('auto-connect', () {
    test('leaves the WiFi entry alone while the Bluetooth entry holds the trainer', () async {
      final ble = bleTrainer()..isConnected = true;
      final wifi = wifiTrainer();
      core.connection.devices.add(ble);

      // Discovery queues the WiFi twin for auto-connect, consent and all.
      expect(wifi.shouldAutoConnect, isFalse, reason: 'the sibling holds the trainer');
      core.connection.addDevices([wifi]);
      await drainQueue();

      expect(wifi.startCalls, 0);
      expect(wifi.isConnected, isFalse);
      expect(ble.isConnected, isTrue);
    });

    test('a connect still in flight on the sibling counts as holding the trainer', () async {
      final ble = bleTrainer()..isStarting.value = true;
      final wifi = wifiTrainer();
      core.connection.devices.add(ble);

      expect(wifi.shouldAutoConnect, isFalse);
    });

    test('an idle sibling does not block: consent alone auto-connects', () async {
      final ble = bleTrainer();
      final wifi = wifiTrainer();
      core.connection.devices.add(ble);

      expect(wifi.shouldAutoConnect, isTrue);
      core.connection.addDevices([wifi]);
      await drainQueue();

      expect(wifi.startCalls, 1);
    });

    test('a trainer with a different key is unaffected', () async {
      final ble = bleTrainer()..isConnected = true;
      final other = wifiTrainer(name: 'TACX NEO 9999', tag: 'other');
      await core.settings.setAutoConnect('TACX NEO 9999', true);
      core.connection.devices.add(ble);

      expect(other.shouldAutoConnect, isTrue);
      core.connection.addDevices([other]);
      await drainQueue();

      expect(other.startCalls, 1);
      expect(ble.isConnected, isTrue);
    });
  });

  group('manual connect (path switch)', () {
    test('connecting the WiFi entry disconnects the Bluetooth entry first, then starts', () async {
      final ble = bleTrainer()..isConnected = true;
      final wifi = wifiTrainer();
      core.connection.devices.addAll([ble, wifi]);

      await core.connection.connectDevice(wifi);

      expect(events, ['ble.disconnect', 'wifi.start']);
      expect(ble.isConnected, isFalse);
      expect(wifi.isConnected, isTrue);
      // The released entry stays listed — it is the way back to the other path.
      expect(core.connection.devices, containsAll([ble, wifi]));
    });

    test('the released sibling is not auto-reconnected while the twin holds the trainer', () async {
      final ble = bleTrainer()..isConnected = true;
      final wifi = wifiTrainer();
      core.connection.devices.addAll([ble, wifi]);
      await core.connection.connectDevice(wifi);
      events.clear();

      expect(ble.shouldAutoConnect, isFalse);
      // A rediscovery that re-queues the released entry must not bring it back.
      core.connection.devices.remove(ble);
      core.connection.addDevices([ble]);
      await drainQueue();

      expect(ble.startCalls, 0);
      expect(wifi.isConnected, isTrue);
    });

    test('a sibling still connecting is torn down, and the switch waits for it to unwind', () async {
      final ble = bleTrainer()..isStarting.value = true;
      final wifi = wifiTrainer();
      core.connection.devices.addAll([ble, wifi]);

      await core.connection.connectDevice(wifi);

      expect(events, ['ble.disconnect', 'wifi.start']);
      expect(ble.isStarting.value, isFalse);
      expect(wifi.isConnected, isTrue);
    });

    test('switching back is symmetric', () async {
      final ble = bleTrainer();
      final wifi = wifiTrainer()..isConnected = true;
      core.connection.devices.addAll([ble, wifi]);

      await core.connection.connectDevice(ble);

      expect(events, ['wifi.disconnect', 'ble.start']);
    });

    test('a connect on a trainer whose twin is idle touches nothing else', () async {
      final ble = bleTrainer();
      final wifi = wifiTrainer();
      core.connection.devices.addAll([ble, wifi]);

      await core.connection.connectDevice(wifi);

      expect(events, ['wifi.start']);
      expect(ble.disconnectCalls, 0);
    });

    test('a different trainer is left connected', () async {
      final ble = bleTrainer()..isConnected = true;
      final other = wifiTrainer(name: 'TACX NEO 9999', tag: 'other');
      await core.settings.setAutoConnect('TACX NEO 9999', true);
      core.connection.devices.addAll([ble, other]);

      await core.connection.connectDevice(other);

      expect(events, ['other.start']);
      expect(ble.isConnected, isTrue);
    });
  });
}
