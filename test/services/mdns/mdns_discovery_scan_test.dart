// The diagnostics scan lists what is on the LAN; on Linux that has to come
// from Avahi like the trainer scanner, so it browses through an injected
// MdnsServiceBrowser per service type.
import 'dart:io';

import 'package:bike_control/services/mdns/mdns_service_browser.dart';
import 'package:bike_control/services/mdns_discovery_scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'package:prop/mdns/mdns_responder.dart' show OwnMdnsBrowsing;

class _FakeBrowser implements MdnsServiceBrowser {
  _FakeBrowser({this.onStart});
  final void Function()? onStart;
  String? type;
  var stopped = false;

  @override
  Future<void> start(String type, MdnsServiceListener listener) async {
    this.type = type;
    onStart?.call();
    listener(
      nsd.Service(name: 'Seen on $type', type: type, port: 36866, addresses: [InternetAddress('192.168.1.50')]),
      nsd.ServiceStatus.found,
    );
  }

  @override
  Future<void> stop() async => stopped = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('browses every type through the injected browser and stops them all', () async {
    final browsers = <_FakeBrowser>[];
    final found = await MdnsDiscoveryScan(
      createBrowser: () => _FakeBrowser().also(browsers.add),
    ).run(timeout: Duration.zero);

    expect(browsers.map((b) => b.type), MdnsDiscoveryScan.types);
    expect(browsers.every((b) => b.stopped), isTrue);
    expect(found.map((s) => s.name), MdnsDiscoveryScan.types.map((t) => 'Seen on $t'));
    expect(found.first.host, '192.168.1.50');
  });

  // The query log tells our own scan from a trainer app by the types we
  // browse; this scan browses every one of [MdnsDiscoveryScan.types].
  test('marks each browsed type as an own browse while it runs', () async {
    addTearDown(OwnMdnsBrowsing.debugReset);
    Set<String>? duringScan;
    await MdnsDiscoveryScan(
      createBrowser: () => _FakeBrowser(onStart: () => duringScan = OwnMdnsBrowsing.activeTypes),
    ).run(timeout: Duration.zero);

    expect(duringScan, MdnsDiscoveryScan.types.toSet());
  });
}

extension<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}
