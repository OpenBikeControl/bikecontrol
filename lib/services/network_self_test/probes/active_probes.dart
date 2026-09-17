import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:prop/utils/resilient_tcp_server.dart';

import '../../../bluetooth/devices/openbikecontrol/obp_mdns_backend.dart';
import '../network_check.dart';
import '../network_probe_context.dart';

/// The two active checks (spec checks 7-8): each opens real sockets, so
/// unlike the passive probes they are async and go through the [resolve] /
/// [tcpProbe] seams on [NetworkProbeContext] rather than touching `dart:io`
/// directly — that's what keeps [resolveOwnHostnameCheck] and
/// [tcpSelfConnectCheck] unit-testable without a network.

/// Check 7: does the hostname we advertised over mDNS actually resolve, on
/// this machine, to the address we advertised it for?
Future<NetworkCheck> resolveOwnHostnameCheck(NetworkProbeContext ctx) async {
  final hostname = ctx.advertisedHostname;
  if (hostname == null) {
    // iOS never learns its own mDNS hostname (nsd backend), so this check
    // has nothing to resolve.
    return const NetworkCheck(
      id: NetworkCheckId.resolveOwnHostname,
      verdict: NetworkVerdict.skipped,
      detail: {'reason': 'hostname unknown'},
    );
  }

  final expected = ctx.snapshot?.addressReport.chosen?.address;
  final start = ctx.now();
  List<InternetAddress> resolved;
  try {
    resolved = await ctx.resolve(hostname);
  } on TimeoutException catch (e) {
    return _resolveFailure(ctx, e);
  } on SocketException catch (e) {
    return _resolveFailure(ctx, e);
  }

  if (resolved.isEmpty) {
    return _resolveFailure(ctx, 'empty result');
  }

  final latencyMs = ctx.now().difference(start).inMilliseconds;
  final addresses = resolved.map((a) => a.address).toList();
  if (expected != null && addresses.contains(expected)) {
    return NetworkCheck(
      id: NetworkCheckId.resolveOwnHostname,
      verdict: NetworkVerdict.pass,
      detail: {'address': expected, 'latencyMs': '$latencyMs'},
    );
  }
  return NetworkCheck(
    id: NetworkCheckId.resolveOwnHostname,
    verdict: NetworkVerdict.warn,
    detail: {'resolvedTo': addresses.join(', '), 'expected': '$expected'},
  );
}

/// Fields shared by every fail branch of [resolveOwnHostnameCheck]. Field-
/// confirmed 2026-08-21: a faulty Bonjour install (service running, NSP
/// present, resolution still broken) is a real cause, and a clean reinstall
/// fixes it — hence [NetworkFixId.openBonjourDownload] on Windows even
/// though the other Bonjour-specific checks (Task 7) look healthy.
NetworkCheck _resolveFailure(NetworkProbeContext ctx, Object error) => NetworkCheck(
  id: NetworkCheckId.resolveOwnHostname,
  verdict: NetworkVerdict.fail,
  detail: {'error': error.toString()},
  fixes: [
    if (ctx.backend == ObpMdnsBackend.platformDefault) NetworkFixId.useOsResponderForObc,
    if (ctx.platform == 'windows') NetworkFixId.openBonjourDownload,
    NetworkFixId.switchToLocal,
  ],
);

/// Check 8: can this machine open a TCP connection to the address/port it
/// just advertised for the network method under examination
/// ([NetworkProbeContext.methodServerLabel]) — i.e. would a trainer app on
/// the same host actually be able to reach us?
Future<NetworkCheck> tcpSelfConnectCheck(NetworkProbeContext ctx) async {
  if (ctx.trainerAppConnected) {
    // A live trainer app already proves connectivity; opening a second,
    // throwaway connection now would only risk confusing it.
    return const NetworkCheck(
      id: NetworkCheckId.tcpSelfConnect,
      verdict: NetworkVerdict.skipped,
      detail: {'reason': 'trainer app connected'},
    );
  }

  final snapshot = ctx.snapshot;
  final server = snapshot?.servers.firstOrNullWhere((s) => s.label == ctx.methodServerLabel && s.listening);
  if (server == null) {
    // methodListeningCheck already failed on this; nothing new to add here.
    return const NetworkCheck(
      id: NetworkCheckId.tcpSelfConnect,
      verdict: NetworkVerdict.skipped,
      detail: {'reason': 'method not listening'},
    );
  }

  final address = snapshot!.addressReport.chosen?.address ?? '127.0.0.1';
  final port = server.port!;
  final start = ctx.now();
  // Refused / timed out / no server to probe ([defaultTcpProbe]'s StateError)
  // are the three ways a reachability probe legitimately fails. Anything
  // else is a bug and propagates to the engine wrapper (recordError under
  // this check's id) rather than being reported as a network failure.
  try {
    await ctx.tcpProbe(address, port);
  } on SocketException catch (e) {
    return _tcpFailure(ctx, e);
  } on TimeoutException catch (e) {
    return _tcpFailure(ctx, e);
  } on StateError catch (e) {
    return _tcpFailure(ctx, e);
  }

  final latencyMs = ctx.now().difference(start).inMilliseconds;
  return NetworkCheck(
    id: NetworkCheckId.tcpSelfConnect,
    verdict: NetworkVerdict.pass,
    detail: {'latencyMs': '$latencyMs'},
  );
}

NetworkCheck _tcpFailure(NetworkProbeContext ctx, Object error) => NetworkCheck(
  id: NetworkCheckId.tcpSelfConnect,
  verdict: NetworkVerdict.fail,
  detail: {'error': error.toString()},
  fixes: [NetworkFixId.restartMethod, if (ctx.platform == 'windows') NetworkFixId.openFirewallSettings],
);

/// Default resolver: IPv4 lookup with its own 3 s cap.
Future<List<InternetAddress>> defaultResolve(String host) =>
    InternetAddress.lookup(host, type: InternetAddressType.IPv4).timeout(const Duration(seconds: 3));

/// Default TCP probe: registers a probe expectation on the active server
/// labelled [label] (the method under examination — OpenBikeControl unless
/// the context says otherwise), then connects to [address]:[port] from a
/// bound source port and destroys the socket. Throws on refusal/timeout.
///
/// The source address the server will see is whatever the OS picks for the
/// route to [address]: itself, when [address] is loopback (we're connecting
/// to 127.0.0.1), or — connecting to our own advertised LAN address hairpins
/// back to ourselves — [address] again, once we bind the socket to it
/// explicitly via `sourceAddress`. Either way source == destination, so a
/// single [address] value is all [ResilientTcpServer.expectProbe] needs.
Future<void> defaultTcpProbe(String address, int port, {String label = 'OpenBikeControl'}) async {
  final server = ResilientTcpServer.activeServers.firstOrNullWhere((s) => s.label == label);
  if (server == null) {
    throw StateError('$label server not running');
  }

  final destination = InternetAddress(address);
  final sourceAddress = destination.isLoopback ? null : destination;

  Socket? socket;
  try {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      // Reserve a source port by binding+releasing a loopback ServerSocket,
      // then hand it to Socket.connect below — the same technique Task 1's
      // test uses so the server can match the probe by exact source
      // address + port.
      final holder = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sourcePort = holder.port;
      await holder.close();

      server.expectProbe(address: address, sourcePort: sourcePort);
      try {
        socket = await Socket.connect(
          address,
          port,
          sourceAddress: sourceAddress,
          sourcePort: sourcePort,
          timeout: const Duration(seconds: 5),
        );
        break;
      } on SocketException catch (e) {
        // The port we just released hasn't finished being torn down by the
        // OS yet; narrowly scoped so a genuine refusal/timeout still throws
        // immediately instead of retrying.
        final rebindRefused = e.osError?.errorCode == 48 || e.message.contains('Address already in use');
        if (attempt == maxAttempts || !rebindRefused) rethrow;
      }
    }
    // The server destroys the probe socket as soon as it accepts it; without
    // an active reader that close is never observed — `socket.done` alone
    // hangs forever, so drain (which subscribes and discards) is required.
    // The probe has already succeeded by the time we get here (the connect
    // above is what proves reachability) — a reset on that server-side
    // destroy, or the drain simply not finishing within the window, is
    // best-effort observation only and must never fail the probe.
    await socket!.drain<void>().timeout(const Duration(seconds: 3)).catchError((_) {});
  } finally {
    socket?.destroy();
  }
}
