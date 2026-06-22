import 'dart:io' show Platform;

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/mdns_discovery_scan.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/mdns/service_advertiser.dart';
import 'package:prop/utils/advertised_service_registry.dart';
import 'package:prop/utils/network_address.dart';
import 'package:prop/utils/resilient_tcp_server.dart';

/// A running TCP bridge server, for diagnostics.
class TcpServerInfo {
  final String? label;
  final int? port;
  final bool listening;
  final bool hasClient;

  const TcpServerInfo({
    required this.label,
    required this.port,
    required this.listening,
    required this.hasClient,
  });
}

/// Status of the permissions whose denial silently breaks WiFi/BLE bridging.
class PermissionsSnapshot {
  /// iOS Local Network can't be queried directly; inferred from whether a
  /// discovery scan returned anything. Null when no scan ran.
  final bool? localNetworkInferred;

  const PermissionsSnapshot({
    required this.localNetworkInferred,
  });

  static Future<PermissionsSnapshot> gather({bool? localNetworkInferred}) async {
    return PermissionsSnapshot(
      localNetworkInferred: localNetworkInferred,
    );
  }
}

/// The full diagnostics snapshot shown on the Logs page and embedded in
/// [debugText]. Build with [gather]; render with [toText].
class DebugDiagnostics {
  final List<AdvertisedRecord> advertised;
  final String backend;
  final String? hostLabel;
  final bool holdsMulticastLock;
  final List<DiscoveredMdnsService> discovered;
  final bool discoveryRan;
  final AddressPickReport addressReport;
  final List<TcpServerInfo> servers;
  final PermissionsSnapshot permissions;

  const DebugDiagnostics({
    required this.advertised,
    required this.backend,
    required this.hostLabel,
    required this.holdsMulticastLock,
    required this.discovered,
    required this.discoveryRan,
    required this.addressReport,
    required this.servers,
    required this.permissions,
  });

  static Future<DebugDiagnostics> gather({
    bool includeDiscovery = true,
    Duration discoveryTimeout = const Duration(seconds: 4),
  }) async {
    final advertiser = ServiceAdvertiser.instance;
    final isResponder = advertiser is ResponderServiceAdvertiser;

    AddressPickReport addressReport;
    try {
      addressReport = await AdvertisedAddressPicker.report();
    } catch (e, s) {
      recordError(e, s, context: 'DebugDiagnostics.address');
      addressReport = const AddressPickReport(chosen: null, candidates: []);
    }

    final servers = ResilientTcpServer.activeServers
        .map(
          (s) => TcpServerInfo(
            label: s.label,
            port: s.isRunning ? s.boundPort : null,
            listening: s.isRunning,
            hasClient: s.hasClient,
          ),
        )
        .toList();

    var discovered = <DiscoveredMdnsService>[];
    var discoveryRan = false;
    if (includeDiscovery && !kIsWeb) {
      try {
        discovered = await MdnsDiscoveryScan().run(timeout: discoveryTimeout);
        discoveryRan = true;
      } catch (e, s) {
        recordError(e, s, context: 'DebugDiagnostics.discovery');
      }
    }

    final permissions = await PermissionsSnapshot.gather(
      // iOS is the only platform with a (non-queryable) "Local Network"
      // permission; infer it from whether discovery saw anything. Elsewhere an
      // empty scan just means no peers, so leave it unset.
      localNetworkInferred: (discoveryRan && !kIsWeb && Platform.isIOS) ? discovered.isNotEmpty : null,
    );

    return DebugDiagnostics(
      advertised: AdvertisedServiceRegistry.instance.records,
      backend: isResponder ? 'responder' : 'nsd',
      hostLabel: isResponder ? advertiser.hostLabel : null,
      holdsMulticastLock: isResponder ? advertiser.holdsMulticastLock : false,
      discovered: discovered,
      discoveryRan: discoveryRan,
      addressReport: addressReport,
      servers: servers,
      permissions: permissions,
    );
  }

  String _txt(Map<String, String> txt) => txt.entries.map((e) => '${e.key}=${e.value}').join(', ');

  String toText() {
    final b = StringBuffer();
    b.writeln('Diagnostics:');

    b.writeln('  Advertised by this device:');
    if (advertised.isEmpty) {
      b.writeln('    (none)');
    } else {
      for (final a in advertised) {
        b.writeln('    ${a.type} "${a.name}" ${a.address}:${a.port}');
        if (a.txt.isNotEmpty) b.writeln('      txt: ${_txt(a.txt)}');
      }
    }
    b.writeln(
      '    backend: $backend'
      '${hostLabel != null ? ' · host: $hostLabel.local' : ''}'
      '${backend == 'responder' ? ' · multicast-lock: ${holdsMulticastLock ? 'held' : 'not held'}' : ''}',
    );

    b.writeln('  Discovered on network:');
    if (!discoveryRan) {
      b.writeln('    (skipped)');
    } else if (discovered.isEmpty) {
      b.writeln('    (none found)');
    } else {
      for (final d in discovered) {
        b.writeln('    ${d.type} "${d.name}" ${d.host}:${d.port}${d.isSelf ? '  (this device)' : ''}');
        if (d.txt.isNotEmpty) b.writeln('      txt: ${_txt(d.txt)}');
      }
    }

    b.writeln('  Network interfaces (advertised = ${addressReport.chosen?.address ?? 'none'}):');
    for (final c in addressReport.candidates) {
      final tags = [
        if (addressReport.chosen?.address == c.address) 'advertised',
        if (c.isVirtual) 'virtual',
      ];
      b.writeln('    ${c.interfaceName}/${c.address} = ${c.score}${tags.isEmpty ? '' : ' (${tags.join(', ')})'}');
    }

    b.writeln('  TCP servers:');
    if (servers.isEmpty) {
      b.writeln('    (none)');
    } else {
      for (final s in servers) {
        b.writeln(
          '    ${s.label ?? 'tcp'} :${s.port ?? '-'} '
          '${s.listening ? 'listening' : 'down'} · ${s.hasClient ? '1 client' : 'no client'}',
        );
      }
    }

    if (permissions.localNetworkInferred != null) {
      b.writeln(
        '  Permissions: ios-local-network='
        '${permissions.localNetworkInferred! ? 'inferred-ok' : 'inferred-blocked'}',
      );
    }

    return b.toString().trimRight();
  }
}
