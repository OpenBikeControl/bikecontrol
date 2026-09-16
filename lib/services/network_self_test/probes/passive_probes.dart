import 'package:dartx/dartx.dart';

import '../../../bluetooth/devices/openbikecontrol/openbikecontrol_device.dart' show OpenBikeControlConstants;
import '../../../bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import '../../debug_diagnostics.dart';
import '../network_check.dart';
import '../network_probe_context.dart';

/// The seven passive checks (spec checks 1–6, 14): everything derivable from
/// one `DebugDiagnostics.gather()` snapshot plus the cheap emulator/settings
/// getters already sitting on [NetworkProbeContext] — no network I/O of their
/// own, so they are plain, synchronous, pure functions.

/// 100.64.0.0/10, the CGNAT range mesh VPNs (Tailscale, ZeroTier) hand out.
/// Mirrors `DebugDiagnostics._isCgnat`, which is private to that file.
bool _isCgnat(String address) {
  final parts = address.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null)) return false;
  return parts[0] == 100 && parts[1]! >= 64 && parts[1]! <= 127;
}

/// The first three dotted octets, used to tell whether two IPv4 addresses
/// are plausibly on the same /24.
String _subnetPrefix(String address) {
  final parts = address.split('.');
  return parts.length >= 3 ? parts.take(3).join('.') : address;
}

/// Check 1: is the OpenBikeControl TCP server the mDNS method actually
/// registered running and listening?
NetworkCheck methodListeningCheck(NetworkProbeContext ctx) {
  final snapshot = ctx.snapshot;
  if (snapshot == null) {
    return NetworkCheck(
      id: NetworkCheckId.methodListening,
      verdict: NetworkVerdict.unknown,
      detail: {'error': ctx.snapshotError.toString()},
    );
  }
  if (!ctx.emulatorStarted) {
    return const NetworkCheck(
      id: NetworkCheckId.methodListening,
      verdict: NetworkVerdict.fail,
      detail: {'reason': 'not started'},
      fixes: [NetworkFixId.restartMethod],
    );
  }
  final server = snapshot.servers.firstOrNullWhere((s) => s.label == 'OpenBikeControl' && s.listening);
  if (server == null) {
    return const NetworkCheck(
      id: NetworkCheckId.methodListening,
      verdict: NetworkVerdict.fail,
      fixes: [NetworkFixId.restartMethod],
    );
  }
  final port = server.port;
  if (port == OpenBikeControlConstants.TCP_PORT) {
    return NetworkCheck(id: NetworkCheckId.methodListening, verdict: NetworkVerdict.pass, detail: {'port': '$port'});
  }
  // Off the preferred port: something else held it when this server bound —
  // historically a previous instance of ours that was never stopped (an
  // un-awaited stop racing the next start), so every restart walked one port
  // further up. A restart now supersedes any leak of ours and lands back on
  // the preferred port, so offer it instead of leaving the rider to discover
  // that only force-closing the app helps. Only a foreign holder (another
  // process on this host) leaves the warning standing afterwards.
  return NetworkCheck(
    id: NetworkCheckId.methodListening,
    verdict: NetworkVerdict.warn,
    detail: {'port': '$port'},
    fixes: const [NetworkFixId.restartMethod],
  );
}

/// Check 2: is the address picked for the mDNS advertisement one that other
/// devices on the LAN can actually reach?
NetworkCheck advertisedAddressCheck(NetworkProbeContext ctx) {
  final snapshot = ctx.snapshot;
  if (snapshot == null) {
    return NetworkCheck(
      id: NetworkCheckId.advertisedAddress,
      verdict: NetworkVerdict.unknown,
      detail: {'error': ctx.snapshotError.toString()},
    );
  }
  final chosen = snapshot.addressReport.chosen;
  if (chosen == null) {
    return const NetworkCheck(
      id: NetworkCheckId.advertisedAddress,
      verdict: NetworkVerdict.fail,
      fixes: [NetworkFixId.restartMethod],
    );
  }

  final candidates = snapshot.addressReport.candidates;
  final chosenCandidate = candidates.firstOrNullWhere((c) => c.address == chosen.address);
  final chosenIsTunnel = snapshot.tunnelCandidates.any((c) => c.address == chosen.address);
  if ((chosenCandidate?.isVirtual ?? false) || chosenIsTunnel) {
    return NetworkCheck(
      id: NetworkCheckId.advertisedAddress,
      verdict: NetworkVerdict.warn,
      detail: {'address': chosen.address},
      fixes: [NetworkFixId.restartMethod],
    );
  }

  final physical = candidates.where((c) => !c.isVirtual).toList();
  final subnets = physical.map((c) => _subnetPrefix(c.address)).toSet();
  if (physical.length >= 2 && subnets.length >= 2) {
    final detail = <String, String>{for (final c in physical) c.interfaceName: '${c.address}=${c.score}'};
    return NetworkCheck(id: NetworkCheckId.advertisedAddress, verdict: NetworkVerdict.warn, detail: detail);
  }

  return NetworkCheck(
    id: NetworkCheckId.advertisedAddress,
    verdict: NetworkVerdict.pass,
    detail: {'address': chosen.address},
  );
}

/// Check 3: advisory row — does a VPN/mesh tunnel interface carry a routable
/// IPv4, and if so is it the harmless CGNAT-mesh kind or a full tunnel that
/// can blackhole inbound LAN connections?
NetworkCheck vpnCheck(NetworkProbeContext ctx) {
  final snapshot = ctx.snapshot;
  if (snapshot == null) {
    return NetworkCheck(
      id: NetworkCheckId.vpn,
      verdict: NetworkVerdict.unknown,
      detail: {'error': ctx.snapshotError.toString()},
    );
  }
  final tunnels = snapshot.tunnelCandidates;
  if (tunnels.isEmpty) {
    return const NetworkCheck(id: NetworkCheckId.vpn, verdict: NetworkVerdict.pass);
  }
  final allMesh = tunnels.every((c) => _isCgnat(c.address));
  final detail = <String, String>{
    if (allMesh) 'note': 'mesh',
    for (final c in tunnels) c.interfaceName: c.address,
  };
  return NetworkCheck(
    id: NetworkCheckId.vpn,
    verdict: allMesh ? NetworkVerdict.pass : NetworkVerdict.warn,
    detail: detail,
  );
}

/// Check 4: did the OS's own mDNS browser see our advertisement echoed back?
NetworkCheck advertisementVisibleCheck(NetworkProbeContext ctx) {
  final snapshot = ctx.snapshot;
  if (snapshot == null) {
    return NetworkCheck(
      id: NetworkCheckId.advertisementVisible,
      verdict: NetworkVerdict.unknown,
      detail: {'error': ctx.snapshotError.toString()},
    );
  }
  if (!snapshot.discoveryRan) {
    return const NetworkCheck(id: NetworkCheckId.advertisementVisible, verdict: NetworkVerdict.skipped);
  }

  final obcRecord = snapshot.advertised.firstOrNullWhere((r) => r.name == 'BikeControl');
  final obcType = obcRecord?.type;
  final seen = obcType != null && snapshot.discovered.any((d) => d.isSelf && d.type == obcType);
  if (seen) {
    return const NetworkCheck(id: NetworkCheckId.advertisementVisible, verdict: NetworkVerdict.pass);
  }
  return const NetworkCheck(
    id: NetworkCheckId.advertisementVisible,
    verdict: NetworkVerdict.fail,
    detail: {'hint': 'advertisement not seen by the OS browser'},
    fixes: [NetworkFixId.restartMethod],
  );
}

/// Check 5: Apple's Local Network privacy permission (iOS/macOS only).
NetworkCheck localNetworkPermissionCheck(NetworkProbeContext ctx) {
  if (ctx.platform != 'ios' && ctx.platform != 'macos') {
    return const NetworkCheck(id: NetworkCheckId.localNetworkPermission, verdict: NetworkVerdict.skipped);
  }
  // A missing snapshot (gather() threw) and a snapshot whose probe never
  // completed both mean "we don't know" — both fall out of this the same way.
  final localNetwork = ctx.snapshot?.permissions.localNetwork;
  switch (localNetwork) {
    case LocalNetworkStatus.denied:
      return const NetworkCheck(
        id: NetworkCheckId.localNetworkPermission,
        verdict: NetworkVerdict.fail,
        fixes: [NetworkFixId.openLocalNetworkSettings],
      );
    case LocalNetworkStatus.granted:
      return const NetworkCheck(id: NetworkCheckId.localNetworkPermission, verdict: NetworkVerdict.pass);
    case LocalNetworkStatus.unknown:
    case null:
      return const NetworkCheck(id: NetworkCheckId.localNetworkPermission, verdict: NetworkVerdict.unknown);
  }
}

/// Check 6: info row — which mDNS backend is registering the OBC
/// advertisement, and under what hostname.
NetworkCheck backendCheck(NetworkProbeContext ctx) {
  final hostname = ctx.advertisedHostname;
  return NetworkCheck(
    id: NetworkCheckId.backend,
    verdict: NetworkVerdict.pass,
    detail: {'backend': ctx.backend.name, if (hostname != null) 'hostname': hostname},
    fixes: ctx.backend == ObpMdnsBackend.osResponder ? const [NetworkFixId.useResponderForObc] : const [],
  );
}

/// Check 14: info row (Android only) — does the responder hold the
/// multicast lock it needs to see mDNS traffic at all?
NetworkCheck multicastLockCheck(NetworkProbeContext ctx) {
  if (ctx.platform != 'android') {
    return const NetworkCheck(id: NetworkCheckId.multicastLock, verdict: NetworkVerdict.skipped);
  }
  // The WifiManager multicast lock is only acquired by MulticastMdnsSocket
  // (the platformDefault backend); the OS responder (NsdManager) manages its
  // own multicast and never touches it, so the lock legitimately doesn't
  // apply there.
  if (ctx.backend == ObpMdnsBackend.osResponder) {
    return const NetworkCheck(
      id: NetworkCheckId.multicastLock,
      verdict: NetworkVerdict.skipped,
      detail: {'reason': 'os responder manages its own multicast'},
    );
  }
  // OBC isn't advertising — methodListeningCheck already reports that, so a
  // second warn here would be redundant.
  if (!ctx.emulatorStarted) {
    return const NetworkCheck(
      id: NetworkCheckId.multicastLock,
      verdict: NetworkVerdict.skipped,
      detail: {'reason': 'OBC is not advertising'},
    );
  }
  final snapshot = ctx.snapshot;
  if (snapshot == null) {
    return NetworkCheck(
      id: NetworkCheckId.multicastLock,
      verdict: NetworkVerdict.unknown,
      detail: {'error': ctx.snapshotError.toString()},
    );
  }
  final held = snapshot.holdsMulticastLock;
  return NetworkCheck(
    id: NetworkCheckId.multicastLock,
    verdict: held ? NetworkVerdict.pass : NetworkVerdict.warn,
    detail: {'held': held.toString()},
  );
}
