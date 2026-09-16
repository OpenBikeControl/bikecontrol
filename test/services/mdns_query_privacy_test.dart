import 'package:bike_control/services/mdns_query_privacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prop/mdns/mdns_responder.dart' show MdnsQueryLogEntry;
import 'package:prop/utils/advertised_service_registry.dart';

void main() {
  final advertised = [
    AdvertisedRecord(
      name: 'BikeControl',
      type: '_wahoo-fitness-tnp._tcp',
      port: 36867,
      address: '192.168.1.9',
      txt: const {},
    ),
  ];

  MdnsQueryLogEntry query(String source, List<String> questions, {int count = 1}) => MdnsQueryLogEntry(
    at: DateTime(2026, 7, 30),
    source: source,
    sourcePort: 5353,
    wantsUnicast: false,
    questions: questions,
    answeredUnicast: false,
    answeredMulticast: false,
    count: count,
  );

  test('keeps a PTR query for an advertised service type', () {
    final result = relevantMdnsQueries(
      [query('192.168.1.50', const ['PTR _wahoo-fitness-tnp._tcp.local'])],
      advertised: advertised,
    );
    expect(result.kept, hasLength(1));
    expect(result.droppedQueries, 0);
    expect(result.droppedHosts, 0);
  });

  test('keeps an SRV query for an advertised instance, case-insensitively', () {
    final result = relevantMdnsQueries(
      [query('192.168.1.50', const ['SRV bikecontrol._WAHOO-fitness-tnp._tcp.local'])],
      advertised: advertised,
    );
    expect(result.kept, hasLength(1));
  });

  test('keeps a subdomain of an advertised instance name', () {
    final result = relevantMdnsQueries(
      [query('192.168.1.50', const ['A Something.BikeControl._wahoo-fitness-tnp._tcp.local'])],
      advertised: advertised,
    );
    expect(result.kept, hasLength(1));
  });

  test('keeps an A query for our own host', () {
    final result = relevantMdnsQueries(
      [query('192.168.1.50', const ['A bikecontrol-1a2b.local'])],
      advertised: const [],
      hostLabel: 'bikecontrol-1a2b',
    );
    expect(result.kept, hasLength(1));
  });

  test('drops a host query when no hostLabel is given', () {
    final result = relevantMdnsQueries(
      [query('192.168.1.50', const ['A bikecontrol-1a2b.local'])],
      advertised: const [],
    );
    expect(result.kept, isEmpty);
    expect(result.droppedQueries, 1);
  });

  test('keeps the generic service-enumeration query', () {
    final result = relevantMdnsQueries(
      [query('192.168.1.50', const ['PTR _services._dns-sd._udp.local'])],
      advertised: const [],
    );
    expect(result.kept, hasLength(1));
  });

  test('drops a third-party query and folds its repeats into the dropped count', () {
    final result = relevantMdnsQueries(
      [
        query('192.168.0.5', const ['A someones-macbook.local'], count: 3),
        query('192.168.0.5', const ['PTR _airplay._tcp.local'], count: 2),
      ],
      advertised: advertised,
    );
    expect(result.kept, isEmpty);
    expect(result.droppedQueries, 5);
    // Both dropped entries share a source, so that is one host, not two.
    expect(result.droppedHosts, 1);
  });

  test('counts distinct dropped hosts, not dropped entries', () {
    final result = relevantMdnsQueries(
      [
        query('192.168.0.5', const ['PTR _airplay._tcp.local']),
        query('192.168.0.6', const ['PTR _airplay._tcp.local']),
      ],
      advertised: advertised,
    );
    expect(result.droppedHosts, 2);
  });

  test('mixed input keeps ours in order, drops and summarises the rest', () {
    final ours1 = query('192.168.1.50', const ['PTR _wahoo-fitness-tnp._tcp.local']);
    final ours2 = query('192.168.1.51', const ['PTR _services._dns-sd._udp.local']);
    final result = relevantMdnsQueries(
      [
        ours1,
        query('192.168.0.5', const ['A someones-macbook.local']),
        ours2,
        query('192.168.0.6', const ['PTR _airplay._tcp.local'], count: 4),
      ],
      advertised: advertised,
    );
    expect(result.kept, [ours1, ours2]);
    expect(result.droppedQueries, 5);
    expect(result.droppedHosts, 2);
  });
}
