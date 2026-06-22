import 'dart:async';
import 'dart:io';

import 'package:bike_control/bluetooth/wifi_trainer_scanner.dart';
import 'package:bike_control/main.dart' show recordError;
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:prop/utils/advertised_service_registry.dart';

/// One mDNS service seen on the LAN during a diagnostics scan.
class DiscoveredMdnsService {
  final String type;
  final String name;
  final String host;
  final int port;
  final Map<String, String> txt;

  /// True when this is one of BikeControl's own advertisements echoed back.
  final bool isSelf;

  const DiscoveredMdnsService({
    required this.type,
    required this.name,
    required this.host,
    required this.port,
    required this.txt,
    required this.isSelf,
  });

  factory DiscoveredMdnsService.fromService(
    nsd.Service service, {
    required String host,
    required int port,
    required bool isSelf,
  }) {
    final txt = <String, String>{};
    service.txt?.forEach((k, v) {
      txt[k] = v == null ? '' : decodeMdnsTxt(v);
    });
    return DiscoveredMdnsService(
      type: service.type ?? '',
      name: service.name ?? '',
      host: host,
      port: port,
      txt: txt,
      isSelf: isSelf,
    );
  }
}

/// Time-boxed browse of the OpenBikeControl and Wahoo DirCon service types.
/// Includes our own advertisement (flagged [DiscoveredMdnsService.isSelf]) so
/// the user can confirm the responder is reachable over the wire.
class MdnsDiscoveryScan {
  static const types = ['_openbikecontrol._tcp', '_wahoo-fitness-tnp._tcp'];

  Future<List<DiscoveredMdnsService>> run({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (kIsWeb) return [];
    final localAddresses = await _listLocalAddresses();
    nsd.disableServiceTypeValidation(true);

    final found = <String, DiscoveredMdnsService>{};
    void listener(nsd.Service service, nsd.ServiceStatus status) {
      if (status == nsd.ServiceStatus.lost) return;
      final name = service.name;
      final port = service.port;
      final host = service.addresses
              ?.firstOrNullWhere((a) => a.type == InternetAddressType.IPv4)
              ?.address ??
          service.host;
      if (name == null || port == null || host == null) return;
      final isSelf =
          WifiTrainerScanner.isSelfAdvertisement(service, localAddresses: localAddresses);
      found['${service.type}/$name'] = DiscoveredMdnsService.fromService(
        service,
        host: host,
        port: port,
        isSelf: isSelf,
      );
    }

    final discoveries = <nsd.Discovery>[];
    try {
      for (final type in types) {
        final discovery = await nsd.startDiscovery(type, autoResolve: true);
        discovery.addServiceListener(listener);
        discoveries.add(discovery);
      }
      await Future<void>.delayed(timeout);
    } finally {
      for (final discovery in discoveries) {
        discovery.removeServiceListener(listener);
        try {
          await nsd.stopDiscovery(discovery);
        } catch (e, s) {
          recordError(e, s, context: 'MdnsDiscoveryScan.stop');
        }
      }
    }
    return found.values.toList();
  }

  Future<Set<String>> _listLocalAddresses() async {
    try {
      final interfaces =
          await NetworkInterface.list(includeLinkLocal: true, type: InternetAddressType.any);
      return interfaces.expand((i) => i.addresses).map((a) => a.address).toSet();
    } catch (e, s) {
      recordError(e, s, context: 'MdnsDiscoveryScan.localAddresses');
      return {};
    }
  }
}
