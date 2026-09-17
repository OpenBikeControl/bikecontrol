import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/services/bonjour/bonjour_service_advertiser.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_fixes.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/rouvy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:nsd_platform_interface/nsd_platform_interface.dart';
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/utils/resilient_tcp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration/harness/fake_nsd_platform.dart';
import '../../integration/harness/test_env.dart';
import 'fake_bonjour_api.dart';
import 'recording_advertiser.dart';

/// Throws once from register(), then behaves like the real fake — models a
/// transient nsd registration failure so [switchObpBackend]'s rollback path
/// can be exercised without touching the real nsd plugin.
class _ThrowOnceRegisterNsdPlatform extends FakeNsdPlatform {
  bool _thrown = false;

  @override
  Future<Registration> register(Service service) async {
    if (!_thrown) {
      _thrown = true;
      throw Exception('simulated nsd register failure');
    }
    return super.register(service);
  }
}

Future<void> main() async {
  final env = await IntegrationEnv.setUp();
  late RecordingAdvertiser instanceAdvertiser;

  setUp(() async {
    env.mdns.reset();
    NsdPlatformInterface.instance = env.mdns;
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();
    instanceAdvertiser = RecordingAdvertiser();
    ServiceAdvertiser.instance = instanceAdvertiser;
  });

  tearDown(() async {
    core.obpMdnsEmulator.isConnected.value = false;
    await core.obpMdnsEmulator.stopServer();
    core.rouvyMdnsEmulator.isConnected.value = false;
    await core.rouvyMdnsEmulator.clickEmulator.stop();
    // Anything the emulators lost track of must not bleed into the next test.
    for (final leaked in ResilientTcpServer.activeServers
        .where((s) => s.label == 'OpenBikeControl' || s.label == 'Click')
        .toList()) {
      await leaked.stop();
    }
    ServiceAdvertiser.instance = NsdServiceAdvertiser();
    NsdPlatformInterface.instance = env.mdns;
    core.obpMdnsEmulator.debugBonjourFactory = null;
    core.obpMdnsEmulator.debugIsWindows = null;
  });

  group('switchObpBackend', () {
    test('switching to osResponder re-registers via the nsd fake and persists the pref', () async {
      final ok = await switchObpBackend(ObpMdnsBackend.osResponder);

      expect(ok, isTrue);
      expect(core.settings.getObpMdnsBackend(), ObpMdnsBackend.osResponder);
      expect(env.mdns.registrations, hasLength(1), reason: 'the OS responder path goes through the nsd plugin');
      expect(core.obpMdnsEmulator.activeBackend, ObpMdnsBackend.osResponder);
    });

    test('a failing start restores the pref and returns false', () async {
      await core.obpMdnsEmulator.startServer(); // running on platformDefault
      NsdPlatformInterface.instance = _ThrowOnceRegisterNsdPlatform();

      final ok = await switchObpBackend(ObpMdnsBackend.osResponder);

      expect(ok, isFalse);
      expect(core.settings.getObpMdnsBackend(), ObpMdnsBackend.platformDefault);
    });

    test('a failing start leaves the emulator started again on the old backend', () async {
      await core.obpMdnsEmulator.startServer(); // running on platformDefault
      NsdPlatformInterface.instance = _ThrowOnceRegisterNsdPlatform();

      await switchObpBackend(ObpMdnsBackend.osResponder);

      expect(core.obpMdnsEmulator.isStarted.value, isTrue);
      expect(core.obpMdnsEmulator.activeBackend, ObpMdnsBackend.platformDefault);
    });

    // "Register through Bonjour" on a Windows box without Bonjour: the start
    // itself succeeds (resolveAdvertiser degrades to platformDefault), so the
    // old "did startServer throw?" test was blind to it — the pref was left
    // at osResponder, the page re-ran with the identical result, and row 6
    // (keyed on activeBackend) offered no way back.
    test('a degraded switch (Windows without Bonjour) is a failed switch: pref restored, returns false', () async {
      await core.obpMdnsEmulator.startServer(); // running on platformDefault
      core.obpMdnsEmulator.debugIsWindows = () => true;
      core.obpMdnsEmulator.debugBonjourFactory = () => BonjourServiceAdvertiser(api: FakeBonjourApi(isAvailable: false));

      final ok = await switchObpBackend(ObpMdnsBackend.osResponder);

      expect(ok, isFalse);
      expect(core.settings.getObpMdnsBackend(), ObpMdnsBackend.platformDefault, reason: 'the previous pref is restored');
      expect(core.obpMdnsEmulator.isStarted.value, isTrue, reason: 'restarted on the restored pref');
      expect(core.obpMdnsEmulator.activeBackend, ObpMdnsBackend.platformDefault);
      expect(env.mdns.registrations, isEmpty, reason: 'nsd is never the Windows OS backend');
      expect(instanceAdvertiser.services, hasLength(1));
    });

    test('refuses while the trainer app is connected: no restart, pref untouched', () async {
      await core.obpMdnsEmulator.startServer(); // running on platformDefault
      core.obpMdnsEmulator.isConnected.value = true;
      final registeredBefore = instanceAdvertiser.services.toList();

      final ok = await switchObpBackend(ObpMdnsBackend.osResponder);

      expect(ok, isFalse);
      expect(core.settings.getObpMdnsBackend(), ObpMdnsBackend.platformDefault);
      expect(core.obpMdnsEmulator.isConnected.value, isTrue, reason: 'the live connection was not dropped');
      expect(core.obpMdnsEmulator.activeBackend, ObpMdnsBackend.platformDefault);
      expect(instanceAdvertiser.services, equals(registeredBefore), reason: 'the running registration was not touched');
      expect(env.mdns.registrations, isEmpty);
    });
  });

  group('restartMethod', () {
    List<ResilientTcpServer> obcServers() =>
        ResilientTcpServer.activeServers.where((s) => s.label == 'OpenBikeControl').toList();

    // The one-tap fix the methodListening row offers once the server sits on
    // a port other than 36867. Real sockets, so the body runs under runAsync.
    testWidgets('after two starts raced each other, the restart lands back on 36867 with one server', (tester) async {
      await tester.pumpWidget(const SizedBox(key: ValueKey('host')));
      final context = tester.element(find.byKey(const ValueKey('host')));

      await tester.runAsync(() async {
        // The un-awaited toggle / trainer-app-switch pattern: a second start
        // arrives while the first is still coming up. This used to leave the
        // first server leaked on 36867 and the emulator on 36868.
        final first = core.obpMdnsEmulator.startServer();
        await core.obpMdnsEmulator.startServer();
        await first;

        final ok = await runNetworkFix(context, NetworkFixId.restartMethod);

        expect(ok, isTrue);
        expect(core.obpMdnsEmulator.isStarted.value, isTrue);
        expect(obcServers(), hasLength(1), reason: 'the leaked server is superseded, not left behind');
        expect(obcServers().single.boundPort, 36867, reason: 'back on the preferred port');
        expect(instanceAdvertiser.services.map((s) => s.port), [36867], reason: 'exactly one advertisement');
      });
    });

    testWidgets('a stop arriving while a start is still coming up wins: nothing is left running', (tester) async {
      await tester.pumpWidget(const SizedBox(key: ValueKey('host')));

      await tester.runAsync(() async {
        final starting = core.obpMdnsEmulator.startServer();
        final stopping = core.obpMdnsEmulator.stopServer();
        await Future.wait([starting, stopping]);

        expect(core.obpMdnsEmulator.isStarted.value, isFalse);
        expect(obcServers(), isEmpty, reason: 'the start\'s server was torn down by the queued stop');
        expect(instanceAdvertiser.services, isEmpty);
      });
    });

    testWidgets('an un-awaited start that fails still reports its error instead of vanishing', (tester) async {
      await tester.pumpWidget(const SizedBox(key: ValueKey('host')));

      await tester.runAsync(() async {
        // A foreign holder on every port the server may walk to makes the
        // bind fail — the toggle callers fire startServer() without awaiting.
        final blockers = <ServerSocket>[];
        for (var port = 36867; port <= 36871; port++) {
          blockers.add(await ServerSocket.bind(InternetAddress.anyIPv6, port, v6Only: false));
        }
        final uncaught = <Object>[];
        try {
          await runZonedGuarded(() async {
            core.obpMdnsEmulator.startServer();
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }, (error, stack) => uncaught.add(error));
        } finally {
          for (final b in blockers) {
            await b.close();
          }
        }

        expect(uncaught, [isA<SocketException>()], reason: 'the dropped future\'s error reached the zone');
        expect(core.obpMdnsEmulator.isStarted.value, isFalse);
      });
    });

    testWidgets('a restart right after an un-awaited stop lands back on 36867', (tester) async {
      await tester.pumpWidget(const SizedBox(key: ValueKey('host')));
      final context = tester.element(find.byKey(const ValueKey('host')));

      await tester.runAsync(() async {
        await core.obpMdnsEmulator.startServer();
        // stopServer() fired without awaiting (the trainer-app switch), the
        // restart follows while the socket is still releasing.
        final stopping = core.obpMdnsEmulator.stopServer();

        final ok = await runNetworkFix(context, NetworkFixId.restartMethod);
        await stopping;

        expect(ok, isTrue);
        expect(core.obpMdnsEmulator.isStarted.value, isTrue);
        expect(obcServers(), hasLength(1));
        expect(obcServers().single.boundPort, 36867);
        expect(instanceAdvertiser.services.map((s) => s.port), [36867]);
      });
    });
  });

  group('restartMethod examines the selected trainer app\'s own method', () {
    List<ResilientTcpServer> serversLabelled(String label) =>
        ResilientTcpServer.activeServers.where((s) => s.label == label).toList();

    // Rouvy rides on the Click server (prop's ClickEmulator behind
    // core.rouvyMdnsEmulator); it never runs OpenBikeControl. Restarting OBC
    // for a Rouvy rider started a server Rouvy never looks at and left the
    // one it does look at alone.
    testWidgets('with Rouvy selected the Click server is restarted, OpenBikeControl is left alone', (tester) async {
      await tester.pumpWidget(const SizedBox(key: ValueKey('host')));
      final context = tester.element(find.byKey(const ValueKey('host')));

      await tester.runAsync(() async {
        core.settings.setTrainerApp(Rouvy());
        await core.rouvyMdnsEmulator.startServer();
        final before = serversLabelled('Click').single;

        final ok = await runNetworkFix(context, NetworkFixId.restartMethod);

        expect(ok, isTrue);
        expect(core.rouvyMdnsEmulator.isStarted.value, isTrue);
        expect(serversLabelled('Click'), hasLength(1), reason: 'restarted, not duplicated');
        expect(serversLabelled('Click').single, isNot(same(before)), reason: 'a fresh server, not the old one');
        expect(serversLabelled('Click').single.boundPort, 36860);
        expect(core.obpMdnsEmulator.isStarted.value, isFalse, reason: 'OpenBikeControl is not Rouvy\'s method');
        expect(serversLabelled('OpenBikeControl'), isEmpty);
        expect(instanceAdvertiser.services.map((s) => s.name), ['BikeControl']);
      });
    });

    testWidgets('with Rouvy connected the restart is refused even though OpenBikeControl is idle', (tester) async {
      await tester.pumpWidget(const SizedBox(key: ValueKey('host')));
      final context = tester.element(find.byKey(const ValueKey('host')));

      await tester.runAsync(() async {
        core.settings.setTrainerApp(Rouvy());
        core.rouvyMdnsEmulator.isConnected.value = true;

        final ok = await runNetworkFix(context, NetworkFixId.restartMethod);

        expect(ok, isFalse);
        expect(core.rouvyMdnsEmulator.isConnected.value, isTrue, reason: 'the live connection was left alone');
        expect(serversLabelled('Click'), isEmpty, reason: 'nothing was restarted');
      });
    });
  });
}
