import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart' show OpenBikeControlConstants;
import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/services/network_self_test/probes/active_probes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/network_address.dart';

DebugDiagnostics _diag({
  AddressPickReport addressReport = const AddressPickReport(chosen: null, candidates: []),
  List<TcpServerInfo> servers = const [],
}) => DebugDiagnostics(
  advertised: const [],
  backend: 'nsd',
  hostLabel: null,
  holdsMulticastLock: false,
  discovered: const [],
  discoveryRan: true,
  addressReport: addressReport,
  servers: servers,
  permissions: const PermissionsSnapshot(localNetwork: null),
);

/// A context with no-op seams; every field can be overridden per test.
NetworkProbeContext ctx({
  DebugDiagnostics? snapshot,
  bool trainerAppConnected = false,
  ObpMdnsBackend backend = ObpMdnsBackend.platformDefault,
  String? advertisedHostname,
  String platform = 'macos',
  Future<List<InternetAddress>> Function(String host)? resolve,
  Future<void> Function(String address, int port)? tcpProbe,
  DateTime Function()? now,
  String methodServerLabel = 'OpenBikeControl',
  int methodPreferredPort = OpenBikeControlConstants.TCP_PORT,
}) => NetworkProbeContext(
  snapshot: snapshot,
  snapshotError: null,
  emulatorStarted: true,
  trainerAppConnected: trainerAppConnected,
  trainerAppConnectedNow: () => trainerAppConnected,
  trainerAppName: null,
  backend: backend,
  advertisedHostname: advertisedHostname,
  platform: platform,
  methodServerLabel: methodServerLabel,
  methodPreferredPort: methodPreferredPort,
  resolve: resolve ?? (host) async => const [],
  tcpProbe: tcpProbe ?? (address, port) async {},
  runProcess: (executable, arguments) async => ProcessResult(0, 0, '', ''),
  queryLog: () => const [],
  sleep: (d) async {},
  now: now ?? () => DateTime(2026, 8, 21),
  onWatchProgress: (progress) {},
);

void main() {
  group('resolveOwnHostnameCheck', () {
    test('skipped: advertised hostname is unknown (iOS)', () async {
      final check = await resolveOwnHostnameCheck(ctx(advertisedHostname: null));
      expect(check.id, NetworkCheckId.resolveOwnHostname);
      expect(check.verdict, NetworkVerdict.skipped);
      expect(check.detail['reason'], 'hostname unknown');
    });

    test('pass: resolved address matches the advertised address, latency recorded', () async {
      var ticks = 0;
      final check = await resolveOwnHostnameCheck(
        ctx(
          advertisedHostname: 'bikecontrol.local',
          snapshot: _diag(
            addressReport: AddressPickReport(chosen: InternetAddress('192.168.1.5'), candidates: const []),
          ),
          resolve: (host) async => [InternetAddress('192.168.1.5')],
          now: () => DateTime(2026, 8, 21).add(Duration(milliseconds: (ticks++) * 10)),
        ),
      );
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.detail['address'], '192.168.1.5');
      expect(check.detail.containsKey('latencyMs'), isTrue);
    });

    test('warn: resolved to a different, non-empty set of addresses', () async {
      final check = await resolveOwnHostnameCheck(
        ctx(
          advertisedHostname: 'bikecontrol.local',
          snapshot: _diag(
            addressReport: AddressPickReport(chosen: InternetAddress('192.168.1.5'), candidates: const []),
          ),
          resolve: (host) async => [InternetAddress('10.0.0.9')],
        ),
      );
      expect(check.verdict, NetworkVerdict.warn);
      expect(check.detail['resolvedTo'], '10.0.0.9');
      expect(check.detail['expected'], '192.168.1.5');
    });

    test('fail: resolve times out, carries useOsResponderForObc under the platformDefault backend', () async {
      final check = await resolveOwnHostnameCheck(
        ctx(
          advertisedHostname: 'bikecontrol.local',
          backend: ObpMdnsBackend.platformDefault,
          resolve: (host) => Future<List<InternetAddress>>.error(TimeoutException('timed out')),
        ),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.fixes, contains(NetworkFixId.useOsResponderForObc));
      expect(check.fixes, contains(NetworkFixId.switchToLocal));
    });

    test('fail: resolve times out, does NOT carry useOsResponderForObc under the osResponder backend', () async {
      final check = await resolveOwnHostnameCheck(
        ctx(
          advertisedHostname: 'bikecontrol.local',
          backend: ObpMdnsBackend.osResponder,
          resolve: (host) => Future<List<InternetAddress>>.error(TimeoutException('timed out')),
        ),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.fixes, isNot(contains(NetworkFixId.useOsResponderForObc)));
      expect(check.fixes, contains(NetworkFixId.switchToLocal));
    });

    test('fail: resolve throws a SocketException', () async {
      final check = await resolveOwnHostnameCheck(
        ctx(
          advertisedHostname: 'bikecontrol.local',
          resolve: (host) => Future<List<InternetAddress>>.error(const SocketException('nope')),
        ),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.detail.containsKey('error'), isTrue);
    });

    test('fail: resolve returns an empty list', () async {
      final check = await resolveOwnHostnameCheck(
        ctx(advertisedHostname: 'bikecontrol.local', resolve: (host) async => const []),
      );
      expect(check.verdict, NetworkVerdict.fail);
    });
  });

  group('tcpSelfConnectCheck', () {
    test('skipped: the trainer app is already connected', () async {
      final check = await tcpSelfConnectCheck(ctx(trainerAppConnected: true));
      expect(check.id, NetworkCheckId.tcpSelfConnect);
      expect(check.verdict, NetworkVerdict.skipped);
      expect(check.detail['reason'], 'trainer app connected');
    });

    test('skipped: no listening OpenBikeControl server in the snapshot', () async {
      final check = await tcpSelfConnectCheck(ctx(snapshot: _diag(servers: const [])));
      expect(check.verdict, NetworkVerdict.skipped);
    });

    test('probes the Click server when the context\'s method is Click (Rouvy)', () async {
      // Only the Click server is up — a Rouvy rider never runs OpenBikeControl.
      int? probedPort;
      final check = await tcpSelfConnectCheck(
        ctx(
          snapshot: _diag(
            servers: const [TcpServerInfo(label: 'Click', port: 36860, listening: true, hasClient: false)],
          ),
          methodServerLabel: 'Click',
          methodPreferredPort: 36860,
          tcpProbe: (address, port) async => probedPort = port,
        ),
      );
      expect(check.verdict, NetworkVerdict.pass);
      expect(probedPort, 36860);
    });

    test('skipped: a Click server alone does not satisfy an OpenBikeControl context', () async {
      final check = await tcpSelfConnectCheck(
        ctx(
          snapshot: _diag(
            servers: const [TcpServerInfo(label: 'Click', port: 36860, listening: true, hasClient: false)],
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.skipped);
      expect(check.detail['reason'], 'method not listening');
    });

    test('pass: the probe succeeds, latency recorded', () async {
      final check = await tcpSelfConnectCheck(
        ctx(
          snapshot: _diag(
            addressReport: AddressPickReport(chosen: InternetAddress('192.168.1.5'), candidates: const []),
            servers: const [
              TcpServerInfo(label: 'OpenBikeControl', port: 36867, listening: true, hasClient: false),
            ],
          ),
          tcpProbe: (address, port) async {},
        ),
      );
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.detail.containsKey('latencyMs'), isTrue);
    });

    test('fail: the probe throws, openFirewallSettings only offered on windows', () async {
      final check = await tcpSelfConnectCheck(
        ctx(
          platform: 'macos',
          snapshot: _diag(
            addressReport: AddressPickReport(chosen: InternetAddress('192.168.1.5'), candidates: const []),
            servers: const [
              TcpServerInfo(label: 'OpenBikeControl', port: 36867, listening: true, hasClient: false),
            ],
          ),
          tcpProbe: (address, port) async => throw const SocketException('refused'),
        ),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.detail.containsKey('error'), isTrue);
      expect(check.fixes, contains(NetworkFixId.restartMethod));
      expect(check.fixes, isNot(contains(NetworkFixId.openFirewallSettings)));
    });

    test('fail: the probe throws on windows, offers openFirewallSettings', () async {
      final check = await tcpSelfConnectCheck(
        ctx(
          platform: 'windows',
          snapshot: _diag(
            addressReport: AddressPickReport(chosen: InternetAddress('192.168.1.5'), candidates: const []),
            servers: const [
              TcpServerInfo(label: 'OpenBikeControl', port: 36867, listening: true, hasClient: false),
            ],
          ),
          tcpProbe: (address, port) async => throw const SocketException('refused'),
        ),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.fixes, contains(NetworkFixId.restartMethod));
      expect(check.fixes, contains(NetworkFixId.openFirewallSettings));
    });
  });

  group('tcpSelfConnectCheck exception handling', () {
    DebugDiagnostics listening() => _diag(
      addressReport: const AddressPickReport(chosen: null, candidates: []),
      servers: const [TcpServerInfo(label: 'OpenBikeControl', port: 36867, listening: true, hasClient: false)],
    );

    test('fail: a TimeoutException from the probe', () async {
      final check = await tcpSelfConnectCheck(
        ctx(snapshot: listening(), tcpProbe: (address, port) async => throw TimeoutException('connect')),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.fixes, contains(NetworkFixId.restartMethod));
    });

    test('fail: a StateError from the probe (no active OpenBikeControl server)', () async {
      final check = await tcpSelfConnectCheck(
        ctx(snapshot: listening(), tcpProbe: (address, port) async => throw StateError('OpenBikeControl server not running')),
      );
      expect(check.verdict, NetworkVerdict.fail);
    });

    test('an unexpected exception type propagates', () async {
      await expectLater(
        tcpSelfConnectCheck(ctx(snapshot: listening(), tcpProbe: (address, port) async => throw ArgumentError('probe bug'))),
        throwsArgumentError,
      );
    });
  });
}
