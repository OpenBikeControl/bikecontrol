import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/services/network_self_test/network_check.dart';
import 'package:bike_control/services/network_self_test/network_probe_context.dart';
import 'package:bike_control/services/network_self_test/probes/windows_probes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/utils/network_address.dart';

DebugDiagnostics _diag({AddressPickReport addressReport = const AddressPickReport(chosen: null, candidates: [])}) =>
    DebugDiagnostics(
      advertised: const [],
      backend: 'nsd',
      hostLabel: null,
      holdsMulticastLock: false,
      discovered: const [],
      discoveryRan: true,
      addressReport: addressReport,
      servers: const [],
      permissions: const PermissionsSnapshot(localNetwork: null),
    );

/// A context with no-op seams; every field can be overridden per test.
NetworkProbeContext ctx({
  String platform = 'windows',
  Future<ProcessResult> Function(String executable, List<String> arguments)? runProcess,
  DebugDiagnostics? snapshot,
}) => NetworkProbeContext(
  snapshot: snapshot,
  snapshotError: null,
  emulatorStarted: true,
  trainerAppConnected: false,
  trainerAppConnectedNow: () => false,
  trainerAppName: null,
  backend: ObpMdnsBackend.platformDefault,
  advertisedHostname: null,
  platform: platform,
  resolve: (host) async => const [],
  tcpProbe: (address, port) async {},
  runProcess: runProcess ?? (executable, arguments) async => ProcessResult(0, 0, '', ''),
  queryLog: () => const [],
  sleep: (d) async {},
  now: () => DateTime(2026, 8, 21),
  onWatchProgress: (progress) {},
);

Future<ProcessResult> Function(String, List<String>) _stub(String stdout, {int exitCode = 0}) =>
    (executable, arguments) async => ProcessResult(0, exitCode, stdout, '');

void main() {
  group('bonjourServiceCheck', () {
    test('skipped: non-windows platform', () async {
      final check = await bonjourServiceCheck(ctx(platform: 'macos'));
      expect(check.id, NetworkCheckId.bonjourService);
      expect(check.verdict, NetworkVerdict.skipped);
    });

    test('unknown: runProcess throws', () async {
      final check = await bonjourServiceCheck(
        ctx(runProcess: (executable, arguments) async => throw ProcessException('sc', arguments)),
      );
      expect(check.verdict, NetworkVerdict.unknown);
      expect(check.detail.containsKey('error'), isTrue);
    });

    test('pass: service is RUNNING', () async {
      final check = await bonjourServiceCheck(
        ctx(runProcess: _stub('SERVICE_NAME: Bonjour Service\n        STATE : 4  RUNNING')),
      );
      expect(check.verdict, NetworkVerdict.pass);
    });

    test('fail(missing): sc query fails with 1060 (service does not exist)', () async {
      final check = await bonjourServiceCheck(
        ctx(runProcess: _stub('The specified service does not exist as an installed service.\n1060', exitCode: 1060)),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.detail['state'], 'missing');
      expect(check.fixes, containsAll([NetworkFixId.openBonjourDownload, NetworkFixId.switchToLocal]));
    });

    test('fail(missing): non-zero exit without RUNNING', () async {
      final check = await bonjourServiceCheck(ctx(runProcess: _stub('unexpected failure', exitCode: 5)));
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.detail['state'], 'missing');
    });

    test('fail(stopped): installed but not running', () async {
      final check = await bonjourServiceCheck(
        ctx(runProcess: _stub('SERVICE_NAME: Bonjour Service\n        STATE : 1  STOPPED')),
      );
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.detail['state'], 'stopped');
      expect(check.fixes, [NetworkFixId.openBonjourDownload]);
      expect(check.detail['note'], contains('restart the trainer app'));
    });
  });

  group('bonjourNspCheck', () {
    test('skipped: non-windows platform', () async {
      final check = await bonjourNspCheck(ctx(platform: 'linux'));
      expect(check.id, NetworkCheckId.bonjourNsp);
      expect(check.verdict, NetworkVerdict.skipped);
    });

    test('pass: mdnsNSP is present in the Winsock catalog (case-insensitive)', () async {
      final check = await bonjourNspCheck(ctx(runProcess: _stub('001  MDNSNSP.DLL   Bonjour mDNS NSP')));
      expect(check.verdict, NetworkVerdict.pass);
    });

    test('fail: mdnsNSP is absent from the Winsock catalog', () async {
      final check = await bonjourNspCheck(ctx(runProcess: _stub('001  RSVP UDP Service Provider')));
      expect(check.verdict, NetworkVerdict.fail);
      expect(check.fixes, containsAll([NetworkFixId.openBonjourDownload, NetworkFixId.switchToLocal]));
      expect(check.detail['note'], contains('MyWhoosh button'));
    });

    test('unknown: runProcess throws', () async {
      final check = await bonjourNspCheck(
        ctx(runProcess: (executable, arguments) async => throw ProcessException('netsh', arguments)),
      );
      expect(check.verdict, NetworkVerdict.unknown);
    });

    test('pass: mdnsNSP past the stdout cap (real catalogs are ~25 KB)', () async {
      // A real `netsh winsock show catalog` runs ~25 KB and lists namespace
      // providers last — on this machine mdnsNSP starts at byte 22617. Reading
      // only the first 4 KB reported "resolver hook missing" on every machine,
      // healthy Bonjour installs included.
      final catalog = '${'Protocol Entry padding line\n' * 900}0001  mdnsNSP  Bonjour mDNS NSP\n';
      expect(catalog.length, greaterThan(20000));

      final check = await bonjourNspCheck(ctx(runProcess: _stub(catalog)));

      expect(check.verdict, NetworkVerdict.pass);
    });
  });

  group('windowsMdnsResolverCheck', () {
    test('skipped: non-windows platform', () async {
      final check = await windowsMdnsResolverCheck(ctx(platform: 'ios'));
      expect(check.id, NetworkCheckId.windowsMdnsResolver);
      expect(check.verdict, NetworkVerdict.skipped);
    });

    test('pass: value absent (reg query fails), advisory only', () async {
      final check = await windowsMdnsResolverCheck(
        ctx(runProcess: _stub('ERROR: The system was unable to find the specified registry key.', exitCode: 1)),
      );
      expect(check.verdict, NetworkVerdict.pass);
      expect(check.detail['EnableMDNS'], 'absent (default)');
    });

    test('pass: EnableMDNS is 0x1', () async {
      final check = await windowsMdnsResolverCheck(ctx(runProcess: _stub('    EnableMDNS    REG_DWORD    0x1')));
      expect(check.verdict, NetworkVerdict.pass);
    });

    test('warn with NO fixes: EnableMDNS is 0x0', () async {
      final check = await windowsMdnsResolverCheck(ctx(runProcess: _stub('    EnableMDNS    REG_DWORD    0x0')));
      expect(check.verdict, NetworkVerdict.warn);
      expect(check.fixes, isEmpty);
      expect(check.detail['note'], isNotNull);
    });
  });

  group('windowsNetworkProfileAndFirewallChecks', () {
    test('skipped: non-windows platform (both rows)', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(ctx(platform: 'macos'));
      expect(result.profile.id, NetworkCheckId.networkProfile);
      expect(result.profile.verdict, NetworkVerdict.skipped);
      expect(result.firewall.id, NetworkCheckId.firewallRule);
      expect(result.firewall.verdict, NetworkVerdict.skipped);
    });

    test('unknown (both rows): runProcess throws', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(runProcess: (executable, arguments) async => throw ProcessException('powershell', arguments)),
      );
      expect(result.profile.verdict, NetworkVerdict.unknown);
      expect(result.firewall.verdict, NetworkVerdict.unknown);
    });

    test('exit 1 with usable output is still judged (no firewall rule case)', () async {
      // powershell.exe exits 1 when the last pipeline yields nothing, which is
      // what a machine with no BikeControl firewall rule produces — stderr
      // empty, #PROFILE complete and correct above it. Verbatim output from a
      // real run that previously reported both rows as "could not check".
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(runProcess: _stub('#PROFILE\nWLAN=Private\n#FIREWALL\n', exitCode: 1)),
      );

      expect(result.profile.verdict, NetworkVerdict.pass);
      expect(result.profile.detail['category'], 'Private');
      expect(result.firewall.verdict, NetworkVerdict.warn);
      expect(result.firewall.detail['rules'], 'none found');
    });

    test('firewall pass: no rule needed when the firewall is off', () async {
      // Field-observed 2026-08-21: all three profiles disabled and no rule for
      // BikeControl. "None found" was true but meaningless — nothing was being
      // blocked — and it came with a fix button into Defender settings.
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(
          runProcess: _stub(
            '#PROFILE\nWLAN=Private\n#FWSTATE\nDomain=False\nPrivate=False\nPublic=False\n#FIREWALL\n',
          ),
        ),
      );

      expect(result.firewall.verdict, NetworkVerdict.pass);
      expect(result.firewall.fixes, isEmpty);
      expect(result.firewall.detail['note'], contains('firewall is off'));
    });

    test('firewall warn: a missing rule still matters when the firewall is on', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(
          runProcess: _stub(
            '#PROFILE\nWLAN=Private\n#FWSTATE\nDomain=False\nPrivate=True\nPublic=False\n#FIREWALL\n',
          ),
        ),
      );

      expect(result.firewall.verdict, NetworkVerdict.warn);
      expect(result.firewall.fixes, [NetworkFixId.openFirewallSettings]);
    });

    test('firewall state is read for the profile governing the advertised interface', () async {
      // Public is on, but the advertised interface is Private and Private is
      // off — the rule cannot be what stops anything.
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(
          runProcess: _stub(
            '#PROFILE\nWLAN=Private\n#FWSTATE\nDomain=True\nPrivate=False\nPublic=True\n#FIREWALL\n',
          ),
        ),
      );

      expect(result.profile.detail['category'], 'Private');
      expect(result.firewall.verdict, NetworkVerdict.pass);
    });

    test('unknown (both rows): no markers means the script never ran', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(ctx(runProcess: _stub('', exitCode: 1)));

      expect(result.profile.verdict, NetworkVerdict.unknown);
      expect(result.firewall.verdict, NetworkVerdict.unknown);
      expect(result.profile.detail['error'], 'exit 1');
    });

    test('firewall unknown when its section is missing but the profile arrived', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(runProcess: _stub('#PROFILE\nWLAN=Private\n', exitCode: 1)),
      );

      expect(result.profile.verdict, NetworkVerdict.pass);
      expect(result.firewall.verdict, NetworkVerdict.unknown);
    });

    test('profile pass: alias matches the advertised interface, category Private', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(
          snapshot: _diag(
            addressReport: AddressPickReport(
              chosen: InternetAddress('192.168.1.5'),
              candidates: const [
                AddressCandidate(interfaceName: 'Ethernet', address: '192.168.1.5', score: 100, isVirtual: false),
                AddressCandidate(interfaceName: 'Wi-Fi', address: '10.0.0.5', score: 50, isVirtual: false),
              ],
            ),
          ),
          runProcess: _stub('#PROFILE\nEthernet=Private\nWi-Fi=Public\n#FIREWALL\n'),
        ),
      );
      expect(result.profile.verdict, NetworkVerdict.pass);
    });

    test('profile warn: alias matches the advertised interface, category Public', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(
          snapshot: _diag(
            addressReport: AddressPickReport(
              chosen: InternetAddress('10.0.0.5'),
              candidates: const [
                AddressCandidate(interfaceName: 'Ethernet', address: '192.168.1.5', score: 100, isVirtual: false),
                AddressCandidate(interfaceName: 'Wi-Fi', address: '10.0.0.5', score: 50, isVirtual: false),
              ],
            ),
          ),
          runProcess: _stub('#PROFILE\nEthernet=Private\nWi-Fi=Public\n#FIREWALL\n'),
        ),
      );
      expect(result.profile.verdict, NetworkVerdict.warn);
      // The fix is the profile switch in Windows' network settings — Defender
      // firewall settings cannot change a network from Public to Private.
      expect(result.profile.fixes, [NetworkFixId.openNetworkProfileSettings]);
      // Names the connection, so the fix can open that connection's own page.
      expect(result.profile.detail['interface'], 'Wi-Fi');
    });

    test('profile warn: alias not found, falls back to the worst category present', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(
          snapshot: _diag(), // no addressReport candidates at all -> alias never resolves
          runProcess: _stub('#PROFILE\nEthernet=Private\nWi-Fi=Public\n#FIREWALL\n'),
        ),
      );
      expect(result.profile.verdict, NetworkVerdict.warn);
      expect(result.profile.fixes, [NetworkFixId.openNetworkProfileSettings]);
      // The Public one is the connection the fallback is about.
      expect(result.profile.detail['interface'], 'Wi-Fi');
    });

    test('firewall pass: an enabled Allow rule exists', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(runProcess: _stub('#PROFILE\n#FIREWALL\nTrue=Allow\n')),
      );
      expect(result.firewall.verdict, NetworkVerdict.pass);
    });

    test('firewall warn: an enabled Block rule exists', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(
        ctx(runProcess: _stub('#PROFILE\n#FIREWALL\nTrue=Block\n')),
      );
      expect(result.firewall.verdict, NetworkVerdict.warn);
      expect(result.firewall.fixes, contains(NetworkFixId.openFirewallSettings));
    });

    test('firewall warn: no rules found at all', () async {
      final result = await windowsNetworkProfileAndFirewallChecks(ctx(runProcess: _stub('#PROFILE\n#FIREWALL\n')));
      expect(result.firewall.verdict, NetworkVerdict.warn);
      expect(result.firewall.detail['rules'], 'none found');
      expect(result.firewall.fixes, contains(NetworkFixId.openFirewallSettings));
    });
  });

  // The catches are typed: a process that cannot be started or that hangs is
  // a legitimate `unknown`, but anything else is a bug in the probe and must
  // reach the engine wrapper (which recordErrors it under the check's id)
  // instead of being filed away as `unknown` with no trace.
  group('exception handling', () {
    Future<ProcessResult> hang(String executable, List<String> arguments) async =>
        throw TimeoutException('runProcess', const Duration(seconds: 8));
    Future<ProcessResult> bug(String executable, List<String> arguments) async => throw StateError('probe bug');

    test('a TimeoutException from runProcess is unknown', () async {
      expect((await bonjourServiceCheck(ctx(runProcess: hang))).verdict, NetworkVerdict.unknown);
      expect((await bonjourNspCheck(ctx(runProcess: hang))).verdict, NetworkVerdict.unknown);
      expect((await windowsMdnsResolverCheck(ctx(runProcess: hang))).verdict, NetworkVerdict.unknown);
      final both = await windowsNetworkProfileAndFirewallChecks(ctx(runProcess: hang));
      expect(both.profile.verdict, NetworkVerdict.unknown);
      expect(both.firewall.verdict, NetworkVerdict.unknown);
    });

    test('an unexpected exception type propagates out of every check', () async {
      await expectLater(bonjourServiceCheck(ctx(runProcess: bug)), throwsStateError);
      await expectLater(bonjourNspCheck(ctx(runProcess: bug)), throwsStateError);
      await expectLater(windowsMdnsResolverCheck(ctx(runProcess: bug)), throwsStateError);
      await expectLater(windowsNetworkProfileAndFirewallChecks(ctx(runProcess: bug)), throwsStateError);
    });
  });
}
