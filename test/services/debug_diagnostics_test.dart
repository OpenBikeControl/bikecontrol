import 'dart:io';

import 'package:bike_control/services/debug_diagnostics.dart';
import 'package:bike_control/services/mdns_discovery_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/mdns/mdns_responder.dart' show MdnsQueryLogEntry;
import 'package:prop/utils/advertised_service_registry.dart';
import 'package:prop/utils/network_address.dart';

void main() {
  test('toText renders every section with the expected markers', () {
    final diag = DebugDiagnostics(
      advertised: [
        AdvertisedRecord(
          name: 'BikeControl',
          type: '_openbikecontrol._tcp',
          port: 36867,
          address: '192.168.1.9',
          txt: {'version': '0x01', 'name': 'BikeControl', 'id': '1337'},
        ),
      ],
      backend: 'responder',
      hostLabel: 'bikecontrol-3f2a',
      holdsMulticastLock: true,
      discovered: const [
        DiscoveredMdnsService(
          type: '_wahoo-fitness-tnp._tcp',
          name: 'BikeControl',
          host: '192.168.1.9',
          port: 36867,
          txt: {},
          isSelf: true,
        ),
      ],
      discoveryRan: true,
      addressReport: AddressPickReport(
        chosen: InternetAddress('192.168.1.9'),
        candidates: const [
          AddressCandidate(interfaceName: 'en0', address: '192.168.1.9', score: 40, isVirtual: false),
          AddressCandidate(interfaceName: 'utun0', address: '10.2.0.2', score: -60, isVirtual: true),
        ],
      ),
      servers: const [
        TcpServerInfo(label: 'OpenBikeControl', port: 36867, listening: true, hasClient: true),
      ],
      permissions: const PermissionsSnapshot(
        localNetwork: LocalNetworkStatus.granted,
      ),
    );

    final text = diag.toText();

    expect(text, contains('Advertised by this device'));
    expect(text, contains('_openbikecontrol._tcp "BikeControl" 192.168.1.9:36867'));
    // TXT entries are rendered alphabetically by key.
    expect(text, contains('txt: id=1337, name=BikeControl, version=0x01'));
    expect(text, contains('host: bikecontrol-3f2a.local'));
    expect(text, contains('multicast-lock: held'));
    expect(text, contains('(this device)'));
    expect(text, contains('en0/192.168.1.9 = 40 (advertised)'));
    expect(text, contains('utun0/10.2.0.2 = -60 (virtual)'));
    expect(text, contains('OpenBikeControl :36867 listening · 1 client'));
    expect(text, contains('local-network=granted'));
  });

  test('toText marks discovery as skipped when it did not run', () {
    final diag = DebugDiagnostics(
      advertised: const [],
      backend: 'nsd',
      hostLabel: null,
      holdsMulticastLock: false,
      discovered: const [],
      discoveryRan: false,
      addressReport: const AddressPickReport(chosen: null, candidates: []),
      servers: const [],
      permissions: const PermissionsSnapshot(localNetwork: null),
    );

    expect(diag.toText(), contains('Discovered on network:'));
    expect(diag.toText(), contains('(skipped)'));
  });

  group('VPN line', () {
    DebugDiagnostics withCandidates(List<AddressCandidate> candidates) => DebugDiagnostics(
      advertised: const [],
      backend: 'nsd',
      hostLabel: null,
      holdsMulticastLock: false,
      discovered: const [],
      discoveryRan: true,
      addressReport: AddressPickReport(chosen: InternetAddress('192.168.1.9'), candidates: candidates),
      servers: const [],
      permissions: const PermissionsSnapshot(localNetwork: null),
    );

    test('names the tunnel interface when a VPN carries a routable IPv4', () {
      // The real support bundle: mDNS fine, both servers listening, no client.
      final text = withCandidates(const [
        AddressCandidate(interfaceName: 'pdp_ip0', address: '192.0.0.2', score: 1, isVirtual: false),
        AddressCandidate(interfaceName: 'en0', address: '10.70.0.15', score: 30, isVirtual: false),
        AddressCandidate(interfaceName: 'utun4', address: '10.2.0.2', score: -70, isVirtual: true),
      ]).toText();

      expect(text, contains('VPN: likely active — utun4/10.2.0.2'));
      expect(text, contains('blocks inbound LAN connections'));
    });

    test('reports none when only physical and non-VPN virtual interfaces exist', () {
      // bridge100 is the Personal Hotspot / Internet Sharing bridge and
      // v4-rmnet the 464XLAT CLAT device: both "virtual", neither a VPN.
      final text = withCandidates(const [
        AddressCandidate(interfaceName: 'en0', address: '192.168.1.9', score: 40, isVirtual: false),
        AddressCandidate(interfaceName: 'bridge100', address: '172.20.10.1', score: -80, isVirtual: true),
        AddressCandidate(interfaceName: 'v4-rmnet_data2', address: '192.0.0.8', score: 1, isVirtual: true),
        AddressCandidate(interfaceName: 'docker0', address: '172.17.0.1', score: -80, isVirtual: true),
      ]).toText();

      expect(text, contains('VPN: none detected'));
    });

    test('flags a mesh VPN in the CGNAT range as usually harmless', () {
      final text = withCandidates(const [
        AddressCandidate(interfaceName: 'en0', address: '192.168.1.9', score: 40, isVirtual: false),
        AddressCandidate(interfaceName: 'utun8', address: '100.76.35.113', score: -90, isVirtual: true),
      ]).toText();

      expect(text, contains('VPN: likely active — utun8/100.76.35.113'));
      expect(text, contains('usually harmless'));
    });

    test('matches Windows adapter FriendlyNames, which are not unix device names', () {
      final text = withCandidates(const [
        AddressCandidate(interfaceName: 'Wi-Fi', address: '192.168.1.9', score: 40, isVirtual: false),
        AddressCandidate(interfaceName: 'ProtonVPN TUN', address: '10.2.0.2', score: 30, isVirtual: false),
      ]).toText();

      expect(text, contains('VPN: likely active — ProtonVPN TUN/10.2.0.2'));
    });

    test('ignores idle Apple tunnels that only ever carry a link-local IPv4', () {
      final text = withCandidates(const [
        AddressCandidate(interfaceName: 'en0', address: '192.168.1.9', score: 40, isVirtual: false),
        AddressCandidate(interfaceName: 'utun2', address: '169.254.10.20', score: -99, isVirtual: true),
      ]).toText();

      expect(text, contains('VPN: none detected'));
    });
  });
  group('mDNS queries received', () {
    // What this fixture "advertises" — the two service types BikeControl
    // actually registers. Queries naming these are BikeControl-relevant and
    // stay listed; everything else in this group is either the generic
    // enumeration query or a third-party query that must be dropped.
    final ourAdvertised = [
      AdvertisedRecord(
        name: 'BikeControl',
        type: '_wahoo-fitness-tnp._tcp',
        port: 36867,
        address: '192.168.1.9',
        txt: const {},
      ),
      AdvertisedRecord(
        name: 'BikeControl',
        type: '_openbikecontrol._tcp',
        port: 36867,
        address: '192.168.1.9',
        txt: const {},
      ),
    ];

    DebugDiagnostics withQueries(List<MdnsQueryLogEntry> queries, {List<AdvertisedRecord>? advertised}) =>
        DebugDiagnostics(
          advertised: advertised ?? ourAdvertised,
          backend: 'responder',
          hostLabel: 'BikeControl',
          holdsMulticastLock: false,
          discovered: const [],
          discoveryRan: false,
          addressReport: const AddressPickReport(chosen: null, candidates: []),
          servers: const [],
          permissions: const PermissionsSnapshot(localNetwork: null),
          recentQueries: queries,
        );

    test('renders each query with its source, QU bit and how it was answered', () {
      final text = withQueries([
        MdnsQueryLogEntry(
          at: DateTime(2026, 7, 30, 9, 41, 12),
          source: '192.168.178.92',
          sourcePort: 5353,
          wantsUnicast: true,
          questions: const ['PTR _wahoo-fitness-tnp._tcp.local'],
          answeredUnicast: true,
          answeredMulticast: true,
        ),
      ]).toText();

      expect(text, contains('mDNS queries received:'));
      expect(text, contains('192.168.178.92:5353'));
      expect(text, contains('QU'));
      expect(text, contains('PTR _wahoo-fitness-tnp._tcp.local'));
      expect(text, contains('unicast+multicast'));
    });

    test('marks a folded entry with its repeat count', () {
      // Uses one of our own advertised types (not a third-party one, e.g. the
      // real-world '_oculusal_sp._tcp' Meta headsets poll non-stop) — this
      // test is about the repeat-count marker, and only a kept entry renders
      // one; an unrelated query this repetitive would instead be folded into
      // the dropped-queries summary.
      final text = withQueries([
        MdnsQueryLogEntry(
          at: DateTime(2026, 7, 30, 20, 32, 33),
          source: '172.20.176.1',
          sourcePort: 5353,
          wantsUnicast: false,
          questions: const ['PTR _openbikecontrol._tcp.local'],
          answeredUnicast: false,
          answeredMulticast: false,
          count: 17,
        ),
      ]).toText();

      expect(text, contains('×17'));
      expect(text, contains('no answer'));
    });

    test('a single occurrence carries no count marker', () {
      final text = withQueries([
        MdnsQueryLogEntry(
          at: DateTime(2026, 7, 30, 20, 32, 38),
          source: '192.168.0.87',
          sourcePort: 5353,
          wantsUnicast: true,
          questions: const ['PTR _openbikecontrol._tcp.local'],
          answeredUnicast: true,
          answeredMulticast: false,
        ),
      ]).toText();

      expect(text, isNot(contains('×')));
    });

    test('says so when nothing has queried us', () {
      // The decisive line for "the trainer app on this machine cannot see
      // BikeControl": if no query ever arrived, the problem is upstream of our
      // responder, not in how we answer.
      expect(withQueries(const []).toText(), contains('(none)'));
    });

    test('the block sits between the VPN line and the TCP servers', () {
      // Support reads top-down: "did it ask, did we answer" belongs right
      // before "did it connect".
      final text = withQueries(const []).toText();
      expect(text.indexOf('VPN:'), lessThan(text.indexOf('mDNS queries received:')));
      expect(text.indexOf('mDNS queries received:'), lessThan(text.indexOf('TCP servers:')));
    });

    // Privacy: support bundles leave the device, so third-party hostnames
    // and IPs a browsing neighbour's device happened to log must not appear
    // in the exported text — only queries that name something BikeControl
    // itself advertises are listed verbatim.
    test('lists only BikeControl-relevant queries and summarises the rest', () {
      final text = withQueries([
        MdnsQueryLogEntry(
          at: DateTime(2026, 7, 30, 9, 41, 12),
          source: '192.168.178.92',
          sourcePort: 5353,
          wantsUnicast: true,
          questions: const ['PTR _wahoo-fitness-tnp._tcp.local'],
          answeredUnicast: true,
          answeredMulticast: true,
        ),
        MdnsQueryLogEntry(
          at: DateTime(2026, 7, 30, 9, 42, 0),
          source: '192.168.178.44',
          sourcePort: 5353,
          wantsUnicast: false,
          questions: const ['A someones-macbook.local'],
          answeredUnicast: false,
          answeredMulticast: false,
        ),
        MdnsQueryLogEntry(
          at: DateTime(2026, 7, 30, 9, 43, 0),
          source: '192.168.178.44',
          sourcePort: 5353,
          wantsUnicast: false,
          questions: const ['PTR _airplay._tcp.local'],
          answeredUnicast: false,
          answeredMulticast: false,
          count: 3,
        ),
      ]).toText();

      expect(text, contains('192.168.178.92:5353'));
      expect(text, isNot(contains('someones-macbook')));
      expect(text, isNot(contains('_airplay')));
      // Folded count (1) + repeats (3) from the one distinct dropped host.
      expect(text, contains('(+4 unrelated queries from 1 hosts, not listed)'));
    });

    test('keeps the generic service-enumeration query and does not count it as dropped', () {
      final text = withQueries([
        MdnsQueryLogEntry(
          at: DateTime(2026, 7, 30, 9, 41, 12),
          source: '192.168.178.92',
          sourcePort: 5353,
          wantsUnicast: false,
          questions: const ['PTR _services._dns-sd._udp.local'],
          answeredUnicast: false,
          answeredMulticast: true,
        ),
      ]).toText();

      expect(text, contains('_services._dns-sd._udp.local'));
      expect(text, isNot(contains('unrelated queries')));
    });

    test('a host query is not matched when no hostLabel is set', () {
      final text = DebugDiagnostics(
        advertised: const [],
        backend: 'responder',
        hostLabel: null,
        holdsMulticastLock: false,
        discovered: const [],
        discoveryRan: false,
        addressReport: const AddressPickReport(chosen: null, candidates: []),
        servers: const [],
        permissions: const PermissionsSnapshot(localNetwork: null),
        recentQueries: [
          MdnsQueryLogEntry(
            at: DateTime(2026, 7, 30, 9, 41, 12),
            source: '192.168.178.92',
            sourcePort: 5353,
            wantsUnicast: false,
            questions: const ['A bikecontrol-1a2b.local'],
            answeredUnicast: false,
            answeredMulticast: true,
          ),
        ],
      ).toText();

      expect(text, isNot(contains('bikecontrol-1a2b')));
      expect(text, contains('unrelated queries'));
    });

    test('kept lines come before the dropped-queries summary, which comes before TCP servers', () {
      final text = withQueries([
        MdnsQueryLogEntry(
          at: DateTime(2026, 7, 30, 9, 41, 12),
          source: '192.168.178.92',
          sourcePort: 5353,
          wantsUnicast: true,
          questions: const ['PTR _wahoo-fitness-tnp._tcp.local'],
          answeredUnicast: true,
          answeredMulticast: true,
        ),
        MdnsQueryLogEntry(
          at: DateTime(2026, 7, 30, 9, 42, 0),
          source: '192.168.178.44',
          sourcePort: 5353,
          wantsUnicast: false,
          questions: const ['A someones-macbook.local'],
          answeredUnicast: false,
          answeredMulticast: false,
        ),
      ]).toText();

      expect(text.indexOf('192.168.178.92:5353'), lessThan(text.indexOf('unrelated queries')));
      expect(text.indexOf('unrelated queries'), lessThan(text.indexOf('TCP servers:')));
    });
  });
}
