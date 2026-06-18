import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/zwift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:prop/emulators/dircon_emulator.dart' show RetrofitMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../test/integration/harness/fake_ble_platform.dart';
import '../test/integration/harness/fake_peripherals.dart';
import 'integration_env.dart';

/// On-device (macOS) smoke tests for the parts the fast faked suite in
/// test/integration genuinely cannot prove: the OS-level Bonjour service
/// registration, the TXT-record encoding surviving the platform channel,
/// the advertised port accepting TCP, and actual mDNS packets leaving the
/// host. The upstream trainer is fake (BLE); everything network-side is real.
///
/// Run: `flutter test integration_test -d macos`
///
/// NOTES:
/// - The first run prompts for the macOS "Local Network" permission
///   (multicast receive); the packet test times out until it is granted in
///   System Settings → Privacy & Security → Local Network.
/// - All tests live in one file on purpose: launching the macOS app twice
///   back-to-back trips a flutter-tool flake ("log reader stopped
///   unexpectedly"), so one launch runs everything.
Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final env = await OnDeviceEnv.setUp();

  setUp(() async {
    env.ble.reset();
    core.actionHandler = StubActions()..supportedApp = Zwift();
  });

  tearDown(() async {
    await env.tearDownConnection();
  });

  /// A smart trainer reachable over (fake) BLE, registered and pre-consented
  /// for VS WiFi. Unique [name] per test — Bonjour caches linger.
  Future<ProxyDevice> bridgedTrainer(String deviceId, String name) async {
    final trainer = buildFtmsTrainer(deviceId: deviceId, name: name);
    env.ble.addPeripheral(trainer);
    final device = ProxyDevice(trainer.scanResult);
    core.connection.devices.add(device);
    device.setRetrofitMode(RetrofitMode.wifi);
    await core.settings.setRetrofitMode(device.trainerKey, RetrofitMode.wifi);
    await core.settings.setAutoConnect(device.trainerKey, true);
    await core.settings.setSmartTrainerConsent(device.trainerKey, true);
    return device;
  }

  group('Bonjour registration', () {
    testWidgets('the WiFi bridge registers a resolvable service that accepts TCP', (tester) async {
      final device = await bridgedTrainer('fake-kickr-resolve', 'KICKR RESOLVE 7351');
      await core.connection.connectDevice(device);
      await OnDeviceEnv.waitFor(() => device.isStartedListenable.value, description: 'bridge started');

      // Browse the REAL Bonjour daemon for our advertisement. mDNSResponder
      // may suffix the name on conflicts, so match by prefix.
      final expectedName = device.advertisementName;
      final discovery = await nsd.startDiscovery('_wahoo-fitness-tnp._tcp', autoResolve: true);
      addTearDown(() => nsd.stopDiscovery(discovery));

      nsd.Service? found;
      await OnDeviceEnv.waitFor(
        () {
          for (final service in discovery.services) {
            if ((service.name ?? '').startsWith(expectedName) && service.port != null) {
              found = service;
              return true;
            }
          }
          return false;
        },
        timeout: const Duration(seconds: 20),
        description: 'Bonjour resolution of "$expectedName"',
      );

      // The TXT record survived the platform-channel + OS round trip.
      final txt = found!.txt;
      expect(txt, isNotNull);
      String txtString(String key) => String.fromCharCodes(txt![key] ?? const []);
      expect(txtString('ble-service-uuids'), contains('1826'));
      expect(txtString('mac-address'), isNotEmpty);
      expect(txtString('serial-number'), hasLength(9));

      // The advertised port accepts a real TCP connection — and the bridge
      // reports the client as connected.
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, found!.port!)
          .timeout(const Duration(seconds: 5));
      await OnDeviceEnv.waitFor(
        () => device.isConnectedListenable.value,
        description: 'bridge to register the TCP client',
      );
      socket.destroy();
    });

    testWidgets('stopping the bridge withdraws the registration', (tester) async {
      final device = await bridgedTrainer('fake-kickr-withdraw', 'KICKR WITHDRAW 7352');
      await core.connection.connectDevice(device);
      await OnDeviceEnv.waitFor(() => device.isStartedListenable.value, description: 'bridge started');

      final expectedName = device.advertisementName;
      final discovery = await nsd.startDiscovery('_wahoo-fitness-tnp._tcp', autoResolve: true);
      addTearDown(() => nsd.stopDiscovery(discovery));

      nsd.Service? found;
      await OnDeviceEnv.waitFor(
        () {
          for (final service in discovery.services) {
            if ((service.name ?? '').startsWith(expectedName) && service.port != null) {
              found = service;
              return true;
            }
          }
          return false;
        },
        timeout: const Duration(seconds: 20),
        description: 'service advertised',
      );
      final advertisedPort = found!.port!;

      await core.connection.disconnect(device, persistForget: false, forget: false, keepInList: true);
      expect(device.isStartedListenable.value, isFalse);

      // Functional withdrawal proof. (The long-running in-process browser is
      // not reliable for removal events on macOS, so don't assert on it.)
      // 1. The advertised TCP port no longer accepts connections.
      await expectLater(
        Socket.connect(InternetAddress.loopbackIPv4, advertisedPort).timeout(const Duration(seconds: 3)),
        throwsA(anything),
      );
      // 2. A FRESH browse — answered from the daemon's cache, which the
      //    goodbye packets purge — no longer returns the service.
      final freshDiscovery = await nsd.startDiscovery('_wahoo-fitness-tnp._tcp', autoResolve: true);
      addTearDown(() => nsd.stopDiscovery(freshDiscovery));
      await Future<void>.delayed(const Duration(seconds: 6));
      expect(
        freshDiscovery.services.where((s) => (s.name ?? '').startsWith(expectedName)),
        isEmpty,
        reason: 'a withdrawn registration must not be served to new browsers',
      );
    });
  });

  group('UI → mDNS packets on the wire', () {
    /// Pump with real time until [condition] holds, keeping the UI alive.
    Future<void> pumpUntil(WidgetTester tester, bool Function() condition,
        {Duration timeout = const Duration(seconds: 20), required String description}) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (condition()) return;
        await tester.pump(const Duration(milliseconds: 100));
      }
      fail('Timed out waiting for $description');
    }

    testWidgets('tapping Virtual Shifting on the trainer page emits real mDNS packets', (tester) async {
      // Capture the wire BEFORE any interaction.
      final sniffer = await MdnsSniffer.start();
      addTearDown(sniffer.stop);

      // A smart trainer, reachable over (fake) BLE — no consent yet, the
      // dialog is part of what we drive.
      final fakeTrainer = buildFtmsTrainer(deviceId: 'fake-kickr-ui', name: 'KICKR UI 7353');
      env.ble.addPeripheral(fakeTrainer);
      final device = ProxyDevice(fakeTrainer.scanResult);
      core.connection.devices.add(device);

      // Open the real Smart Trainer details page.
      await tester.pumpWidget(
        ShadcnApp(
          // Pin to English — the host machine's locale drives the resolved
          // locale on-device, and the test taps English button labels.
          locale: const Locale('en'),
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en')],
          home: ProxyDeviceDetailsPage(device: device),
        ),
      );
      await tester.pump();
      expect(find.text('Virtual Shifting'), findsOneWidget);

      // Click "Virtual Shifting" → the takeover consent dialog appears.
      await tester.tap(find.text('Virtual Shifting'));
      await pumpUntil(tester, () => find.text('Continue').evaluate().isNotEmpty,
          description: 'consent dialog');

      // Confirm — this connects the (fake) BLE upstream and starts the real
      // WiFi bridge: real TCP server, real Bonjour registration.
      await tester.tap(find.text('Continue'));
      await pumpUntil(tester, () => device.isStartedListenable.value, description: 'bridge started');
      expect(device.isConnected, isTrue);

      // Nudge mDNSResponder with a real PTR question so an answer goes out on
      // the wire even between periodic announcements, and verify actual mDNS
      // packets for our service type AND our concrete instance were observed.
      sniffer.query('_wahoo-fitness-tnp._tcp.local');
      await pumpUntil(
        tester,
        () {
          if (!sniffer.sawAscii('_wahoo-fitness-tnp')) {
            sniffer.query('_wahoo-fitness-tnp._tcp.local');
            return false;
          }
          return true;
        },
        description: 'mDNS packets for _wahoo-fitness-tnp on the wire',
      );
      await pumpUntil(
        tester,
        () => sniffer.sawAscii(device.advertisementName),
        description: 'mDNS packet carrying the service instance name "${device.advertisementName}"',
      );

      // Picking "No connection" in the same card stops the bridge again.
      await tester.tap(find.text('No connection'));
      await pumpUntil(tester, () => !device.isStartedListenable.value, description: 'bridge stopped');
      expect(core.connection.devices, contains(device));
    });
  });
}
