// ignore: depend_on_referenced_packages
import 'package:nsd_platform_interface/nsd_platform_interface.dart';

/// A [Discovery] that replays already-known services to listeners attached
/// after the announcement — mirroring mDNS, where records are re-announced
/// and a late listener still learns about existing services.
class _ReplayDiscovery extends Discovery {
  _ReplayDiscovery(super.id);

  @override
  void addServiceListener(ServiceListener serviceListener) {
    super.addServiceListener(serviceListener);
    for (final service in List.of(services)) {
      serviceListener(service, ServiceStatus.found);
    }
  }
}

/// In-memory mDNS bus replacing the nsd plugin. Registrations made by the app
/// (DirconEmulator) become visible to discoveries started by the app
/// (WifiTrainerScanner) and to tests acting as a fake trainer app. Tests can
/// also inject "foreign" services to simulate other devices on the LAN.
class FakeNsdPlatform extends NsdPlatformInterface {
  int _nextId = 0;

  /// Active registrations made through [register] (the app's own ads).
  final registrations = <Registration>[];

  /// Foreign services injected by the test (fake trainers on the LAN).
  final _foreignServices = <Service>[];

  /// Active discoveries, with the service type they browse for.
  final _discoveries = <({Discovery discovery, String type})>[];

  List<Service> get _allServices => [
        ..._foreignServices,
        ...registrations.map((r) => r.service),
      ];

  /// Simulate another device starting to advertise on the LAN.
  void addForeignService(Service service) {
    _foreignServices.add(service);
    for (final entry in _discoveries) {
      if (entry.type == service.type) entry.discovery.add(service);
    }
  }

  /// Simulate a device's advertisement disappearing.
  void removeForeignService(Service service) {
    _foreignServices.removeWhere((s) => isSame(s, service));
    for (final entry in _discoveries) {
      if (entry.type == service.type) entry.discovery.remove(service);
    }
  }

  void reset() {
    registrations.clear();
    _foreignServices.clear();
    _discoveries.clear();
  }

  @override
  Future<Discovery> startDiscovery(
    String serviceType, {
    bool autoResolve = true,
    IpLookupType ipLookupType = IpLookupType.none,
  }) async {
    final discovery = _ReplayDiscovery('fake-discovery-${_nextId++}');
    _discoveries.add((discovery: discovery, type: serviceType));
    // Seed already-known services; _ReplayDiscovery replays them to whoever
    // attaches a listener after this returns.
    for (final service in _allServices.where((s) => s.type == serviceType)) {
      discovery.add(service);
    }
    return discovery;
  }

  @override
  Future<void> stopDiscovery(Discovery discovery) async {
    _discoveries.removeWhere((entry) => identical(entry.discovery, discovery));
  }

  @override
  Future<Service> resolve(Service service) async => service;

  @override
  Future<Registration> register(Service service) async {
    final registration = Registration('fake-registration-${_nextId++}', service);
    registrations.add(registration);
    for (final entry in _discoveries) {
      if (entry.type == service.type) entry.discovery.add(service);
    }
    return registration;
  }

  @override
  Future<void> unregister(Registration registration) async {
    registrations.remove(registration);
    for (final entry in _discoveries) {
      if (entry.type == registration.service.type) entry.discovery.remove(registration.service);
    }
  }

  @override
  void enableLogging(LogTopic logTopic) {}

  @override
  void disableServiceTypeValidation(bool value) {}
}
