// A stand-in for the machine's radios and network, for tests that drive the
// real connection code end to end but must stay offline and deterministic —
// the onboarding video capture in particular.
//
// Everything below the app's own code is replaced, nothing in it:
//
// * Bluetooth: the app's own emulated BLE platform ([FakeUniversalBlePlatform])
//   — the same fake the integration suite and the debug emulation panel use.
// * mDNS: the in-memory [FakeNsdPlatform] from the integration harness, so an
//   advertisement is registered in memory instead of announced on the LAN.
// * TCP servers: `ServerSocket.bind` (through [IOOverrides]) returns a socket
//   that is bound to nothing and never accepts. No port is opened.
// * Network interfaces: one Wi-Fi interface with a fixed private address, so
//   the advertised-address policy picks the same address on every machine.
// * HTTP: requests are answered from local fixture files; any URL without a
//   fixture is a 404 rather than a request to the internet.
// * Notifications: the system notifications a connect posts go nowhere.
//
// All of these answer with already-completed futures, so they run on the fake
// clock: nothing waits on the real event loop.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/bluetooth/emulation/emulated_ble_platform.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:nsd_platform_interface/nsd_platform_interface.dart';
import 'package:prop/utils/network_address.dart';
import 'package:universal_ble/universal_ble.dart';

import '../integration/harness/fake_nsd_platform.dart';

class OfflineMachine {
  OfflineMachine._(this.ble, this.nsd);

  final FakeUniversalBlePlatform ble;
  final FakeNsdPlatform nsd;

  /// The address the fake Wi-Fi interface carries.
  static final InternetAddress lanAddress = InternetAddress('192.168.1.20');

  /// Installs every fake. [httpFixtures] maps a full URL to the local file
  /// that answers it.
  static OfflineMachine install({Map<String, String> httpFixtures = const {}}) {
    final machine = OfflineMachine._(FakeUniversalBlePlatform(), FakeNsdPlatform());
    UniversalBle.setInstance(machine.ble);
    NsdPlatformInterface.instance = machine.nsd;
    FlutterLocalNotificationsPlatform.instance = _SilentNotifications();
    IOOverrides.global = _OfflineIOOverrides();
    HttpOverrides.global = _FixtureHttpOverrides(httpFixtures);
    AdvertisedAddressPicker.listInterfaces = () async => [
          _FakeInterface('en0', [lanAddress]),
        ];
    return machine;
  }
}

class _SilentNotifications extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show({required int id, String? title, String? body, String? payload}) async {}

  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

class _FakeInterface implements NetworkInterface {
  _FakeInterface(this.name, List<InternetAddress> addresses)
      : addresses = [for (final a in addresses) _FakeInterfaceAddress(a)];

  @override
  final String name;

  @override
  final List<InterfaceAddress> addresses;

  @override
  int get index => 1;
}

class _FakeInterfaceAddress implements InterfaceAddress {
  _FakeInterfaceAddress(this._inner);

  final InternetAddress _inner;

  @override
  int get prefixLength => 24;

  @override
  InternetAddress? get broadcast => null;

  @override
  InternetAddressType get type => _inner.type;

  @override
  String get address => _inner.address;

  @override
  String get host => _inner.host;

  @override
  Uint8List get rawAddress => _inner.rawAddress;

  @override
  bool get isLoopback => _inner.isLoopback;

  @override
  bool get isLinkLocal => _inner.isLinkLocal;

  @override
  bool get isMulticast => _inner.isMulticast;

  @override
  Future<InternetAddress> reverse() => _inner.reverse();
}

final class _OfflineIOOverrides extends IOOverrides {
  @override
  Future<ServerSocket> serverSocketBind(
    dynamic address,
    int port, {
    int backlog = 0,
    bool v6Only = false,
    bool shared = false,
  }) async =>
      _UnboundServerSocket(address is InternetAddress ? address : InternetAddress.anyIPv4, port);
}

/// A server socket bound to nothing: it never accepts a client.
class _UnboundServerSocket extends Stream<Socket> implements ServerSocket {
  _UnboundServerSocket(this.address, this.port);

  final _clients = StreamController<Socket>();

  @override
  final InternetAddress address;

  @override
  final int port;

  @override
  StreamSubscription<Socket> listen(
    void Function(Socket event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _clients.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future<ServerSocket> close() async {
    // Not awaited: closing a controller nobody listens to never completes.
    unawaited(_clients.close());
    return this;
  }
}

class _FixtureHttpOverrides extends HttpOverrides {
  _FixtureHttpOverrides(this.fixtures);

  final Map<String, String> fixtures;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _FixtureHttpClient(fixtures);
}

class _FixtureHttpClient implements HttpClient {
  _FixtureHttpClient(this.fixtures);

  final Map<String, String> fixtures;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FixtureRequest(fixtures[url.toString()]);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => getUrl(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('offline HTTP client: ${invocation.memberName} is not faked');
}

class _FixtureRequest implements HttpClientRequest {
  _FixtureRequest(this.fixturePath);

  final String? fixturePath;

  @override
  final HttpHeaders headers = _NoHeaders();

  @override
  Future<HttpClientResponse> close() async {
    final path = fixturePath;
    if (path == null) return _FixtureResponse(HttpStatus.notFound, const []);
    return _FixtureResponse(HttpStatus.ok, File(path).readAsBytesSync());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('offline HTTP request: ${invocation.memberName} is not faked');
}

class _NoHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixtureResponse extends Stream<List<int>> implements HttpClientResponse {
  _FixtureResponse(this.statusCode, this._bytes);

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.fromIterable([if (_bytes.isNotEmpty) _bytes])
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('offline HTTP response: ${invocation.memberName} is not faked');
}
