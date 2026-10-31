import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/mdns/avahi_service_browser.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:nsd/nsd.dart' as nsd;

typedef MdnsServiceListener = void Function(nsd.Service service, nsd.ServiceStatus status);

/// Browses one mDNS service type and reports resolved services as they come
/// and go. One instance browses one type at a time.
abstract class MdnsServiceBrowser {
  /// nsd everywhere it is implemented; Avahi over D-Bus on Linux, where nsd
  /// has no implementation.
  factory MdnsServiceBrowser.forPlatform() => HostPlatform.isLinux
      ? AvahiServiceBrowser(onError: (e, s) => recordError(e, s, context: 'Avahi service browser'))
      : NsdServiceBrowser();

  Future<void> start(String type, MdnsServiceListener listener);

  Future<void> stop();
}

class NsdServiceBrowser implements MdnsServiceBrowser {
  nsd.Discovery? _discovery;
  MdnsServiceListener? _listener;

  @override
  Future<void> start(String type, MdnsServiceListener listener) async {
    nsd.disableServiceTypeValidation(true);
    final discovery = await nsd.startDiscovery(type, autoResolve: true);
    discovery.addServiceListener(listener);
    _discovery = discovery;
    _listener = listener;
  }

  @override
  Future<void> stop() async {
    final discovery = _discovery;
    final listener = _listener;
    _discovery = null;
    _listener = null;
    if (discovery == null) return;
    if (listener != null) discovery.removeServiceListener(listener);
    await nsd.stopDiscovery(discovery);
  }
}
