// Linux has no nsd implementation; DirCon trainers are browsed through
// Avahi over D-Bus instead. The bus is faked here — what matters is how
// browser signals turn into found/lost services.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bike_control/services/mdns/avahi_service_browser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart' as nsd;

const _type = '_wahoo-fitness-tnp._tcp';

AvahiItem _item(String name, {int interface = 2}) =>
    AvahiItem(interface: interface, protocol: 0, name: name, type: _type, domain: 'local');

class _FakeBus implements AvahiBus {
  final signalsController = StreamController<AvahiBrowserSignal>.broadcast();
  final resolved = <String, nsd.Service>{};
  final freed = <String>[];
  var closed = false;
  var browserPath = '/Client1/ServiceBrowser1';

  /// Runs inside [createBrowser], before its path is returned.
  void Function(String path)? duringCreate;

  @override
  Stream<AvahiBrowserSignal> get signals => signalsController.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<String> createBrowser(String type) async {
    duringCreate?.call(browserPath);
    return browserPath;
  }

  @override
  Future<nsd.Service> resolve(AvahiItem item) async {
    final service = resolved[item.name];
    if (service == null) throw StateError('timeout resolving ${item.name}');
    return service;
  }

  @override
  Future<void> freeBrowser(String path) async => freed.add(path);

  @override
  Future<void> close() async => closed = true;

  void emit(String member, AvahiItem item, {String? path}) =>
      signalsController.add(AvahiBrowserSignal(path: path ?? browserPath, member: member, item: item));
}

nsd.Service _service(String name) => nsd.Service(
  name: name,
  type: _type,
  host: 'kickr.local',
  port: 36866,
  addresses: [InternetAddress('192.168.178.50')],
  txt: {'ble-service-uuids': Uint8List.fromList(utf8.encode('1826'))},
);

void main() {
  late _FakeBus bus;
  late List<(String?, nsd.ServiceStatus)> events;
  late List<Object> errors;
  late AvahiServiceBrowser browser;

  setUp(() {
    bus = _FakeBus();
    events = [];
    errors = [];
    browser = AvahiServiceBrowser(bus: () => bus, onError: (e, s) => errors.add(e));
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a trainer that appears is resolved and reported found, then lost', () async {
    bus.resolved['KICKR CORE 1234'] = _service('KICKR CORE 1234');
    await browser.start(_type, (s, status) => events.add((s.name, status)));

    bus.emit('ItemNew', _item('KICKR CORE 1234'));
    await settle();
    expect(events, [('KICKR CORE 1234', nsd.ServiceStatus.found)]);

    bus.emit('ItemRemove', _item('KICKR CORE 1234'));
    await settle();
    expect(events.last, ('KICKR CORE 1234', nsd.ServiceStatus.lost));
  });

  test('the resolved service carries host, port, IPv4 address and TXT', () async {
    bus.resolved['KICKR CORE 1234'] = _service('KICKR CORE 1234');
    nsd.Service? found;
    await browser.start(_type, (s, status) => found = s);
    bus.emit('ItemNew', _item('KICKR CORE 1234'));
    await settle();

    expect(found!.port, 36866);
    expect(found!.addresses!.single.address, '192.168.178.50');
    expect(utf8.decode(found!.txt!['ble-service-uuids']!), '1826');
  });

  test('an item announced before the browser path is known is not lost', () async {
    bus.resolved['KICKR CORE 1234'] = _service('KICKR CORE 1234');
    bus.duringCreate = (path) => bus.emit('ItemNew', _item('KICKR CORE 1234'), path: path);
    await browser.start(_type, (s, status) => events.add((s.name, status)));
    await settle();
    expect(events, [('KICKR CORE 1234', nsd.ServiceStatus.found)]);
  });

  test("another browser's signals are ignored", () async {
    bus.resolved['KICKR CORE 1234'] = _service('KICKR CORE 1234');
    await browser.start(_type, (s, status) => events.add((s.name, status)));
    bus.emit('ItemNew', _item('KICKR CORE 1234'), path: '/Client1/ServiceBrowser9');
    await settle();
    expect(events, isEmpty);
  });

  test('a trainer seen on two interfaces is lost only when gone from both', () async {
    bus.resolved['KICKR CORE 1234'] = _service('KICKR CORE 1234');
    await browser.start(_type, (s, status) => events.add((s.name, status)));
    bus.emit('ItemNew', _item('KICKR CORE 1234', interface: 2));
    bus.emit('ItemNew', _item('KICKR CORE 1234', interface: 3));
    await settle();

    bus.emit('ItemRemove', _item('KICKR CORE 1234', interface: 2));
    await settle();
    expect(events.where((e) => e.$2 == nsd.ServiceStatus.lost), isEmpty);

    bus.emit('ItemRemove', _item('KICKR CORE 1234', interface: 3));
    await settle();
    expect(events.last, ('KICKR CORE 1234', nsd.ServiceStatus.lost));
  });

  test('a service that cannot be resolved is reported as an error, not found', () async {
    await browser.start(_type, (s, status) => events.add((s.name, status)));
    bus.emit('ItemNew', _item('Unreachable'));
    await settle();
    expect(events, isEmpty);
    expect(errors, hasLength(1));
  });

  test('a removal racing its resolve does not resurrect the trainer', () async {
    final gate = Completer<void>();
    final slowBus = _SlowBus(gate)..resolved['KICKR CORE 1234'] = _service('KICKR CORE 1234');
    browser = AvahiServiceBrowser(bus: () => slowBus, onError: (e, s) => errors.add(e));
    await browser.start(_type, (s, status) => events.add((s.name, status)));
    slowBus.emit('ItemNew', _item('KICKR CORE 1234'));
    await settle();
    slowBus.emit('ItemRemove', _item('KICKR CORE 1234'));
    await settle();
    gate.complete();
    await settle();
    expect(events.where((e) => e.$2 == nsd.ServiceStatus.found), isEmpty);
  });

  test('stop frees the browser and closes the bus', () async {
    await browser.start(_type, (s, status) {});
    await browser.stop();
    expect(bus.freed, [bus.browserPath]);
    expect(bus.closed, isTrue);
  });

  test('a browser failure is reported', () async {
    await browser.start(_type, (s, status) {});
    bus.signalsController.add(AvahiBrowserSignal(path: bus.browserPath, member: 'Failure', error: 'boom'));
    await settle();
    expect(errors, hasLength(1));
  });

  group('parseAvahiTxt', () {
    test('splits key=value records and keeps value bytes', () {
      final txt = parseAvahiTxt([utf8.encode('ble-service-uuids=1826,1818'), utf8.encode('serial-number=42')]);
      expect(utf8.decode(txt['ble-service-uuids']!), '1826,1818');
      expect(utf8.decode(txt['serial-number']!), '42');
    });

    test('a bare key has a null value; an empty value stays empty', () {
      final txt = parseAvahiTxt([utf8.encode('flag'), utf8.encode('empty=')]);
      expect(txt.containsKey('flag'), isTrue);
      expect(txt['flag'], isNull);
      expect(txt['empty'], isEmpty);
    });

    test('a value may itself contain "="', () {
      final txt = parseAvahiTxt([utf8.encode('k=a=b')]);
      expect(utf8.decode(txt['k']!), 'a=b');
    });
  });
}

class _SlowBus extends _FakeBus {
  _SlowBus(this.gate);
  final Completer<void> gate;

  @override
  Future<nsd.Service> resolve(AvahiItem item) async {
    await gate.future;
    return super.resolve(item);
  }
}
