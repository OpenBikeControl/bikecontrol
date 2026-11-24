import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bike_control/main.dart' show recordError;
import 'package:flutter/foundation.dart';
import 'package:prop/mdns/dns_message.dart';

/// Resolves a `.local` hostname to an IPv4 address with a one-shot mDNS
/// query, bypassing the OS resolver.
///
/// Needed on Windows: the nsd plugin there reports a resolved service with
/// its hostname only, no addresses, and the OS resolver can't look up every
/// name a device advertises (e.g. labels with spaces, like
/// "ELITE-JUSTO 2-01090-W.local").
///
/// Sends a legacy-unicast query (RFC 6762 §6.7) from an ephemeral port, so no
/// socket on 5353 is needed and the responder answers straight back to us.
///
/// Not on iOS: an app may not send multicast there without an entitlement
/// BikeControl does not have, so every query failed with "No route to host"
/// (errno 65). iOS resolves `.local` names through the system resolver, which
/// is used instead.
class MdnsHostResolver {
  static final mdnsGroup = InternetAddress('224.0.0.251');
  static const mdnsPort = 5353;

  /// The IPv4 address [host] resolves to, or null when nothing answers within
  /// [timeout]. [target]/[port] are for tests.
  static Future<String?> resolveIPv4(
    String host, {
    Duration timeout = const Duration(seconds: 2),
    InternetAddress? target,
    int port = mdnsPort,
    bool? useSystemResolver,
    Future<List<InternetAddress>> Function(String host)? systemLookup,
  }) async {
    final name = DnsName.fromString(host);
    if (name.labels.isEmpty) return null;

    if (useSystemResolver ?? (!kIsWeb && target == null && Platform.isIOS)) {
      try {
        final lookup = systemLookup ?? ((h) => InternetAddress.lookup(h, type: InternetAddressType.IPv4));
        final addresses = await lookup(host).timeout(timeout);
        return addresses.where((a) => a.type == InternetAddressType.IPv4).firstOrNull?.address;
      } on SocketException {
        // The name does not resolve (yet); the caller falls back to the host.
        return null;
      } on TimeoutException {
        return null;
      }
    }

    final RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } on SocketException {
      return null;
    }
    final destination = target ?? mdnsGroup;
    final id = Random().nextInt(0xFFFF) + 1;
    final query = DnsMessage(
      id: id,
      questions: [DnsQuestion(name: name, type: DnsType.a, wantsUnicastResponse: true)],
    ).encode();

    final result = Completer<String?>();
    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null || result.isCompleted) return;
      final message = DnsMessage.decode(datagram.data);
      if (message == null || !message.isResponse) return;
      for (final record in [...message.answers, ...message.additionals]) {
        if (record is ARecord && record.ttl > 0 && record.name.matches(name)) {
          result.complete(record.address);
          return;
        }
      }
    }, onError: (Object e, StackTrace s) {
      // dart:io reports a failed send here, not from send(), and closes the
      // socket. Without a handler it reached the root zone and was logged as
      // an app crash on every attempt.
      recordError(e, s, context: 'MdnsHostResolver $host');
      if (!result.isCompleted) result.complete(null);
    });

    // Multicast is lossy; repeat the question a couple of times.
    void send() {
      if (result.isCompleted) return;
      try {
        socket.send(query, destination, port);
      } on SocketException {
        // No route right now; the next attempt or the timeout settles it.
      }
    }

    final retries = [
      for (final delay in const [Duration(milliseconds: 250), Duration(milliseconds: 1000)]) Timer(delay, send),
    ];
    send();

    try {
      return await result.future.timeout(timeout, onTimeout: () => null);
    } finally {
      for (final timer in retries) {
        timer.cancel();
      }
      await subscription.cancel();
      socket.close();
    }
  }
}
