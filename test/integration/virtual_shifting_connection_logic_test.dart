import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart' show ftmsEmulator;
import 'package:bike_control/bluetooth/emulation/emulated_peripherals.dart';
import 'package:bike_control/services/sensors/fake_sensor_source.dart';
import 'package:bike_control/services/sensors/sensor_quantity.dart';

import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/emulators/definitions/sensor_definition.dart';
import 'package:prop/emulators/definitions/zwift_emulator_definition.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:prop/testing.dart' show FakeDirconTrainer;
import 'package:prop/utils/constants.dart' show BikeControlMdnsMarkers;
import 'package:prop/utils/self_advertisement_registry.dart';
import 'package:universal_ble/universal_ble.dart';

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

  group('auto-connect intent', () {
    // The takeover-consent dialog is gone: tapping Connect once is the whole
    // consent story, so intent alone must be enough. Without intent the
    // trainer is still only discovered, never started on its own.
    test('a discovered trainer with no intent stays disconnected', () async {
      final trainer = buildFtmsTrainer();
      env.ble.addPeripheral(trainer);

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty,
        description: 'trainer in device list',
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(core.connection.proxyDevices.single.isConnected, isFalse);
      expect(env.mdns.registrations, isEmpty);
    });

    test('with intent the trainer connects and the WiFi bridge advertises', () async {
      final trainer = buildFtmsTrainer();
      env.ble.addPeripheral(trainer);
      await core.settings.setAutoConnect('KICKR CORE 1234', true);

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

  group('unexpected upstream drop tears the bridge down', () {
    // Support bd2f3b55: a KICKR reachable over both BLE and WiFi had its
    // DirCon socket drop while the bridge was live. The device vanished from
    // the list, but its FitnessBikeDefinition stayed attached to the shared
    // emulator — so every MyWhoosh control-point write still hit the dead
    // socket ("Bad state: DirconClient is not connected", once per write),
    // and "KICKR CORE - BikeControl" kept advertising with no trainer behind
    // it.
    Future<void> expectBridgeFullyTornDown(ProxyDevice device) async {
      await IntegrationEnv.waitFor(
        () => !core.connection.devices.contains(device),
        description: 'dropped trainer removed from the list',
      );
      expect(device.fitnessBike, isNull);
      expect(ftmsEmulator.composite.children.whereType<FitnessBikeDefinition>(), isEmpty);
      await IntegrationEnv.waitFor(() => !ftmsEmulator.isStarted.value, description: 'shared emulator stopped');
      await IntegrationEnv.waitFor(() => env.mdns.registrations.isEmpty, description: 'bridge no longer advertised');
    }

    test('WiFi upstream: a DirCon socket drop detaches the definition and stops advertising', () async {
      final trainer = FakeDirconTrainer(name: 'KICKR CORE 1A2B');
      await trainer.start();
      addTearDown(trainer.stop);
      await core.settings.setAutoConnect('KICKR CORE 1A2B', true);

      await core.connection.performScanning();
      env.mdns.addForeignService(trainer.advertisement);
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isConnected,
        description: 'WiFi trainer auto-connected',
      );
      final device = core.connection.proxyDevices.single;
      expect(device.isWifiUpstream, isTrue);
      await IntegrationEnv.waitFor(() => device.isStartedListenable.value, description: 'bridge started');
      expect(ftmsEmulator.composite.children, contains(device.fitnessBike));
      // Let the connect-time handshake (subscriptions + FTMS feature read)
      // finish so the drop isn't racing in-flight requests — the fake trainer
      // writes its replies unguarded and a reply into a destroyed socket would
      // fail the test for a reason unrelated to the teardown under test.
      await IntegrationEnv.waitFor(
        () => trainer.definition.enabledNotifications.length >= 3 && device.fitnessBike?.trainerFeature.value != null,
        description: 'connect-time handshake settled',
      );

      // Take the advertisement away first so rediscovery can't re-add the
      // trainer and mask whether the drop alone cleaned up.
      env.mdns.removeForeignService(trainer.advertisement);
      await trainer.dropClient();

      await expectBridgeFullyTornDown(device);
    });

    test('BLE upstream: a peripheral-side drop detaches the definition and stops advertising', () async {
      final trainer = buildFtmsTrainer();
      env.ble.addPeripheral(trainer);
      await core.settings.setAutoConnect('KICKR CORE 1234', true);

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isConnected,
        description: 'BLE trainer auto-connected',
      );
      final device = core.connection.proxyDevices.single;
      await IntegrationEnv.waitFor(() => device.isStartedListenable.value, description: 'bridge started');
      expect(ftmsEmulator.composite.children, contains(device.fitnessBike));

      // Removing the peripheral drops its connection and keeps it out of the
      // next scan, so the assertions see the drop alone.
      env.ble.removePeripheral(trainer.deviceId);

      await expectBridgeFullyTornDown(device);
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
        // A different install, so its mac-address differs from ours; the
        // constant manufacturer-data is what marks it as a BikeControl.
        txt: {
          'mac-address': Uint8List.fromList('95E042B7-1337-039E-C35F-AABBCCDDEEFF'.codeUnits),
          'manufacturer-data': Uint8List.fromList(BikeControlMdnsMarkers.manufacturerData.codeUnits),
        },
      );
      env.mdns.addForeignService(ad);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(core.connection.proxyDevices, isEmpty);
    });
  });

  group('trainer app switch reconciles the ride-along controller', () {
    test('switching Zwift → Rouvy takes the ride-along controller back off the bridge', () async {
      core.settings.setTrainerApp(Zwift());
      final trainer = buildFtmsTrainer();
      env.ble.addPeripheral(trainer);
      await core.settings.setAutoConnect('KICKR CORE 1234', true);

      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isConnected,
        description: 'trainer auto-connected under Zwift',
      );
      final device = core.connection.proxyDevices.single;
      await IntegrationEnv.waitFor(() => device.isStartedListenable.value, description: 'bridge started');

      // Under Zwift the bridge carries a ride-along controller definition.
      expect(
        ftmsEmulator.composite.children.whereType<ZwiftEmulatorDefinition>(),
        isNotEmpty,
        reason: 'the ride-along controller is attached while the app is Zwift',
      );

      // Switching to Rouvy must take it back off, so the bridge advertises only
      // its own trainer services again.
      core.settings.setTrainerApp(Rouvy());
      await IntegrationEnv.waitFor(
        () => ftmsEmulator.composite.children.whereType<ZwiftEmulatorDefinition>().isEmpty,
        description: 'ride-along controller detached on switch to Rouvy',
      );
    });
  });

  // Selects a scripted heart-rate source with the real SensorHub, the same
  // way the rider's pick reaches it regardless of transport — SensorSinkSync
  // / SensorSinkController / ftmsEmulator (what W1 and W4 below exercise)
  // only ever see `core.sensors.selectionFor`/`resolved`, never the BLE
  // strap that produced it. Using FakeSensorSource (a `lib/`, not `test/`,
  // helper — see its doc comment) keeps these tests about the sink/bridge
  // wiring instead of the BLE auto-connect queue's timing, which
  // `sensor_source_registration_test.dart` already covers on its own.
  FakeSensorSource registerAndSelectHeartRateSource(String id) {
    final source = FakeSensorSource(id: id, displayName: id, provides: {SensorQuantity.heartRate});
    core.sensors.register(source);
    core.sensors.select(SensorQuantity.heartRate, id);
    addTearDown(() => core.sensors.select(SensorQuantity.heartRate, null));
    return source;
  }

  // Same as [registerAndSelectHeartRateSource], generalised to any quantity —
  // used by the B2 cadence/power seeding tests below.
  FakeSensorSource registerAndSelectSource(SensorQuantity quantity, String id) {
    final source = FakeSensorSource(id: id, displayName: id, provides: {quantity});
    core.sensors.register(source);
    core.sensors.select(quantity, id);
    addTearDown(() => core.sensors.select(quantity, null));
    return source;
  }

  group('a selected sensor source must not keep a disconnected trainer advertised', () {
    // W1 (fix wave 2): an earlier fix made the sensor sink three-state so "no
    // source selected" genuinely detaches everywhere (SensorSinkMode.none).
    // But with a source SELECTED, SensorSinkController attaches
    // SensorDefinition to the shared ftmsEmulator's composite alongside the
    // trainer's FitnessBikeDefinition. ProxyDevice._stopFtmsEmulatorIfUnused
    // used to stop the shared emulator only when its composite was
    // completely empty — so on trainer disconnect, once the FBD (and any
    // ride-along controller) detached, a SensorDefinition left riding along
    // made `children.isEmpty` false forever, and the shared emulator (and its
    // advertisement) outlived the trainer for the rest of the session.
    test(
      'trainer disconnect stops the shared emulator even while a heart-rate source is attached',
      () async {
        final trainer = buildFtmsTrainer(deviceId: 'fake-kickr-w1', name: 'KICKR CORE W1');
        env.ble.addPeripheral(trainer);
        await core.settings.setAutoConnect('KICKR CORE W1', true);

        await core.connection.performScanning();
        await IntegrationEnv.waitFor(
          () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.isConnected,
          description: 'trainer auto-connected',
        );
        final device = core.connection.proxyDevices.single;
        await IntegrationEnv.waitFor(() => device.isStartedListenable.value, description: 'bridge started');

        // The rider selects a heart rate source while the trainer is
        // bridged — this is the case the earlier "no source selected" fix
        // does NOT cover.
        registerAndSelectHeartRateSource('hr-w1');

        // The sink actually attaches SensorDefinition to the shared bridge
        // composite now that both a trainer and a source are present.
        await IntegrationEnv.waitFor(
          () => ftmsEmulator.composite.children.whereType<SensorDefinition>().isNotEmpty,
          description: 'sensor definition attached to the bridge',
        );

        // Disconnect the TRAINER only — the heart rate source stays selected
        // and attached to whatever the sink lands on next.
        await core.connection.disconnect(device, persistForget: false, forget: false, keepInList: true);

        // The regression: a SensorDefinition riding along must not, on its
        // own, keep the shared emulator looking "in use" once the trainer
        // that actually owned it is gone.
        await IntegrationEnv.waitFor(() => !ftmsEmulator.isStarted.value, description: 'shared emulator stopped');
        expect(env.mdns.registrations, isEmpty);
      },
    );
  });

  group('a trainer connecting mid-ride picks up the already-selected heart rate', () {
    // W4 (fix wave 2): SensorBridgeBinding only pushes the resolved heart
    // rate once at app start and thereafter on change — connecting a trainer
    // mid-ride, after a steady external heart rate is already flowing, left
    // the freshly-built FitnessBikeDefinition with no heart rate at all until
    // the rider's reading happened to change again.
    //
    // Fix round 2: a later wave gated SensorHub._publish on
    // core.sensors.isProEnabled (wired to IAPManager.instance.
    // isProEnabledForCurrentDevice by core.connection.initialize(), called for
    // this whole file above) — correct behaviour, a rider without Pro must
    // not get an external heart rate. This test predates that gate and drives
    // the real Connection/IAPManager singleton, so without explicitly opting
    // in to Pro here the hub correctly refuses to publish and the wait below
    // times out forever, not because anything is broken but because this
    // test was never asking for what it needed. Mirrors the exact mechanism
    // `sensor_source_registration_test.dart`'s "a lapsed subscription..."
    // wiring test already established for the same singleton.
    test(
      'a freshly attached trainer definition is seeded with the already-resolved external heart rate',
      () async {
        IAPManager.instance.setProForTesting(enabled: true);
        addTearDown(() => IAPManager.instance.setProForTesting(enabled: false));

        // The rider already has an external heart rate source selected and
        // reporting BEFORE any trainer connects.
        final source = registerAndSelectHeartRateSource('hr-w4');
        source.emit(SensorQuantity.heartRate, 128);
        await IntegrationEnv.waitFor(
          () => core.sensors.resolved(SensorQuantity.heartRate).value == 128,
          description: 'heart rate resolved before any trainer exists',
        );

        // A trainer connects mid-ride — a new sink appearing.
        final trainer = buildFtmsTrainer(deviceId: 'fake-kickr-w4', name: 'KICKR CORE W4');
        env.ble.addPeripheral(trainer);
        await core.settings.setAutoConnect('KICKR CORE W4', true);
        await core.connection.performScanning();
        await IntegrationEnv.waitFor(
          () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.fitnessBike != null,
          description: 'trainer bridge attaches its FitnessBikeDefinition',
        );

        final device = core.connection.proxyDevices.single;
        expect(
          device.fitnessBike!.heartRateBpm.value,
          128,
          reason:
              'a newly attached trainer must be seeded with the already-resolved external heart rate, '
              'not sit silent until the rider\'s heart rate happens to change again',
        );
      },
    );

    // The inverse of the test above, and the one that actually proves the
    // Pro gate does something rather than just not-breaking anything: with
    // Pro explicitly OFF (a lapsed subscriber, or a rider who never
    // subscribed), the exact same mid-ride scenario must NOT seed the
    // trainer's FitnessBikeDefinition with the external reading. Nothing
    // before this guarded that — every other test either enables Pro or
    // never selects an external source at all.
    test(
      'a lapsed subscriber does not get the external heart rate seeded into a freshly attached trainer',
      () async {
        IAPManager.instance.setProForTesting(enabled: false);
        addTearDown(() => IAPManager.instance.setProForTesting(enabled: false));

        final source = registerAndSelectHeartRateSource('hr-w4-lapsed');
        source.emit(SensorQuantity.heartRate, 128);

        final trainer = buildFtmsTrainer(deviceId: 'fake-kickr-w4-lapsed', name: 'KICKR CORE W4 LAPSED');
        env.ble.addPeripheral(trainer);
        await core.settings.setAutoConnect('KICKR CORE W4 LAPSED', true);
        await core.connection.performScanning();
        // Waiting on the trainer's own bridge attachment — a milestone that
        // does not depend on the Pro gate — is what lets this test end
        // deterministically instead of waiting on the very thing it expects
        // to never happen.
        await IntegrationEnv.waitFor(
          () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.fitnessBike != null,
          description: 'trainer bridge attaches its FitnessBikeDefinition',
        );

        expect(
          core.sensors.resolved(SensorQuantity.heartRate).value,
          isNull,
          reason: 'a lapsed subscriber must not have an external heart rate resolve at all',
        );
        final device = core.connection.proxyDevices.single;
        expect(
          device.fitnessBike!.heartRateBpm.value,
          isNull,
          reason:
              'the gate must keep the external reading off the bridge entirely (heartRateBpm defaults null with '
              'no relayed trainer sensor here), not merely delay it or land on some other value',
        );
      },
    );
  });

  group('a trainer connecting mid-ride picks up already-selected cadence/power (B2)', () {
    // B2 (fix wave 2): _seedFitnessBikeDefinition seeded heart rate into every
    // fresh FitnessBikeDefinition (the W4 group above) but not cadence/power —
    // so exactly the same "connects mid-ride, after a steady external reading
    // is already flowing" gap that W4 fixed for heart rate was still open for
    // cadence and power. Mirrors the W4 test shape.
    test(
      'a freshly attached trainer definition is seeded with the already-resolved external cadence and power',
      () async {
        IAPManager.instance.setProForTesting(enabled: true);
        addTearDown(() => IAPManager.instance.setProForTesting(enabled: false));

        // The rider already has external cadence AND power sources selected
        // and reporting BEFORE any trainer connects.
        final cadenceSource = registerAndSelectSource(SensorQuantity.cadence, 'cad-b2');
        cadenceSource.emit(SensorQuantity.cadence, 95);
        final powerSource = registerAndSelectSource(SensorQuantity.power, 'pwr-b2');
        powerSource.emit(SensorQuantity.power, 220);
        await IntegrationEnv.waitFor(
          () =>
              core.sensors.resolved(SensorQuantity.cadence).value == 95 &&
              core.sensors.resolved(SensorQuantity.power).value == 220,
          description: 'cadence and power resolved before any trainer exists',
        );

        // A trainer connects mid-ride — a new sink appearing.
        final trainer = buildFtmsTrainer(deviceId: 'fake-kickr-b2', name: 'KICKR CORE B2');
        env.ble.addPeripheral(trainer);
        await core.settings.setAutoConnect('KICKR CORE B2', true);
        await core.connection.performScanning();
        await IntegrationEnv.waitFor(
          () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.fitnessBike != null,
          description: 'trainer bridge attaches its FitnessBikeDefinition',
        );

        final device = core.connection.proxyDevices.single;
        expect(
          device.fitnessBike!.cadenceRpm.value,
          95,
          reason:
              'a newly attached trainer must be seeded with the already-resolved external cadence, '
              'not sit unseeded until the next resolved-value change',
        );
        expect(
          device.fitnessBike!.powerW.value,
          220,
          reason: 'same gap, same fix, for power',
        );
      },
    );

    // THE INVARIANT: a rider who selects no external source must see
    // byte-identical behaviour. This is the test that would have caught the
    // ordering mistake the fix explicitly warns against — seeding
    // unconditionally (setExternalCadence(resolved.value) with no null
    // guard) would call setExternalCadence(null)/setExternalPower(null) on
    // EVERY connect for EVERY rider, latching cadenceRpm/powerW at 0 instead
    // of leaving them null until the trainer's own telemetry arrives (see
    // FitnessBikeDefinition.trainerReportsNoCadence) — breaking the
    // cadence-less-trainer virtual-shifting fallback for every rider, not
    // just ones with an external source selected.
    test(
      'a rider with no external cadence/power selected keeps a freshly attached trainer completely unseeded',
      () async {
        IAPManager.instance.setProForTesting(enabled: true);
        addTearDown(() => IAPManager.instance.setProForTesting(enabled: false));

        final trainer = buildFtmsTrainer(deviceId: 'fake-kickr-b2-none', name: 'KICKR CORE B2 NONE');
        env.ble.addPeripheral(trainer);
        await core.settings.setAutoConnect('KICKR CORE B2 NONE', true);
        await core.connection.performScanning();
        await IntegrationEnv.waitFor(
          () => core.connection.proxyDevices.isNotEmpty && core.connection.proxyDevices.single.fitnessBike != null,
          description: 'trainer bridge attaches its FitnessBikeDefinition',
        );

        final device = core.connection.proxyDevices.single;
        expect(
          device.fitnessBike!.cadenceRpm.value,
          isNull,
          reason: 'nothing selected must mean nothing seeded — cadenceRpm stays null until the trainer '
              'itself reports something',
        );
        expect(
          device.fitnessBike!.powerW.value,
          isNull,
          reason: 'same for power',
        );
      },
    );

  });

  group('default virtual shifting mode on connect', () {
    Future<ProxyDevice> connectCog() async {
      env.ble.addPeripheral(buildZwiftCogTrainer());
      await core.settings.setAutoConnect('KICKR CORE 5775', true);
      await core.connection.performScanning();
      await IntegrationEnv.waitFor(
        () =>
            core.connection.proxyDevices.isNotEmpty &&
            core.connection.proxyDevices.single.isConnected &&
            core.connection.proxyDevices.single.fitnessBike != null,
        description: 'cog trainer connected',
      );
      return core.connection.proxyDevices.single;
    }

    test('an unconfigured grade-capable trainer comes up in Track Resistance', () async {
      // The reported KICKR CORE / Elite Direto footgun: Target Power ran their
      // virtual shifting like ERG, so shifting felt like nothing. A grade-native
      // trainer with no saved config must default to Track Resistance.
      final device = await connectCog();
      expect(device.fitnessBike!.virtualShiftingMode.value, VirtualShiftingMode.trackResistance);
    });

    test('a saved Target Power choice is honoured over the capability default', () async {
      await core.shiftingConfigs.upsert(
        ShiftingConfig.defaults(trainerKey: 'KICKR CORE 5775')
            .copyWith(mode: VirtualShiftingMode.targetPower, isActive: true),
      );
      final device = await connectCog();
      expect(device.fitnessBike!.virtualShiftingMode.value, VirtualShiftingMode.targetPower);
    });
  });
}
