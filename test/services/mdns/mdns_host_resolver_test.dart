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
}
