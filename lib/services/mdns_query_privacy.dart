import 'package:prop/mdns/mdns_responder.dart' show MdnsQueryLogEntry;
import 'package:prop/utils/advertised_service_registry.dart';

/// The generic service-enumeration query (RFC 6763 §9) — every mDNS browser
/// sends this to discover which service types exist on the LAN. It carries no
/// third-party identifier, so keeping it is safe, and it doubles as proof a
/// browse happened at all.
const _serviceEnumerationName = '_services._dns-sd._udp.local';

/// Result of filtering an mDNS query log down to the entries that name
/// something of ours.
///
/// Support bundles (`DebugDiagnostics.toText`) leave the device and get
/// attached to support tickets. The raw query log also carries every *other*
/// device's hostname and IP that happened to query the LAN while BikeControl
/// was listening (someone's `A somebodys-macbook.local`, a stray
/// `_airplay._tcp` browse) — those are not ours to send off-device.
/// [relevantMdnsQueries] keeps only queries that name a service, instance or
/// host BikeControl itself advertises, and summarises the rest as counts
/// only, with no identifying detail.
class RelevantMdnsQueries {
  /// Queries worth showing verbatim, in their original order.
  final List<MdnsQueryLogEntry> kept;

  /// Sum of [MdnsQueryLogEntry.count] across every dropped entry — repeats
  /// included, so a continuous third-party poller is not undercounted.
  final int droppedQueries;

  /// Number of distinct [MdnsQueryLogEntry.source] addresses among the
  /// dropped entries (repeats from the same source count once).
  final int droppedHosts;

  const RelevantMdnsQueries({
    required this.kept,
    required this.droppedQueries,
    required this.droppedHosts,
  });
}

/// Filters [entries] down to the ones that name something BikeControl
/// advertises: a service type or instance in [advertised], this device's own
/// [hostLabel], or the generic `_services._dns-sd._udp.local` enumeration
/// query.
///
/// A query entry is kept iff *any* of its [MdnsQueryLogEntry.questions]
/// (e.g. `'PTR _wahoo-fitness-tnp._tcp.local'`, `'SRV
/// BikeControl._wahoo-fitness-tnp._tcp.local'`, `'A bikecontrol-1a2b.local'`)
/// names — case-insensitively — one of those. Matching is on the question's
/// name part (after the leading record-type token) and by suffix, so a
/// subdomain of an advertised name (e.g.
/// `Something.BikeControl._wahoo-fitness-tnp._tcp.local`) also counts.
/// Everything else is dropped.
RelevantMdnsQueries relevantMdnsQueries(
  List<MdnsQueryLogEntry> entries, {
  required Iterable<AdvertisedRecord> advertised,
  String? hostLabel,
}) {
  final ourNames = <String>{
    _serviceEnumerationName,
    for (final record in advertised) ...[
      '${record.type}.local'.toLowerCase(),
      '${record.name}.${record.type}.local'.toLowerCase(),
    ],
    if (hostLabel != null) '$hostLabel.local'.toLowerCase(),
  };

  bool namesOurs(String question) {
    final spaceIndex = question.indexOf(' ');
    final name = (spaceIndex == -1 ? question : question.substring(spaceIndex + 1)).toLowerCase();
    return ourNames.any((ours) => name == ours || name.endsWith('.$ours'));
  }

  final kept = <MdnsQueryLogEntry>[];
  var droppedQueries = 0;
  final droppedSources = <String>{};

  for (final entry in entries) {
    if (entry.questions.any(namesOurs)) {
      kept.add(entry);
    } else {
      droppedQueries += entry.count;
      droppedSources.add(entry.source);
    }
  }

  return RelevantMdnsQueries(
    kept: kept,
    droppedQueries: droppedQueries,
    droppedHosts: droppedSources.length,
  );
}
