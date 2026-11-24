import 'dart:io';

import 'package:bike_control/services/mdns/mdns_host_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/mdns/dns_message.dart';

void main() {
  late RawDatagramSocket responder;
  final questions = <DnsQuestion>[];

  Future<void> startResponder(List<DnsRecord> Function(DnsMessage query) answer) async {
    responder = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    responder.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = responder.receive();
      if (datagram == null) return;
      final query = DnsMessage.decode(datagram.data)!;
      questions.addAll(query.questions);
      final answers = answer(query);
      if (answers.isEmpty) return;
      responder.send(
        DnsMessage(id: query.id, isResponse: true, isAuthoritative: true, answers: answers).encode(),
        datagram.address,
        datagram.port,
      );
    });
  }

  setUp(questions.clear);
  tearDown(() => responder.close());

  test('resolves a hostname whose label contains a space', () async {
    await startResponder(
      (query) => [ARecord(name: query.questions.single.name, address: '192.168.129.58', ttl: 120)],
    );

    final address = await MdnsHostResolver.resolveIPv4(
      'ELITE-JUSTO 2-01090-W.local',
      target: InternetAddress.loopbackIPv4,
      port: responder.port,
    );

    expect(address, '192.168.129.58');
    final question = questions.first;
    expect(question.name.labels, ['ELITE-JUSTO 2-01090-W', 'local']);
    expect(question.type, DnsType.a);
  });

  test('ignores answers for other names', () async {
    await startResponder(
      (_) => [ARecord(name: DnsName.fromString('Other.local'), address: '10.0.0.1', ttl: 120)],
    );

    final address = await MdnsHostResolver.resolveIPv4(
      'KICKR.local',
      target: InternetAddress.loopbackIPv4,
      port: responder.port,
      timeout: const Duration(milliseconds: 400),
    );

    expect(address, isNull);
  });

  test('gives up after the timeout when nothing answers', () async {
    await startResponder((_) => []);

    final address = await MdnsHostResolver.resolveIPv4(
      'KICKR.local',
      target: InternetAddress.loopbackIPv4,
      port: responder.port,
      timeout: const Duration(milliseconds: 400),
    );

    expect(address, isNull);
    expect(questions, isNotEmpty);
  });

  group('system resolver (iOS)', () {
    setUp(() async => startResponder((_) => const []));

    test('asks the system and sends no multicast query of its own', () async {
      final asked = <String>[];
      final address = await MdnsHostResolver.resolveIPv4(
        'KICKR-CORE-A5D9.local',
        target: InternetAddress.loopbackIPv4,
        port: responder.port,
        useSystemResolver: true,
        systemLookup: (host) async {
          asked.add(host);
          return [InternetAddress('fe80::1'), InternetAddress('192.168.1.40')];
        },
      );

      expect(address, '192.168.1.40');
      expect(asked, ['KICKR-CORE-A5D9.local']);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(questions, isEmpty);
    });

    test('a name the system cannot resolve gives null, not an error', () async {
      final address = await MdnsHostResolver.resolveIPv4(
        'gone.local',
        useSystemResolver: true,
        systemLookup: (host) async => throw const SocketException('Failed host lookup'),
      );

      expect(address, isNull);
    });

    test('a lookup that never answers gives null after the timeout', () async {
      final address = await MdnsHostResolver.resolveIPv4(
        'slow.local',
        timeout: const Duration(milliseconds: 50),
        useSystemResolver: true,
        systemLookup: (host) => Future<List<InternetAddress>>.delayed(const Duration(seconds: 5), () => const []),
      );

      expect(address, isNull);
    });
  });
}
