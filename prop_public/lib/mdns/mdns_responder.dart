//INFO: This is a stub - contact me if you need the full implementation.
//
// The full implementation is an in-process mDNS responder. This stub keeps
// only the query-log entry the app renders in its diagnostics.

/// One mDNS query this responder saw, with repeats folded together.
class MdnsQueryLogEntry {
  /// When this query was last seen. Updated on every repeat.
  DateTime at;

  /// Querier address, e.g. '192.168.178.50'.
  final String source;

  final int sourcePort;

  /// Whether the query asked for a unicast reply (the QU bit, RFC 6762 §5.4).
  final bool wantsUnicast;

  /// Human-readable questions, e.g. 'PTR _wahoo-fitness-tnp._tcp.local'.
  final List<String> questions;

  final bool answeredUnicast;
  final bool answeredMulticast;

  /// How many times this exact query was seen in a row.
  int count;

  MdnsQueryLogEntry({
    required this.at,
    required this.source,
    required this.sourcePort,
    required this.wantsUnicast,
    required this.questions,
    required this.answeredUnicast,
    required this.answeredMulticast,
    this.count = 1,
  });

  String get reply => '';

  @override
  String toString() => '$source:$sourcePort';
}
