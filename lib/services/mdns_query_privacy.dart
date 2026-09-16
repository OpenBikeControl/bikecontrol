import 'package:prop/mdns/mdns_responder.dart' show MdnsQueryLogEntry;
import 'package:prop/utils/advertised_service_registry.dart';

/// The generic service-enumeration query (RFC 6763 §9) — every mDNS browser
/// sends this to discover which service types exist on the LAN. It carries no
/// third-party identifier, so keeping it is safe, and it doubles as proof a
/// browse happened at all.
const _serviceEnumerationName = '_services._dns-sd._udp.local';

/// Builds the set of names BikeControl advertises and matches individual mDNS
/// question strings against it. Shared by [relevantMdnsQueries] (which
/// question) and [ourQuestions] (which questions *within* one query), so both
/// use the exact same definition of "ours".
class _OwnNameMatcher {
  final Set<String> _ourNames;

  _OwnNameMatcher({required Iterable<AdvertisedRecord> advertised, String? hostLabel})
    : _ourNames = {
        _serviceEnumerationName,
        for (final record in advertised) ...[
          '${record.type}.local'.toLowerCase(),
          '${record.name}.${record.type}.local'.toLowerCase(),
        ],
        if (hostLabel != null) '$hostLabel.local'.toLowerCase(),
      };

  /// Whether [question] (e.g. `'PTR _wahoo-fitness-tnp._tcp.local'`, `'SRV
  /// BikeControl._wahoo-fitness-tnp._tcp.local'`, `'A bikecontrol-1a2b.local'`)
  /// names one of ours — case-insensitively, matching the question's name
  /// part (after the leading record-type token) and by suffix, so a
  /// subdomain of an advertised name (e.g.
  /// `Something.BikeControl._wahoo-fitness-tnp._tcp.local`) also counts.
  bool namesOurs(String question) {
    final spaceIndex = question.indexOf(' ');
    final name = (spaceIndex == -1 ? question : question.substring(spaceIndex + 1)).toLowerCase();
    return _ourNames.any((ours) => name == ours || name.endsWith('.$ours'));
  }
}

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
  /// Queries worth showing, in their original order. A kept entry may still
  /// bundle third-party questions in the same packet (real browsers often ask
  /// for several services, or an unrelated host, in one query) — use
  /// [ourQuestions] to narrow an entry down to the ones actually safe to
  /// render.
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
/// A query entry is kept iff *any* of its [MdnsQueryLogEntry.questions] names
/// one of ours (see [_OwnNameMatcher.namesOurs]); everything else is dropped.
RelevantMdnsQueries relevantMdnsQueries(
  List<MdnsQueryLogEntry> entries, {
  required Iterable<AdvertisedRecord> advertised,
  String? hostLabel,
}) {
  final matcher = _OwnNameMatcher(advertised: advertised, hostLabel: hostLabel);

  final kept = <MdnsQueryLogEntry>[];
  var droppedQueries = 0;
  final droppedSources = <String>{};

  for (final entry in entries) {
    if (entry.questions.any(matcher.namesOurs)) {
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

/// The subset of [entry]'s questions that name something BikeControl
/// advertises (or the generic enumeration query) — i.e. the ones safe to
/// render verbatim.
///
/// A single mDNS packet often bundles several questions: a real browser (an
/// Apple TV, say) asks `PTR _airplay._tcp.local, PTR _raop._tcp.local, PTR
/// _wahoo-fitness-tnp._tcp.local` together, and occasionally an unrelated `A
/// other-host.local` rides along in the same query. [relevantMdnsQueries]
/// only decides whether the *entry* is kept (because at least one question
/// names ours); this narrows a kept entry down further so a caller can render
/// only the question(s) that are actually ours, hiding third-party ones the
/// same query happened to carry.
List<String> ourQuestions(
  MdnsQueryLogEntry entry, {
  required Iterable<AdvertisedRecord> advertised,
  String? hostLabel,
}) {
  final matcher = _OwnNameMatcher(advertised: advertised, hostLabel: hostLabel);
  return entry.questions.where(matcher.namesOurs).toList();
}
