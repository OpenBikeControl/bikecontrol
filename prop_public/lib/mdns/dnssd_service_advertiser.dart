//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation registers the host and service records through the
// platform's own dns_sd bridge (iOS). This stub keeps the public surface so
// the app compiles.

import 'package:flutter/foundation.dart';
import 'package:prop/mdns/service_advertiser.dart';

/// The platform side of the dns_sd bridge.
abstract class DnsSdPlatform {
  static const conflictCode = 'conflict';

  Future<void> registerHost({required String label, required String ipv4});

  Future<void> updateHost({required String ipv4});

  Future<void> unregisterHost();

  Future<int> registerService({
    required String name,
    required String type,
    required int port,
    required String hostLabel,
    required Map<String, String> txt,
  });

  Future<void> unregisterService(int handle);
}

/// A [ServiceAdvertiser] backed by the platform's dns_sd bridge. Stubbed here.
class DnsSdServiceAdvertiser implements ServiceAdvertiser {
  static const Duration defaultAnnounceInterval = Duration(seconds: 60);

  final Duration announceInterval;

  DnsSdServiceAdvertiser({this.announceInterval = defaultAnnounceInterval});

  /// The hostname label this advertiser published, or null when it has none.
  String? get hostLabel => null;

  Future<void> refreshAddress() async {}

  @override
  ValueListenable<String?> get advertisedAddress => ServiceAdvertiser.untrackedAddress;

  @override
  Future<ServiceAdvertisement> register(AdvertisedService service) => throw UnimplementedError();
}
