//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation provides three backends — the OS responder (via the
// `nsd` plugin), an in-process mDNS responder with pinned multicast egress,
// and the platform dns_sd bridge. This stub keeps the public surface so the
// app compiles.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:prop/mdns/mdns_responder.dart';

class AdvertisedService {
  /// Instance name, e.g. 'BikeControl'.
  final String name;

  /// Service type without domain, e.g. '_wahoo-fitness-tnp._tcp'.
  final String type;

  final int port;

  /// The IPv4 address to advertise.
  final InternetAddress address;

  final Map<String, Uint8List> txt;

  AdvertisedService({
    required this.name,
    required this.type,
    required this.port,
    required this.address,
    required this.txt,
  });
}

abstract class ServiceAdvertisement {
  Future<void> unregister();
}

abstract class ServiceAdvertiser {
  /// Process-wide advertiser the emulators use.
  static ServiceAdvertiser instance = NsdServiceAdvertiser();

  /// The right backend for the current platform.
  static ServiceAdvertiser platformDefault() => NsdServiceAdvertiser();

  Future<ServiceAdvertisement> register(AdvertisedService service);

  /// The IPv4 currently in our advertisements, or null when nothing is
  /// advertised. Backends whose daemon owns the records report
  /// [untrackedAddress].
  ValueListenable<String?> get advertisedAddress => untrackedAddress;

  /// A never-changing null [advertisedAddress] for backends that do not own
  /// their host records.
  static final ValueListenable<String?> untrackedAddress = ValueNotifier<String?>(null);
}

/// Hostname-label rules shared by the backends that publish their own host
/// record. Stubbed here.
abstract final class MdnsHostLabel {
  /// [serviceName] turned into a DNS label, or null when it cannot be one.
  static String? derivedFrom(String serviceName) => null;

  /// The stored random label, or a fresh one stored on the spot.
  static String storedRandom() => '';
}

/// The OS-responder backend (via the `nsd` plugin). Stubbed here.
class NsdServiceAdvertiser implements ServiceAdvertiser {
  @override
  ValueListenable<String?> get advertisedAddress => ServiceAdvertiser.untrackedAddress;

  @override
  Future<ServiceAdvertisement> register(AdvertisedService service) => throw UnimplementedError();
}

/// The in-process mDNS responder backend (desktop + Android). Stubbed here.
class ResponderServiceAdvertiser implements ServiceAdvertiser {
  static const Duration desktopAnnounceInterval = Duration(seconds: 10);
  static const Duration defaultAnnounceInterval = Duration(seconds: 60);

  final Duration announceInterval;

  ResponderServiceAdvertiser({this.announceInterval = defaultAnnounceInterval});

  /// The dedicated mDNS hostname label (without `.local`) all services share.
  /// Null while nothing is advertised.
  String? get hostLabel => null;

  /// Android only: whether the active responder socket holds the multicast
  /// lock. False when nothing is currently advertised.
  bool get holdsMulticastLock => false;

  /// The most recent mDNS queries this responder saw.
  List<MdnsQueryLogEntry> get recentQueries => const [];

  Future<void> refreshAddress() async {}

  @override
  ValueListenable<String?> get advertisedAddress => ServiceAdvertiser.untrackedAddress;

  @override
  Future<ServiceAdvertisement> register(AdvertisedService service) => throw UnimplementedError();
}
