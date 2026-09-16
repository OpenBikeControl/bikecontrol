import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/services/mdns_discovery_scan.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/services/network_self_test/probes/passive_probes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/advertised_service_registry.dart';
import 'package:prop/utils/network_address.dart';

DebugDiagnostics _diag({
  List<AdvertisedRecord> advertised = const [],
  String backend = 'nsd',
  String? hostLabel,
  bool holdsMulticastLock = false,
  List<DiscoveredMdnsService> discovered = const [],
  bool discoveryRan = true,
  AddressPickReport addressReport = const AddressPickReport(chosen: null, candidates: []),
  List<TcpServerInfo> servers = const [],
  PermissionsSnapshot permissions = const PermissionsSnapshot(localNetwork: null),
}) => DebugDiagnostics(
  advertised: advertised,
  backend: backend,
  hostLabel: hostLabel,
  holdsMulticastLock: holdsMulticastLock,
  discovered: discovered,
  discoveryRan: discoveryRan,
  addressReport: addressReport,
  servers: servers,
  permissions: permissions,
);

/// A context with no-op seams; every field can be overridden per test.
NetworkProbeContext ctx({
  DebugDiagnostics? snapshot,
  Object? snapshotError,
  bool emulatorStarted = true,
  bool trainerAppConnected = false,
  String? trainerAppName,
  ObpMdnsBackend backend = ObpMdnsBackend.platformDefault,
  String? advertisedHostname,
  String platform = 'macos',
}) => NetworkProbeContext(
  snapshot: snapshot,
  snapshotError: snapshotError,
  emulatorStarted: emulatorStarted,
  trainerAppConnected: trainerAppConnected,
  trainerAppConnectedNow: () => trainerAppConnected,
  trainerAppName: trainerAppName,
  backend: backend,
  advertisedHostname: advertisedHostname,
  platform: platform,
  resolve: (host) async => const [],
  tcpProbe: (address, port) async {},
  runProcess: (executable, arguments) async => ProcessResult(0, 0, '', ''),
  queryLog: () => const [],
  sleep: (d) async {},
  now: () => DateTime(2026, 8, 21),
  onWatchProgress: (progress) {},
);

void main() {
  group('methodListeningCheck', () {
    test('pass: OpenBikeControl server listens on the standard port', () {
      final check = methodListeningCheck(
        ctx(
          snapshot: _diag(
            servers: const [TcpServerInfo(label: 'OpenBikeControl', port: 36867, listening: true, hasClient: false)],
          ),
        ),
      );
      expect(check.id, NetworkCheckId.methodListening);
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.detail['port'], '36867');
      expect(check.fixes, isEmpty);
    });

    test('fail: emulator not started', () {
      final check = methodListeningCheck(ctx(emulatorStarted: false, snapshot: _diag()));
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.detail['reason'], 'not started');
      expect(check.fixes, [NetworkFixId.restartMethod]);
    });

    test('fail: started but no OpenBikeControl server is listening', () {
      final check = methodListeningCheck(ctx(snapshot: _diag(servers: const [])));
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.fixes, [NetworkFixId.restartMethod]);
    });

    test('warn: listening on a non-standard port', () {
      final check = methodListeningCheck(
        ctx(
          snapshot: _diag(
            servers: const [TcpServerInfo(label: 'OpenBikeControl', port: 12345, listening: true, hasClient: false)],
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.warn);
      expect(check.detail['port'], '12345');
    });

    test('unknown: snapshot is null because gather() threw (shared rule)', () {
      final error = Exception('boom');
      final check = methodListeningCheck(ctx(snapshot: null, snapshotError: error));
      expect(check.verdict, NetworkVerdict.unknown);
      expect(check.detail['error'], error.toString());
    });
  });

  group('advertisedAddressCheck', () {
    test('fail: no address was chosen', () {
      final check = advertisedAddressCheck(ctx(snapshot: _diag()));
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.fixes, [NetworkFixId.restartMethod]);
    });

    test('warn: chosen candidate is flagged virtual', () {
      final chosen = InternetAddress('10.8.0.5');
      final check = advertisedAddressCheck(
        ctx(
          snapshot: _diag(
            addressReport: AddressPickReport(
              chosen: chosen,
              candidates: const [
                AddressCandidate(interfaceName: 'docker0', address: '10.8.0.5', score: 10, isVirtual: true),
              ],
            ),
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.warn);
      expect(check.fixes, [NetworkFixId.restartMethod]);
    });

    test('warn: chosen candidate is a VPN tunnel by name, not the isVirtual flag', () {
      final chosen = InternetAddress('10.8.0.5');
      final check = advertisedAddressCheck(
        ctx(
          snapshot: _diag(
            addressReport: AddressPickReport(
              chosen: chosen,
              candidates: const [
                AddressCandidate(interfaceName: 'utun3', address: '10.8.0.5', score: 10, isVirtual: false),
              ],
            ),
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.warn);
      expect(check.fixes, [NetworkFixId.restartMethod]);
    });

    test('warn: at least two physical candidates on different subnets', () {
      final chosen = InternetAddress('192.168.1.5');
      final check = advertisedAddressCheck(
        ctx(
          snapshot: _diag(
            addressReport: AddressPickReport(
              chosen: chosen,
              candidates: const [
                AddressCandidate(interfaceName: 'en0', address: '192.168.1.5', score: 100, isVirtual: false),
                AddressCandidate(interfaceName: 'en1', address: '10.0.0.5', score: 90, isVirtual: false),
              ],
            ),
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.warn);
      expect(check.fixes, isEmpty);
      expect(check.detail['en0'], '192.168.1.5=100');
      expect(check.detail['en1'], '10.0.0.5=90');
    });

    test('pass: a single physical LAN candidate is chosen', () {
      final chosen = InternetAddress('192.168.1.5');
      final check = advertisedAddressCheck(
        ctx(
          snapshot: _diag(
            addressReport: AddressPickReport(
              chosen: chosen,
              candidates: const [
                AddressCandidate(interfaceName: 'en0', address: '192.168.1.5', score: 100, isVirtual: false),
              ],
            ),
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.detail['address'], '192.168.1.5');
      expect(check.fixes, isEmpty);
    });
  });

  // The home card's "your network looks unusual" step reads the same rule as
  // check 2, so the two can never disagree about which address is suspect.
  group('advertisedAddressWarning', () {
    test('null when no address was chosen — that is "no network", not this', () {
      expect(advertisedAddressWarning(const AddressPickReport(chosen: null, candidates: [])), isNull);
    });

    test('the address when the chosen candidate is flagged virtual', () {
      final report = AddressPickReport(
        chosen: InternetAddress('10.8.0.5'),
        candidates: const [AddressCandidate(interfaceName: 'docker0', address: '10.8.0.5', score: 10, isVirtual: true)],
      );
      expect(advertisedAddressWarning(report), '10.8.0.5');
    });

    test('the address when the chosen candidate is a VPN tunnel by name', () {
      final report = AddressPickReport(
        chosen: InternetAddress('10.5.0.2'),
        candidates: const [
          AddressCandidate(interfaceName: 'NordLynx', address: '10.5.0.2', score: 30, isVirtual: false),
        ],
      );
      expect(advertisedAddressWarning(report), '10.5.0.2');
    });

    test('the address when a second physical interface on another subnet could just as well be it', () {
      final report = AddressPickReport(
        chosen: InternetAddress('192.168.1.5'),
        candidates: const [
          AddressCandidate(interfaceName: 'en0', address: '192.168.1.5', score: 40, isVirtual: false),
          AddressCandidate(interfaceName: 'en1', address: '10.0.0.5', score: 30, isVirtual: false),
        ],
      );
      expect(advertisedAddressWarning(report), '192.168.1.5');
    });

    test('null for a single physical LAN candidate', () {
      final report = AddressPickReport(
        chosen: InternetAddress('192.168.1.5'),
        candidates: const [AddressCandidate(interfaceName: 'en0', address: '192.168.1.5', score: 40, isVirtual: false)],
      );
      expect(advertisedAddressWarning(report), isNull);
    });

    test('null when the LAN wins over an idle tunnel', () {
      // The picker demoted the tunnel; the rider is advertising the right
      // address and must not be told otherwise.
      final report = AddressPickReport(
        chosen: InternetAddress('192.168.1.5'),
        candidates: const [
          AddressCandidate(interfaceName: 'en0', address: '192.168.1.5', score: 40, isVirtual: false),
          AddressCandidate(interfaceName: 'utun3', address: '10.5.0.2', score: -70, isVirtual: true),
        ],
      );
      expect(advertisedAddressWarning(report), isNull);
    });
  });

  group('vpnCheck', () {
    test('pass: no tunnel candidates', () {
      final check = vpnCheck(
        ctx(
          snapshot: _diag(
            addressReport: const AddressPickReport(
              chosen: null,
              candidates: [
                AddressCandidate(interfaceName: 'en0', address: '192.168.1.5', score: 100, isVirtual: false),
              ],
            ),
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.fixes, isEmpty);
    });

    test('pass: tunnel candidates are all in the CGNAT mesh range', () {
      final check = vpnCheck(
        ctx(
          snapshot: _diag(
            addressReport: const AddressPickReport(
              chosen: null,
              candidates: [AddressCandidate(interfaceName: 'utun4', address: '100.64.0.5', score: 10, isVirtual: true)],
            ),
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.detail['note'], 'mesh');
      expect(check.detail['utun4'], '100.64.0.5');
    });

    test('warn: a non-mesh VPN tunnel is active', () {
      final check = vpnCheck(
        ctx(
          snapshot: _diag(
            addressReport: const AddressPickReport(
              chosen: null,
              candidates: [AddressCandidate(interfaceName: 'utun3', address: '10.8.0.5', score: 10, isVirtual: true)],
            ),
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.warn);
      expect(check.detail['utun3'], '10.8.0.5');
      expect(check.fixes, isEmpty);
    });
  });

  group('advertisementVisibleCheck', () {
    test('pass: our own advertisement was discovered', () {
      final check = advertisementVisibleCheck(
        ctx(
          snapshot: _diag(
            advertised: [
              AdvertisedRecord(
                name: 'BikeControl',
                type: '_openbikecontrol._tcp',
                port: 36867,
                address: '192.168.1.5',
                txt: {},
              ),
            ],
            discovered: const [
              DiscoveredMdnsService(
                type: '_openbikecontrol._tcp',
                name: 'BikeControl',
                host: '192.168.1.5',
                port: 36867,
                txt: {},
                isSelf: true,
              ),
            ],
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.pass);
    });

    test('skipped: discovery did not run', () {
      final check = advertisementVisibleCheck(ctx(snapshot: _diag(discoveryRan: false)));
      expect(check.verdict, NetworkVerdict.skipped);
    });

    test('fail: discovery ran but our advertisement was not seen', () {
      final check = advertisementVisibleCheck(
        ctx(
          snapshot: _diag(
            advertised: [
              AdvertisedRecord(
                name: 'BikeControl',
                type: '_openbikecontrol._tcp',
                port: 36867,
                address: '192.168.1.5',
                txt: {},
              ),
            ],
            discovered: const [],
          ),
        ),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.detail['hint'], 'advertisement not seen by the OS browser');
      expect(check.fixes, [NetworkFixId.restartMethod]);
    });
  });

  group('localNetworkPermissionCheck', () {
    test('skipped: platform has no such permission', () {
      final check = localNetworkPermissionCheck(ctx(platform: 'windows', snapshot: _diag()));
      expect(check.verdict, NetworkVerdict.skipped);
    });

    test('fail: permission denied', () {
      final check = localNetworkPermissionCheck(
        ctx(
          platform: 'macos',
          snapshot: _diag(permissions: const PermissionsSnapshot(localNetwork: LocalNetworkStatus.denied)),
        ),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.fixes, [NetworkFixId.openLocalNetworkSettings]);
    });

    test('unknown: status could not be determined', () {
      final check = localNetworkPermissionCheck(
        ctx(
          platform: 'ios',
          snapshot: _diag(permissions: const PermissionsSnapshot(localNetwork: LocalNetworkStatus.unknown)),
        ),
      );
      expect(check.verdict, NetworkVerdict.unknown);
    });

    test('unknown: no permission status at all (e.g. snapshot missing)', () {
      final check = localNetworkPermissionCheck(ctx(platform: 'macos', snapshot: null));
      expect(check.verdict, NetworkVerdict.unknown);
    });

    test('pass: permission granted', () {
      final check = localNetworkPermissionCheck(
        ctx(
          platform: 'macos',
          snapshot: _diag(permissions: const PermissionsSnapshot(localNetwork: LocalNetworkStatus.granted)),
        ),
      );
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.fixes, isEmpty);
    });
  });

  group('backendCheck', () {
    test('pass: platform-default backend, hostname reported', () {
      final check = backendCheck(
        ctx(backend: ObpMdnsBackend.platformDefault, advertisedHostname: 'bikecontrol.local'),
      );
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.detail['backend'], ObpMdnsBackend.platformDefault.name);
      expect(check.detail['hostname'], 'bikecontrol.local');
      expect(check.fixes, isEmpty);
    });

    test('pass: OS-responder backend offers switching back, no hostname known', () {
      final check = backendCheck(ctx(backend: ObpMdnsBackend.osResponder, advertisedHostname: null));
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.detail['backend'], ObpMdnsBackend.osResponder.name);
      expect(check.detail.containsKey('hostname'), isFalse);
      expect(check.fixes, [NetworkFixId.useResponderForObc]);
    });
  });

  group('multicastLockCheck', () {
    test('skipped: not Android', () {
      final check = multicastLockCheck(ctx(platform: 'macos', snapshot: _diag()));
      expect(check.verdict, NetworkVerdict.skipped);
    });

    test('skipped: OS responder backend manages its own multicast', () {
      final check = multicastLockCheck(
        ctx(
          platform: 'android',
          backend: ObpMdnsBackend.osResponder,
          snapshot: _diag(holdsMulticastLock: false),
        ),
      );
      expect(check.verdict, NetworkVerdict.skipped);
      expect(check.detail['reason'], 'os responder manages its own multicast');
    });

    test('skipped: OBC is not advertising', () {
      final check = multicastLockCheck(
        ctx(
          platform: 'android',
          backend: ObpMdnsBackend.platformDefault,
          emulatorStarted: false,
          snapshot: _diag(holdsMulticastLock: false),
        ),
      );
      expect(check.verdict, NetworkVerdict.skipped);
    });

    test('pass: multicast lock is held', () {
      final check = multicastLockCheck(
        ctx(platform: 'android', backend: ObpMdnsBackend.platformDefault, snapshot: _diag(holdsMulticastLock: true)),
      );
      expect(check.verdict, NetworkVerdict.pass);
    });

    test('warn: multicast lock is not held', () {
      final check = multicastLockCheck(
        ctx(platform: 'android', backend: ObpMdnsBackend.platformDefault, snapshot: _diag(holdsMulticastLock: false)),
      );
      expect(check.verdict, NetworkVerdict.warn);
      expect(check.fixes, isEmpty);
    });
  });
}
