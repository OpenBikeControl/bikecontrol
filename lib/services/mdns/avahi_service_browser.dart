import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/services/mdns/mdns_service_browser.dart';
import 'package:dbus/dbus.dart';
import 'package:nsd/nsd.dart' as nsd;

/// One service instance as an Avahi service browser reports it: the same
/// instance shows up once per interface (and protocol) it was seen on.
class AvahiItem {
  const AvahiItem({
    required this.interface,
    required this.protocol,
    required this.name,
    required this.type,
    required this.domain,
  });

  final int interface;
  final int protocol;
  final String name;
  final String type;
  final String domain;
}

/// A signal from an `org.freedesktop.Avahi.ServiceBrowser` object.
class AvahiBrowserSignal {
  const AvahiBrowserSignal({required this.path, required this.member, this.item, this.error});

  /// The browser object that sent it.
  final String path;

  /// `ItemNew`, `ItemRemove`, `Failure`, `AllForNow` or `CacheExhausted`.
  final String member;

  /// Set for `ItemNew` and `ItemRemove`.
  final AvahiItem? item;

  /// Set for `Failure`.
  final String? error;
}

/// The slice of Avahi's D-Bus API the browser needs.
abstract class AvahiBus {
  /// Every service-browser signal on the bus, whichever browser sent it.
  /// Listened to before [createBrowser], so no signal of the new browser is
  /// missed.
  Stream<AvahiBrowserSignal> get signals;

  /// Throws when Avahi is not running.
  Future<void> connect();

  /// Creates a service browser for [type] and returns its object path.
  Future<String> createBrowser(String type);

  Future<nsd.Service> resolve(AvahiItem item);

  Future<void> freeBrowser(String path);

  Future<void> close();
}

/// Browses through Avahi, the mDNS daemon on Linux desktops, which also does
/// the caching and expiry nsd leaves to the OS elsewhere.
class AvahiServiceBrowser implements MdnsServiceBrowser {
  AvahiServiceBrowser({AvahiBus Function()? bus, required void Function(Object error, StackTrace stack) onError})
    : _createBus = bus ?? DBusAvahiBus.new,
      _onError = onError;

  final AvahiBus Function() _createBus;
  final void Function(Object error, StackTrace stack) _onError;

  AvahiBus? _bus;
  StreamSubscription<AvahiBrowserSignal>? _subscription;
  String? _path;
  MdnsServiceListener? _listener;

  /// Interfaces each instance is currently seen on, by name. It is lost only
  /// once it is gone from all of them.
  final _seenOn = <String, Set<int>>{};

  @override
  Future<void> start(String type, MdnsServiceListener listener) async {
    final bus = _createBus();
    _bus = bus;
    _listener = listener;
    try {
      await bus.connect();
      // Signals that arrive before the browser's path is known are held back
      // and replayed once it is.
      final early = <AvahiBrowserSignal>[];
      _subscription = bus.signals.listen((signal) {
        final path = _path;
        if (path == null) {
          early.add(signal);
        } else if (signal.path == path) {
          _handle(signal);
        }
      });
      final path = await bus.createBrowser(type);
      _path = path;
      for (final signal in early) {
        if (signal.path == path) _handle(signal);
      }
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  void _handle(AvahiBrowserSignal signal) {
    final item = signal.item;
    switch (signal.member) {
      case 'ItemNew' when item != null:
        final seenOn = _seenOn.putIfAbsent(item.name, () => {});
        final isNew = seenOn.isEmpty;
        seenOn.add(item.interface);
        if (isNew) unawaited(_resolve(item));
      case 'ItemRemove' when item != null:
        final seenOn = _seenOn[item.name];
        if (seenOn == null) return;
        seenOn.remove(item.interface);
        if (seenOn.isNotEmpty) return;
        _seenOn.remove(item.name);
        _listener?.call(nsd.Service(name: item.name, type: item.type), nsd.ServiceStatus.lost);
      case 'Failure':
        _onError(StateError('Avahi service browser failed: ${signal.error}'), StackTrace.current);
    }
  }

  Future<void> _resolve(AvahiItem item) async {
    try {
      final service = await (_bus ?? (throw StateError('stopped'))).resolve(item);
      // Gone again (or browsing stopped) while resolving.
      if (!_seenOn.containsKey(item.name)) return;
      _listener?.call(service, nsd.ServiceStatus.found);
    } catch (e, s) {
      _onError(e, s);
    }
  }

  @override
  Future<void> stop() async {
    final bus = _bus;
    final path = _path;
    _bus = null;
    _path = null;
    _listener = null;
    _seenOn.clear();
    await _subscription?.cancel();
    _subscription = null;
    if (bus == null) return;
    try {
      if (path != null) await bus.freeBrowser(path);
    } finally {
      await bus.close();
    }
  }
}

/// Splits Avahi's TXT records (`aay`, one `key=value` byte string each) the
/// way nsd hands them over: a bare key maps to null.
Map<String, Uint8List?> parseAvahiTxt(Iterable<Iterable<int>> records) {
  final txt = <String, Uint8List?>{};
  for (final record in records) {
    final bytes = record.toList();
    final eq = bytes.indexOf(0x3d); // '='
    if (eq < 0) {
      txt[String.fromCharCodes(bytes)] = null;
    } else {
      txt[String.fromCharCodes(bytes.sublist(0, eq))] = Uint8List.fromList(bytes.sublist(eq + 1));
    }
  }
  return txt;
}

class DBusAvahiBus implements AvahiBus {
  DBusAvahiBus() : _client = DBusClient.system();

  static const _name = 'org.freedesktop.Avahi';
  static const _server = 'org.freedesktop.Avahi.Server';
  static const _browser = 'org.freedesktop.Avahi.ServiceBrowser';

  /// AVAHI_IF_UNSPEC: every interface.
  static const _anyInterface = -1;

  /// AVAHI_PROTO_INET: IPv4 only. Trainer apps and DirCon trainers are
  /// reached over IPv4, and browsing one protocol keeps each instance from
  /// being reported twice.
  static const _ipv4 = 0;

  final DBusClient _client;
  late final _serverObject = DBusRemoteObject(_client, name: _name, path: DBusObjectPath('/'));

  @override
  late final Stream<AvahiBrowserSignal> signals = DBusSignalStream(_client, sender: _name, interface: _browser).map(
    (signal) {
      final values = signal.values;
      final isItem = (signal.name == 'ItemNew' || signal.name == 'ItemRemove') && values.length >= 5;
      return AvahiBrowserSignal(
        path: signal.path.value,
        member: signal.name,
        item: isItem
            ? AvahiItem(
                interface: values[0].asInt32(),
                protocol: values[1].asInt32(),
                name: values[2].asString(),
                type: values[3].asString(),
                domain: values[4].asString(),
              )
            : null,
        error: signal.name == 'Failure' && values.isNotEmpty ? values[0].asString() : null,
      );
    },
  );

  @override
  Future<void> connect() async {
    // Connects, and fails right here when Avahi is not running.
    await _serverObject.callMethod(_server, 'GetVersionString', const [], replySignature: DBusSignature('s'));
  }

  @override
  Future<String> createBrowser(String type) async {
    final response = await _serverObject.callMethod(
      _server,
      'ServiceBrowserNew',
      [DBusInt32(_anyInterface), DBusInt32(_ipv4), DBusString(type), DBusString('local'), DBusUint32(0)],
      replySignature: DBusSignature('o'),
    );
    return response.returnValues.first.asObjectPath().value;
  }

  @override
  Future<nsd.Service> resolve(AvahiItem item) async {
    final response = await _serverObject.callMethod(
      _server,
      'ResolveService',
      [
        DBusInt32(item.interface),
        DBusInt32(item.protocol),
        DBusString(item.name),
        DBusString(item.type),
        DBusString(item.domain),
        DBusInt32(_ipv4),
        DBusUint32(0),
      ],
      replySignature: DBusSignature('iissssisqaayu'),
    );
    final values = response.returnValues;
    return nsd.Service(
      name: values[2].asString(),
      type: values[3].asString(),
      host: values[5].asString(),
      addresses: [InternetAddress(values[7].asString())],
      port: values[8].asUint16(),
      txt: parseAvahiTxt(values[9].asArray().map((record) => record.asByteArray())),
    );
  }

  @override
  Future<void> freeBrowser(String path) async {
    await DBusRemoteObject(_client, name: _name, path: DBusObjectPath(path)).callMethod(
      _browser,
      'Free',
      const [],
      replySignature: DBusSignature(''),
    );
  }

  @override
  Future<void> close() => _client.close();
}
