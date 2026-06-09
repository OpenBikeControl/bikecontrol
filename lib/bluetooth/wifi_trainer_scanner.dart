import 'dart:async';
import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/utils/constants.dart';
import 'package:prop/utils/self_advertisement_registry.dart';
import 'package:universal_ble/universal_ble.dart';

/// A DirCon smart trainer discovered on the local network.
class WifiTrainer {
  WifiTrainer({required this.syntheticDevice, required this.host, required this.port});

  /// Synthetic [BleDevice] so the trainer flows through the existing
  /// ProxyDevice / Connection machinery unchanged.
  final BleDevice syntheticDevice;
  final String host;
  final int port;
}

/// Browses `_wahoo-fitness-tnp._tcp` (DirCon) and reports trainers on the
/// LAN, excluding BikeControl's own advertisements. Lifecycle mirrors BLE
/// scanning: started from Connection.performScanning, stopped from
/// Connection.stop. Deliberately core-free — callbacks are injected.
class WifiTrainerScanner {
  WifiTrainerScanner({required this.onFound, required this.onLost});

  static const serviceType = '_wahoo-fitness-tnp._tcp';

  final void Function(WifiTrainer trainer) onFound;
  final void Function(String deviceId) onLost;

  nsd.Discovery? _discovery;
  final _known = <String, WifiTrainer>{};

  /// Local interface IPs, refreshed on [start] — used for self-exclusion.
  Set<String> _localAddresses = {};

  /// Idempotent. When already browsing, re-announces everything known so
  /// devices removed from the Connection list (e.g. after a disconnect)
  /// reappear on the next scan pass.
  Future<void> start() async {
    if (kIsWeb) return;
    if (_discovery != null) {
      for (final trainer in _known.values.toList()) {
        onFound(trainer);
      }
      return;
    }
    _localAddresses = await _listLocalAddresses();
    final discovery = await nsd.startDiscovery(serviceType, autoResolve: true);
    discovery.addServiceListener(handleService);
    _discovery = discovery;
  }

  Future<void> stop() async {
    final discovery = _discovery;
    _discovery = null;
    _known.clear();
    if (discovery != null) {
      discovery.removeServiceListener(handleService);
      await nsd.stopDiscovery(discovery);
    }
  }

  @visibleForTesting
  void handleService(nsd.Service service, nsd.ServiceStatus status) {
    final name = service.name;
    if (name == null) return;
    if (status == nsd.ServiceStatus.lost) {
      final deviceId = deviceIdFor(name);
      _known.remove(deviceId);
      onLost(deviceId);
      return;
    }
    if (isSelfAdvertisement(service, localAddresses: _localAddresses)) return;
    final port = service.port;
    final host =
        service.addresses?.firstOrNullWhere((a) => a.type == InternetAddressType.IPv4)?.address ?? service.host;
    if (host == null || port == null) return;
    final trainer = WifiTrainer(syntheticDevice: syntheticDeviceFor(service), host: host, port: port);
    _known[trainer.syntheticDevice.deviceId] = trainer;
    onFound(trainer);
  }

  static String deviceIdFor(String serviceName) => 'dircon://$serviceName';

  /// Three independent checks — any one excludes (see design spec §4):
  /// 1. registered name, 2. TXT fingerprint, 3. own address + registered port.
  static bool isSelfAdvertisement(nsd.Service service, {required Set<String> localAddresses}) {
    final name = service.name;
    if (name != null && SelfAdvertisementRegistry.instance.containsName(name)) return true;

    final txt = service.txt;
    if (txt != null) {
      for (final value in txt.values) {
        if (value == null) continue;
        if (BikeControlMdnsMarkers.txtFingerprints.contains(String.fromCharCodes(value))) return true;
      }
    }

    final port = service.port;
    final addresses = service.addresses;
    if (port != null &&
        addresses != null &&
        SelfAdvertisementRegistry.instance.containsPort(port) &&
        addresses.any((a) => localAddresses.contains(a.address))) {
      return true;
    }
    return false;
  }

  static BleDevice syntheticDeviceFor(nsd.Service service) {
    var services = <String>[];
    final raw = service.txt?['ble-service-uuids'];
    if (raw != null) {
      services = String.fromCharCodes(raw)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map(_normalizeUuid)
          .toList();
    }
    if (services.isEmpty) {
      // A DirCon ad without service hints is still a trainer — assume FTMS.
      services = [FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase()];
    }
    return BleDevice(deviceId: deviceIdFor(service.name!), name: service.name, services: services);
  }

  static String _normalizeUuid(String uuid) {
    final clean = uuid.toLowerCase();
    if (clean.length == 4) return '0000$clean-0000-1000-8000-00805f9b34fb';
    return clean;
  }

  Future<Set<String>> _listLocalAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(includeLinkLocal: true, type: InternetAddressType.any);
      return interfaces.expand((i) => i.addresses).map((a) => a.address).toSet();
    } catch (_) {
      return {};
    }
  }
}
