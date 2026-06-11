import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/widgets.dart' show Locale;
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:prop/emulators/dircon_emulator.dart' show debugSetDirconPortBase;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';

import '../test/integration/harness/fake_ble_platform.dart';

/// Notifications are irrelevant here and the plugin is not initialize()d the
/// way the real main() does it — swallow show() instead of throwing.
class _NoopLocalNotifications extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> show(int id, String? title, String? body, {String? payload}) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

/// On-device environment for the macOS integration tests: the BLE central is
/// faked (no hardware, no permission prompts), everything else — mDNS/Bonjour,
/// TCP sockets — is REAL. SharedPreferences is kept in-memory so the test
/// never touches the developer's actual app preferences.
class OnDeviceEnv {
  OnDeviceEnv._();

  final ble = FakeUniversalBlePlatform();

  static Future<OnDeviceEnv> setUp() async {
    await AppLocalizations.load(const Locale('en'));

    final env = OnDeviceEnv._();
    UniversalBle.setInstance(env.ble);
    FlutterLocalNotificationsPlatform.instance = _NoopLocalNotifications();

    // In-memory prefs — do NOT persist into the real app's storage.
    SharedPreferences.setMockInitialValues({});
    core.settings.prefs = await SharedPreferences.getInstance();

    // Stay clear of the default 36868+ range in case a real BikeControl
    // instance is running on this machine.
    debugSetDirconPortBase(52868);
    return env;
  }

  Future<void> tearDownConnection() async {
    await core.connection.stop();
    for (final device in List.of(core.connection.devices)) {
      try {
        await core.connection.disconnect(device, persistForget: false, forget: true);
      } catch (e, s) {
        // Teardown only — log and keep going so the advertisement is gone.
        // ignore: avoid_print
        print('tearDownConnection: $device: $e\n$s');
      }
    }
    core.connection.devices.clear();
    core.connection.hasDevices.value = false;
    core.connection.isScanning.value = false;
  }

  static Future<void> waitFor(
    FutureOr<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 15),
    String description = 'condition',
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw TimeoutException('Timed out waiting for $description');
  }
}

/// Captures real mDNS traffic on the host: joins the 224.0.0.251:5353
/// multicast group and records every datagram, so tests can assert that
/// actual mDNS packets for our service hit the wire.
class MdnsSniffer {
  MdnsSniffer._(this._socket);

  static final _mdnsGroup = InternetAddress('224.0.0.251');
  static const _mdnsPort = 5353;

  final RawDatagramSocket _socket;
  final List<Uint8List> packets = [];
  StreamSubscription<RawSocketEvent>? _sub;

  static Future<MdnsSniffer> start() async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _mdnsPort,
      reuseAddress: true,
      reusePort: true,
    );
    socket.joinMulticast(_mdnsGroup);
    final sniffer = MdnsSniffer._(socket);
    sniffer._sub = socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) sniffer.packets.add(datagram.data);
      }
    });
    return sniffer;
  }

  /// True when any captured datagram carries [marker] as ASCII bytes. mDNS
  /// encodes names as length-prefixed labels, so a dot-free label (like the
  /// `_wahoo-fitness-tnp` service label or a service instance name) appears
  /// verbatim in the packet.
  bool sawAscii(String marker) {
    final needle = marker.codeUnits;
    return packets.any((packet) {
      outer:
      for (var i = 0; i + needle.length <= packet.length; i++) {
        for (var j = 0; j < needle.length; j++) {
          if (packet[i + j] != needle[j]) continue outer;
        }
        return true;
      }
      return false;
    });
  }

  /// Multicasts a one-shot mDNS PTR question for [serviceType] (e.g.
  /// `_wahoo-fitness-tnp._tcp.local`) so mDNSResponder answers on the wire
  /// even between periodic announcements.
  void query(String serviceType) {
    final bytes = <int>[
      0, 0, // transaction id (0 for mDNS)
      0, 0, // flags: standard query
      0, 1, // QDCOUNT
      0, 0, 0, 0, 0, 0, // AN/NS/AR counts
    ];
    for (final label in serviceType.split('.')) {
      bytes.add(label.length);
      bytes.addAll(label.codeUnits);
    }
    bytes.addAll([0, 0, 12, 0, 1]); // root, QTYPE=PTR, QCLASS=IN
    _socket.send(bytes, _mdnsGroup, _mdnsPort);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _socket.close();
  }
}
