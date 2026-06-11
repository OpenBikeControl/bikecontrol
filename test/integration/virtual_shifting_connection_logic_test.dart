import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:prop/utils/constants.dart' show BikeControlMdnsMarkers;
import 'package:prop/utils/self_advertisement_registry.dart';
import 'package:universal_ble/universal_ble.dart';

import 'harness/fake_ble_platform.dart';
import 'harness/fake_peripherals.dart';
import 'harness/test_env.dart';

/// Real [BaseActions] pipeline (keymap → pro guard → trainer routing) with no
/// platform key/touch output — the trainer branch returns before any of that
/// for shift actions.
class _RealChainActions extends BaseActions {
  _RealChainActions() : super(supportedModes: const []);

  @override
  void cleanup() {}
}

/// Connection-type logic and the WiFi-bridge lifecycle at the app level:
/// which retrofit mode a trainer gets, consent gating, what happens when the
/// user picks "No connection", and how mDNS-discovered WiFi trainers
/// enter/leave the device list. The network protocol itself is covered in the
/// prop package's own tests.
Future<void> main() async {
  final env = await IntegrationEnv.setUp();

  core.connection.initialize();

  setUp(() async {
    await env.resetState();
    core.actionHandler = StubActions()..supportedApp = Zwift();
  });

  tearDown(() async {
    await env.resetConnection();
  });

  ProxyDevice smartTrainerDevice() => ProxyDevice(buildFtmsTrainer().scanResult);

  group('default connection type (retrofit mode)', () {
    test('smart trainer defaults to Virtual Shifting over WiFi when nothing is configured', () {
      expect(smartTrainerDevice().defaultRetrofitMode, RetrofitMode.wifi);
    });

    test('an enabled Bluetooth trainer connection switches the default to VS Bluetooth', () async {
      core.settings.setTrainerApp(Zwift()); // gate: BLE emulator is app-specific
      await core.settings.setZwiftBleEmulatorEnabled(true);
      expect(smartTrainerDevice().defaultRetrofitMode, RetrofitMode.bluetooth);
    });

    test('Bluetooth wins over WiFi when both trainer connections are enabled', () async {
      core.settings.setTrainerApp(Zwift());
      await core.settings.setZwiftMdnsEmulatorEnabled(true);
      await core.settings.setZwiftBleEmulatorEnabled(true);
      expect(smartTrainerDevice().defaultRetrofitMode, RetrofitMode.bluetooth);
    });

    test('a power meter (no FTMS/FE-C) defaults to Proxy', () {
      final device = ProxyDevice(
        BleDevice(deviceId: 'pm', name: 'Power Meter', services: const ['00001818-0000-1000-8000-00805f9b34fb']),
      );
      expect(device.isSmartTrainer, isFalse);
      expect(device.defaultRetrofitMode, RetrofitMode.proxy);
    });
  });

  group('auto-connect consent gating', () {
    test('auto-connect intent alone is not enough for a smart trainer — consent required', () async {
      final trainer = buildFtmsTrainer();
      env.ble.addPeripheral(trainer);
      await core.settings.setAutoConnect('KICKR CORE 1234', true);

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty,
        description: 'trainer in device list',
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(core.connection.proxyDevices.single.isConnected, isFalse);
      expect(env.mdns.registrations, isEmpty);
    });

    test('with intent + consent the trainer connects and the WiFi bridge advertises', () async {
      final trainer = buildFtmsTrainer();
      env.ble.addPeripheral(trainer);
      await core.settings.setAutoConnect('KICKR CORE 1234', true);
      await core.settings.setSmartTrainerConsent('KICKR CORE 1234', true);

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isConnected,
        description: 'trainer auto-connected',
      );

      final device = core.connection.proxyDevices.single;
      expect(device.retrofitMode.value, RetrofitMode.wifi);
      await IntegrationEnv.waitFor(() => device.isStartedListenable.value, description: 'bridge started');

      // The bridge is discoverable for trainer apps (mDNS) and registered for
      // self-exclusion so our own scanner won't list it as a WiFi trainer.
      await IntegrationEnv.waitFor(() => env.mdns.registrations.isNotEmpty, description: 'mDNS advertisement');
      final ad = env.mdns.registrations.single.service;
      expect(ad.type, '_wahoo-fitness-tnp._tcp');
      expect(ad.name, contains('BikeControl'));
      expect(SelfAdvertisementRegistry.instance.containsName(ad.name!), isTrue);
    });
  });

  group('"No connection" in-place disconnect', () {
    Future<ProxyDevice> connectTrainer() async {
      final trainer = buildFtmsTrainer();
      env.ble.addPeripheral(trainer);
      await core.settings.setAutoConnect('KICKR CORE 1234', true);
      await core.settings.setSmartTrainerConsent('KICKR CORE 1234', true);
      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isConnected,
        description: 'trainer connected',
      );
      final device = core.connection.proxyDevices.single;
      await IntegrationEnv.waitFor(() => env.mdns.registrations.isNotEmpty, description: 'advertising');
      return device;
    }

    test('keepInList keeps the device reconnectable and fully stops advertising', () async {
      final device = await connectTrainer();

      await core.connection.disconnect(device, persistForget: false, forget: false, keepInList: true);

      // Still in the list (the details page holds this object)…
      expect(core.connection.devices, contains(device));
      expect(device.isConnected, isFalse);
      expect(device.isStartedListenable.value, isFalse);
      // …and nothing is left advertising on the network (the recent
      // "VS → No connection keeps advertising" bug).
      expect(env.mdns.registrations, isEmpty);
      expect(SelfAdvertisementRegistry.instance.containsName('KICKR CORE 1234 - BikeControl'), isFalse);
    });

    test('the same device object reconnects in place and advertises again', () async {
      final device = await connectTrainer();
      await core.connection.disconnect(device, persistForget: false, forget: false, keepInList: true);
      expect(env.mdns.registrations, isEmpty);

      await core.connection.connectDevice(device);

      await IntegrationEnv.waitFor(() => device.isConnected, description: 'reconnect');
      // The state mirrors were re-bound on reconnect — the emulator state must
      // reach the stable wrappers again (regression guard for the stuck
      // "connecting" card).
      await IntegrationEnv.waitFor(() => device.isStartedListenable.value, description: 'bridge restarted');
      await IntegrationEnv.waitFor(() => env.mdns.registrations.isNotEmpty, description: 're-advertised');
    });
  });

  group('controller → virtual shifting reaction chain', () {
    test('a Zwift Click shift press changes gear on the connected bridge (real action pipeline)', () async {
      // Real keymap/action pipeline instead of the stub.
      core.actionHandler = _RealChainActions()..supportedApp = Zwift();

      // Connected smart trainer with the bridge running…
      final trainer = buildFtmsTrainer();
      env.ble.addPeripheral(trainer);
      await core.settings.setAutoConnect('KICKR CORE 1234', true);
      await core.settings.setSmartTrainerConsent('KICKR CORE 1234', true);

      // …and a connected Zwift Click controller.
      final click = buildZwiftClick();
      autoRespondToZwiftHandshake(env.ble, click);
      env.ble.addPeripheral(click);

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () =>
            core.connection.proxyDevices.isNotEmpty &&
            core.connection.proxyDevices.single.isConnected &&
            core.connection.proxyDevices.single.fitnessBike != null &&
            core.connection.devices.whereType<ZwiftClick>().isNotEmpty &&
            click.writes.isNotEmpty,
        description: 'trainer bridge + controller connected',
      );

      final fitnessBike = core.connection.proxyDevices.single.fitnessBike!;
      final gearBefore = fitnessBike.currentGear.value;

      // Press and release the plus button on the Click.
      env.ble.notify(
        click.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftClickNotification(plusPressed: true, minusPressed: false),
      );
      env.ble.notify(
        click.deviceId,
        ZwiftConstants.ZWIFT_ASYNC_CHARACTERISTIC_UUID,
        zwiftClickNotification(plusPressed: false, minusPressed: false),
      );

      await IntegrationEnv.waitFor(
        () => fitnessBike.currentGear.value == gearBefore + 1,
        description: 'gear shift on the bridge',
      );
    });
  });

  group('WiFi trainer discovery through Connection', () {
    nsd.Service wifiTrainerAd(String name, {int port = 36866}) => nsd.Service(
          name: name,
          type: '_wahoo-fitness-tnp._tcp',
          port: port,
          addresses: [InternetAddress('192.168.1.55')],
          txt: {'ble-service-uuids': Uint8List.fromList('1826'.codeUnits)},
        );

    test('an mDNS-discovered DirCon trainer appears as a WiFi ProxyDevice', () async {
      await core.connection.performScanning();
      env.mdns.addForeignService(wifiTrainerAd('TACX NEO 9999'));

      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty,
        description: 'WiFi trainer in the device list',
      );
      final device = core.connection.proxyDevices.single;
      expect(device.scanResult.deviceId, 'dircon://TACX NEO 9999');
      expect(device.isWifiUpstream, isTrue);
      expect(device.isSmartTrainer, isTrue);
      // Discovered but never auto-connected without consent.
      expect(device.isConnected, isFalse);
    });

    test('a lost advertisement removes a disconnected trainer from the list', () async {
      await core.connection.performScanning();
      final ad = wifiTrainerAd('TACX NEO 9999');
      env.mdns.addForeignService(ad);
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty,
        description: 'WiFi trainer discovered',
      );

      env.mdns.removeForeignService(ad);
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isEmpty,
        description: 'WiFi trainer removed after mDNS lost',
      );
    });

    test('a connected trainer survives mDNS flapping — the socket is the source of truth', () async {
      await core.connection.performScanning();
      final ad = wifiTrainerAd('TACX NEO 9999');
      env.mdns.addForeignService(ad);
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty,
        description: 'WiFi trainer discovered',
      );
      final device = core.connection.proxyDevices.single;
      device.isConnected = true; // live TCP session in the real flow

      env.mdns.removeForeignService(ad);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(core.connection.proxyDevices, contains(device));
      device.isConnected = false;
    });

    test('our own bridge advertisement is never listed as a WiFi trainer (self-exclusion)', () async {
      // Simulate this device's own emulator advertising on the LAN.
      SelfAdvertisementRegistry.instance.add(name: 'KICKR CORE - BikeControl', port: 36868);
      await core.connection.performScanning();
      env.mdns.addForeignService(wifiTrainerAd('KICKR CORE - BikeControl', port: 36868));

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(core.connection.proxyDevices, isEmpty);
    });

    test('another BikeControl install on the LAN is excluded via the TXT fingerprint', () async {
      await core.connection.performScanning();
      final ad = nsd.Service(
        name: 'KICKR - BikeControl',
        type: '_wahoo-fitness-tnp._tcp',
        port: 36870,
        addresses: [InternetAddress('192.168.1.99')],
        txt: {'mac-address': Uint8List.fromList(BikeControlMdnsMarkers.macAddress.codeUnits)},
      );
      env.mdns.addForeignService(ad);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(core.connection.proxyDevices, isEmpty);
    });
  });
}
